# Code Review: PR #39

- **Target PR:** [#39](https://github.com/kidomarcostelo/budget-tracking/pull/39) (`feat/non-blocking-notifications` → `main`)
- **Tracking Issue:** [#33](https://github.com/kidomarcostelo/budget-tracking/issues/33) (`.scratch/BT-13-non-blocking-notifications/task.md`)
- **Commits:**
  - `741a06b3 feat(database): add pending column to transactions and exclusion queries (VS1)`
  - `1bd13efb feat(notifications): implement non-blocking transaction notifications and pending queue (BT-13)`
- **Review Date:** 2026-11-11T17:31:00+08:00

---

## Standards

### Documented Standards Violations (Hard)

1. **`AGENTS.md` (Color & Theming: "Use theme palettes defined in `budget/lib/colors.dart`. Avoid hardcoded raw Color hex values in page widgets")**
   - **Location:** `budget/lib/pages/pendingTransactionsPage.dart:136, 158`
   - **Violation:** Swipe backgrounds use raw `Colors.green.withOpacity(0.85)` and `Colors.red.withOpacity(0.85)` rather than semantic theme colors (`getColor(context, "incomeAmount")` and `getColor(context, "expenseAmount")`).

2. **`AGENTS.md` (Localization: "All user-facing text must use localized strings via `app_localizations` or existing localization delegates")**
   - **Location:** `budget/lib/struct/initializeNotifications.dart:182-184`
   - **Violation:** `"possible-duplicate".tr()` uses a non-existent key (canonical key in `en.json` is `"possible-duplicate-detected"`). Additionally, `"${"at".tr()}"` references `"at"` which is not in `en.json`, causing raw string fallback.
   - **Location:** `budget/lib/struct/initializeNotifications.dart:229`
   - **Violation:** `"$count " + "new-transactions-detected".tr()` uses manual string concatenation rather than localized interpolation/args.

---

### Baseline Smells (Judgement Calls)

1. **Duplicated Code** — `budget/lib/pages/autoTransactionsPageEmail.dart:126-155` and `budget/lib/struct/googlePayParser.dart:238-270`
   ```dart
   final bool isNonBlocking =
       appStateSettings["notificationScanningNonBlocking"] == true;
   if ((willPushRoute || isPossibleDuplicate) && !isNonBlocking) {
     pushRoute(null, AddTransactionPage(...));
   } else {
     processAddTransactionFromParams(navigatorKey.currentContext, { ... });
   }
   ```
   *Analysis*: Identical non-blocking decision branch and dictionary payload shape across both notification parsers.
   *Fix*: Extract into a shared ingestion dispatcher.

2. **Duplicated Code** — `budget/lib/struct/initializeNotifications.dart:169` & `200`
   ```dart
   final int notificationId =
       transaction.transactionPk.hashCode.abs() % 100000 + 10000;
   ```
   *Analysis*: Notification ID derivation formula repeated in both show and cancel methods.
   *Fix*: Extract a private `_getNotificationId(String pk)` helper.

3. **Primitive Obsession** — `budget/lib/widgets/util/appLinks.dart:178-180`
   ```dart
   bool isPending = params["pending"] == "true";
   bool isPossibleDuplicate = params["isPossibleDuplicate"] == "true";
   ```
   *Analysis*: Encoding boolean domain flags as string literals (`"true"` / `"false"`) in `Map<String, String?>` rather than typed method arguments or an options struct.

---

## Spec

### (a) Missing or Partial Requirements

1. **Possible-duplicate flag in queue & edit flow**
   > Spec: *"VS4: List items: amount, title/merchant, date, category, possible-duplicate flag" (also "Q4 Duplicate handling: existing dedup (exact skip, uncertain flagged)")*
   `PendingTransactionsPage` delegates to `TransactionEntry` without rendering any duplicate flag or indicator. Because `isPossibleDuplicate` is not persisted in the database, tapping a pending item from the queue opens `AddTransactionPage` without duplicate context.

2. **Fresh install default setting**
   > Spec: *"VS2: notificationScanningNonBlocking setting (default false for existing users, true for fresh installs)" (also "Q12b Default: blocking for existing, non-blocking for new")*
   In `budget/lib/struct/defaultPreferences.dart:134`, `"notificationScanningNonBlocking": false` is defined in defaults. Fresh installs therefore default to `false` (blocking mode) rather than `true`.

3. **Pending exclusion from all aggregate queries**
   > Spec: *"VS1: Exclude pending=true from ALL aggregate queries, totals, balances, budgets, charts" (also "Q10 Calculations: completely excluded until approved")*
   `watchTotalNetBeforeStartDate()` (`tables.dart:7396`), which calculates cumulative balance/spending chart baselines in `walletDetailsPage.dart`, does not filter out pending transactions. `getHighestLowestAmount()` (`tables.dart:1646`) also omits the pending filter.

---

### (b) Scope Creep (Unasked-for Behaviour)

1. **Arbitrary category fallback**
   > Spec: *"VS2: In non-blocking mode: queueTransactionFromMessage creates transaction with pending=true, shows local notification without pushRoute"*
   In `appLinks.dart:227-234`, when category resolution fails in non-blocking mode, it silently falls back to `allCategories.first`.

2. **iOS thread grouping**
   > Spec: *"VS6: Android notification grouping with shared group key" (also "Q3 Android notification grouping")*
   `initializeNotifications.dart:160-162` adds `DarwinNotificationDetails(threadIdentifier: ...)` for iOS grouping, which was not requested.

---

### (c) Incorrect Implementations

1. **Fresh install toggle inverted**
   > Spec: *"Q12b Default: blocking for existing, non-blocking for new"*
   `defaultPreferences.dart` sets `notificationScanningNonBlocking: false`, making fresh installs default to the old blocking flow instead of non-blocking.

2. **Duplicate status lost in pending queue**
   > Spec: *"Q4 Duplicate handling: existing dedup (exact skip, uncertain flagged)"*
   Uncertain duplicates are flagged in the notification title, but this metadata is discarded upon database insertion, leaving items indistinguishable from normal transactions in `PendingTransactionsPage`.

---

## Summary

- **Standards:** 2 hard violations, 3 baseline smells (Worst: missing localization keys `"possible-duplicate"` and `"at"` in notification strings resulting in raw key fallback in the UI).
- **Spec:** 7 findings (Worst: `isPossibleDuplicate` flag discarded upon ingestion, leaving uncertain duplicates unflagged in `PendingTransactionsPage`, and `watchTotalNetBeforeStartDate` leaking pending amounts into wallet chart calculations).
