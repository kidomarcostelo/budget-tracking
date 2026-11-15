# Task: Background Keep-Alive & Notification Listener for Tap-to-Pay Capture

**Task ID:** BT-0016  
**Issue Reference:** [Local Tracking] (publish via `gh issue create` once authenticated)  
**Status:** In Progress  
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
- Implement `CashewKeepAliveService.kt` in `budget/android/app/src/main/kotlin/com/example/budget/`.
- Declare service and permissions in `AndroidManifest.xml` (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `WAKE_LOCK`).
- Expose `startKeepAlive`, `stopKeepAlive`, `isIgnoringBatteryOptimizations`, and `requestIgnoreBatteryOptimizations` on `com.budget.tracker_app/background_service` in `MainActivity.kt`.

### VS2: Dart BackgroundServiceManager & Lifecycle Binding
- Create `budget/lib/struct/backgroundService.dart` managing the MethodChannel.
- Bind service start/stop to `NotificationDispatcher.initNotificationScanning()` and `stopListening()`.
- Ensure foreground service starts automatically on app launch if `notificationScanning == true`.

### VS3: Battery Optimization Reliability UX
- Add a battery optimization status/prompt tile in `autoTransactionsPageEmail.dart`.
- Detect if battery optimization is active; if so, display warning tile with action to open Android system battery optimization settings.
- Add localized strings for the new guidance tile.

### VS4: Unit Tests & Verification
- Unit test `BackgroundServiceManager` platform channel calls.
- Unit test notification dispatch with keep-alive active.
- Verify static analysis and formatting.

---

## 4. Invariants & Safety Guardrails
- NEVER edit past Drift migration steps.
- No raw color hex codes in UI widgets — use semantic theme palette.
- All user-facing strings must use `app_localizations` / `.tr()`.
- Branching rule: Work on `feat/bt-0016-background-headless-listener`, never commit to `main`.
