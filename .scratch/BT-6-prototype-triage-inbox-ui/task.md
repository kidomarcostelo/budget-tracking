# Task: Prototype the Triage Inbox UI and Review Flow

**ID:** BT-6  
**Issue Reference:** [#4](https://github.com/kidomarcostelo/budget-tracking/issues/4)  
**Parent Map:** [#2](https://github.com/kidomarcostelo/budget-tracking/issues/2)  
**Status:** In Progress (Spec & Prototype Definition)  
**Assignee:** Agent

---

## 1. Objective & Scope

- **Problem Statement:**  
  When transactions are extracted automatically from bank emails (Issue #3 / #6), push notifications, or shared receipt screenshots (Issue #8), they should not be blindly written directly to the user's primary `Transactions` table without human verification. Users need a dedicated, frictionless **Triage Inbox** review queue where unconfirmed candidates sit until approved, adjusted, or dismissed.
- **Expected Outcome:**  
  A polished, interactive Flutter UI and review flow adhering strictly to Cashew's design language, featuring:
  1. **Triage Inbox Screen / Tab:** A dedicated queue view with badge indicators (e.g. `3 pending transactions to review`) accessible from the home screen and transactions dashboard.
  2. **Triage Transaction Cards:** Expandable/interactive cards displaying:
     - Bank/Institution chip or avatar (e.g. BDO, UnionBank, GCash, Maya, GoTyme).
     - Transaction amount formatted with the account/wallet currency and ISO sign.
     - Extracted title/merchant name (with quick inline edit).
     - Transaction type selector: **Expense** vs **Income** vs **Transfer** (with destination wallet selector when Transfer is chosen).
     - Proposed `Category` selector chip (pre-filled by scanner template or past transaction association).
     - Proposed `Wallet` selector chip (pre-filled from account number / bank match).
     - Collapsible **Source Snippet** card showing the raw email excerpt or OCR bounding box for instant user verification.
  3. **One-Tap Quick Actions:**
     - **Approve / Confirm:** Commits candidate to Drift `Transactions` table and marks triage record as approved.
     - **Dismiss / Reject:** Removes candidate from queue (marks dismissed).
     - **Split Categories (1:N):** Opens category split modal (bridges to Issue #5).
  4. **Batch Review Bar:**
     - "Approve All Verified": Bulk commits all cards whose merchant, amount, category, and wallet are confident.
     - Bulk dismiss action.

---

## 2. Invariants & Constraints

- **Local-First Staging ([ADR 0001](../../docs/adr/0001-local-first-drift-sqlite.md)):**  
  Unconfirmed transactions reside exclusively in the `TriageTransactions` staging table. They MUST NOT impact wallet balances, budget calculations, or net worth statistics until explicitly approved.
- **Domain Vocabulary ([`GLOSSARY.md`](../../GLOSSARY.md)):**  
  Always use `Wallet` (not account), `Category`, `Budget`, and `Transaction`.
- **Cashew Theming & Design System:**  
  - Use theme colors from `budget/lib/colors.dart` (`getColor(context, "lightDarkAccent")`, `getColor(context, "canvasContainer")`, etc.).
  - Reusable bottom sheets via `openBottomSheet` / `budget/lib/widgets/openBottomSheet.dart`.
  - Haptic feedback and smooth animations matching Cashew's UI conventions.
- **Localization:**  
  All user-facing strings must be localized via `app_localizations`.

---

## 3. UI Component Architecture

```
budget/lib/pages/triageInboxPage.dart
 ├── TriageInboxHeader (Filter chips: All, Pending, Dismissed; Batch actions)
 ├── TriageInboxEmptyState (Zero-state illustration when inbox is clear)
 └── ListView.builder / ReorderableList
      └── TriageTransactionCard
           ├── CardHeader: Bank Icon/Badge, Date, Source Snippet toggle
           ├── CardBody: AmountDisplay, Editable Title, Type Segmented Control (Expense | Income | Transfer)
           ├── CardMetadataRow: WalletPickerChip, CategoryPickerChip
           ├── CollapsibleSourceSnippet: Raw parsed text excerpt
           └── CardActionButtons:
                ├── DismissButton (Icon/Text: cross / gray)
                ├── SplitButton (Icon: call_split)
                └── ConfirmButton (Icon: checkmark / accent)
```

---

## 4. Plan & Implementation Steps

- [x] Analyze existing transaction creation flows (`AddTransactionPage`, `processAddTransactionFromParams`).
- [ ] Create UI wireframes and visual widget mockups for `TriageTransactionCard`.
- [ ] Implement `TriageInboxPage` widget with reactive `StreamBuilder` connected to pending triage items.
- [ ] Implement interactive Type Toggle (Expense / Income / Transfer) with responsive wallet routing.
- [ ] Implement category and wallet quick-pick bottom sheets embedded directly in the triage card.
- [ ] Implement "Confirm" atomic execution (write to `Transactions`, mark `TriageTransactions` status = approved in single Drift transaction).
- [ ] Implement batch approval bar ("Approve All Verified").
- [ ] Add widget tests and verification suite in `budget/test/triage_inbox_test.dart`.

---

## 5. Acceptance & Verification

- [ ] Interactive triage card allows full review and one-tap confirmation without leaving the screen.
- [ ] Toggling between Expense, Income, and Transfer updates destination wallet selectors and category visibility dynamically.
- [ ] Unconfirmed items produce zero side-effects on primary balances or budget totals.
- [ ] Zero static analysis errors (`flutter analyze`) and clean formatting (`dart format`).

---

## Links

- GitHub Issue: [#4](https://github.com/kidomarcostelo/budget-tracking/issues/4)
- Parent Map: [#2](https://github.com/kidomarcostelo/budget-tracking/issues/2)
- Upstream Research: [#3](https://github.com/kidomarcostelo/budget-tracking/issues/3) ([`BT-5`](../BT-5-gmail-extraction-sync-feasibility/task.md))
- Downstream Schema: [#5](https://github.com/kidomarcostelo/budget-tracking/issues/5)
- Duplicate Detection: [#6](https://github.com/kidomarcostelo/budget-tracking/issues/6) ([`BT-2`](../BT-2-plan-bank-email-duplicate-detection/task.md))
