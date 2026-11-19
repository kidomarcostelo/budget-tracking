# Task: Research Headless Background Notification Capture for Google Wallet When App is Closed

**ID:** BT-0019  
**Issue Reference:** [#50](https://github.com/kidomarcostelo/budget-tracking/issues/50)  
**Status:** In Progress (Research Phase)  
**Assignee / Agent:** Antigravity  

---

## 1. Objective & Scope

### Problem Statement
User testing on physical Android devices showed that tap-to-pay notification capture fails when Cashew is **not running in the background** (e.g., process killed by OS, swiped away by user from recent tasks, or device rebooted). When Google Wallet transactions occur while Cashew is closed, Cashew fails to receive, parse, or record the notification.

### Expected Behavior
- Notifications from Google Wallet (and configured bank templates) should be reliably captured even if Cashew's UI is not open or running in the background.
- Transactions should be queued as `pending = true` in Drift DB or a persistent staging buffer with a local user review notification displayed.
- Clear on-device testing methodology must be established so changes can be thoroughly validated on a physical device prior to merging remote PRs.

---

## 2. Invariants & Constraints
- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- Keep existing transaction deduplication (`TransactionDeduplicator`) and parsing heuristics (`GooglePayParser`) intact.
- Android 14+ (API 34/35) foreground service type and permission constraints must be respected.
- Drift database schema versioning must follow strict migration rules (never edit past migrations).
- Implementation must support on-device verification on physical hardware before merging to `main`.

---

## 3. Research Questions & Hypotheses

### R1: Headless FlutterEngine vs. Native Kotlin Interceptor
- **Option A (Headless FlutterEngine):** Does `notification_listener_service` support headless callbacks, or do we implement a native `NotificationListenerService` subclass that initializes a background `FlutterEngine` and calls a `@pragma('vm:entry-point')` Dart function?
  - *Pros:* Reuses Dart `GooglePayParser`, `NotificationDispatcher`, and Drift DB directly.
  - *Cons:* FlutterEngine startup latency (~200–400ms) and RAM overhead when receiving a notification while killed.
- **Option B (Native Kotlin Parser / Buffer):** Intercept the notification in native Kotlin `NotificationListenerService`, extract notification title/text, and write to a lightweight SQLite database or SharedPreferences file buffer. When Cashew launches, flush buffered raw notifications through `NotificationDispatcher`.
  - *Pros:* 0ms Flutter startup latency, minimal battery/RAM footprint, 100% reliability even if Flutter engine fails to spin up.
  - *Cons:* Duplication of parsing logic if parsing in Kotlin, or delayed notification posting until app opens if only buffering.
- **Option C (Hybrid Kotlin Native + Headless Engine):** Native listener shows the local review notification immediately and writes to a shared SQLite database or launches a background headless engine to process.

### R2: Android Service & Process Survival
- How does `NotificationListenerService` behave when an app is swiped away from recents? (Android keeps the system notification listener service binding active even if the main UI activity is killed, provided the service is declared in `AndroidManifest.xml`).
- What prevents `CashewKeepAliveService` from surviving process termination? Investigate `START_STICKY`, `onTaskRemoved()`, and `BOOT_COMPLETED` broadcast receiver.
- Battery optimization policies across manufacturers (Samsung, Xiaomi, Pixel).

### R3: On-Device Physical Device Testing Protocol
- Define build and deploy commands using `flutter build apk --debug` or `flutter run -d <deviceId>`.
- Isolate debug installations using `applicationIdSuffix ".debug"` (from BT-0010) to avoid conflicting with production Cashew.
- Steps to simulate payment notifications via `adb shell cmd notification post` or real Google Wallet tap-to-pay.
- Verification checklist for:
  1. App open in foreground.
  2. App backgrounded (home pressed).
  3. App swiped away from Recents / killed via `adb shell am force-stop` or task killer.
  4. Device rebooted.

---

## 4. Work Breakdown & Status
- [x] Create GitHub issue [#50](https://github.com/kidomarcostelo/budget-tracking/issues/50)
- [x] Create local task folder and task index entry
- [ ] In-depth research & architectural decision document (`research.md`)
- [ ] Define physical device test plan & harness
- [ ] Align with user on chosen architectural approach
- [ ] Implement prototype / solution on dedicated branch
- [ ] Physical on-device validation before remote PR merge

---

## 5. References
- GitHub Issue: [#50](https://github.com/kidomarcostelo/budget-tracking/issues/50)
- Prior Keep-Alive Task: [BT-0016 Task Doc](../BT-0016-background-headless-listener/task.md)
- Decoupled Notification Parser Research: [BT-0014 Research Doc](../BT-0014-decoupled-notification-parser/research.md)
- PR #47 (BT-0016 implementation): [pr-47 / BT-0016](https://github.com/kidomarcostelo/budget-tracking/pull/47)
- PR #49 (BT-0018 wallet resolution): [pr-49 / BT-0018](https://github.com/kidomarcostelo/budget-tracking/pull/49)
