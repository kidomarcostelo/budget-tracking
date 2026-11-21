# BT-0021 Research & Implementation Plan
## Tag Transfers to Savings Objectives in `TransferBalancePopup`

---

## Research Findings

### 1. `TransferBalancePopup` Widget

**File:** [`budget/lib/pages/addWalletPage.dart`](../budget/lib/pages/addWalletPage.dart)

#### Widget declaration (lines 998–1024)
```dart
class TransferBalancePopup extends StatefulWidget {
  const TransferBalancePopup({
    required this.wallet,
    required this.allowEditWallet,
    this.walletTo,
    this.showAllEditDetails = false,
    this.initialAmount,
    this.initialDate,
    this.initialTitle,
    this.initialNote,
    this.initialObjectiveLoanPk,   // ← existing loan-objective path
    this.initialIsNegative,
    super.key,
  });
  ...
  final String? initialObjectiveLoanPk;
```

The widget already carries `initialObjectiveLoanPk` for the **loan** objective path, but has **no equivalent for savings (`ObjectiveType.goal`) objectives**.

#### State class (lines 1027–1060)
State fields declared:
- `enteredAmount`, `isNegative`, `walletFrom`, `walletTo`, `selectedTime`, `selectedDateTime`, `selectedTitle`, `walletForCurrency`
- **No `selectedObjectivePk` state field exists yet.**

#### `walletSelector` helper (lines 1062–1110)
Renders a tappable bordered chip. Used twice in `build()`: once for `walletFrom`, once for `walletTo`.

#### `transferBalance()` method (lines 1112–1227)

The method:
1. Converts `enteredAmount` to primary currency (line 1117).
2. Resolves `walletFrom`; if `walletTo == null`, opens a wallet picker and returns early (lines 1122–1137).
3. Guard against same wallet (lines 1139–1150).
4. Builds a note string (line 1156).
5. **First call** (lines 1164–1175): creates the **destination** (`walletTo`) transaction — a **positive** (income) entry. This is the entry that should be tagged with the savings objective. Currently called **without** `objectiveLoanPk` or any objective param:
   ```dart
   String? transactionPk = await createCorrectionTransaction(
     enteredAmount * getAmountRatioWalletTransferTo(allWallets, walletTo!.walletPk),
     walletTo!,
     note: note,
     dateTime: selectedDateTimeSetToNow.add(Duration(seconds: 1)),
     title: ...,
   );
   ```
6. **Second call** (lines 1177–1190): creates the **source** (`walletFrom`) transaction — a **negative** (expense) entry. This is tagged with `objectiveLoanPk` (the existing loan path):
   ```dart
   await createCorrectionTransaction(
     objectiveLoanPk: widget.initialObjectiveLoanPk,
     pairedTransactionFk: transactionPk,
     enteredAmount * getAmountRatioWalletTransferFrom(allWallets, walletFrom.walletPk),
     walletFrom,
     note: note,
     dateTime: selectedDateTimeSetToNow,
     title: ...,
   );
   ```

> **Key observation:** Only the `walletFrom` call currently receives `objectiveLoanPk`. The `walletTo` call receives nothing related to objectives. BT-0021 adds `objectivePk` to the **`walletTo` call only**.

#### `build()` layout (lines 1230–1527)

Structure of the `build()` method:

```
PopupFramework(
  title: "transfer-balance".tr(),
  outsideExtraWidget: OutsideExtraWidgetIconButton(      // edit icon (pencil)
    onPressed: () => openBottomSheet(
      PopupFramework(
        child: Column([
          editTransferDetails,       // TextInput + DateButton
          SizedBox(height: 13),
          Button("set-details"),
        ]),
        title: "transaction-details".tr(),
      )
    )
  ),
  child: Column([
    if (widget.showAllEditDetails) Padding(child: editTransferDetails),
    SizedBox(height: 13),
    Wrap([walletSelector(walletFrom), arrow, walletSelector(walletTo)]),
    SelectAmount(...),
    Row([
      Expanded(Button("transfer-amount", onTap: transferBalance)),
    ]),
  ]),
)
```

`editTransferDetails` is a local `Widget` variable (lines 1231–1261) containing only:
- `TextInput` for title
- `DateButton` for date/time

**`SelectAddedBudget` is NOT present** in `TransferBalancePopup`'s `build()` at all. The search across the entire codebase confirms `SelectAddedBudget` only appears in `AddTransactionPage` (lines 942, 1500).

**`HorizontalBreakAbove`** is similarly **not used** in `addWalletPage.dart` — it's internal to `SelectObjective`'s own build when `horizontalBreak: true`.

---

### 2. `createCorrectionTransaction` Function

**File:** [`budget/lib/pages/addWalletPage.dart`](../budget/lib/pages/addWalletPage.dart), lines 961–996

#### Full signature (lines 961–969)
```dart
Future<String?> createCorrectionTransaction(
  double amount,
  TransactionWallet wallet, {
  String? note,
  DateTime? dateTime,
  String? title,
  String? pairedTransactionFk,
  String? objectiveLoanPk,       // ← loan objective only
}) async {
```

#### Body (lines 970–995)
```dart
await initializeBalanceCorrectionCategory();

int? rowId = await database.createOrUpdateTransaction(
  insert: true,
  updateSharedEntry: false,
  Transaction(
    pairedTransactionFk: pairedTransactionFk,
    transactionPk: "-1",
    name: title ?? "",
    amount: amount,
    note: note ?? "",
    categoryFk: "0",              // ← balance correction sentinel
    walletFk: wallet.walletPk,
    dateCreated: dateTime ?? DateTime.now(),
    income: amount > 0,
    paid: true,
    skipPaid: false,
    objectiveLoanFk: objectiveLoanPk,  // ← only objectiveLoanFk set
    // objectiveFk is NOT set — this is the gap BT-0021 fills
  ),
);
```

**Confirmed:** `objectiveFk` is **not set** anywhere in `createCorrectionTransaction`. The function only sets `objectiveLoanFk`.

#### All callers of `createCorrectionTransaction` (codebase-wide)
Search confirms `createCorrectionTransaction` is **only defined and called within `addWalletPage.dart`**:
- Line 940: balance correction via "correct total balance" flow (not a transfer — no objective)
- Line 1164: `walletTo` transfer call (BT-0021 target)
- Line 1177: `walletFrom` transfer call (existing `objectiveLoanPk`)
- Line 1198: commented-out transfer fee call

There are **no other callers** in the codebase. Adding the `objectivePk` optional parameter is fully backwards-compatible.

---

### 3. `Transaction` Schema — `objectiveFk` Column

**File:** [`budget/lib/database/tables.dart`](../budget/lib/database/tables.dart), lines 331–332

```dart
TextColumn get objectiveFk =>
    text().references(Objectives, #objectivePk).nullable()();
```

- Type: `TextColumn`, nullable, FK referencing `Objectives.objectivePk`.
- **Confirmed exists** in the schema.

Also confirmed (line 981 of `addWalletPage.dart`):
```dart
categoryFk: "0",
```
The sentinel `"0"` marks balance correction / transfer entries.

---

### 4. `SelectObjective` Widget

**File:** [`budget/lib/pages/addTransactionPage.dart`](../budget/lib/pages/addTransactionPage.dart), lines 3196–3309

#### Constructor signature (lines 3197–3206)
```dart
const SelectObjective({
  required this.setSelectedObjective,  // Function(String?) — required
  this.selectedObjectivePk,            // String? — optional, drives selection display
  this.extraHorizontalPadding,         // double? — optional
  this.wrapped,                        // bool? — optional
  this.horizontalBreak = false,        // bool — defaults false
  required this.objectiveType,         // ObjectiveType — required (goal | loan)
  this.setSelectedIncome,              // Function(bool)? — only for loan objectives
  super.key,
});
```

#### Embedding pattern for `ObjectiveType.goal` (lines 948–954)
```dart
SelectObjective(
  setSelectedObjective: setSelectedObjectivePk,
  selectedObjectivePk: selectedObjectivePk,
  extraHorizontalPadding: 13,
  wrapped: false,
  objectiveType: ObjectiveType.goal,
),
```

The widget renders a `SelectChips` row. If there are **no goals in the database**, it returns `Container()` (line 3239), so it's **invisible when unused** — no need to guard its display.

The `horizontalBreak` param controls `HorizontalBreakAbove`, which only matters in double-column layouts (tablets/desktops). For the popup context, `horizontalBreak` can be left at its default `false`.

---

### 5. `watchTotalTowardsObjective` Query

**File:** [`budget/lib/database/tables.dart`](../budget/lib/database/tables.dart), lines 5864–5887

```dart
Stream<double?> watchTotalTowardsObjective(
    AllWallets allWallets, Objective objective) {
  ...
  query = selectOnly(transactions)
    ..addColumns([totalAmt])
    ..where((objective.type == ObjectiveType.loan
            ? transactions.objectiveLoanFk.equals(objective.objectivePk)
            : transactions.objectiveFk.equals(objective.objectivePk)) &  // ← filters by objectiveFk
        transactions.pending.equals(false) &
        transactions.walletFk.equals(wallet.walletPk));
```

**Confirmed:**
- For `ObjectiveType.goal`, the query filters `transactions.objectiveFk.equals(objective.objectivePk)`.
- It does **NOT** filter by `categoryFk`. Therefore balance correction transactions (`categoryFk: "0"`) with `objectiveFk` set **will be counted** toward the savings goal total.
- The only additional filters are `paid = true` (line 5869) and `pending = false` — both of which `createCorrectionTransaction` satisfies (`paid: true`, `skipPaid: false`).

**Conclusion:** Setting `objectiveFk` on the destination transfer transaction is sufficient for the savings progress bar to update automatically.

---

### 6. `watchTotalOfBudget` — Balance Correction Exclusion

**File:** [`budget/lib/database/tables.dart`](../budget/lib/database/tables.dart), lines 6693–6760

The budget total query applies (line 6743):
```dart
onlyShowIfNotBalanceCorrection(transactions, isIncome) &
```

Where (lines 6485–6489):
```dart
Expression<bool> onlyShowIfNotBalanceCorrection(
    $TransactionsTable tbl, bool? isIncome) {
  return ((tbl.categoryFk.equals("0").not()) |
      (isIncome == null ? Constant(true) : Constant(false)));
}
```

**Confirmed:** The budget total **strictly excludes** `categoryFk = "0"` entries (unless `isIncome` is null, i.e., net-spending view). An objective-tagged transfer transaction (`categoryFk: "0"`) will **never** be counted in any Budget total. This validates the design decision: we must tag at the **Objective level** (`objectiveFk`), not via Budget, because Budgets hard-exclude balance corrections.

---

### 7. `SelectAddedBudget` in `TransferBalancePopup`

**Confirmed absent.** The `addWalletPage.dart` contains no reference to `SelectAddedBudget` or `HorizontalBreakAbove`. The transfer popup is a compact popup, not a full-page form. The `SelectObjective` widget should be placed directly in the main `child:` Column of the `PopupFramework`, **after the `Wrap` wallet-selector row** and **before the `SelectAmount` block** — matching the logical "what this transfer is for" position.

---

### 8. Localization

The `SelectObjective` widget itself handles its own chip labels using the existing `"no-goal".tr()` key (line 3271), which is defined in `translations.csv` line 638:

```
"no-goal","No goal","Pas d'objectif",...
```

No new translation key is needed **for the `SelectObjective` widget itself** — it already renders correctly. However, a label above or alongside the selector in the popup (e.g., "Goal" or "Savings goal") would ideally reuse an existing key. The key `"savings-goal"` exists (translations.csv line 608):

```
"savings-goal","Savings goal","Objectif d'épargne",...
```

If we want to add a visual header above the chip row (optional — `SelectObjective` renders without one already), `"savings-goal".tr()` is available. The minimum change requires **no new localization key**.

---

### 9. `onlyShowIfFollowsFilters` — `includeAddedToObjective`

**File:** [`budget/lib/database/tables.dart`](../budget/lib/database/tables.dart), lines 6307–6315

```dart
Expression<bool> includeAddedToObjective = budgetTransactionFilters
            ?.contains(BudgetTransactionFilters.addedToObjective) == false
    ? Constant(
          isFilterSelectedWithDefaults(budgetTransactionFilters,
              BudgetTransactionFilters.addedToObjective),
        ) |
        (tbl.objectiveFk.isNull())
    : Constant(true);
```

When `addedToObjective` is NOT in the budget's filter list (the default for most budgets), the expression resolves to:
```
isFilterSelectedWithDefaults(...) | (objectiveFk IS NULL)
```

If `isFilterSelectedWithDefaults` returns `false` (the typical default), this becomes:
```
false | (objectiveFk IS NULL)
```
which **excludes** transactions where `objectiveFk IS NOT NULL`.

**However**, the entire `onlyShowIfFollowsFilters` filter is applied **in addition to** `onlyShowIfNotBalanceCorrection`. Since balance corrections (`categoryFk: "0"`) are already excluded by `onlyShowIfNotBalanceCorrection` before `onlyShowIfFollowsFilters` is evaluated in `watchTotalOfBudget`, the `includeAddedToObjective` filter is irrelevant for our transfer transactions — they're already excluded by `categoryFk = "0"`.

**Conclusion:** Objective-tagged transfers will **never** pollute Budget totals. Objective progress tracking is clean and isolated.

---

## Implementation Plan

### Step 1 — Extend `createCorrectionTransaction` signature

**File:** [`budget/lib/pages/addWalletPage.dart`](../budget/lib/pages/addWalletPage.dart), line 961

Add an optional `String? objectivePk` parameter and populate `objectiveFk` in the `Transaction` constructor.

**Before (lines 961–988):**
```dart
Future<String?> createCorrectionTransaction(
  double amount,
  TransactionWallet wallet, {
  String? note,
  DateTime? dateTime,
  String? title,
  String? pairedTransactionFk,
  String? objectiveLoanPk,
}) async {
  await initializeBalanceCorrectionCategory();

  int? rowId = await database.createOrUpdateTransaction(
    insert: true,
    updateSharedEntry: false,
    Transaction(
      pairedTransactionFk: pairedTransactionFk,
      transactionPk: "-1",
      name: title ?? "",
      amount: amount,
      note: note ?? "",
      categoryFk: "0",
      walletFk: wallet.walletPk,
      dateCreated: dateTime ?? DateTime.now(),
      income: amount > 0,
      paid: true,
      skipPaid: false,
      objectiveLoanFk: objectiveLoanPk,
    ),
  );
```

**After:**
```dart
Future<String?> createCorrectionTransaction(
  double amount,
  TransactionWallet wallet, {
  String? note,
  DateTime? dateTime,
  String? title,
  String? pairedTransactionFk,
  String? objectiveLoanPk,
  String? objectivePk,            // ← NEW
}) async {
  await initializeBalanceCorrectionCategory();

  int? rowId = await database.createOrUpdateTransaction(
    insert: true,
    updateSharedEntry: false,
    Transaction(
      pairedTransactionFk: pairedTransactionFk,
      transactionPk: "-1",
      name: title ?? "",
      amount: amount,
      note: note ?? "",
      categoryFk: "0",
      walletFk: wallet.walletPk,
      dateCreated: dateTime ?? DateTime.now(),
      income: amount > 0,
      paid: true,
      skipPaid: false,
      objectiveLoanFk: objectiveLoanPk,
      objectiveFk: objectivePk,   // ← NEW
    ),
  );
```

**Impact on existing callers:**
- Line 940 (balance correction path): no `objectivePk` passed → `null` → no change in behavior. ✅
- Line 1177 (`walletFrom` transfer call): no `objectivePk` passed → `null`. ✅
- Line 1164 (`walletTo` transfer call): will pass `objectivePk: selectedObjectivePk` (see Step 4). ✅
- Commented-out fee call (line 1198): irrelevant. ✅

---

### Step 2 — Add `selectedObjectivePk` state field to `_TransferBalancePopupState`

**File:** [`budget/lib/pages/addWalletPage.dart`](../budget/lib/pages/addWalletPage.dart), lines 1027–1060

Add a new mutable state field after the existing fields (after line 1047):

```dart
String? selectedObjectivePk;
```

No need to initialize from a widget param (there's no `initialObjectivePk` added to the widget's constructor — the selector starts with nothing selected, matching `AddTransactionPage` behavior). If a future caller needs pre-population, an `initialObjectivePk` widget param can be added then.

---

### Step 3 — Embed `SelectObjective` in `build()`

**File:** [`budget/lib/pages/addWalletPage.dart`](../budget/lib/pages/addWalletPage.dart), lines 1298–1525

**Placement rationale:**

The `child: Column(...)` of `PopupFramework` currently reads:
```
[optional editTransferDetails,]
SizedBox(height: 13),
Wrap([walletFrom, arrow, walletTo]),
SelectAmount(...),
Row([Button("transfer-amount")]),
```

The `SelectObjective` widget should go **between the `Wrap` wallet-selector row and the `SelectAmount` block**, positioned after `SizedBox(height: 13)` and the `Wrap` — analogous to how `AddTransactionPage` places it after the category/wallet selection and before the amount entry. This placement is semantically correct ("what goal is this transfer for?") and visually unobtrusive (the widget returns `Container()` when no goals exist, so users without savings goals see nothing extra).

Do **not** put it inside `editTransferDetails`, because `editTransferDetails` is also shown in the bottom sheet opened by the edit icon, and that sheet is a quick "set title/date" flow — mixing in the objective selector there would be confusing.

Do **not** restrict it to `widget.showAllEditDetails == true`. The objective selector should be accessible in both modes (default popup and full-edit mode).

**Edit to `build()` — insert after the closing `),` of the `Wrap(...)` block (after line 1358):**

```dart
// After the Wrap([walletFrom, arrow, walletTo]) block:
SelectObjective(
  setSelectedObjective: (String? pk) {
    setState(() {
      selectedObjectivePk = pk;
    });
  },
  selectedObjectivePk: selectedObjectivePk,
  objectiveType: ObjectiveType.goal,
),
```

The widget requires the import of `addTransactionPage.dart` or the class being in scope — verify that `SelectObjective` is accessible from `addWalletPage.dart`. If it isn't yet, add an import:
```dart
import 'package:budget/pages/addTransactionPage.dart';
```

Check whether this import already exists:
```
grep -n "addTransactionPage" budget/lib/pages/addWalletPage.dart
```
*(Run this check before writing the code — add the import only if missing.)*

---

### Step 4 — Pass `objectivePk` in `transferBalance()`

**File:** [`budget/lib/pages/addWalletPage.dart`](../budget/lib/pages/addWalletPage.dart), lines 1164–1175

Modify the **first** (destination / `walletTo`) `createCorrectionTransaction` call only:

**Before:**
```dart
String? transactionPk = await createCorrectionTransaction(
  enteredAmount *
      getAmountRatioWalletTransferTo(allWallets, walletTo!.walletPk),
  walletTo!,
  note: note,
  dateTime: selectedDateTimeSetToNow.add(Duration(seconds: 1)),
  title: selectedTitle == ""
      ? (allWallets.indexedByPk[walletTo!.walletPk]!.name +
          " " +
          (isNegative ? "transfer-out".tr() : "transfer-in".tr()))
      : selectedTitle,
);
```

**After:**
```dart
String? transactionPk = await createCorrectionTransaction(
  enteredAmount *
      getAmountRatioWalletTransferTo(allWallets, walletTo!.walletPk),
  walletTo!,
  note: note,
  dateTime: selectedDateTimeSetToNow.add(Duration(seconds: 1)),
  title: selectedTitle == ""
      ? (allWallets.indexedByPk[walletTo!.walletPk]!.name +
          " " +
          (isNegative ? "transfer-out".tr() : "transfer-in".tr()))
      : selectedTitle,
  objectivePk: selectedObjectivePk,  // ← NEW
);
```

**Why only the `walletTo` call?**

The destination transaction is the **income** entry on the savings wallet (amount > 0). This is the event that represents money arriving into the savings bucket. Tagging it with `objectiveFk` causes `watchTotalTowardsObjective` to include it in the goal progress sum, because that query sums all transactions where `objectiveFk = objective.objectivePk`.

The source (`walletFrom`) transaction represents money *leaving* the payroll wallet — it's a negative/expense entry that should not be counted toward the savings goal. It already carries `objectiveLoanPk` for the loan objective path; adding a savings `objectiveFk` to it would double-count or mismatch the goal progress.

The existing `walletFrom` call (lines 1177–1190) is **not changed**.

---

### Step 5 — Impact Analysis

| Call site | Change needed? | Reason |
|---|---|---|
| Line 940 (correct-balance path) | ❌ No | Standalone balance correction, no objective context |
| Line 1164 (`walletTo`) | ✅ Yes | Add `objectivePk: selectedObjectivePk` |
| Line 1177 (`walletFrom`) | ❌ No | Already has loan objective; leave untouched |
| Line 1198 (commented transfer fee) | ❌ N/A | Dead code |

No other files reference `createCorrectionTransaction`. **No other callers break.**

No schema migration needed — `objectiveFk` already exists in the `Transactions` table (confirmed at line 331 of `tables.dart`). No Drift migration step required.

---

### Step 6 — Localization

**No new translation key is required.**

`SelectObjective` renders its own chip list with the existing `"no-goal".tr()` label for the deselected chip. The `"savings-goal".tr()` key (CSV line 608) is available if a visual section header is desired, but the chip widget is self-labeling and consistent with how it appears in `AddTransactionPage`.

If a section heading above the `SelectObjective` row is desired in the future, add it with `"savings-goal".tr()` — but this is not required for the core feature to work.

---

### Step 7 — Tests to Write

New test file: `budget/test/transfer_objective_tagging_test.dart`

**Unit tests (pure logic — no Flutter widget tree needed):**

1. **`createCorrectionTransaction` sets `objectiveFk` when `objectivePk` is provided**
   - Mock `database.createOrUpdateTransaction` to capture the `Transaction` passed.
   - Call `createCorrectionTransaction(100, fakeWallet, objectivePk: "obj-1")`.
   - Assert captured transaction has `objectiveFk == "obj-1"`.

2. **`createCorrectionTransaction` leaves `objectiveFk` null when `objectivePk` is omitted**
   - Call `createCorrectionTransaction(100, fakeWallet)` (no `objectivePk`).
   - Assert `objectiveFk == null`.

3. **`createCorrectionTransaction` sets both `objectiveLoanFk` and `objectiveFk` independently**
   - Call with both `objectiveLoanPk: "loan-1"` and `objectivePk: "goal-1"`.
   - Assert `objectiveLoanFk == "loan-1"` and `objectiveFk == "goal-1"`.

**Widget/integration tests:**

4. **`TransferBalancePopup` — selecting a goal sets `selectedObjectivePk`**
   - Pump `TransferBalancePopup` with mock data.
   - Verify `SelectObjective` is rendered.
   - Simulate tapping a goal chip.
   - Assert `selectedObjectivePk` state changes to the selected goal's PK.

5. **`TransferBalancePopup` — `transferBalance()` passes `selectedObjectivePk` to `walletTo` call only**
   - Pump and configure popup (walletFrom, walletTo, amount, selectedObjectivePk = "goal-1").
   - Trigger `transferBalance()`.
   - Capture `Transaction` objects passed to `database.createOrUpdateTransaction`.
   - Assert the **income/positive** transaction (walletTo) has `objectiveFk == "goal-1"`.
   - Assert the **expense/negative** transaction (walletFrom) has `objectiveFk == null`.

6. **`TransferBalancePopup` — no goal selected → both transactions have `objectiveFk == null`**
   - Trigger `transferBalance()` without selecting a goal.
   - Assert both captured transactions have `objectiveFk == null`.

7. **`watchTotalTowardsObjective` counts balance-correction transactions tagged with `objectiveFk`**
   - Insert a `Transaction` with `categoryFk: "0"`, `objectiveFk: "goal-1"`, `paid: true`, `pending: false`.
   - Call `watchTotalTowardsObjective(allWallets, goal)`.
   - Assert the stream emits the transaction's amount (not zero).

---

## Summary of Files Changed

| File | Type of change |
|---|---|
| `budget/lib/pages/addWalletPage.dart` | Add `objectivePk` param to `createCorrectionTransaction`; add `selectedObjectivePk` state; embed `SelectObjective` in `TransferBalancePopup.build()`; pass `objectivePk` to `walletTo` call in `transferBalance()` |
| *(possibly)* `budget/lib/pages/addWalletPage.dart` | Add `import 'package:budget/pages/addTransactionPage.dart'` if not already present |
| `budget/test/transfer_objective_tagging_test.dart` | New test file (7 test cases) |

**No schema changes. No migration. No new localization keys required.**
