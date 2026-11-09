# Google Sign-In and Google Drive Cloud Backup for Custom & Fork Builds: Feasibility and Architecture Research

**Document Reference:** `.scratch/BT-13-google-drive-cloud-backup/research.md`  
**Date:** 2026-11-09  
**Status:** Completed  
**Author / Role:** Antigravity AI Assistant

---

## 1. Executive Summary

When attempting to sign in to Google in Cashew on builds originating from this repository (local builds, debug APKs, or GitHub Actions CI releases), users encounter the error message:
> **"Check your connection and try again"**

Primary-source analysis of Cashew's codebase reveals that:
1. **The error message is a catch-all fallback:** In [`budget/lib/widgets/accountAndBackup.dart`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/accountAndBackup.dart#L184-L214), any unhandled exception or failed authentication in [`signInGoogle`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/accountAndBackup.dart#L75-L215) displays the localized string `sign-in-error-description` ("Check your connection and try again"), regardless of whether the actual cause was a network drop, user cancellation, or an OAuth security rejection.
2. **The root failure is an Android Google Play Services OAuth rejection (`ApiException: 10: DEVELOPER_ERROR`):** Google Play Services validates that the calling app's package name and the SHA-1 certificate fingerprint of the APK's signing key match an OAuth 2.0 Android Client registered in the corresponding Google Cloud / Firebase project.
3. **Current repository configuration points to upstream:** The committed [`budget/android/app/google-services.json`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/android/app/google-services.json) references upstream project `budget-app-flutter` (`267621253497`), which only authorizes the original upstream developer's signing keys (`6139edafe5c4cdb6dccd5f01222b9db88a1620f9` and `1066b81467dc8c595807e67062163d24efe8c3b5`).
4. **Build keystores are currently non-deterministic:** In `.github/workflows/build-apk.yml` and default Gradle runs, builds without an explicit `keystore.properties` fall back to `signingConfigs.debug`. In GitHub Actions `ubuntu-latest` runners, Gradle generates an ephemeral `debug.keystore` on the fly. As measured from `.scratch/apk/release/app-release.apk`, the artifact was signed with an ephemeral key (`33:9B:4D:2C:D6:10:3D:77:C1:75:7C:06:9F:53:FB:B4:04:FB:08:95`), which changes on every VM rebuild.

To enable online Google Drive cloud backup on fork builds, two elements are required:
- **A deterministic, persistent signing key** across local and CI builds so the SHA-1 fingerprint is fixed and repeatable.
- **A configured Firebase / Google Cloud project** owned by the fork maintainer with matching OAuth 2.0 clients and enabled Google Drive API.

---

## 2. Cashew Cloud Backup & Authentication Architecture

### 2.1 Google Sign-In Pipeline
In [`accountAndBackup.dart`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/accountAndBackup.dart#L114-L136):
```dart
List<String> scopes = [
  "https://www.googleapis.com/auth/userinfo.profile",
  "https://www.googleapis.com/auth/userinfo.email",
  drive.DriveApi.driveAppdataScope,
  ...(drivePermissionsAttachments == true
      ? [drive.DriveApi.driveFileScope]
      : []),
  ...(gMailPermissions == true
      ? [
          gMail.GmailApi.gmailReadonlyScope,
          gMail.GmailApi.gmailModifyScope
        ]
      : [])
];
googleSignIn = getPlatform() == PlatformOS.isIOS
    ? signIn.GoogleSignIn(
        clientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
        scopes: scopes)
    : signIn.GoogleSignIn.standard(scopes: scopes);
```

On Android, `GoogleSignIn.standard` invokes Google Play Services via the `google_sign_in_android` native plugin. Google Play Services reads:
1. `packageName`: `com.budget.tracker_app` (or `com.budget.tracker_app.debug`)
2. `signingCertificateHash`: The SHA-1 hash of the certificate used to sign the APK.

### 2.2 Google Drive AppData Storage
Unlike general file storage, Cashew backs up to Google Drive's hidden `appDataFolder` ([`accountAndBackup.dart:448`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/accountAndBackup.dart#L448)):
```dart
var driveFile = new drive.File();
driveFile.name = ...;
driveFile.modifiedTime = DateTime.now().toUtc();
driveFile.parents = ["appDataFolder"];
await driveApi.files.create(driveFile, uploadMedia: media);
```
- **Privacy & User Experience:** Files in `appDataFolder` are inaccessible to other apps and hidden from standard Google Drive browser views. Users cannot accidentally delete, rename, or scramble them.
- **Scope Requirement:** Access requires `https://www.googleapis.com/auth/drive.appdata` (`driveAppdataScope`), which is a sensitive scope.
- **Automated Lifecycle:** Auto-backups trigger on app launch / resume via `runAllCloudFunctions()` ([`navigationFramework.dart:307`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/navigationFramework.dart#L307)), with configurable backup retention limits (`appStateSettings["backupLimit"]`).

### 2.3 Error Masking in `accountAndBackup.dart`
Lines 184–214:
```dart
} catch (e) {
  print(e);
  if (waitForCompletion == true && context != null) popRoute(context);
  openSnackbar(
    SnackbarMessage(
      title: "sign-in-error".tr(),
      description: "sign-in-error-description".tr(), // Always "Check your connection and try again"
      ...
    ),
  );
  ...
  throw ("Error signing in");
}
```
Because the UI swallows the actual exception `e` (`PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)`), users and developers cannot determine whether the problem was network timeout, user dismissal, or an invalid OAuth certificate.

---

## 3. Keystore & CI Build Analysis

### 3.1 Current Gradle Signing Configuration
In [`budget/android/app/build.gradle`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/android/app/build.gradle#L68-L86):
```groovy
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    debug {
        applicationIdSuffix ".debug"
        manifestPlaceholders = [appName: "Cashew Dev"]
    }
    release {
        if (keystoreProperties['storeFile'] != null && file(keystoreProperties['storeFile']).exists()) {
            signingConfig signingConfigs.release
        } else {
            signingConfig signingConfigs.debug
        }
    }
}
```

### 3.2 Ephemeral Keystores in CI
In `.github/workflows/build-apk.yml`:
- The GitHub Actions runner executes `flutter build apk --release` and `flutter build apk --debug`.
- No `key.properties` is injected.
- Gradle falls back to `signingConfigs.debug`.
- Because the Ubuntu runner is a clean virtual machine, Gradle creates a new `~/.android/debug.keystore` with a randomized key on each run.
- **Finding:** Every build downloaded via `.scratch/build-and-deploy.sh` or GitHub Actions has a **different SHA-1 fingerprint**. It is impossible to configure Google Cloud OAuth when the signing certificate changes on every build.

### 3.3 Certificate Hash Verification
Inspection of `.scratch/apk/release/app-release.apk` (built Nov 7, 2026):
- Subject: `CN=Android Debug, O=Android, C=US`
- Fingerprint SHA-1: `33:9B:4D:2C:D6:10:3D:77:C1:75:7C:06:9F:53:FB:B4:04:FB:08:95`
- Registered SHA-1s in `google-services.json`:
  - `61:39:ED:AF:E5:C4:CD:B6:DC:CD:5F:01:22:2B:9D:B8:8A:16:20:F9`
  - `10:66:B8:14:67:DC:8C:59:58:07:E6:70:62:16:3D:24:EF:E8:C3:B5`
- **Result:** Exact mismatch causing immediate `ApiException: 10`.

---

## 4. Google Cloud & OAuth Security Requirements

### 4.1 Required Package Identifiers
Following the debug isolation established in BT-10 ([`PR-22`](file:///data/data/com.termux/files/home/repo/budget-tracking/docs/code-reviews/PR-22-debug-app-isolation.md)):
1. **Production / Release:** `com.budget.tracker_app`
2. **Development / Debug:** `com.budget.tracker_app.debug`

Both client IDs must exist in the target Firebase project, mapped to the deterministic signing certificate's SHA-1 and SHA-256 fingerprints.

### 4.2 OAuth 2.0 Consent Screen & CASA Tier
- **User Type:** External
- **Publishing Status:**
  - *Testing:* Only accounts explicitly added under **Test users** in the Google Cloud Console OAuth consent screen can authenticate. Any other Google account will receive an `access_denied` error.
  - *Production:* If set to Production without full Google CASA verification, Google permits sign-in with an "Unverified App" warning prompt that the user can bypass.
- **Required APIs:**
  - `Google Drive API` must be explicitly toggled to **Enabled** in Google Cloud Console (`console.cloud.google.com/apis/library/drive.googleapis.com`).

---

## 5. Architectural Recommendations

### Recommendation 1: Introduce a Deterministic Repository Keystore
Add a tracked, persistent development keystore (e.g. `budget/android/app/debug.keystore` with standard alias `androiddebugkey` and password `android`).
- Update `budget/android/app/build.gradle` so that when `key.properties` is absent, Gradle uses this tracked keystore instead of generating an ephemeral one.
- This guarantees that **all** builds (local Termux builds, local laptop builds, and GitHub Actions CI artifacts) share the exact same SHA-1 fingerprint.

### Recommendation 2: Implement Granular Sign-In Error Reporting
Modify [`accountAndBackup.dart`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/accountAndBackup.dart#L184-L214) to parse the caught exception:
- If `e` is `ApiException: 10` (Developer Error): Display *"Google Sign-In configuration error (Code 10: SHA-1 / Package mismatch)"*.
- If `account == null`: Display *"Sign-in cancelled"*.
- If genuine socket or network failure: Display *"Check your connection and try again"*.

### Recommendation 3: Provide Step-by-Step Fork Provisioning Guide
Document the exact procedure for generating personal Firebase credentials and updating `google-services.json` so anyone maintaining this fork can enable personal cloud sync seamlessly.
