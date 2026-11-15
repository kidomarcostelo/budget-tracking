# Code Review: Pull Request #40 (BT-0016)

- **Target / PR:** Pull Request #40 / #41 (`feat(notifications): add background keep-alive service and battery optimization prompt`)
- **Branch:** `feat/bt-0016-background-headless-listener` → `main`
- **Head Commit:** [`65cabff1`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget) — `feat(notifications): add background keep-alive service and battery optimization prompt (BT-0016)`
- **Fixed Point:** `origin/main` ([`1596a93c`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget))
- **Originating Spec:** Issue #7 (Parent Epic), [`.scratch/BT-0016-background-headless-listener/task.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0016-background-headless-listener/task.md), and [`.scratch/BT-0016-background-headless-listener/issue-body.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0016-background-headless-listener/issue-body.md)
- **Review Date:** 2026-11-16
- **Review Type:** Two-Axis Code Review (Standards & Spec)

---

## Executive Summary

| Axis | Findings Count | Worst Issue | Status |
|:-----|:--------------:|:------------|:-------|
| **Standards** | 4 (2 hard violations, 2 smells) | Hardcoded non-localized English string literals in native Android notification drawer & channel configuration (`CashewKeepAliveService.kt`). | Needs Attention |
| **Spec** | 6 (3 missing/partial, 1 scope creep, 2 incorrect) | Foreground keep-alive service fails to start automatically on app launch when `notificationScanning == true` (`main.dart` L60–63). | Needs Attention |

---

## 1. Standards Axis

### (a) Documented Standards Violations

1. **Hard Violation: User-Facing Text Localization**
   - **Standard:** [`AGENTS.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/AGENTS.md) (*"Localization: All user-facing text must use localized strings via `app_localizations` or existing localization delegates."*)
   - **Location:** [`budget/android/app/src/main/kotlin/com/example/budget/CashewKeepAliveService.kt:63-95`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/android/app/src/main/kotlin/com/example/budget/CashewKeepAliveService.kt#L63-L95)
   - **Violation:** System notification drawer and channel settings use hardcoded English string literals instead of Android XML string resources or localized assets:
     - Channel name/description: `"Background Transaction Monitor"`, `"Keeps Cashew running in background to capture Google Pay and bank notifications"`
     - Notification title/text: `"Cashew background monitor active"`, `"Listening for Google Pay and payment notifications"`
   - **Remediation:** Move notification strings into `android/app/src/main/res/values/strings.xml` (with localized values in `values-*/strings.xml`), or inject localized strings from Dart via `MethodChannel` when starting the service.

2. **Hard Violation: Widget Decomposition**
   - **Standard:** [`AGENTS.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/AGENTS.md) (*"Widget Decomposition: Extract complex UI into reusable widgets under `budget/lib/widgets/`. Avoid monolithic build methods where possible."*)
   - **Location:** [`budget/lib/pages/autoTransactionsPageEmail.dart:347-375`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L347-L375)
   - **Violation:** A 33-line composite alert card (`Padding` > `Column` > `StatusBox` + `Button`) was appended directly into the monolithic `build` method of `autoTransactionsPageEmail.dart` (~1,250 LOC) rather than extracted into a clean widget under `budget/lib/widgets/`.
   - **Remediation:** Extract into `budget/lib/widgets/batteryOptimizationCard.dart` or decompose into a dedicated sub-widget helper.

---

### (b) Baseline Code Smells (Judgement Calls)

1. **Duplicated Code — Method Channel Boilerplate**
   - **Location:** [`budget/lib/struct/backgroundService.dart:19-75`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/struct/backgroundService.dart#L19-L75)
   - **Smell:** `startKeepAlive`, `stopKeepAlive`, and `requestIgnoreBatteryOptimizations` duplicate identical platform checks, channel invocation logic, and try/catch error handling blocks:
     ```dart
     final platform = platformOverride ?? getPlatform(ignoreEmulation: true);
     if (platform != PlatformOS.isAndroid) return false;
     try {
       final bool? result = await channel.invokeMethod<bool>('...');
       return result ?? true;
     } catch (e) {
       print('Error: $e');
       return false;
     }
     ```
   - **Remediation:** Extract a shared private helper `Future<bool> _invokeNativeAction(String method, {PlatformOS? platformOverride})`.

2. **Duplicated Code — Redundant Action Handlers in Layout**
   - **Location:** [`budget/lib/pages/autoTransactionsPageEmail.dart:357-372`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L357-L372)
   - **Smell:** Both the enclosing `StatusBox` and the nested `Button` attach duplicate `onTap: _requestBatteryOptimizationExemption` callbacks within the same column:
     ```dart
     StatusBox(..., onTap: _requestBatteryOptimizationExemption),
     const SizedBox(height: 5),
     Button(..., onTap: _requestBatteryOptimizationExemption),
     ```
     Duplicating the tap handler across both parent card and internal button is redundant and clones the shape of the permission card above it.
   - **Remediation:** Keep the action on the button and remove the outer card `onTap`, or make the entire card clickable without duplicating the callback.

---

## 2. Spec Axis

### (a) Requirements Missing or Partial

1. **Automatic service start on app launch is missing:**
   - **Spec Quote:** `task.md` L64: `"- Ensure foreground service starts automatically on app launch if notificationScanning == true."`
   - **Finding:** In [`budget/lib/main.dart:60-63`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/main.dart#L60-L63), the app startup sequence only reloads `DedupeLedger`. Neither `NotificationDispatcher.instance.initNotificationScanning()` nor `BackgroundServiceManager.instance.startKeepAlive()` is called during app initialization. The keep-alive service only starts if the user manually visits `AutoTransactionsPageNotifications`.
   - **Remediation:** In `main.dart` or during global provider initialization, check `sharedPreferences.getBool("notificationScanning")` and invoke `BackgroundServiceManager.instance.startKeepAlive()` if enabled.

2. **Headless background isolate not implemented:**
   - **Spec Quote:** `issue-body.md` L7: `"Replace the event-channel-based listener with a headless background isolate approach using flutter_notification_listener_plus"`
   - **Finding:** Per `task.md` Q1/Q5, the headless isolate was substituted with a native keep-alive service; `issue-body.md` remains unfulfilled.
   - **Remediation:** Align `issue-body.md` with the grilling resolution recorded in `task.md` (Q1/Q5 native foreground service approach).

3. **Notification dispatch verification test missing:**
   - **Spec Quote:** `task.md` L73: `"- Unit test notification dispatch with keep-alive active."`
   - **Finding:** [`budget/test/background_service_test.dart`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/test/background_service_test.dart) verifies platform channel method invocations, but contains no tests asserting notification event dispatch through `NotificationDispatcher` when the service is active.
   - **Remediation:** Add a test simulating notification delivery through `NotificationDispatcher.instance.handleEvent()` while keep-alive is verified running.

---

### (b) Scope Creep

1. **Unrelated BT-0017 task index entry:**
   - **Finding:** [`.scratch/index.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/index.md) bumps `Next ID: 0018` and adds an entry for `BT-0017` (Enhanced Pie Chart and Stats Page), which is unrelated to BT-0016.
   - **Remediation:** Revert the uncommitted change to `.scratch/index.md` or defer it to the BT-0017 feature branch.

---

### (c) Requirements Implemented Incorrectly

1. **Android 14 (API 34) Foreground Service type omitted in `startForeground`:**
   - **Spec Quote:** `task.md` L58: `"Declare service and permissions in AndroidManifest.xml (FOREGROUND_SERVICE, FOREGROUND_SERVICE_SPECIAL_USE, WAKE_LOCK)."`
   - **Finding:** The app targets SDK 34. In [`budget/android/app/src/main/kotlin/com/example/budget/CashewKeepAliveService.kt:54`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/android/app/src/main/kotlin/com/example/budget/CashewKeepAliveService.kt#L54), `startForeground(NOTIFICATION_ID, notification)` is called without passing `ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE`. On Android 14+ (API 34), declaring `specialUse` in the manifest requires supplying the foreground service type flag at runtime, otherwise it risks `MissingForegroundServiceTypeException` or validation failure.
   - **Remediation:** On SDK >= 34, call:
     ```kotlin
     if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
         startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
     } else {
         startForeground(NOTIFICATION_ID, notification)
     }
     ```

2. **`START_STICKY` does not re-initialize Flutter engine on kill:**
   - **Spec Quote:** `task.md` L25: `"Fully-killed / reboot: protected by Foreground Service priority and battery exemption."`
   - **Finding:** In [`CashewKeepAliveService.kt:58`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/android/app/src/main/kotlin/com/example/budget/CashewKeepAliveService.kt#L58), returning `START_STICKY` allows Android to recreate the native service if the process is killed under memory pressure. However, restarting the service alone does not initialize a `FlutterEngine`. The Dart `NotificationListenerService` stream listener remains unattached, causing incoming payment notifications to be dropped until the user manually relaunches Cashew.
   - **Remediation:** Update docs/spec to clarify that `START_STICKY` only preserves the foreground process priority while the app is alive, or implement a background `FlutterEngineCache` / headless runner if process-death recovery is required.

---

## 3. Summary & Recommended Action Plan

- **Standards Axis:** 4 findings (2 hard violations, 2 smells). Worst issue: Non-localized string literals in Android notification service.
- **Spec Axis:** 6 findings (3 missing/partial, 1 scope creep, 2 incorrect). Worst issue: Service not started on app launch when enabled (`main.dart`).

### Recommended Remediation Steps:
1. **Fix `startForeground` for Android 14:** Pass `ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE` in `CashewKeepAliveService.kt`.
2. **Auto-start on Launch:** In `budget/lib/main.dart`, invoke `BackgroundServiceManager.instance.startKeepAlive()` when `notificationScanning` is true.
3. **Localize Notification Strings:** Extract hardcoded strings in `CashewKeepAliveService.kt` to Android string resources or pass via method channel.
4. **Decompose Battery Optimization Widget:** Extract the prompt card from `autoTransactionsPageEmail.dart` into `budget/lib/widgets/batteryOptimizationCard.dart`.
5. **Deduplicate Platform Channel Invocation:** Consolidate boilerplate in `backgroundService.dart`.
