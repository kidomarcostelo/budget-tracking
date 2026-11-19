# BT-0019: Research — Why Cashew's Notification Listener Fails When the App is Killed on Android

**Issue:** [#50](https://github.com/kidomarcostelo/budget-tracking/issues/50)  
**Status:** Research Complete  
**Date:** 2026-11-19

---

## Table of Contents

1. [1A — EventChannel / Stream dependency on live FlutterEngine](#1a--eventchannel--stream-dependency-on-live-flutterengine)
2. [1B — CashewKeepAliveService lifecycle — started from wrong context](#1b--cashewkeepaliveservice-lifecycle--started-from-wrong-context)
3. [1C — notification_listener_service native service — does it run headlessly?](#1c--notification_listener_service-native-service--does-it-run-headlessly)
4. [1D — Flutter background isolate / headless engine — Android lifecycle rules](#1d--flutter-background-isolate--headless-engine--android-lifecycle-rules)
5. [2E — NotificationListenerService process survival](#2e--notificationlistenerservice-process-survival)
6. [2F — Battery optimization impact](#2f--battery-optimization-impact)
7. [3A — Option A: Headless FlutterEngine from Native NotificationListenerService](#3a--option-a-headless-flutterengine-from-native-notificationlistenerservice)
8. [3B — Option B: Native Kotlin Notification Buffer → Flush on App Open](#3b--option-b-native-kotlin-notification-buffer--flush-on-app-open)
9. [3C — Option C: Self-Restart / BOOT_COMPLETED + onTaskRemoved Override](#3c--option-c-self-restart--boot_completed--ontaskremoved-override)
10. [4 — On-Device Testing Protocol](#4--on-device-testing-protocol)
11. [Summary and Recommended Architecture](#summary-and-recommended-architecture)

---

## 1A — EventChannel / Stream dependency on live FlutterEngine

### How notification_listener_service delivers events to Dart

The event delivery chain in notification_listener_service v1.0.0 (X-Slayer fork, locally cached) works as follows:

**Full event path:**

1. Android system triggers NotificationListener.onNotificationPosted()
2. handleNotification() fires sendBroadcast(Intent with INTENT action)
3. NotificationReceiver.onReceive() receives the broadcast (registered BroadcastReceiver)
4. eventSink.success(data) called — EventSink held by NotificationListenerServicePlugin
5. EventChannel "x-slayer/notifications_event" → Dart Stream
6. NotificationListenerService.notificationsStream.listen(...)
7. NotificationDispatcher.handleEvent()

**Source code evidence (from local pub cache):**

NotificationListener.java (the Android NotificationListenerService subclass):
- onNotificationPosted() calls handleNotification(notification, false)
- handleNotification() builds an Intent and calls sendBroadcast(intent)
- Crucially: does NOT call eventSink.success() directly — it fires a local broadcast

NotificationListenerServicePlugin.java (the Flutter plugin):
- onListen() registers a NotificationReceiver as a local BroadcastReceiver via context.registerReceiver()
- The notificationReceiver holds a reference to the EventSink

NotificationReceiver.java:
- onReceive() calls eventSink.success(data) with a HashMap of notification fields

### What happens when the Dart VM / FlutterEngine is terminated?

When the Flutter process is killed:

1. The Flutter engine is destroyed. The BinaryMessenger and FlutterJNI native bindings are torn down.
2. EventChannel.StreamHandler.onCancel() is called. This triggers context.unregisterReceiver(notificationReceiver) and sets notificationReceiver = null.
3. The Dart Stream becomes dead. The subscription in NotificationDispatcher._subscription is cancelled.
4. The Android NotificationListenerService (Java) MAY still survive (see section 2E), but it has no active BroadcastReceiver to send events to — the plugin's onCancel() unregistered it.

**What happens if eventSink.success() is called after engine destruction?**

If the engine is destroyed but the native BroadcastReceiver is somehow still registered (cleanup failed), calling eventSink.success() will silently fail or log:

`
Tried to send a platform message to Flutter, but FlutterJNI was detached from native C++. Could not send.
`

Events are NOT buffered — they are silently dropped. There is no queue or replay mechanism built into EventChannel.

**Conclusion:** The entire Dart-side stream pipeline is tightly coupled to the FlutterEngine lifecycle. If the engine dies, events are lost regardless of whether the native NotificationListenerService is still connected to the Android system.

**Sources:**
- Local source: notification_listener_service-1.0.0/android/.../NotificationListenerServicePlugin.java
- Local source: notification_listener_service-1.0.0/android/.../NotificationReceiver.java
- https://api.flutter.dev/javadoc/io/flutter/plugin/common/EventChannel.StreamHandler.html

---

## 1B — CashewKeepAliveService lifecycle — started from wrong context

### Current architecture

CashewKeepAliveService is started via:
1. Dart calls BackgroundServiceManager.instance.startKeepAlive()
2. This invokes MethodChannel('com.budget.tracker_app/background_service') with method 'startKeepAlive'
3. The MethodChannel handler is registered in MainActivity.configureFlutterEngine() — NOT in a standalone service
4. The handler calls CashewKeepAliveService.start(this@MainActivity)

**Critical problem:** The MethodChannel is bound to MainActivity's FlutterEngine. This means:
- If MainActivity is destroyed, the channel handler dies
- If the Flutter engine is not running, startKeepAlive() can never be called from Dart
- The keep-alive service can only be started while the Flutter UI is active

### Is onTaskRemoved() called? Does the foreground service survive?

Android behavior when user swipes from Recents:
- Activity.finish() is NOT called — the task is removed
- For services still running: Service.onTaskRemoved(Intent rootIntent) IS called
- CashewKeepAliveService does NOT override onTaskRemoved() — no self-restart logic
- After onTaskRemoved(), Android will stop the service on many OEM devices

**Is START_STICKY sufficient after process death?**

CashewKeepAliveService.onStartCommand() returns START_STICKY. This means:
- If killed by the OS (low memory): Android will restart the service with a null intent
- If swiped from Recents by user: START_STICKY is NOT guaranteed to restart on most OEM devices
- When Android restarts a START_STICKY service, it only restarts native Kotlin/Java code — NOT the Flutter engine or Dart VM

| Scenario | Flutter Engine | CashewKeepAliveService | NotificationListenerService |
|----------|---------------|------------------------|----------------------------|
| Home button pressed | May stay alive | Running (foreground) | Running, connected |
| Screen locked | May stay alive | Running (foreground) | Running, connected |
| Swiped from Recents (Pixel) | Killed | Stopped (START_STICKY may restart native-only) | May restart (system-bound) |
| Swiped from Recents (Samsung/MIUI) | Killed | Stopped (force-stop-like) | Killed or disconnected |
| adb shell am force-stop | Killed | Stopped (not restarted) | Killed |
| Device reboot | N/A | Not started (no BOOT_COMPLETED receiver) | Restarted by system |

**Sources:**
- Local source: budget/lib/struct/backgroundService.dart
- Local source: budget/android/app/src/main/kotlin/com/example/budget/MainActivity.kt lines 149-193
- Local source: budget/android/app/src/main/kotlin/com/example/budget/CashewKeepAliveService.kt
- https://developer.android.com/reference/android/app/Service#START_STICKY

---

## 1C — notification_listener_service native service — does it run headlessly?

**Answer: No. It entirely relies on the Flutter engine being alive (via BroadcastReceiver) to deliver events to Dart.**

Evidence from local source:

1. NotificationListener.java extends android.service.notification.NotificationListenerService. This IS bound by the Android system and CAN survive without the Flutter engine — Android's system_server holds the binding.

2. However, NotificationListener.java does NOT:
   - Call FlutterMain.startInitialization() or any Flutter engine bootstrapping
   - Spin up a headless engine on onNotificationPosted
   - Hold a reference to any Flutter engine

3. Instead, it fires a local broadcast intent (sendBroadcast(intent)). This broadcast is received by NotificationReceiver, which is registered programmatically by NotificationListenerServicePlugin.onListen() — only when the Flutter engine is running.

| Component | Survives process death? | Notes |
|-----------|------------------------|-------|
| Android NotificationListenerService (Java class) | Yes (usually) — system rebinds it | Subject to OEM restrictions |
| BroadcastReceiver registered by plugin | No — unregistered when engine dies | Programmatically registered |
| EventChannel / Dart Stream | No | Flutter engine is dead |
| NotificationDispatcher._subscription | No | Dart isolate is dead |
| CashewKeepAliveService | Possibly (START_STICKY) but native-only | No Dart VM restarted |

**Sources:**
- Local source: notification_listener_service-1.0.0/android/.../NotificationListener.java
- Local source: notification_listener_service-1.0.0/android/.../NotificationListenerServicePlugin.java
- https://pub.dev/packages/notification_listener_service

---

## 1D — Flutter background isolate / headless engine — Android lifecycle rules

### What is @pragma('vm:entry-point')?

@pragma('vm:entry-point') is a Dart VM annotation that prevents the Dart compiler's tree-shaker from stripping a function during AOT compilation. Without it, functions not called from Dart code may be eliminated in release builds.

For background callbacks, top-level Dart functions must be annotated so they can be invoked by name from native Kotlin/Java code via DartExecutor.executeDartEntrypoint().

### Official Flutter background execution patterns

Flutter supports these patterns for Android background execution:

1. Background isolates (Dart Isolate.spawn): In-process, no shared memory. Cannot access Flutter plugins directly without RootIsolateToken + BackgroundIsolateBinaryMessenger (Flutter 3.7+).

2. Headless FlutterEngine (spawned from native Android code): Create a FlutterEngine in Kotlin from within a Service, execute a DartEntrypoint by name. This is how firebase_messaging handles background messages.

3. flutter_background_service (pub.dev): Wraps the headless engine lifecycle. Uses @pragma('vm:entry-point') on a Dart function in a persistent foreground service.

4. workmanager (pub.dev): Wraps Android WorkManager, uses a headless FlutterEngine per work item. Minimum interval: 15 minutes.

### Spawning a headless FlutterEngine from NotificationListenerService

`kotlin
// In Kotlin NotificationListenerService.onNotificationPosted()
if (flutterEngine == null) {
    FlutterMain.startInitialization(applicationContext)
    FlutterMain.ensureInitializationComplete(applicationContext, null)
    flutterEngine = FlutterEngine(applicationContext).apply {
        dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                FlutterMain.findAppBundlePath(),
                "backgroundEntrypoint"
            )
        )
    }
}
`

**Known issues:**
- FlutterEngine startup takes 300-800ms (cold start)
- Each FlutterEngine instance consumes ~20-50MB RAM; must be cached
- Drift DB opened from two engines requires WAL mode and careful write isolation
- Plugin registration required: GeneratedPluginRegistrant.registerWith(flutterEngine)
- Cannot call startForegroundService() from onNotificationPosted() on Android 12+ (throws ForegroundServiceStartNotAllowedException)

**Sources:**
- https://docs.flutter.dev/perf/isolates
- https://github.com/firebase/flutterfire/blob/master/packages/firebase_messaging/firebase_messaging/android/src/main/java/io/flutter/plugins/firebase/messaging/FlutterFirebaseMessagingBackgroundService.java
- https://pub.dev/packages/flutter_background_service
- https://pub.dev/packages/workmanager


---

## 2E — NotificationListenerService process survival

### Does Android guarantee NLS stays bound after app kill?

Android's NotificationListenerService is a special system-bound service. Unlike ordinary started services, it is bound by Android's NotificationManagerService (part of system_server). This binding is established when the user grants notification access permission in System Settings.

**Key behaviors:**

- On stock AOSP (Pixel, Android One): Android 12-15 generally keeps the NotificationListenerService running even after the user swipes the app from Recents. The service is re-bound by the system if the process dies, because system_server holds the binding.

- The system calls onListenerDisconnected() if the binding is temporarily severed. On API 24+, the service can call requestRebind(ComponentName) to ask the system to rebind it. The package's NotificationListener.java already does this in its onListenerDisconnected() callback.

- Runs in app's process: NotificationListenerService does NOT run in its own isolated process unless android:process is specified in the manifest. Cashew's manifest does not specify a separate process, so notification.listener.service.NotificationListener runs in the same process (com.budget.tracker_app). When the process is killed, the native service class is killed too and must be rebound by the OS.

### Android version-specific behavior (12-15)

| Android Version | Recents swipe behavior | Force-stop behavior |
|----------------|------------------------|---------------------|
| Android 12 (API 32) | NLS may restart; strict BG start restrictions begin | NLS killed; not restarted until system rebind |
| Android 13 (API 33) | NLS rebind likely on Pixel; OEM dependent | NLS killed |
| Android 14 (API 34) | FGS type enforcement; NLS rebind on Pixel | NLS killed; force-stop prevents auto-restart |
| Android 15 (API 35) | BOOT_COMPLETED restrictions for certain FGS types | NLS killed |

**Critical point about adb shell am force-stop:**
Force-stop marks the app as "stopped" state. Android explicitly prevents any component of a stopped app from starting automatically until the user manually opens the app. This includes NotificationListenerService, BroadcastReceiver, and START_STICKY service restarts. Force-stop is the most severe kill scenario.

**Sources:**
- https://developer.android.com/reference/android/service/notification/NotificationListenerService
- https://developer.android.com/about/versions/oreo/background
- https://developer.android.com/about/versions/15/behavior-changes-15

---

## 2F — Battery optimization impact

### Doze mode and battery optimization effects

Doze mode (introduced Android 6): When the device is idle and unplugged, Android restricts CPU wakeups, network access, and background processing.

NotificationListenerService has a special exemption from Doze restrictions — it is considered a privileged system binding and continues to receive onNotificationPosted() callbacks even during Doze on AOSP. However, if the Flutter engine is dead, those callbacks still cannot reach Dart.

REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission: Already declared in Cashew's AndroidManifest.xml. When granted:
- The app process is less likely to be killed by Android's OOM killer
- CashewKeepAliveService is less likely to be stopped
- However, it does NOT prevent user force-stop or swipe from Recents on OEM skins

### Manufacturer-specific behavior

| Manufacturer | Background kill behavior | Recommended user action |
|-------------|--------------------------|------------------------|
| Stock Android / Pixel | Relatively permissive; NLS typically survives swipe | Exempt from battery optimization is sufficient |
| Samsung One UI | Aggressive "Sleeping apps" / "Deep sleeping apps"; may kill NLS | Set battery to Unrestricted; add to Never sleeping apps |
| Xiaomi MIUI / HyperOS | Most aggressive; process killed almost immediately after swipe | Enable Autostart; set battery to No restrictions; lock in Recents |
| OnePlus / ColorOS (Oppo) | Similar to MIUI | Enable auto-launch; set power saving to No restriction |

Key insight: Battery optimization exemption is a necessary but not sufficient condition. On OEM devices, additional per-manufacturer steps are required. The dontkillmyapp.com resource documents per-device steps.

**Sources:**
- https://developer.android.com/training/monitoring-device-state/doze-standby
- https://dontkillmyapp.com
- https://www.samsung.com/global/galaxy/apps/one-ui/battery/
- https://dontkillmyapp.com/xiaomi

---

## 3A — Option A: Headless FlutterEngine spawned from Native NotificationListenerService

### Architecture overview

`
Android system notifies → Native NotificationListenerService.onNotificationPosted()
  ↓ (if FlutterEngine not running) FlutterEngine.create() + executeDartEntrypoint("backgroundEntrypoint")
  ↓ MethodChannel pass: packageName, title, content, timestamp
  ↓ Dart backgroundEntrypoint() → GooglePayParser.parse() → Drift DB write (pending=true)
  ↓ Post local notification: "Tap to review transaction"
`

### Feasibility on Android 12-15

Technically feasible but with significant caveats:

1. **Startup latency:** First cold start of a Flutter engine from a native service takes 300-800ms. Notification data is preserved via onNotificationPosted() regardless, but processing is delayed.

2. **Memory overhead:** Each FlutterEngine instance consumes ~20-50MB RAM. Must cache the engine and reuse it. Must call flutterEngine.destroy() in onDestroy().

3. **Drift DB in headless engine:** Drift uses sqlite3_flutter_libs for FFI. Opening the same DB file from two engines (main UI + background) requires WAL mode and careful write isolation to avoid contention.

4. **Plugin registration:** Must call GeneratedPluginRegistrant.registerWith(flutterEngine) to initialize all Flutter plugins in the headless engine.

5. **Android 15 restrictions:** Cannot start FGS from BOOT_COMPLETED for certain types. The NotificationListenerService itself starts independently (system-bound), so the headless engine can be spun up from within it.

6. **FGS start from NLS on Android 12+:** Calling startForegroundService() from within onNotificationPosted() while the app is in the background throws ForegroundServiceStartNotAllowedException. The headless engine must NOT try to start a new foreground service.

### Implementation steps

1. Create Kotlin CashewNotificationListenerService extending NotificationListenerService
2. In onNotificationPosted(), filter for Google Wallet packages
3. Spin up cached headless FlutterEngine via FlutterEngineGroup
4. Call Dart @pragma('vm:entry-point') void backgroundNotificationCallback(Map data)
5. In Dart: WidgetsFlutterBinding.ensureInitialized(), initialize Drift, call GooglePayParser.parse(), write to DB with pending=true
6. Post local notification via native NotificationManager

### Known issues

- Double-write risk if app is open AND headless engine fires simultaneously
- App settings (SharedPreferences) may not be accessible in headless engine without loading from disk manually
- Complex lifecycle management for FlutterEngineGroup
- Risk of memory leaks if engine not properly destroyed

**Verdict:** High complexity, medium reliability. Rewrites a significant part of the notification infrastructure.

---

## 3B — Option B: Native Kotlin Notification Buffer → Flush on App Open (Lightweight)

### Architecture overview

`
Android system notifies → Native CashewNotificationListenerService (pure Kotlin, no Flutter)
  ↓ Extract: packageName, title, content, timestamp
  ↓ Write JSON entry to SharedPreferences key "cashew_notification_buffer" (append to list)
  ↓ Post local notification: "1 transaction pending review — open Cashew"

[App opens] → Dart reads SharedPreferences buffer on startup
  ↓ Pass each buffered event through NotificationDispatcher.handleEvent()
  ↓ Normal GooglePayParser + DedupeLedger + Drift DB flow
  ↓ Clear buffer
`

### Reliability

Near 100% reliable for capturing notification data, because:
- The native NotificationListenerService (Java/Kotlin) is rebound by the Android system automatically
- Pure Kotlin code — no Flutter engine startup required
- SharedPreferences write is fast (~1ms) and synchronous
- Local notification can be posted using native Android NotificationManager immediately

**Latency:** Transactions appear only when the user opens Cashew. This is a UX trade-off.

### SharedPreferences key collision note

Flutter's shared_preferences package stores data in a file named FlutterSharedPreferences with a prefix "flutter." on each key. Native Kotlin can read/write the same file:

`kotlin
val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
val existingBuffer = prefs.getString("flutter.cashew_notification_buffer", "[]") ?: "[]"
// Append new JSON entry
prefs.edit().putString("flutter.cashew_notification_buffer", updatedJson).apply()
`

Then in Dart on app start:
`dart
final prefs = await SharedPreferences.getInstance();
await prefs.reload();
final bufferedJson = prefs.getString('cashew_notification_buffer') ?? '[]';
`

### Trade-offs vs Option A

| Aspect | Option A (Headless Engine) | Option B (Native Buffer) |
|--------|---------------------------|--------------------------|
| Reliability on force-stop | Low (engine may fail to start) | High (pure Kotlin) |
| Reliability on swipe (OEM) | Low-Medium | High |
| Implementation complexity | High | Low-Medium |
| Android 14/15 compatibility | Complex | Simple |
| Latency | Near-instant DB write | Deferred to app open |
| Existing pipeline reuse | Partial (Dart in headless) | Full (flush at app open) |
| Risk of data loss | Medium | Very low |

**Verdict:** Recommended for Cashew's use case. Simplest implementation, highest reliability, no Android version compatibility risk.

---

## 3C — Option C: Self-Restart / BOOT_COMPLETED + onTaskRemoved Override

### Core flaw: Native service restart does NOT equal Flutter engine restart

Even if CashewKeepAliveService is successfully restarted via:
- START_STICKY auto-restart
- onTaskRemoved() → AlarmManager trick
- BOOT_COMPLETED receiver

...the Dart VM / Flutter engine is NOT restarted by any of these mechanisms. The NotificationDispatcher's stream subscription only exists in the Dart isolate. There is nothing to subscribe to after a pure native restart.

### onTaskRemoved() reliability

- Calling startForegroundService() from onTaskRemoved() on Android 12+ in background state may throw ForegroundServiceStartNotAllowedException
- Many OEM ROMs ignore AlarmManager-based restart tricks when the app is in the "stopped" state after a user swipe
- On Android 15, specific FGS types cannot be started from BOOT_COMPLETED at all

### BOOT_COMPLETED receiver

Cashew currently has NO BOOT_COMPLETED receiver registered for CashewKeepAliveService. It has one for flutter_local_notifications (ScheduledNotificationBootReceiver), but that is unrelated. Adding BOOT_COMPLETED → start CashewKeepAliveService only addresses the reboot scenario, not the user-swipe scenario, and still does not restart the Flutter engine.

### WorkManager alternative

WorkManager CAN restart periodic background work after process death and reboots. However, WorkManager work runs in a Dart headless engine when using the workmanager package, bringing the same headless engine complexity as Option A, plus WorkManager's minimum interval is 15 minutes — too long for real-time transaction capture.

**Verdict:** This option alone does not solve the core problem (dead Dart VM). It is an enhancement that complements Options A or B, not a standalone solution. BOOT_COMPLETED + onTaskRemoved can be added to Option B as an enhancement, but Option B already handles post-reboot naturally once the user opens the app.

---

## 4 — On-Device Testing Protocol

### Prerequisites

`ash
# From budget-tracking repo root
cd budget

# Install dependencies
flutter pub get

# Build debug APK (applicationIdSuffix ".debug" configured for BT-0010 isolation)
flutter build apk --debug

# OR for direct device run:
flutter run -d <deviceId> --debug
`

Note: The debug app package is com.budget.tracker_app.debug. Use this package ID in ADB commands.

### Device setup

`ash
# List connected devices
adb devices

# Enable notification access for Cashew in system settings
# (Must be done manually: Settings → Apps → Special app access → Notification access)

# Optionally, disable battery optimization via in-app banner
`

### Scenario 1: App in foreground

`ash
# Start app
adb shell am start -n com.budget.tracker_app.debug/.MainActivity

# Simulate notification (note: package name matters for isGooglePayPackage() filter)
adb shell cmd notification post -S bigtext -t "Google Pay" "Payment of P500.00 to Starbucks"

# Check logcat
adb logcat -s NotificationListener CashewKeepAlive FlutterMain
`

### Scenario 2: App backgrounded (home pressed)

`ash
# Press home button
adb shell input keyevent KEYCODE_HOME

# Wait 5 seconds, then simulate notification
adb shell cmd notification post -S bigtext -t "Google Pay" "Payment of P750.00 to McDonalds"

# Open app and verify transaction was captured
adb shell am start -n com.budget.tracker_app.debug/.MainActivity
`

### Scenario 3: App killed (swiped from Recents / force-stopped)

`ash
# Simulate kill
adb shell am force-stop com.budget.tracker_app.debug

# Confirm process is dead
adb shell pidof com.budget.tracker_app.debug  # Should return nothing

# Wait 5 seconds for system to stabilize

# Simulate Google Wallet notification
# IMPORTANT: Use a real Google Wallet tap-to-pay transaction for accurate testing
# because cmd notification post does not set packageName to com.google.android.apps.walletnfcrel
# To test without real transaction:
# 1. Temporarily modify GooglePayParser.isRecognizedPackage() to also accept "android" package
# 2. Then run:
adb shell cmd notification post -S bigtext -t "Google Pay" "Payment of P1200.00 to Jollibee"

# Check logcat to see if NLS received it
adb logcat -s NotificationListener CashewKeepAlive

# Then open Cashew and verify buffer was flushed (for Option B)
adb shell am start -n com.budget.tracker_app.debug/.MainActivity
`

### Scenario 4: Device rebooted

`ash
# Reboot device
adb reboot

# Wait for device to come back online
adb wait-for-device

# Perform a real Google Wallet tap-to-pay transaction
# Then open Cashew and verify the transaction was captured
adb shell am start -n com.budget.tracker_app.debug/.MainActivity
`

### Verification checklist

| Scenario | Expected Result (after Option B fix) | Pass/Fail |
|----------|--------------------------------------|-----------|
| Foreground | Immediate transaction prompt | |
| Backgrounded (home pressed) | Immediate transaction prompt (NLS + stream active) | |
| Killed (adb force-stop) | Notification buffered in SharedPreferences; appears on next app open | |
| Killed (swipe from Recents) | Notification buffered; appears on next app open | |
| Rebooted | Notification buffered after reboot (once NLS rebound); appears on next app open | |

### Logcat tags to watch

`ash
adb logcat -s \
  NotificationListener:V \
  CashewKeepAlive:V \
  FlutterMain:V \
  flutter:V

# Or capture all and grep
adb logcat | grep -E "(NotificationListener|CashewKeepAlive|FlutterMain|cashew)"
`

---

## Summary and Recommended Architecture

### Why the current architecture fails

The root cause is a fundamental coupling between the Dart event delivery pipeline and the Flutter engine lifecycle:

1. notification_listener_service uses an EventChannel → BroadcastReceiver architecture. The BroadcastReceiver is registered in onListen() and unregistered in onCancel(). Both lifecycle methods are tied to the Flutter engine. When the engine dies, the receiver dies.

2. CashewKeepAliveService is started via a MethodChannel registered in MainActivity.configureFlutterEngine(). It cannot start itself, cannot restart the Flutter engine, and uses START_STICKY which only restarts native code (not Dart).

3. Even if the native NotificationListenerService (Java) survives the process kill (possible on Pixel stock Android), it has no active recipient for broadcast intents because the BroadcastReceiver is dead.

4. Force-stop (adb shell am force-stop) puts the app in a "stopped" state where even START_STICKY and NotificationListenerService auto-rebind are suppressed until the user manually opens the app.

### Recommendation: Option B — Native Kotlin Notification Buffer

Option B is the recommended approach for the following reasons:

| Criterion | Option A (Headless Flutter) | Option B (Native Buffer) | Option C (Self-Restart) |
|-----------|---------------------------|--------------------------|------------------------|
| Reliability on force-stop | Low (engine may fail to start) | High (pure Kotlin) | Does not solve it |
| Reliability on swipe (OEM) | Low-Medium | High | Does not solve it |
| Implementation complexity | High | Low-Medium | Medium |
| Android 14/15 compatibility | Complex | Simple | Complex |
| Latency | Near-instant | Deferred to app open | N/A |
| Existing pipeline reuse | Partial (Dart in headless) | Full (flush at app open) | No |
| Risk of data loss | Medium | Very low | High |

### Implementation plan (high level)

1. **Create CashewNativeNotificationListener.kt:** A pure Kotlin NotificationListenerService subclass that:
   - Filters for Google Wallet/bank packages by packageName
   - Writes {packageName, title, content, timestamp} as JSON entries to SharedPreferences ("cashew_notification_buffer")
   - Posts a local notification via native NotificationManager: "X transaction(s) pending — open Cashew to review"

2. **Register in AndroidManifest.xml:** Add CashewNativeNotificationListener service declaration, keeping the existing notification.listener.service.NotificationListener for active Flutter session delivery.

3. **Add BOOT_COMPLETED receiver (optional enhancement):** Register CashewBootReceiver.kt to handle post-reboot notification capture state.

4. **Flush buffer in Dart on startup:** In initNotificationScanning() or main(), add a _flushNotificationBuffer() call that:
   - Reads SharedPreferences['cashew_notification_buffer']
   - Deserializes each JSON entry into a synthetic ServiceNotificationEvent
   - Passes through NotificationDispatcher.handleEvent()
   - Clears the buffer

5. **Deduplication:** The existing DedupeLedger will prevent double-processing if the app was open AND the buffer captured the same notification.

**Estimated complexity:** 2-3 days (1 Kotlin file + 1 Dart flush method + manifest changes + tests)

---

*Research compiled by Antigravity agent on 2026-11-19. Primary sources: local pub cache inspection, Android developer documentation, Flutter background execution guides, and pub.dev package documentation.*
