# Plan: Headless Background Notification Capture via Native Buffer (BT-0019)

> **Task ID:** BT-0019  
> **Source Issue:** [#50](https://github.com/kidomarcostelo/budget-tracking/issues/50)  
> **Research Reference:** [research.md](research.md)  
> **Related Epics / Tasks:**
> - [BT-0003: Extend automatic transaction creation to Google Pay](../BT-0003-extend-auto-transactions-google-pay/task.md)
> - [BT-0015: Non-blocking notification with pending transaction queue](../BT-0015-non-blocking-notifications/task.md)
> - [BT-0016: Background keep-alive service and notification listener](../BT-0016-background-headless-listener/task.md)
> - [BT-0018: Google Pay wallet resolution specificity](../BT-0018-googlepay-wallet-resolution-specificity/task.md)

---

## 1. Summary & Goals

User testing of the background listener on a physical Android device revealed that when Cashew is **not running in the background** (e.g. process killed by OS, dismissed from Recent Apps by user swipe, or device rebooted), Google Wallet tap-to-pay transactions fail to be captured.

### Root Causes (from Research):
1. **EventChannel / BroadcastReceiver Coupling:** `notification_listener_service: ^1.0.0` registers its `BroadcastReceiver` programmatically inside `onListen()` and unregisters it in `onCancel()`. When the Flutter Engine / Dart VM dies, the receiver dies. Android's native `NotificationListenerService` fires local broadcasts into a void, silently discarding all notifications.
2. **Keep-Alive Context Boundary:** `CashewKeepAliveService` is started via a Flutter `MethodChannel` bound to `MainActivity`. It cannot restart itself, has no `onTaskRemoved()` self-rescheduling, and `START_STICKY` only restarts native Kotlin code without reviving the Flutter Engine or Dart VM.
3. **No Headless Bootstrapping:** The third-party plugin has no mechanism to spin up a headless `FlutterEngine` upon incoming notifications when the app process is terminated.

### Solution (Option B: Native Kotlin Notification Buffer):
Implement a lightweight, highly resilient native Kotlin `NotificationListenerService` subclass (`CashewNativeNotificationListener`) that intercepts recognized payment notifications (Google Wallet, Google Pay, and supported banks) completely independently of the Flutter Engine. 
- The native listener writes notification payloads as JSON entries into a persistent buffer in `SharedPreferences("FlutterSharedPreferences")`.
- It posts an immediate native Android status bar notification: *"1 transaction pending — open Cashew to review"*.
- When the user opens or resumes Cashew, Dart flushes the buffer on cold start and inside `OnAppResume`, passing each synthetic event through the battle-tested `NotificationDispatcher` -> `GooglePayParser` -> `DedupeLedger` -> Drift DB pending queue pipeline.

---

## 2. Settled Architecture Decisions

| # | Topic | Selected Option | Rationale |
|---|---|---|---|
| **D1** | Background Capture Strategy | **Option B: Native Kotlin Buffer** | Avoids the 300–800ms latency, 20–50MB RAM overhead, and multi-engine SQLite concurrency pitfalls of spinning up a headless `FlutterEngine` (Option A). Pure Kotlin listener survives and buffers reliably even when Flutter is dead. |
| **D2** | Buffer Persistence Medium | **`SharedPreferences` ("FlutterSharedPreferences")** | Flutter's `shared_preferences` plugin stores data in `FlutterSharedPreferences.xml` prefixed with `flutter.`. Native Kotlin can read and write to this file in < 2ms without needing a separate SQLite table or Drift schema migration. |
| **D3** | Buffer Data Contract | **Compact JSON Array** | `[{"id": 123, "packageName": "com.google.android.apps.walletnfcrel", "title": "...", "content": "...", "timestamp": 1732000000000}]`. Direct mapping to Dart `ServiceNotificationEvent`. |
| **D4** | User Notification on Capture | **Native Android Status Bar Notification** | When a notification is buffered while Cashew is dead, post a low-priority system notification informing the user that a transaction was captured and tapping it opens Cashew. |
| **D5** | Dart Processing Pipeline | **100% Reuse of Existing Pipeline** | Deserialized buffer entries are dispatched into `NotificationDispatcher.instance.handleEvent()`. Reuses existing `GooglePayParser`, `DedupeLedger`, and Drift DB pending transaction queue. |
| **D6** | Deduplication Protection | **Existing `DedupeLedger`** | If Cashew happened to be alive when the notification fired and the active stream captured it, `DedupeLedger` automatically suppresses the buffered copy when flushed. |
| **D7** | Flush Trigger Points | **Dual Trigger: Cold Start + `OnAppResume`** | Flushed during app initialization (`main.dart` / `initNotificationScanning()`) AND inside `OnAppResume` (when the user switches back to Cashew after tapping to pay). |
| **D8** | Testing & Validation Mode | **Physical Device Verification** | Provide an explicit debug simulation flag/package recognition for ADB testing so the user can verify killed-state capture on their phone before merging to remote. |

---

## 3. Architecture & Data Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                          Android OS System                             │
│       (Google Wallet / Bank Payment Notification arrives)              │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
               System BIND_NOTIFICATION_LISTENER_SERVICE
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│            CashewNativeNotificationListener.kt (Native Kotlin)         │
│                                                                        │
│  1. Check: isRecognizedPackage(packageName)?                           │
│  2. Read existing buffer from SharedPreferences                        │
│  3. Append {"id", "packageName", "title", "content", "timestamp"}      │
│  4. Save buffer to "flutter.cashew_notification_buffer"                │
│  5. Post native review notification: "1 transaction pending review"    │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ User taps notification OR opens Cashew
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                          Cashew Flutter App                            │
│                                                                        │
│   main.dart (Startup) OR OnAppResume (Foreground Resume)               │
│                                    │                                   │
│                                    ▼                                   │
│             NotificationDispatcher.flushBufferedNotifications()        │
│                                    │                                   │
│  1. Read & clear "cashew_notification_buffer" from SharedPreferences   │
│  2. Deserialize each entry into synthetic ServiceNotificationEvent     │
│  3. Dispatch to handleEvent(event)                                     │
│                                    │                                   │
│       ┌────────────────────────────┼───────────────────────────┐       │
│       ▼                            ▼                           ▼       │
│  GooglePayParser             DedupeLedger                 Drift DB     │
│ (parse card, amount)     (suppress duplicates)        (save pending tx)│
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Work Breakdown & Vertical Slices

### Slice 1: Native Kotlin Buffer Service (`CashewNativeNotificationListener.kt`)
- Implement `CashewNativeNotificationListener.kt` in `budget/android/app/src/main/kotlin/com/example/budget/`.
- Filter incoming notifications using `GooglePayParser.recognizedPackages` and bank triggers.
- Read, append, and atomic-write JSON buffer to `FlutterSharedPreferences` under key `flutter.cashew_notification_buffer`.
- Post a persistent/tap-to-open notification using `NotificationCompat.Builder` with localized resource strings (`strings.xml`).
- Register service in `budget/android/app/src/main/AndroidManifest.xml` with `BIND_NOTIFICATION_LISTENER_SERVICE`.

### Slice 2: Dart Buffer Reader & Dispatcher Integration
- Add `flushBufferedNotifications()` method to `NotificationDispatcher` in `budget/lib/struct/notificationDispatcher.dart`.
- Access `sharedPreferences.getString("cashew_notification_buffer")`.
- Deserialize JSON entries and reconstruct synthetic `ServiceNotificationEvent` instances.
- Route through `handleEvent(event)`, allowing `DedupeLedger` to filter already-handled notifications.
- Clear the SharedPreferences buffer upon successful deserialization.

### Slice 3: App Lifecycle Integration
- Call `flushBufferedNotifications()` in `budget/lib/main.dart` during app initialization.
- Wire `flushBufferedNotifications()` into `OnAppResume` in `main.dart` so returning to Cashew from Google Wallet immediately triggers a flush.

### Slice 4: Test Suite & On-Device Testing Harness
- Unit tests in `budget/test/notification_buffer_test.dart` for buffer serialization, deserialization, empty buffer, malformed JSON resilience, and deduplication.
- Add test-mode package recognition support for ADB simulated testing (`"android"` package simulation).
- Complete physical device testing guide with step-by-step ADB commands and manual validation scenarios.

---

## 5. Non-Negotiable Invariants & Guardrails

- **Zero Drift Migrations:** No schema version changes or Drift database modifications.
- **Zero Suppression:** No `// ignore:` or `// ignore_for_file:` comments.
- **Static Analysis Bar:** `flutter analyze` must report 0 issues.
- **Formatting Bar:** `dart format --output=none --set-exit-if-changed .` must pass clean.
- **Test Integrity:** All existing tests must pass, plus new regression/buffer tests.
- **Branching Rule:** Work on a dedicated feature branch (e.g. `feat/BT-0019-headless-notification-buffer`), never commit directly to `main`.
- **Review Barrier:** Pause for user review on PR creation before merging.
