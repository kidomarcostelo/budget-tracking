# Task: Background Keep-Alive & Notification Listener for Tap-to-Pay Capture

**Task ID:** BT-0016  
**Issue Reference:** [Local Tracking] (publish via `gh issue create` once authenticated)  
**Status:** In Review (Remediations Applied)  
**Assignee / Agent:** Antigravity  

---

## 1. Problem Statement

When Cashew is in the background or the screen is locked, Android's process lifecycle management can freeze or terminate the Flutter process. Consequently, when the user performs a tap-to-pay transaction via Google Wallet / Google Pay, Cashew's `NotificationListenerService` event stream cannot deliver the notification to Dart. The user currently has to remember to open Cashew before making a payment so that the app process remains resident in memory.

---

## 2. Design Decisions (from /grilling session, 2026-11-15)

| # | Question / Decision | Resolution |
|---|---------------------|------------|
| Q1 | Dart Parser vs Native Kotlin Rewrite | Reuse 100% of existing Dart `GooglePayParser`, `NotificationDispatcher`, and Drift DB logic. |
| Q2 | Background Transaction Routing | Save as `pending = true` and display local notification for user review (integrated with BT-0015). |
| Q3 | Scope of Notifications | Unified pipeline: all enabled scanner templates (Google Pay + bank notifications) handled in background. |
| Q4 | Battery Optimization Guidance | In-app settings tile to check and request exemption from battery optimizations (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). |
| Q5 | Background Execution Architecture | Android Foreground Keep-Alive Service (`CashewKeepAliveService`) that keeps Cashew alive in RAM so `NotificationListenerService` never drops events. |
| Q6 | Guarantees | Primary guarantee: backgrounded / screen-locked. Fully-killed / reboot: protected by Foreground Service priority and battery exemption. |
| Q7 | User Setting Representation | Automatic: when `notificationScanning` is enabled, the background monitor is activated. No extra confusing toggle. |
| Q8 | Tracking | BT-0016, referencing parent epic #7 (BT-0003 Google Pay automation). |

---

## 3. Architecture & Vertical Slices

```
                    ┌────────────────────────────────────────┐
                    │ Android OS (Payment / Bank Notification)│
                    └───────────────────┬────────────────────┘
                                        │
                         NotificationListenerService
                                        │
┌───────────────────────────────────────▼────────────────────────────────────────┐
│ Cashew App Process (Kept alive by CashewKeepAliveService)                      │
│                                                                                │
│  ┌─────────────────────────┐         ┌───────────────────────────────────────┐ │
│  │ CashewKeepAliveService  │         │ NotificationDispatcher                │ │
│  │ (Android Foreground Svc)│         │ (Maintains active event stream)       │ │
│  └─────────────────────────┘         └───────────────────┬───────────────────┘ │
│                                                          │                     │
│                                              GooglePayParser / Template        │
│                                                          │                     │
│                                              Drift DB: Pending Transaction     │
│                                                          │                     │
│                                              Local Review Notification         │
└────────────────────────────────────────────────────────────────────────────────┘
```

### VS1: Native Foreground Keep-Alive Service & MethodChannel
- [x] Implement `CashewKeepAliveService.kt` in `budget/android/app/src/main/kotlin/com/example/budget/`.
- [x] Pass `ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE` in `startForeground` for Android 14+ (API 34) compliance.
- [x] Use localized Android string resources (`strings.xml`) for notification title, content, channel name, and description.
- [x] Declare service and permissions in `AndroidManifest.xml` (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `WAKE_LOCK`).
- [x] Expose `startKeepAlive`, `stopKeepAlive`, `isIgnoringBatteryOptimizations`, and `requestIgnoreBatteryOptimizations` on `com.budget.tracker_app/background_service` in `MainActivity.kt`.

### VS2: Dart BackgroundServiceManager & Lifecycle Binding
- [x] Create `budget/lib/struct/backgroundService.dart` managing the MethodChannel with consolidated invocation helper.
- [x] Bind service start/stop to `NotificationDispatcher.initNotificationScanning()` and `stopListening()`.
- [x] Automatically invoke `BackgroundServiceManager.instance.startKeepAlive()` eagerly in `main.dart` if `notificationScanning == true`.

### VS3: Battery Optimization Reliability UX
- [x] Extract `BatteryOptimizationCard` into `budget/lib/widgets/batteryOptimizationCard.dart`.
- [x] Remove duplicate tap handlers between container card and button.
- [x] Add localized strings in `en.json` for title, description, and action button.

### VS4: Unit Tests & Verification
- [x] Unit test `BackgroundServiceManager` platform channel calls for start, stop, battery check, exemption request, and non-Android no-ops.
- [x] Unit test notification dispatch with keep-alive verified active.
- [x] Verify static analysis and formatting.

---

## 4. Code Review Remediation Summary (PR #40 / BT-0016)
1. **Android 14 API 34 Support:** `CashewKeepAliveService.kt` passes `ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE` to `startForeground()`.
2. **Localization:** Added `budget/android/app/src/main/res/values/strings.xml` and referenced resource strings in native service.
3. **Widget Decomposition:** Extracted `BatteryOptimizationCard` into `budget/lib/widgets/batteryOptimizationCard.dart`.
4. **App Startup:** `budget/lib/main.dart` eagerly starts keep-alive on startup when `notificationScanning == true`.
5. **Deduplication:** Consolidated channel invocation in `budget/lib/struct/backgroundService.dart`.
6. **Task Cleanliness:** Reverted unrelated `BT-0017` from `.scratch/index.md`.
7. **Integration Test:** Added notification processing test while keep-alive is active in `background_service_test.dart`.

---

## 5. Invariants & Safety Guardrails
- NEVER edit past Drift migration steps.
- No raw color hex codes in UI widgets — use semantic theme palette.
- All user-facing strings must use `app_localizations` / `.tr()`.
- Branching rule: Work on `feat/bt-0016-background-headless-listener`, never commit to `main`.
