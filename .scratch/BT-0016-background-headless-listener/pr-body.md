## Summary

Resolves the issue where Cashew misses Google Pay / Google Wallet tap-to-pay notifications unless the app was manually opened beforehand. Implements an Android Foreground Keep-Alive Service (`CashewKeepAliveService`) that keeps Cashew resident in memory while the screen is locked, paired with on-device Battery Optimization guidance.

- **Task Reference:** BT-0016 (`.scratch/BT-0016-background-headless-listener/task.md`)
- **Parent Epic:** #7 (BT-0003 Google Pay auto-transactions)
- **Pending Queue Integration:** #33 (BT-0015)
- **Review Reference:** `docs/code-reviews/PR-40-background-headless-listener.md`

## Changes & Remediations

### 1. Native Android Keep-Alive Service (Android 14+ Ready)
- Added `CashewKeepAliveService.kt` in `com.budget.tracker_app` running as an Android foreground service with a low-priority notification channel.
- Added `ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE` to `startForeground()` on Android 14+ (API 34) to prevent runtime exceptions.
- Extracted notification and channel strings to `res/values/strings.xml` for localization standard compliance.
- Declared `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `WAKE_LOCK`, and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` in `AndroidManifest.xml`.
- Registered `com.budget.tracker_app/background_service` MethodChannel in `MainActivity.kt`.

### 2. Dart Service Manager & Lifecycle Binding
- Added `BackgroundServiceManager` singleton in `budget/lib/struct/backgroundService.dart` with consolidated `_invokeNativeAction` helper.
- Bound `startKeepAlive()` to `initNotificationScanning()` and `stopKeepAlive()` to `stopListening()`.
- Automatically invoke `startKeepAlive()` eagerly in `main.dart` on app launch when `notificationScanning == true`.
- Preserved 100% of existing `GooglePayParser`, deduplication ledger, and pending queue workflows.

### 3. Decomposed Battery Optimization UX
- Extracted `BatteryOptimizationCard` into `budget/lib/widgets/batteryOptimizationCard.dart`.
- Removed redundant tap handler between container card and action button.
- Added localized strings in `en.json`.

### 4. Tests
- Added 7 unit and integration tests in `budget/test/background_service_test.dart` verifying channel methods, status checks, non-Android safe no-ops, lifecycle synchronization, and event processing while keep-alive is active.

## Verification Checklist
- [x] Unit & integration tests pass (`background_service_test.dart`)
- [x] Android 14 foreground service type flag verified
- [x] All user-facing text localized via string resources and `en.json`
- [x] Widget decomposition standards satisfied
- [x] No regressions to existing notification scanning or dedupe logic
- [ ] Manual test: Screen locked, tap-to-pay captured to pending queue without launching Cashew first
