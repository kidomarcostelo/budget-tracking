# Task: Route recognized self-transfers directly to Transfer balance flow

**Issue Reference:** [#17](https://github.com/kidomarcostelo/budget-tracking/issues/17)  
**Status:** Open / Backlog  
**Assignee / Agent:** Unassigned  

---

## 1. Objective & Scope
- **Problem Statement:** When sharing an inter-bank self-transfer receipt (e.g. MariBank transfer of ₱9,901 to Maya where both sender and recipient resolve to owner profile "Kid Omar"), the app parses the transaction and amount, but routes to `AddTransactionPage` (Expense flow) instead of automatically opening the dual-wallet `TransferBalancePopup`.
- **Expected Behavior:** Receipts recognized as internal self-transfers must route directly to `TransferBalancePopup` with pre-filled source wallet (`walletFrom`), destination wallet (`walletTo`), amount, and notes.

---

## 2. Invariants & Constraints
- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- Do not falsely classify transfers as expenses.
- Do not trigger premature snackbars upon cancelling or dismissing pages.

---

## 3. Plan & Implementation Steps
- [ ] Debug on-device runtime execution of `SharedReceiptProcessor.processSharedImage`, `SharedReceiptProcessor.resolveTransfer`, and `SharedReceiptProcessor.isSelfTransfer` for MariBank receipts.
- [ ] Verify whether `openBottomSheet(context, TransferBalancePopup(...))` requires specific navigator contexts or timing adjustments when invoked from intent listener.
- [ ] Add regression tests validating dynamic receipt routing to `TransferBalancePopup`.

---

## 4. Verification & Testing
- [ ] Run on-device test with `messenger3.png` via Android Share.
- [ ] Verify `TransferBalancePopup` appears with `MariBank` and `Maya`.
- [ ] Verify `flutter analyze` and `flutter test`.
