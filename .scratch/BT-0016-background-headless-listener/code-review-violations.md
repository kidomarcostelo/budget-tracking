# Code Review Violations: BT-0016

- **Target Branch:** `feat/bt-0016-background-headless-listener`
- **Fixed Point:** `origin/main` (`1596a93c`)
- **Diff:** `git diff origin/main...HEAD`
- **Commit:** `65cabff1 feat(notifications): add background keep-alive service and battery optimization prompt (BT-0016)`
- **Task Reference:** BT-0016 (`.scratch/BT-0016-background-headless-listener/task.md`)
- **Review Date:** 2026-11-16T00:36:00+08:00

---

## Standards

### (a) Documented Standards Violations

1. **Hard Violation: User-Facing Text Localization**
   - **Standard:** `AGENTS.md` ("Localization: All user-facing text must use localized strings via `app_localizations` or existing localization delegates.")
   - **Location:** `budget/android/app/src/main/kotlin/com/example/budget/CashewKeepAliveService.kt:63-95`
   - **Violation:** System notification drawer and channel settings use hardcoded English string literals instead of Android XML string resources or localized assets:
     - Channel name/description: `"Background Transaction Monitor"`, `"Keeps Cashew running in background to capture Google Pay and bank notifications"`
     - Notification title/text: `"Cashew background monitor active"`, `"Listening for Google Pay and payment notifications"`

2. **Hard Violation: Widget Decomposition**
   - **Standard:** `AGENTS.md` ("Widget Decomposition: Extract complex UI into reusable widgets under `budget/lib/widgets/`. Avoid monolithic build methods where possible.")
   - **Location:** `budget/lib/pages/autoTransactionsPageEmail.dart:347-375`
   - **Violation:** A 33-line composite alert block (`Padding` > `Column` > `StatusBox` + `Button`) was appended directly into the monolithic `build` method of `autoTransactionsPageEmail.dart` (~1,250 LOC) rather than decomposed into a reusable widget under `budget/lib/widgets/`.

---

### (b) Baseline Code Smells (Judgement Calls)

1. **Duplicated Code — Method Channel Boilerplate**
   - **Location:** `budget/lib/struct/backgroundService.dart:19-75`
   - **Smell:** `startKeepAlive`, `stopKeepAlive`, and `requestIgnoreBatteryOptimizations` duplicate the exact same platform-check, channel invocation, and error handling pattern:
     ```dart
     final platform = platformOverride ?? getPlatform(ignoreEmulation: true);
     if (platform != PlatformOS.isAndroid) return false;
     try {
       final bool? result = await channel.invokeMethod<bool>('...');
       return result ?? true;
     } catch (e) { ...; return false; }
     ```
   - **Recommendation:** Extract a shared `_invokeNativeAction(String method, {PlatformOS? platformOverride})` helper.

2. **Duplicated Code — Redundant Action Handlers in Layout**
   - **Location:** `budget/lib/pages/autoTransactionsPageEmail.dart:357-372`
   - **Smell:** Both `StatusBox` and the nested `Button` attach duplicate `onTap: _requestBatteryOptimizationExemption` bindings within the same column:
     ```dart
     StatusBox(..., onTap: _requestBatteryOptimizationExemption),
     const SizedBox(height: 5),
     Button(..., onTap: _requestBatteryOptimizationExemption),
     ```
     Duplicating the tap handler across both parent and button is redundant and clones the shape of the permission card above it.

---

## Spec

### (a) Requirements Missing or Partial

1. **Automatic service start on app launch is missing:**
   - **Spec Quote:** `task.md` L64: `"- Ensure foreground service starts automatically on app launch if notificationScanning == true."`
   - **Finding:** `budget/lib/main.dart` (L60–63) only reloads `DedupeLedger`. Neither `NotificationDispatcher.instance.initNotificationScanning()` nor `BackgroundServiceManager.instance.startKeepAlive()` is invoked during app initialization. The keep-alive service only starts if the user manually visits `AutoTransactionsPageNotifications`.
2. **Headless background isolate not implemented:**
   - **Spec Quote:** `issue-body.md` L7: `"Replace the event-channel-based listener with a headless background isolate approach using flutter_notification_listener_plus"`
   - **Finding:** Per `task.md` Q1/Q5, the headless isolate was substituted with a native keep-alive service; `issue-body.md` remains unfulfilled.
3. **Notification dispatch verification test missing:**
   - **Spec Quote:** `task.md` L73: `"- Unit test notification dispatch with keep-alive active."`
   - **Finding:** `budget/test/background_service_test.dart` verifies platform channel method invocations, but contains no tests verifying notification event dispatch through `NotificationDispatcher` with keep-alive running.

### (b) Scope Creep

1. **Unrelated BT-0017 task index entry:**
   - **Finding:** `.scratch/index.md` bumps `Next ID: 0018` and adds an entry for `BT-0017` (Enhanced Pie Chart and Stats Page), which is unrelated to BT-0016.

### (c) Requirements Implemented Incorrectly

1. **Android 14 (API 34) Foreground Service type omitted in `startForeground`:**
   - **Spec Quote:** `task.md` L58: `"Declare service and permissions in AndroidManifest.xml (FOREGROUND_SERVICE, FOREGROUND_SERVICE_SPECIAL_USE, WAKE_LOCK)."`
   - **Finding:** The app targets SDK 34. In `CashewKeepAliveService.kt` (L54), `startForeground(NOTIFICATION_ID, notification)` is invoked without `ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE`. On Android 14+, declaring `specialUse` in the manifest requires supplying the foreground service type flag at runtime, otherwise it risks runtime type validation failure.
2. **`START_STICKY` does not re-initialize Flutter engine on kill:**
   - **Spec Quote:** `task.md` L25: `"Fully-killed / reboot: protected by Foreground Service priority and battery exemption."`
   - **Finding:** In `CashewKeepAliveService.kt` (L58), `START_STICKY` restarts the native Android service if killed, but never initializes a `FlutterEngine`. The Dart `NotificationListenerService` stream listener remains unattached, failing to process payment notifications.

---

## Summary

- **Standards:** 4 findings (2 hard violations, 2 baseline smells). Worst issue: Hardcoded non-localized English strings in native Android notification service drawer/channel (`CashewKeepAliveService.kt`).
- **Spec:** 6 findings (3 missing/partial, 1 scope creep, 2 incorrect implementations). Worst issue: Foreground service fails to start automatically on app launch when `notificationScanning == true` (`task.md` L64 omitted from `main.dart`).
