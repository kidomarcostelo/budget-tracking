# Google Cloud & Google Drive Backup Provisioning Guide

This guide describes how to configure Google Cloud and Firebase so that Google Sign-In and automated Google Drive cloud backups work seamlessly on builds of Cashew built from this repository.

---

## 1. Background & Architecture

Cashew performs online cloud backups by storing database snapshots in Google Drive's hidden `appDataFolder` (`https://www.googleapis.com/auth/drive.appdata`). Because files stored here are sequestered from standard Google Drive browser views, they cannot be accidentally moved or deleted by users.

To authorize your device to read and write to your Google Drive, Android's Google Play Services performs an OAuth 2.0 handshake that strictly validates:
1. The app's **Package Name** (`com.budget.tracker_app` or `com.budget.tracker_app.debug`).
2. The **SHA-1 Certificate Fingerprint** of the signing key used to compile the APK.

---

## 2. Deterministic Development Keystore

To avoid randomized certificates across CI and local builds, this repository contains a persistent development keystore at `budget/android/app/debug.keystore`:

- **Keystore location:** `budget/android/app/debug.keystore`
- **Keystore type:** `PKCS12`
- **Alias:** `androiddebugkey`
- **Password:** `android`
- **Certificate Fingerprints:**
  - **SHA-1:** `33:42:2F:0A:0E:89:76:EF:6C:34:1E:6C:FB:0C:7D:66:D9:25:FA:D6`
  - **SHA-256:** `84:40:F7:E8:80:8D:B7:8C:C4:A9:AB:02:47:B6:49:1C:55:78:62:71:E4:52:6C:BF:65:7E:D7:70:25:2D:9E:1E`

Both `debug` builds and fallback `release` builds automatically compile using this keystore in `budget/android/app/build.gradle`.

---

## 3. Step-by-Step Firebase & Google Cloud Configuration

### Step 3.1: Create a Firebase Project
1. Navigate to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** (e.g. name it `cashew-personal-backup`).
3. Google Analytics can be disabled. Click **Create project**.

### Step 3.2: Register Android Apps
You will register two app entries in your Firebase project:

1. **Release Client:**
   - Click the Android icon to add an app.
   - **Android package name:** `com.budget.tracker_app`
   - **App nickname:** `Cashew Release`
   - **Debug signing certificate SHA-1:** `33:42:2F:0A:0E:89:76:EF:6C:34:1E:6C:FB:0C:7D:66:D9:25:FA:D6`
   - Click **Register app**.

2. **Debug / Dev Client:**
   - Under **Project settings** > **General** > **Your apps**, click **Add app** > **Android**.
   - **Android package name:** `com.budget.tracker_app.debug`
   - **App nickname:** `Cashew Dev`
   - **Debug signing certificate SHA-1:** `33:42:2F:0A:0E:89:76:EF:6C:34:1E:6C:FB:0C:7D:66:D9:25:FA:D6`
   - Click **Register app**.

### Step 3.3: Enable Google Sign-In Provider
1. In Firebase Console sidebar, go to **Build** > **Authentication**.
2. Click **Get started**, select the **Sign-in method** tab.
3. Select **Google**, toggle **Enable**, set your support email, and click **Save**.

### Step 3.4: Enable Google Drive API in Google Cloud
1. Open the [Google Cloud Console](https://console.cloud.google.com/) with the same project selected from the project dropdown.
2. Go to **APIs & Services** > **Library**.
3. Search for **Google Drive API** and click **Enable**.

### Step 3.5: Configure OAuth Consent Screen & Test Users
1. In Google Cloud Console, navigate to **APIs & Services** > **OAuth consent screen**.
2. Select **External** and click **Create**.
3. Set **App name** to `Cashew` and enter your user support and developer email.
4. On the **Scopes** page, click **Add or remove scopes** and add:
   - `.../auth/userinfo.email`
   - `.../auth/userinfo.profile`
   - `https://www.googleapis.com/auth/drive.appdata`
5. On the **Test users** page, click **Add users** and enter the **exact Google account email** you use on your phone.
   *(Note: While the app is in Testing mode, only accounts listed under Test users can authenticate).*
6. Click **Save and continue**.

### Step 3.6: Update `google-services.json`
1. In the Firebase Console, go to **Project settings** (gear icon) > **General**.
2. Scroll to **Your apps**, select `com.budget.tracker_app`, and click **Download google-services.json**.
   *(Because both `com.budget.tracker_app` and `com.budget.tracker_app.debug` are registered in the same project, the downloaded file will contain client blocks for both package names).*
3. Replace the file at:
   ```
   budget/android/app/google-services.json
   ```

---

## 4. Deploy & Verify

1. Trigger a build or deploy the APK to your phone:
   ```bash
   bash .scratch/build-and-deploy.sh
   ```
2. Open Cashew on your phone.
3. Navigate to **Settings** > **Backups** > tap **Google Drive**.
4. Select your configured test account in the Google account picker.
5. Verification checklist:
   - [ ] No *"Check your connection"* or *"ApiException 10"* errors appear.
   - [ ] Your profile name and email address display under Google Drive.
   - [ ] Tap **Backup Now**; verify a new backup timestamp appears.
