# Google Pay / Wallet Device Verification Guide

This guide describes how to simulate and verify Google Pay / Google Wallet payment notifications on Android devices, emulators, or via automated widget verification using Android Debug Bridge (`adb`) and Flutter test tooling.

---

## 1. Prerequisites & Device Setup

1. **Connect Device via ADB**:
   ```bash
   adb devices
   ```
2. **Target Application Package**:
   - Local development and debug builds run under **`com.budget.tracker_app.debug`** (per `docs/architecture.md` §4).
   - Production / release builds run under **`com.budget.tracker_app`**.
   - Adjust the package parameter `-p <package>` in the ADB commands below to match your installed build variant.

3. **Grant Notification Listener Permission**:
   - Go to device **Settings** > **Apps & notifications** > **Special app access** > **Notification access** (or device equivalent).
   - Enable **Cashew** notification access.
   - Alternatively, grant via ADB shell (on root/debug builds):
     ```bash
     # Debug build:
     adb shell cmd notification allow_listener com.budget.tracker_app.debug/notification.listener.service.NotificationListener

     # Release build:
     adb shell cmd notification allow_listener com.budget.tracker_app/notification.listener.service.NotificationListener
     ```
4. **Configure Cashew In-App Settings**:
   - Navigate to **More / Settings** > **Auto Transactions** (Notification Scanning).
   - Ensure **Notification Scanning** is toggled **ON**.
   - Ensure **Google Pay Notifications** is toggled **ON**.
   - Create or verify that a wallet matches the payment method (e.g. create a wallet named `UnionBank` or `Chase Freedom`).

---

## 2. Notification Simulation Commands

### A. Direct Broadcast Simulation (`adb shell am broadcast`)

Cashew processes notifications via the Android notification listener event channel (`slayer.notification.listener.service.intent`). Direct intent broadcasting injects exact Google Wallet package notifications directly into Cashew's listener pipeline.

> [!IMPORTANT]
> **Android 14+ (API 34+) Platform Security Restriction**:
> As documented in `research.md` (Q7), `notification_listener_service: 1.0.0` registers its receiver with `RECEIVER_NOT_EXPORTED` on Android 14+ (API 34+) in compliance with Android security policies. Because the receiver is not exported, ADB shell broadcasts from unprivileged shell `UID 2000` will be blocked with:
> ```
> java.lang.SecurityException: Intent is protected or receiver is not exported (RECEIVER_NOT_EXPORTED)
> ```
> **How to verify depending on your environment:**
> 1. **Automated Suite (All OS versions)**: Run `flutter test test/google_pay_flow_widget_test.dart`. This tests 100% of these scenarios programmatically in-process without broadcast restrictions.
> 2. **Android 13 and below / Emulators (API <= 33)**: Run the `adb shell am broadcast` commands below directly.
> 3. **Rooted / Userdebug Emulators (API 34+)**: Run `adb root` before executing `adb shell am broadcast`.
> 4. **Physical Devices (API 34+)**: Perform a test payment or tap via Google Wallet / Google Pay to receive authentic system notifications.

#### Fixture 1: Real Philippine 7-Eleven Sample (Pattern A - UnionBank)
```bash
adb shell am broadcast \
  -a slayer.notification.listener.service.intent \
  -p com.budget.tracker_app.debug \
  --es package_name "com.google.android.apps.walletnfcrel" \
  --es title "7-Eleveb-ST4594" \
  --es message "P123.00 with UnionBank Rewards Platinum **3353" \
  --ei notification_id 101 \
  --ez is_removed false \
  --el notification_time $(date +%s000)
```

#### Fixture 2: Standard Currency Symbol Pattern (Pattern A - Starbucks PHP)
```bash
adb shell am broadcast \
  -a slayer.notification.listener.service.intent \
  -p com.budget.tracker_app.debug \
  --es package_name "com.google.android.apps.walletnfcrel" \
  --es title "Starbucks" \
  --es message "₱185.00 with Mastercard •••• 1234" \
  --ei notification_id 102 \
  --ez is_removed false \
  --el notification_time $(date +%s000)
```

#### Fixture 3: US Dollar & Masked Dots (Pattern B - Chase Freedom USD)
```bash
adb shell am broadcast \
  -a slayer.notification.listener.service.intent \
  -p com.budget.tracker_app.debug \
  --es package_name "com.google.android.apps.walletnfcrel" \
  --es title "Trader Joe's" \
  --es message "\$42.75 with Chase Freedom •••• 9876" \
  --ei notification_id 103 \
  --ez is_removed false \
  --el notification_time $(date +%s000)
```

#### Fixture 4: Generic Google Wallet Header with Merchant in Body (Pattern C)
```bash
adb shell am broadcast \
  -a slayer.notification.listener.service.intent \
  -p com.budget.tracker_app.debug \
  --es package_name "com.google.android.apps.walletnfcrel" \
  --es title "Google Wallet" \
  --es message "Paid ₱250.00 at Mercury Drug" \
  --ei notification_id 104 \
  --ez is_removed false \
  --el notification_time $(date +%s000)
```

#### Fixture 5: Notification Dismissal Event (`hasRemoved: true`)
```bash
adb shell am broadcast \
  -a slayer.notification.listener.service.intent \
  -p com.budget.tracker_app.debug \
  --es package_name "com.google.android.apps.walletnfcrel" \
  --es title "7-Eleveb-ST4594" \
  --es message "P123.00 with UnionBank Rewards Platinum **3353" \
  --ei notification_id 101 \
  --ez is_removed true \
  --el notification_time $(date +%s000)
```

---

### B. Status Bar Notification Simulation (`adb shell cmd notification post`)

Android 11+ supports posting visual status bar notifications:
```bash
adb shell cmd notification post \
  -S bigtext \
  -t "7-Eleveb-ST4594" \
  "google_pay_test_tag_1" \
  "P123.00 with UnionBank Rewards Platinum **3353"
```
> **Package Origin Note**: `cmd notification post` posts notifications under the system `android` package (`uid 1000`). Google Pay scanning strictly checks for recognized Google packages (`com.google.android.apps.walletnfcrel`, `com.google.android.apps.nbu.paisa.user`, `com.google.android.gms`). To test notifications posted via `cmd notification post`, enable **Custom Notification Templates** in Cashew and configure a rule matching the notification title/content, or use Section 2A (`am broadcast`) / Section 3 automated suite for genuine Google Pay package verification.

---

## 3. Verification Checklist

The 6 core scenarios have been automated and pass 100% in the dedicated end-to-end suite (`budget/test/google_pay_flow_widget_test.dart`). For manual device validation on supported hardware, use the checklist below:

| Step | Action | Expected Result | Automated Test | Manual Device Status |
| :--- | :--- | :--- | :--- | :--- |
| **1. Interactive Flow** | Deliver Fixture 1 with app in foreground. | `AddTransactionPage` opens immediately with prefilled title `7-Eleveb-ST4594`, amount `123`, note `UnionBank Rewards Platinum •••• 3353`, and `UnionBank` wallet selected. | `Interactive flow: incoming Google Pay notification renders AddTransactionPage with prefilled details` | Verified in Widget Test Suite (Ready for on-device confirmation) |
| **2. Deduplication Suppression** | Deliver Fixture 1 a second time within 2 minutes. | Notification is silently suppressed by `DedupeLedger`. Zero additional pages or dialogs are pushed. | `Deduplication suppression: identical notification within 5-min sliding window is suppressed` | Verified in Widget Test Suite (Ready for on-device confirmation) |
| **3. Notification Dismissal** | Deliver Fixture 1, then deliver Fixture 5 (`is_removed: true`). | The dismissal event is ignored. No duplicate prompt or route is created. | `Dismissal events (hasRemoved == true) are ignored and do not push duplicate page` | Verified in Widget Test Suite (Ready for on-device confirmation) |
| **4. Ambiguous Duplicate Review** | Record an existing bank debit for `₱250.00` at Starbucks, then deliver Fixture 4 (`Paid ₱250.00 at Mercury Drug`). | `AddTransactionPage` opens with `PossibleDuplicateBanner` displaying prior transaction details and dismiss button. | `Uncertain match review flow: ambiguous notification renders AddTransactionPage with PossibleDuplicateBanner` | Verified in Widget Test Suite (Ready for on-device confirmation) |
| **5. Settings Toggle Gating** | Toggle **Google Pay Notifications** to **OFF** in Settings, then deliver Fixture 1. | Notification produces no prompt, no route push, and is not recorded in deduplication ledger. | `Google Pay disabled preference prevents page routing and ledger recording` | Verified in Widget Test Suite (Ready for on-device confirmation) |
| **6. Multi-Currency Support** | Ensure USD wallet exists, deliver Fixture 3 (`$42.75`). | `AddTransactionPage` opens prefilled with `$42.75`, `Chase Freedom •••• 9876` note, and `Chase Freedom` wallet selected. | `Pattern B: USD currency and masked card number prefills correctly` | Verified in Widget Test Suite (Ready for on-device confirmation) |
