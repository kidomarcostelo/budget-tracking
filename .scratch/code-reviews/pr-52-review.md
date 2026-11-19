# Code Review: Pull Request #52 (BT-0019)

- **Target / PR:** Pull Request [#52](https://github.com/kidomarcostelo/budget-tracking/pull/52) — `feat(notifications): add native notification buffer for killed-state capture (BT-0019) (#50)`
- **Branch:** `feat/BT-0019-headless-notification-buffer` → `main`
- **Head Commit:** [`acde9a07`](https://github.com/kidomarcostelo/budget-tracking/commit/acde9a07b467a314542ee6723a8e49d242b08c38)
- **Base / Fixed Point:** `origin/main` ([`93c67492`](https://github.com/kidomarcostelo/budget-tracking/commit/93c67492f795d37bebb05cd5d08977bcd20026a6))
- **Originating Spec:** Issue [#50](https://github.com/kidomarcostelo/budget-tracking/issues/50), [`.scratch/BT-0019-headless-background-notification-listener/task.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0019-headless-background-notification-listener/task.md) & [`.scratch/BT-0019-headless-background-notification-listener/plan.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0019-headless-background-notification-listener/plan.md)
- **Review Date:** 2026-11-20
- **Review Type:** Two-Axis Code Review (Standards & Spec)

---

## Executive Summary

| Axis | Findings Count | Worst Issue | Status |
|:-----|:--------------:|:------------|:-------|
| **Standards** | 5 (2 documented standards violations, 3 baseline smells) | Commits use GitHub noreply email address instead of `kidomarcostelo@gmail.com` as mandated in `AGENTS.md`. | Needs Attention |
| **Spec** | 6 (1 missing/partial, 3 scope creep, 2 incorrect implementations) | Production `DedupeLedger` matching logic polluted with hardcoded `com.android.shell` test-harness bypass; bank notification templates dropped when app is killed. | Needs Attention |

---

## 1. Standards Axis

### (a) Documented Standards Violations

1. **Commit Author & Email**
   - **Standard:** [`AGENTS.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/AGENTS.md) (*Boundaries & Safety Guardrails — Commit Author & Email*)
   - **Rule:** *"Always ensure Git commits use the author email `kidomarcostelo@gmail.com` (`git config user.email "kidomarcostelo@gmail.com"`). Do not commit using another email address."*
   - **Violation:** All 4 branch commits (`13bedcd5`, `43c6e789`, `dde14d00`, `acde9a07`) were authored using `111844659+kidomarcostelo@users.noreply.github.com`.
   - **Context & Remediation:** This was previously observed in PR #48/#49 where GitHub GH007 privacy check rejects public email pushes. If noreply emails are required, update `AGENTS.md` across `main` or unblock email privacy settings in GitHub account settings.

2. **Localization**
   - **Standard:** [`AGENTS.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/AGENTS.md) (*Code Conventions & Patterns — Localization*)
   - **Rule:** *"All user-facing text must use localized strings via `app_localizations` or existing localization delegates."*
   - **Violation:** In [`budget/android/app/src/main/AndroidManifest.xml#L109`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/android/app/src/main/AndroidManifest.xml#L109):
     ```xml
     android:label="Cashew Notification Capture"
     ```
     The service label uses a hardcoded English string attribute instead of referencing a localized string resource (e.g., `@string/notification_capture_service_label`).

---

### (b) Baseline Code Smells (Judgement Calls)

1. **Duplicated Code — Matching & Parsing Duplication**
   - **Smell:** Duplicated Code (*Refactoring* ch. 3)
   - **Locations:**
     - [`budget/lib/struct/dedupeLedger.dart:715-760`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/struct/dedupeLedger.dart#L715-L760): Identical matching logic (amount normalization checks, package check, time window calculation) is repeated verbatim across `entries.reversed` and `uncertainEntries.reversed`.
     - [`budget/android/app/src/main/kotlin/com/example/budget/CashewNativeNotificationListener.kt:207-241`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/android/app/src/main/kotlin/com/example/budget/CashewNativeNotificationListener.kt#L207-L241): `parsePaymentDetails` re-implements duplicate regex parsing and currency normalization in Kotlin that is already maintained in Dart within [`GooglePayParser`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/struct/googlePayParser.dart).
   - **Recommendation:** Extract the dedupe comparison block into a private helper function in `dedupeLedger.dart`. For Kotlin parsing, consider keeping notification text generic in the status bar (as originally planned in `plan.md`) to avoid maintaining duplicate parsers across Kotlin and Dart.

2. **Mysterious Name / Primitive Obsession — Magic Notification ID**
   - **Smell:** Primitive Obsession / Mysterious Name (*Refactoring* ch. 3)
   - **Location:** [`budget/lib/struct/notificationDispatcher.dart:379`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/struct/notificationDispatcher.dart#L379)
   - **Hunk:**
     ```dart
     await flutterLocalNotificationsPlugin.cancel(9992);
     ```
   - **Observation:** The integer literal `9992` is coupled implicitly to Kotlin's `NOTIFICATION_ID = 9992` without a named constant or documentation explaining what ID `9992` represents.
   - **Recommendation:** Define a named constant `static const int nativePendingReviewNotificationId = 9992;`.

3. **Feature Envy — In-Memory Table Filtering**
   - **Smell:** Feature Envy (*Refactoring* ch. 3; relates to `AGENTS.md` *Database Seams*)
   - **Location:** [`budget/lib/database/tables.dart:1965-1994`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/database/tables.dart#L1965-L1994)
   - **Observation:** `findPendingTransaction()` executes `(select(transactions)..where((t) => t.pending.equals(true))..orderBy([(t) => OrderingTerm.desc(t.dateCreated)])).get()` to fetch all pending rows into memory, and then manually iterates through them in Dart to check amount proximity and title matching.
   - **Recommendation:** Express the amount proximity or title match directly in SQL/Drift predicates or limit the candidate rows before fetching into memory.

---

## 2. Spec Axis

### (a) Requirements Missing or Partial

1. **Bank Notification Capture When App is Killed**
   - **Spec Quote:** *"Notifications from Google Wallet (and configured bank templates) should be reliably captured even if Cashew's UI is not open or running in the background."* ([`task.md:16`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0019-headless-background-notification-listener/task.md#L16); [`plan.md:24`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0019-headless-background-notification-listener/plan.md#L24))
   - **Finding:** `CashewNativeNotificationListener.kt` only filters packages against `RECOGNIZED_PACKAGES` (Google Wallet/GPay: `com.google.android.apps.walletnfcrel`, `com.google.android.apps.nbu.paisa.user`, `com.google.android.gms`) and debug packages (`android`, `com.android.shell`). Configured bank notification templates in Cashew are not filtered or captured by the native listener when the app is killed.

---

### (b) Behaviour in Diff Not Asked For (Scope Creep)

1. **Kotlin Transaction Parsing Duplication**
   - **Spec Quote:** *"D5 | Dart Processing Pipeline | 100% Reuse of Existing Pipeline: Deserialized buffer entries are dispatched into `NotificationDispatcher.instance.handleEvent()`. Reuses existing `GooglePayParser`..."* ([`plan.md:39`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0019-headless-background-notification-listener/plan.md#L39))
   - **Finding:** `CashewNativeNotificationListener.kt` implements regex payment parsing in Kotlin (`parsePaymentDetails`) to populate custom status bar titles and amounts, diverging from the architecture decision to maintain 100% parsing in Dart.

2. **App Links Sign Inversion & Query Routing Adjustments**
   - **Spec Quote:** *"Keep existing transaction deduplication (`TransactionDeduplicator`) and parsing heuristics (`GooglePayParser`) intact."* ([`task.md:24`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0019-headless-background-notification-listener/task.md#L24))
   - **Finding:** Commits [`dde14d00`](https://github.com/kidomarcostelo/budget-tracking/commit/dde14d00) and [`acde9a07`](https://github.com/kidomarcostelo/budget-tracking/commit/acde9a07) touched `appLinks.dart`, `autoTransactionsPageEmail.dart`, and introduced query methods in `tables.dart` (`findPendingTransaction`, `getLatestPendingTransaction`) to resolve transaction sign handling and route tapped notifications to prefilled pages—work outside the original BT-0019 scope.

3. **Gradle Repository Reordering**
   - **Finding:** Commit [`43c6e789`](https://github.com/kidomarcostelo/budget-tracking/commit/43c6e789) reordered `mavenCentral()` ahead of `jcenter()` in `budget/android/build.gradle`. While harmless, it was not part of the issue specification.

---

### (c) Requirements Implemented Incorrectly

1. **Production DedupeLedger Polluted with Test Harness Special Cases**
   - **Spec Quote:** *"Keep existing transaction deduplication (`TransactionDeduplicator`) and parsing heuristics (`GooglePayParser`) intact."* ([`task.md:24`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0019-headless-background-notification-listener/task.md#L24))
   - **Finding:** In [`budget/lib/struct/dedupeLedger.dart:724-734`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/struct/dedupeLedger.dart#L724-L734), production deduplication code was modified with hardcoded checks for `com.android.shell`:
     ```dart
     if (packageName == 'com.android.shell' &&
         title != null &&
         existing.title != null && ...)
     ```
     Test-harness workarounds should not leak into core production deduplication logic.

2. **Race Condition on Notification Tap**
   - **Spec Quote:** *"When the user opens or resumes Cashew, Dart flushes the buffer on cold start and inside `OnAppResume`..."* ([`plan.md:27`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0019-headless-background-notification-listener/plan.md#L27))
   - **Finding:** In [`budget/lib/struct/initializeNotifications.dart:131-135`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/struct/initializeNotifications.dart#L131-L135), tapping the native notification opens `openPendingTransaction?latest=true` and attempts `findPendingTransaction()`. If the asynchronous `flushBufferedNotifications()` DB insertion has not completed, it relies on a fragile `Future.delayed(const Duration(milliseconds: 300))` retry.

---

## Summary

- **Total Findings:** Standards: 5 findings (2 violations, 3 smells) | Spec: 6 findings (1 missing/partial, 3 scope creep, 2 incorrect implementations).
- **Worst Issue (Standards):** Commit author email (`111844659+kidomarcostelo@users.noreply.github.com`) violates `AGENTS.md` commit policy.
- **Worst Issue (Spec):** Hardcoded test-harness bypass for `com.android.shell` directly inside core production deduplication logic in `dedupeLedger.dart`.

---

## 3. Resolution & Remediation (Commit `3da6b5d8`)

| # | Axis | Finding | Resolution Status | Remediation Details |
|---|---|---|---|---|
| 1 | Standards | Commit Author & Email | **Documented & Clarified** | GitHub remote rejects `kidomarcostelo@gmail.com` under GH007 private email protection. Configured Git with the user's unblocked GitHub privacy address (`111844659+kidomarcostelo@users.noreply.github.com`). Recommendation: update `AGENTS.md` to permit this noreply address or adjust GitHub account privacy settings. |
| 2 | Standards | Hardcoded label in AndroidManifest | **Resolved** | Added `@string/notification_capture_service_label` to `budget/android/app/src/main/res/values/strings.xml` and referenced it in `AndroidManifest.xml`. |
| 3 | Standards | Duplicated code in `dedupeLedger.dart` | **Resolved** | Extracted `_isNotificationMatch` helper function, deduplicating the matching loops between `entries.reversed` and `uncertainEntries.reversed`. |
| 4 | Standards | Magic Notification ID `9992` | **Resolved** | Defined `static const int nativePendingReviewNotificationId = 9992;` in `NotificationDispatcher` and referenced it when canceling the review notification. |
| 5 | Standards | Feature Envy in `findPendingTransaction` | **Resolved** | Replaced in-memory table filtering with Drift SQL predicates (`pending.equals(true) & ...`, `..limit(1)`). |
| 6 | Spec | Bank notification capture when killed | **Resolved** | Added `syncTemplateKeywordsToPreferences` in `NotificationDispatcher` to sync user-configured `ScannerTemplate` keywords to SharedPreferences. Updated `CashewNativeNotificationListener.kt` to check `matchesTemplateKeyword` so bank notifications are intercepted and buffered even when Flutter is dead. |
| 7 | Spec | Scope Creep: Kotlin Parsing | **Clarified / Working as Designed** | Explicit user requirement during on-device acceptance testing (prompt 4: "I like the 'New transaction detected (with transaction expense and title)'"). Lightweight display formatting in Kotlin is required because Dart VM is not active when notification arrives. |
| 8 | Spec | Scope Creep: App Links Sign & Routing | **Clarified / Working as Designed** | Explicit user requirement during on-device acceptance testing (prompt 4: tap-to-prefill routing; prompt 8: expense defaulting). |
| 9 | Spec | Scope Creep: Gradle Repositories | **Clarified / Retained** | Necessary dependency fix to prioritize `mavenCentral()` over deprecated `jcenter()`. |
| 10 | Spec | Test-harness bypass `com.android.shell` | **Resolved** | Completely removed `com.android.shell` checks from `dedupeLedger.dart`. Amount mismatch checks now apply universally without test-harness special cases. |
| 11 | Spec | Notification tap race condition | **Resolved** | Ensured `await NotificationDispatcher.instance.flushBufferedNotifications()` is awaited before querying `findPendingTransaction`, eliminating the arbitrary 300ms delay. Added `_activeFlushFuture` lock in `NotificationDispatcher` to prevent duplicate concurrent flushes. |
