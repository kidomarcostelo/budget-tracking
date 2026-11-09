# Code Review: PR #34

- **Target PR:** [#34](https://github.com/kidomarcostelo/budget-tracking/pull/34) (`feat/align-preview-demo-data-banks` → `main`)
- **Tracking Issue:** [#27](https://github.com/kidomarcostelo/budget-tracking/issues/27) (`.scratch/BT-11-align-preview-demo-data-banks/task.md`)
- **Commit:** `bc5b9de7 feat(database): align preview demo data with Philippine banks and PHP currency`
- **Review Date:** 2026-11-09T21:46:35+08:00

---

## Standards

### Documented Standards Violations (Hard)

- **`docs/architecture.md` (Directory Structure & Layering Boundaries)**
  - **Location**: `budget/lib/database/generatePreviewData.dart:8`
  - **Hunk**:
    ```dart
    +import 'package:budget/pages/addWalletPage.dart';
    ```
  - **Violation**: Section 1 (`Directory Structure`) delineates `lib/database/` for data layer and DAOs, and `lib/pages/` for screen-level UI widgets. Importing a UI page into a database utility inverts layer dependencies. `initializeBalanceCorrectionCategory()` performs core database categorization and should reside in `lib/database/tables.dart` or `lib/functions.dart`, not be imported from a UI page widget.

---

### Baseline Smells (Judgement Calls)

1. **Duplicated Code** — `budget/lib/database/generatePreviewData.dart:627-742`
   ```dart
   // Self-transfer 1: UnionBank -> MariBank
   int? ubInRowId = await database.createOrUpdateTransaction(...);
   if (ubInRowId != null) { final t = await database.getTransactionFromRowId(ubInRowId); ubInPk = t.transactionPk; }
   await database.createOrUpdateTransaction(..., Transaction(pairedTransactionFk: ubInPk, ...));
   ```
   *Analysis*: The multi-step orchestration (inserting an inbound transfer, resolving its PK from the returned row ID, and inserting the outbound transfer referencing `pairedTransactionFk`) is duplicated verbatim across 3 self-transfer pairs (UnionBank → MariBank, MariBank → Maya, GoTyme → MariBank).
   *Fix*: Extract a local helper (e.g. `_seedPairedTransfer(...)`) to remove ~80 lines of duplicate boilerplate.

2. **Feature Envy** — `budget/lib/database/generatePreviewData.dart:8, 88`
   ```dart
   await initializeBalanceCorrectionCategory();
   ```
   *Analysis*: `generatePreviewData.dart` reaches into `addWalletPage.dart` to invoke category initialization logic that directly queries and mutates the database.
   *Fix*: Relocate `initializeBalanceCorrectionCategory()` to `lib/database/tables.dart` or `lib/functions.dart`.

#### Conformance Highlights
- Commit metadata adheres to `AGENTS.md` (author: `kidomarcostelo@gmail.com`, conventional commit format, no `Co-authored-by` trailers).
- No `// ignore:` or `// ignore_for_file:` suppressions added (`CONSTRAINTS.md`).
- `preview_data_test.dart` cleanly tests generation and teardown invariants without `@Skip` annotations.

---

## Spec

### (a) Missing or Partial Requirements

1. **Wallet Icons Missing**
   > Spec: *"Assign appropriate theme colors and icons matching brand palettes."*
   Brand hex colors were properly configured, but `iconName: null` was left on all 4 seed wallets (`UnionBank`, `MariBank`, `GoTyme`, `Maya`), leaving brand icons unassigned.

2. **Global Preview Currency Setting**
   > Spec: *"Set default preview currency to `PHP` and prefill `accountOwnerName` with `Kid Omar Costelo` to support owner-recognition self-transfer testing."*
   While individual preview wallets are set to `currency: "php"`, no explicit preview preference/setting was set for currency under settings (only `accountOwnerName` was updated via `updateSettings`).

---

### (b) Scope Creep (Unasked-for Behaviour)

1. **Additional GoTyme → MariBank Self-Transfer**
   > Spec: *"Self-transfers: Inter-bank InstaPay transfers between UnionBank and MariBank/Maya."*
   The diff introduces a third self-transfer pair between GoTyme and MariBank (`GoTyme transfer-out` / `MariBank transfer-in`, ₱3,600), beyond the requested UnionBank ↔ MariBank/Maya transfers.

2. **Unspecified Travel & Dining Transactions**
   > Spec: *"Merchant purchases: 7-Eleven, Starbucks, Mercury Drug, Grab, Shopee."*
   The diff adds additional specific merchants not listed in the spec: "Cebu Pacific Flight" (₱4,500), "Resort Hotel Booking" (₱8,200), and "Jollibee" (₱650) to replace upstream vacation items.

3. **Randomized Transaction Scaling & Side Income**
   > Spec: *"Populate transactions matching the user's verified bank samples (`.scratch/bank-samples/`)"*
   The diff modifies the background loops generating filler transactions (scaling amounts to ₱150–₱1,200 across all 4 wallets and injecting randomized "Side Income" of ₱2,500–₱7,500 into wallet `0` or `10`).

---

### (c) Implemented but Looks Wrong

1. **Raw Merchant Name Typo on 7-Eleven**
   > Spec: *"Merchant purchases: 7-Eleven, Starbucks, Mercury Drug, Grab, Shopee."*
   The transaction was seeded with `name: "7-Eleveb-ST4594"`. While this matches the raw title in `.scratch/bank-samples/google-pay/sample-notification.md`, other seeded merchants use normalized display names ("Starbucks Coffee", "Shopee", "Mercury Drug"). In the UI, this displays as a misspelling ("7-Eleveb").

2. **Destructive Reset of `accountOwnerName` on Teardown**
   > Spec: *"Ensure `deletePreviewData()` deletes all newly registered preview wallet PKs and safely restores default state."*
   `deletePreviewData()` unconditionally resets `accountOwnerName` to `""`, wiping out any preexisting owner name configured before preview activation rather than restoring its prior state.

---

## Summary

- **Standards:** 1 hard violation, 2 baseline smells (Worst: layering violation importing UI widget `addWalletPage.dart` into `lib/database/generatePreviewData.dart`).
- **Spec:** 7 findings (Worst: destructive reset of `accountOwnerName` erasing preexisting user preferences upon teardown, and unassigned wallet icons).
