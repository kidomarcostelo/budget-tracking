# Task: Non-blocking notification with pending transaction queue

**Issue Reference:** [#33](https://github.com/kidomarcostelo/budget-tracking/issues/33)  
**Status:** Draft  
**Assignee / Agent:** TBD

---

## 1. Objective & Scope
- **Problem Statement:** The current notification scanning flow is **blocking** — when a bank notification is detected, `queueTransactionFromMessage()` immediately calls `pushRoute()` to open `AddTransactionPage`, interrupting whatever the user is doing. Users want a non-blocking experience where a local notification appears, and they can review the transaction at their convenience.
- **Expected Behavior:** Detected transactions are saved as "pending" in the database, a local notification is shown with a summary, and the user can tap to review or access a pending queue page from the home screen.

---

## 2. Invariants & Constraints
- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- NEVER edit past Drift migration steps or `drift_schemas/` files — create a new migration version.
- All aggregate queries (budget totals, wallet balances, charts) must exclude `pending = true` transactions.
- All user-facing text must use localized strings.
- Static analysis must pass (`flutter analyze`).
- Existing blocking flow must remain available via settings toggle.

---

## 3. Plan & Implementation Steps (Vertical Slices)

### VS1 — Pending Transaction Infrastructure
- [ ] Add `pending` boolean column to `Transactions` table (default `false`)
- [ ] Create new Drift migration step
- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] Update ALL aggregate queries to filter `WHERE pending = false`
- [ ] Add DB methods: `watchPendingTransactions()`, `approvePendingTransaction(pk)`, `dismissPendingTransaction(pk)`, `approveAllPendingTransactions()`, `dismissAllPendingTransactions()`
- [ ] Write tests for new queries and exclusion behavior

### VS2 — Non-Blocking Notification Path
- [ ] Add `notificationScanningNonBlocking` setting to scanning settings page
- [ ] Default `false` for existing users, `true` for fresh installs
- [ ] Modify `queueTransactionFromMessage()`: non-blocking → create with `pending = true` + show local notification
- [ ] Modify Google Pay parser `willPushRoute` to respect setting
- [ ] Set up Android notification channel for transaction detections
- [ ] Notification format: "New transaction: -$45.00 at Starbucks"

### VS3 — Notification Tap → Edit Pending Transaction
- [ ] Add payload: `openPendingTransaction?transactionPk=<pk>`
- [ ] Handle in `initializeNotifications.dart`
- [ ] Tap → query pending transaction → open `AddTransactionPage` edit mode
- [ ] Saving approves (flip `pending` to `false`)
- [ ] Handle edge case: already approved/dismissed

### VS4 — Pending Queue Page
- [ ] New `PendingTransactionsPage` with Drift `StreamBuilder`
- [ ] List items: amount, title, date, category, duplicate flag
- [ ] Swipe right = approve, swipe left = dismiss, tap = edit
- [ ] "Approve All" + "Dismiss All" bulk actions
- [ ] Empty state message

### VS5 — Home Screen Badge & Entry Point
- [ ] Badge icon in app bar (bell/inbox)
- [ ] Reactive count via `StreamBuilder`
- [ ] Tap → `PendingTransactionsPage`
- [ ] Hide when count = 0

### VS6 — Notification Grouping
- [ ] Android notification grouping with shared group key
- [ ] Group summary: "X new transactions detected"
- [ ] Group summary tap → `PendingTransactionsPage`
- [ ] Individual tap → specific pending transaction (VS3)

---

## 4. Verification & Testing
- [ ] Unit / Widget tests added or updated
- [ ] Static analysis passes: `flutter analyze`
- [ ] Code formatted: `dart format --output=none --set-exit-if-changed .`
- [ ] Manual verification in emulator or app preview
- [ ] Verify existing blocking flow still works when toggle is off
- [ ] Verify aggregate queries exclude pending transactions
- [ ] Verify notification tap opens correct transaction
- [ ] Verify swipe approve/dismiss in pending queue
