# Task: Tag Balance Transfers to Savings Objectives in Transfer Popup (BT-0021)

**ID:** BT-0021  
**Issue Reference:** [#55](https://github.com/kidomarcostelo/budget-tracking/issues/55)  
**Status:** Completed (PR #56 under review)  
**Assignee / Agent:** Higher-Reasoning Agent  

---

## 1. Objective & Scope

### Problem Statement
Users saving toward financial milestones (such as an Emergency Fund or target savings) typically keep their funds in a dedicated account/wallet (e.g. digital bank, high-yield savings) separate from their primary payroll/checking account.

When transferring money between these accounts in Cashew:
1. Cashew's **Transfer Balance** popup (`TransferBalancePopup` in `budget/lib/pages/addWalletPage.dart`) only supports specifying `walletFrom`, `walletTo`, amount, title, and date. It exposes `initialObjectiveLoanPk` for loan payoffs, but has **no selector or support for savings `Objective` (Goal)**.
2. Under the hood, transfers create paired `Balance Correction` transactions (`categoryFk: "0"`). Because balance corrections are strictly excluded from income and budget calculations (`tbl.categoryFk.equals("0").not()`), transfers cannot be counted toward a Savings Budget.
3. Users cannot seamlessly move money from Payroll to an Emergency Fund wallet and have that transfer advance their Emergency Fund savings goal in a single step. To link it today, the user must make the transfer, navigate into the destination wallet's transaction list, locate the incoming transfer transaction, and manually assign the Objective.

### Expected Behavior
1. **Objective Selector in Transfer Popup:**
   - In `TransferBalancePopup`, provide an option (via `SelectObjective` chip or details sheet) to select a savings goal (`ObjectiveType.goal`).
2. **Tag Incoming Transfer Transaction:**
   - When executing `transferBalance()`, the incoming transaction (`walletTo`) receives `objectiveFk: selectedObjectivePk`.
   - The outgoing transaction (`walletFrom`) remains an untagged transfer out so the objective is credited without being canceled out.
3. **Objective Progress Updates:**
   - Cashew's `watchTotalTowardsObjective` query sums `transactions.amount` where `objectiveFk == objectivePk`. Since the incoming transaction in `walletTo` has `amount: +enteredAmount`, the savings objective progress bar immediately reflects the contribution.

---

## 2. Invariants & Constraints
- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- Use canonical domain vocabulary: `Wallet`, `Objective`, `Transaction`. Avoid terms like "Goal" or "Account" in internal architecture except where adhering to existing enum values (`ObjectiveType.goal`).
- Zero tolerance on static analysis errors or warnings (`flutter analyze`).
- No modifications to past Drift migration schemas; only add `objectiveFk` to the `createCorrectionTransaction` helper which already maps directly to the existing `transactions.objective_fk` Drift column.
- Format integrity: Dart files must pass `dart format`.

---

## 3. Scope of Changes & Implementation Seams
1. **`budget/lib/pages/addWalletPage.dart` (`TransferBalancePopup`):**
   - Add state for `String? selectedObjectivePk`.
   - Embed `SelectObjective` for `ObjectiveType.goal` in the transfer details popup.
   - Pass `objectivePk: selectedObjectivePk` to `createCorrectionTransaction` for the destination wallet (`walletTo`).
2. **`createCorrectionTransaction` (`budget/lib/pages/addWalletPage.dart`):**
   - Accept optional `String? objectivePk` parameter and populate `objectiveFk: objectivePk` on the created `Transaction`.
3. **Unit / Widget Tests:**
   - Add test cases in `budget/test/` asserting that creating a balance transfer with a selected objective sets `objectiveFk` on the destination transaction and updates `watchTotalTowardsObjective`.

---

## 4. Verification & Testing
- [x] Unit / Widget tests added or updated
- [x] Static analysis passes: `flutter analyze`
- [x] Code formatted: `dart format --output=none --set-exit-if-changed .`
- [x] All test suites pass: `flutter test`
