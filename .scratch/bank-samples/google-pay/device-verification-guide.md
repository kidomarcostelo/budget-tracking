# Google Pay / Wallet Device Verification Guide

This guide describes how to simulate and verify Google Pay / Google Wallet payment notifications on physical Android devices or emulators using Android Debug Bridge (`adb`).

---

## 1. Prerequisites & Device Setup

1. **Connect Device via ADB**:
   ```bash
   adb devices
   ```
2. **Launch Cashew**:
   Ensure Cashew is installed (`com.budget.tracker_app`) and running on the target Android device.
3. **Grant Notification Listener Permission**:
   - Go to device **Settings** > **Apps & notifications** > **Special app access** > **Notification access** (or device equivalent).
   - Enable **Cashew** notification access.
   - Alternatively, grant via ADB shell (on root/debug builds):
     ```bash
     adb shell cmd notification allow_listener com.budget.tracker_app/notification.listener.service.NotificationListener
     ```
4. **Configure Cashew In-App Settings**:
   - Navigate to **More / Settings** > **Auto Transactions** (Notification Scanning).
   - Ensure **Notification Scanning** is toggled **ON**.
   - Ensure **Google Pay Notifications** is toggled **ON**.
   - Create or verify that a wallet matches the payment method (e.g. create a wallet named `UnionBank` or `Chase Freedom`).

---

## 2. Notification Simulation Commands

### A. Direct Broadcast Simulation (`adb shell am broadcast`) [Recommended]

Cashew processes notifications via the Android notification listener event channel (`slayer.notification.listener.service.intent`). While `cmd notification post` posts notifications under the system `android` package (which is ignored by Google Pay package filtering unless custom templates match), direct intent broadcasting injects exact Google Wallet package notifications directly into Cashew's listener pipeline.

#### Fixture 1: Real Philippine 7-Eleven Sample (Pattern A - UnionBank)
```bash
adb shell am broadcast \
  -a slayer.notification.listener.service.intent \
  -p com.budget.tracker_app \
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
  -p com.budget.tracker_app \
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
  -p com.budget.tracker_app \
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
  -p com.budget.tracker_app \
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
  -p com.budget.tracker_app \
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
> **Package Origin Note**: `cmd notification post` posts notifications under the system `android` package (uid 1000). Google Pay scanning strictly checks for recognized Google packages (`com.google.android.apps.walletnfcrel`, `com.google.android.apps.nbu.paisa.user`, `com.google.android.gms`). To test `cmd notification post`, enable **Custom Notification Templates** in Cashew and configure a rule matching the notification title/content, or use Section 2A (`am broadcast`) for genuine Google Pay package verification.

---

## 3. Manual Verification Checklist

| Step | Action | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- |
| **1. Interactive Flow** | Broadcast Fixture 1 with app in foreground. | `AddTransactionPage` opens immediately with prefilled title `7-Eleveb-ST4594`, amount `123`, note `UnionBank Rewards Platinum •••• 3353`, and `UnionBank` wallet selected. | [ ] |
| **2. Deduplication Suppression** | Broadcast Fixture 1 a second time within 2 minutes. | Notification is silently suppressed by `DedupeLedger`. Zero additional pages or dialogs are pushed. | [ ] |
| **3. Notification Dismissal** | Broadcast Fixture 1, then broadcast Fixture 5 (`is_removed: true`). | The dismissal event is ignored. No duplicate prompt is displayed. | [ ] |
| **4. Ambiguous Duplicate Review** | Record an existing bank debit for `₱250.00` at Starbucks, then broadcast Fixture 4 (`Paid ₱250.00 at Mercury Drug`). | `AddTransactionPage` opens with `PossibleDuplicateBanner` displaying prior transaction details and dismiss button. | [ ] |
| **5. Settings Toggle Gating** | Toggle **Google Pay Notifications** to **OFF** in Settings, then broadcast Fixture 1. | Notification produces no prompt, no route push, and is not recorded in deduplication ledger. | [ ] |
| **6. Multi-Currency Support** | Ensure USD wallet exists, broadcast Fixture 3 (`$42.75`). | `AddTransactionPage` opens prefilled with `$42.75`, `Chase Freedom •••• 9876` note, and `Chase Freedom` wallet selected. | [ ] |
