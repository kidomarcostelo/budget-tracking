# Code Review & Violations Report: Commit `ad78cc0e`

**Target Commit:** [`ad78cc0e`](https://github.com/kidomarcostelo/budget-tracking/commit/ad78cc0ebbd5e10bed7674fca5e5022483fd8b2f) (`feat(notifications): centralize listener dispatcher and ignore removal events`)  
**Pull Request:** [#18](https://github.com/kidomarcostelo/budget-tracking/pull/18) (`feat/notification-single-dispatcher`)  
**Tracking Issue:** [#7](https://github.com/kidomarcostelo/budget-tracking/issues/7) (Local task: [`BT-3`](task.md))  

---

## 1. Hard Quality Bar & Compiler Violations (`CONSTRAINTS.md`)

These violations broke GitHub Actions CI on PR #18 and represent non-negotiable quality gate breaches.

### 1.1 Unresolved Identifier / Missing Import in [`notificationDispatcher.dart`](../../budget/lib/struct/notificationDispatcher.dart)
- **Rule Breached:** [`CONSTRAINTS.md`](../../CONSTRAINTS.md) § 1 (*"Zero Tolerance on Analysis Errors/Warnings: flutter analyze in budget/ must exit with return code 0"*) and § 5 (*"Verification Checklist"*).
- **Location:** `budget/lib/struct/notificationDispatcher.dart:54:9`
- **Error in CI:**
  ```text
  lib/struct/notificationDispatcher.dart:54:9: Error: The getter 'appStateSettings' isn't defined for the class 'NotificationDispatcher'.
  - 'NotificationDispatcher' is from 'package:budget/struct/notificationDispatcher.dart' ('lib/struct/notificationDispatcher.dart').
      if (appStateSettings["notificationScanning"] != true) return;
          ^^^^^^^^^^^^^^^^
  Target kernel_snapshot failed: Exception
  FAILURE: Build failed with an exception. (compileFlutterBuildDebug)
  ```
- **Cause:** `appStateSettings` is declared in `package:budget/struct/settings.dart`, but `notificationDispatcher.dart` omits the import.

### 1.2 Formatting Non-Compliance in [`notification_dispatcher_test.dart`](../../budget/test/notification_dispatcher_test.dart)
- **Rule Breached:** [`CONSTRAINTS.md`](../../CONSTRAINTS.md) § 1 (*"Format Integrity: All Dart code must conform to dart format. Check with dart format --output=none --set-exit-if-changed . inside budget/"*).
- **Location:** `budget/test/notification_dispatcher_test.dart`
- **Error in CI:**
  ```text
  Run dart format --output=none --set-exit-if-changed . || (dart format . && git diff && exit 1)
  Changed test/notification_dispatcher_test.dart
  Formatted 258 files (1 changed) in 2.87 seconds.
  Process completed with exit code 1.
  ```
- **Cause:** Several long test description strings and assertion expressions exceeded standard line length limits and were not formatted using `dart format` prior to pushing.

---

## 2. Documented Standards Violations (`AGENTS.md`)

### 2.1 Unlocalized User-Facing String in [`autoTransactionsPageEmail.dart`](../../budget/lib/pages/autoTransactionsPageEmail.dart)
- **Standard:** [`AGENTS.md`](../../AGENTS.md) → **Code Conventions & Patterns** → **Localization** (*"All user-facing text must use localized strings via app_localizations or existing localization delegates."*)
- **Location:** `budget/lib/pages/autoTransactionsPageEmail.dart:214-216`
- **Hunk:**
  ```dart
  description:
      "When a notification is received and the app is open, attempt to add a transaction given its information. Create a template so Cashew understands the format of a notification.",
  ```
- **Violation:** The description was updated directly as a hardcoded English string literal. In addition to being unlocalized, this edit belongs to slice S5 rather than S1.

---

## 3. Baseline Code Smells (Judgement Calls)

### 3.1 Middle Man — Obsolete Forwarding Shims in [`autoTransactionsPageEmail.dart`](../../budget/lib/pages/autoTransactionsPageEmail.dart)
- **Smell Type:** **Middle Man**
- **Location:** `budget/lib/pages/autoTransactionsPageEmail.dart:43-54, 150-152`
- **Hunk:**
  ```dart
  Future<bool> requestReadNotificationPermission() async {
    return await NotificationDispatcher.instance
        .requestReadNotificationPermission();
  }

  onNotification(ServiceNotificationEvent event) async {
    await NotificationDispatcher.instance.handleEvent(
      event,
      customQueueHandler: queueTransactionFromMessage,
    );
  }
  ...
  String getNotificationMessage(ServiceNotificationEvent event) {
    return NotificationDispatcher.formatNotificationMessage(event);
  }
  ```
- **Analysis:** `onNotification` and `getNotificationMessage` have zero callers in the codebase. `requestReadNotificationPermission` merely delegates directly to `NotificationDispatcher.instance`. Callers should invoke the dispatcher directly and dead shims should be deleted.

### 3.2 Speculative Generality in [`notificationDispatcher.dart`](../../budget/lib/struct/notificationDispatcher.dart)
- **Smell Type:** **Speculative Generality**
- **Location:** `budget/lib/struct/notificationDispatcher.dart:26, 29-35`
- **Hunk:**
  ```dart
  bool get isListening => _subscription != null;

  /// Checks if notification listener access has been granted by the user.
  Future<bool> isPermissionGranted() async {
    try {
      return await NotificationListenerService.isPermissionGranted();
    } catch (e) {
      return false;
    }
  }
  ```
- **Analysis:** Neither `isListening` nor `isPermissionGranted()` is consumed by any production code, widget, or unit test.

### 3.3 Duplicated Code in [`notificationDispatcher.dart`](../../budget/lib/struct/notificationDispatcher.dart)
- **Smell Type:** **Duplicated Code**
- **Location:** `budget/lib/struct/notificationDispatcher.dart:38-48`
- **Analysis:** `requestReadNotificationPermission` repeats the `try/catch` wrapping and invokes `NotificationListenerService.isPermissionGranted()` directly rather than reusing its own sibling method `isPermissionGranted()`.

---

## 4. Spec Conformance & Scope Discrepancies (`task.md`)

### 4.1 Missing Real Bank Fixture Integration in Tests
- **Spec Reference:** [`.scratch/BT-3-extend-auto-transactions-google-pay/task.md`](task.md#L60) (line 60)
- **Requirement:** *"Add unit tests with redacted fixtures from `.scratch/bank-samples/`."*
- **Discrepancy:** The unit test suite `notification_dispatcher_test.dart` tests event handling exclusively with small inline synthetic map objects. The actual fixture files in `.scratch/bank-samples/` were not loaded or integrated into the test assertions.

### 4.2 Out-of-Scope Settings UI Copy Modification
- **Spec Reference:** [`.scratch/BT-3-extend-auto-transactions-google-pay/task.md`](task.md#L60) (line 60 & 67)
- **Requirement:** S1 specifies *"Keep current behavior for existing templates"*, while S5 specifically tracks *"Settings copy for the Google Pay source (toggle per source)"*.
- **Discrepancy:** Altering the settings description text in `autoTransactionsPageEmail.dart` represents premature scope creep that also broke the localization constraint.

---

## 5. Remediation Plan

To get PR #18 into a green and mergeable state:

1. **Fix Compiler Error:**
   Add `import 'package:budget/struct/settings.dart';` to `budget/lib/struct/notificationDispatcher.dart`.
2. **Revert Premature Settings Copy / Restore Localization:**
   In `budget/lib/pages/autoTransactionsPageEmail.dart`, revert the unlocalized description string to the original `autoTransactionsDescription` localized key.
3. **Clean Up Dead Shims:**
   Remove uncalled `onNotification` and `getNotificationMessage` functions from `autoTransactionsPageEmail.dart`.
4. **Format Test Files:**
   Run `dart format budget/test/notification_dispatcher_test.dart` to satisfy the format check.
5. **Execute Verification Checklist:**
   ```bash
   cd budget
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   ```
