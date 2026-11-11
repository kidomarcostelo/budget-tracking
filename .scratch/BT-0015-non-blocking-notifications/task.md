# Task: Non-blocking notification with pending transaction queue

**Issue Reference:** [#33](https://github.com/kidomarcostelo/budget-tracking/issues/33)  
**Status:** In Review (PR Pending)  
**Assignee / Agent:** Antigravity

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
- [x] Add `pending` boolean column to `Transactions` table (default `false`)
- [x] Create new Drift migration step
- [x] Run `dart run build_runner build --delete-conflicting-outputs`
- [x] Update ALL aggregate queries to filter `WHERE pending = false`
- [x] Add DB methods: `watchPendingTransactions()`, `approvePendingTransaction(pk)`, `dismissPendingTransaction(pk)`, `approveAllPendingTransactions()`, `dismissAllPendingTransactions()`
- [x] Write tests for new queries and exclusion behavior

### VS2 — Non-Blocking Notification Path
- [x] Add `notificationScanningNonBlocking` setting to scanning settings page
- [x] Default `false` for existing users, `true` for fresh installs
- [x] Modify `queueTransactionFromMessage()`: non-blocking → create with `pending = true` + show local notification
- [x] Modify Google Pay parser `willPushRoute` to respect setting
- [x] Set up Android notification channel for transaction detections
- [x] Notification format: "New transaction: -$45.00 at Starbucks"

### VS3 — Notification Tap → Edit Pending Transaction
- [x] Add payload: `openPendingTransaction?transactionPk=<pk>`
- [x] Handle in `initializeNotifications.dart`
- [x] Tap → query pending transaction → open `AddTransactionPage` edit mode
- [x] Saving approves (flip `pending` to `false`)
- [x] Handle edge case: already approved/dismissed

### VS4 — Pending Queue Page
- [x] New `PendingTransactionsPage` with Drift `StreamBuilder`
- [x] List items: amount, title, date, category, duplicate flag
- [x] Swipe right = approve, swipe left = dismiss, tap = edit
- [x] "Approve All" + "Dismiss All" bulk actions
- [x] Empty state message

### VS5 — Home Screen Badge & Entry Point
- [x] Badge icon in app bar (bell/inbox)
- [x] Reactive count via `StreamBuilder`
- [x] Tap → `PendingTransactionsPage`
- [x] Hide when count = 0

### VS6 — Notification Grouping
- [x] Android notification grouping with shared group key
- [x] Group summary: "X new transactions detected"
- [x] Group summary tap → `PendingTransactionsPage`
- [x] Individual tap → specific pending transaction (VS3)

---

## 4. Verification & Testing
- [x] Unit / Widget tests added or updated (176 tests passing)
- [x] Static analysis passes: `flutter analyze` (0 issues)
- [x] Code formatted: `dart format --output=none --set-exit-if-changed .` (clean)
- [x] Verify existing blocking flow still works when toggle is off
- [x] Verify aggregate queries exclude pending transactions
- [x] Verify notification tap opens correct transaction
- [x] Verify swipe approve/dismiss in pending queue
- [x] Addressed PR #39 code review findings (commit `ca617b01`): theming colors, localization interpolation, aggregate queries exclusion, fresh install setting defaults, duplicate indication in queue and edit review flow, and deduplicated parsing dispatcher.
