# Google Pay / Wallet Device Verification Guide

This guide describes how to simulate and verify Google Pay / Google Wallet payment notifications on physical Android devices or emulators using Android Debug Bridge (`adb`).

---

## 1. Prerequisites & Device Setup

1. **Connect Device via ADB**:
   ```bash
   adb devices
   ```
2. **Launch Cashew**:
   Ensure Cashew is installed and running on the target Android device.
3. **Grant Notification Listener Permission**:
   - Go to device **Settings** > **Apps & notifications** > **Special app access** > **Notification access** (or device equivalent).
   - Enable **Cashew** notification access.
   - Alternatively, grant via ADB shell (if root/debug build):
     ```bash
     adb shell cmd notification allow_listener package:com.simolation.budget/package:com.simolation.budget.NotificationService
     ```
4. **Configure Cashew In-App Settings**:
   - Navigate to **More / Settings** > **Auto Transactions** (Notification Scanning).
   - Ensure **Notification Scanning** is toggled **ON**.
   - Ensure **Google Pay Notifications** is toggled **ON**.
   - Create or verify that a wallet matches the payment method (e.g. create a wallet named `UnionBank` or `Chase Freedom`).

---

## 2. Notification Simulation Commands (`adb shell cmd notification post`)

Android 11+ supports posting simulated notifications from arbitrary packages or with custom titles and text.

> **Note on Package Spoofing**: `cmd notification post` by default posts under the `android` shell package. For direct notification listener testing on stock OEM devices, use the custom intent broadcast or post with explicit titles matching Google Pay patterns.

### Fixture 1: Real Philippine 7-Eleven Sample (Pattern A - UnionBank)
```bash
adb shell cmd notification post \
  -S bigtext \
  -t "7-Eleveb-ST4594" \
  "google_pay_test_tag_1" \
  "P123.00 with UnionBank Rewards Platinum **3353"
```

### Fixture 2: Standard Currency Symbol Pattern (Pattern A - Starbucks PHP)
```bash
adb shell cmd notification post \
  -S bigtext \
  -t "Starbucks" \
  "google_pay_test_tag_2" \
  "₱185.00 with Mastercard •••• 1234"
```

### Fixture 3: US Dollar & Masked Dots (Pattern B - Chase Freedom USD)
```bash
adb shell cmd notification post \
  -S bigtext \
  -t "Trader Joe's" \
  "google_pay_test_tag_3" \
  "\$42.75 with Chase Freedom •••• 9876"
```

### Fixture 4: Generic Google Wallet Header with Merchant in Body (Pattern C)
```bash
adb shell cmd notification post \
  -S bigtext \
  -t "Google Wallet" \
  "google_pay_test_tag_4" \
  "Paid ₱250.00 at Mercury Drug"
```

### Direct Broadcast Simulation (For Automated Test Harnesses / Emulators)
If testing through an emulator test harness or custom broadcast receiver:
```bash
adb shell am broadcast \
  -a com.simolation.budget.TEST_NOTIFICATION \
  -n com.simolation.budget/.TestNotificationReceiver \
  --es package "com.google.android.apps.walletnfcrel" \
  --es title "7-Eleveb-ST4594" \
  --es content "P123.00 with UnionBank Rewards Platinum **3353" \
  --el timestamp $(date +%s%3N)
```

---

## 3. Manual Verification Checklist

| Step | Action | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- |
| **1. Interactive Flow** | Post Fixture 1 with app in foreground. | `AddTransactionPage` opens immediately with prefilled title `7-Eleveb-ST4594`, amount `123`, note `UnionBank Rewards Platinum •••• 3353`, and `UnionBank` wallet selected. | [ ] |
| **2. Deduplication Suppression** | Post Fixture 1 a second time within 2 minutes. | Notification is silently suppressed by `DedupeLedger`. Zero additional pages or dialogs are pushed. | [ ] |
| **3. Notification Dismissal** | Post Fixture 2, then immediately swipe away the notification from status bar. | The dismissal event (`hasRemoved == true`) is ignored. No duplicate prompt is displayed. | [ ] |
| **4. Ambiguous Duplicate Review** | Record an existing bank debit for `₱250.00` at Starbucks, then post Fixture 4 (`Paid ₱250.00 at Mercury Drug`). | `AddTransactionPage` opens with `PossibleDuplicateBanner` displaying prior transaction details and dismiss button. | [ ] |
| **5. Settings Toggle Gating** | Toggle **Google Pay Notifications** to **OFF** in Settings, then post Fixture 1. | Notification produces no prompt, no route push, and is not recorded in deduplication ledger. | [ ] |
| **6. Multi-Currency Support** | Ensure USD wallet exists, post Fixture 3 (`$42.75`). | `AddTransactionPage` opens prefilled with `$42.75`, `Chase Freedom •••• 9876` note, and `Chase Freedom` wallet selected. | [ ] |
