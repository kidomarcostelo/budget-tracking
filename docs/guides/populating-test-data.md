# Populating Test Data in Cashew Dev

This guide documents all available methods to populate data (transactions, wallets, budgets, categories, and goals) into the **Cashew Dev** (`com.budget.tracker_app.debug`) build on Android.

---

## Overview of Methods

| Method | Best For | Prerequisites |
| :--- | :--- | :--- |
| **1. Built-in Preview Demo** | Fresh install / zero setup | Launching app for the first time |
| **2. Hidden Debug Flags Menu** | Populating or adding transactions on an existing install | Dev build (`Cashew Dev`) |
| **3. Restore from Official Cashew** | Testing with a clone of your real financial data | Official Cashew installed |
| **4. Direct SQLite Push via ADB** | Automated scripting, test fixtures, fast resets | ADB connected |
| **5. ADB Notification Simulation** | Testing auto-transaction parsing & deduplication | ADB connected |

---

## Method 1: Built-in "Preview Demo" (Fresh Install)

When launching **Cashew Dev** for the first time (or after clearing app data):

1. Launch **Cashew Dev**.
2. On the initial **Welcome / Onboarding** screen, tap the **"Preview Demo"** button at the bottom.
3. The app instantly populates a rich sample dataset:
   - **Wallets:** Default bank account (USD), foreign currency wallet (EUR), etc.
   - **Categories:** Standard expense and income categories with icons.
   - **Budgets:** Monthly budgets with category spending goals.
   - **Objectives:** Savings goals with progress indicators.
   - **Transactions:** 60+ realistic past and recurring transactions.

> [!NOTE]
> To exit demo mode at any time, tap the warning banner at the top of the Home page or go to **Settings** and tap **"Exit Demo"**.

---

## Method 2: In-App Hidden Debug Flags Menu

If you have already onboarded or want to inject test data into an existing database:

1. Open **Cashew Dev**.
2. Tap the **More** tab (the `•••` icon on the bottom navigation bar).
3. Look for the tile labeled **"About Cashew"** (with the `ⓘ` info icon, displayed side-by-side with the **"Feedback"** tile right below *All Spending*).  
   *(Note: Do not tap into "Settings & Customization" — the "About Cashew" tile is located directly on the main More tab).*
4. Tap **"About Cashew"**.
5. Once on the About page, **long-press** on the app title text **"Cashew"** (or **"Cashew Dev"**) at the very top.
6. The hidden **Debug Flags** page will open (active in debug builds where `allowDangerousDebugFlags` is enabled).
7. Scroll down to the debug actions:
   - **Create preview data**: Generates the full demo wallet, budget, and transaction suite.
   - **Create random transactions**: Immediately injects 10 randomized transactions into your current database.

---

## Method 3: Mirror / Restore from Official Cashew App

Because **Cashew Dev** (`com.budget.tracker_app.debug`) is isolated from **Cashew** (`com.budget.tracker_app`), you can clone your real data into Dev to test with authentic records without risking your live data.

### Step 1: Export from Official Cashew
1. Open the official **Cashew** app.
2. Go to **More** > **Settings** > **Data & Backups** (or **Backup & Restore**).
3. Tap **Create Local Backup** (or export to file).

### Step 2: Restore into Cashew Dev
1. Open **Cashew Dev**.
2. Go to **More** > **Settings** > **Data & Backups** > **Restore Backup**.
3. Select the backup file exported from Step 1.
4. All your real categories, wallets, and transactions will now be loaded into Cashew Dev.

> [!IMPORTANT]
> Because the package IDs and databases are completely separate, any edits, additions, or resets made inside **Cashew Dev** will **not** affect your official **Cashew** app.

---

## Method 4: Direct SQLite Push via ADB (`run-as`)

Because `com.budget.tracker_app.debug` is built with `android:debuggable="true"`, you can access and replace the SQLite database directly over ADB without root permissions.

### A. Push a Pre-Seeded Database
```bash
# 1. Stop Cashew Dev
adb shell am force-stop com.budget.tracker_app.debug

# 2. Push SQLite file to temporary staging
adb push path/to/seed.sqlite /data/local/tmp/db.sqlite

# 3. Copy into app's private sandbox
adb shell "run-as com.budget.tracker_app.debug cp /data/local/tmp/db.sqlite app_flutter/db.sqlite"

# 4. Remove staging file
adb shell rm /data/local/tmp/db.sqlite

# 5. Launch Cashew Dev
adb shell am start -n com.budget.tracker_app.debug/com.budget.tracker_app.MainActivity
```

### B. Pull / Snapshot the Current Debug Database
To save your current dev state as a fixture:
```bash
adb shell "run-as com.budget.tracker_app.debug cat app_flutter/db.sqlite" > .scratch/debug-snapshot.sqlite
```

### C. Quick Reset / Wipe Data
To reset Cashew Dev back to a clean slate:
```bash
adb shell pm clear com.budget.tracker_app.debug
```

---

## Method 5: Transaction Injection via ADB Notification Simulation

If you are developing or testing automated notification scanning (e.g. Google Pay, SMS, or bank transfers):

Follow the step-by-step broadcast fixtures in [`docs/guides/device-verification-guide.md`](file:///data/data/com.termux/files/home/repo/budget-tracking/docs/guides/device-verification-guide.md).

Example:
```bash
adb shell am broadcast \
  -a slayer.notification.listener.service.intent \
  -p com.budget.tracker_app.debug \
  --es package_name "com.google.android.apps.walletnfcrel" \
  --es title "7-Eleven" \
  --es message "₱123.00 with UnionBank Rewards Platinum **3353" \
  --ei notification_id 101 \
  --ez is_removed false \
  --el notification_time $(date +%s000)
```
This triggers the in-app parser, prompting or recording the transaction directly into the database.
