# Task: Enable Google Sign-In and Google Drive Cloud Backup for Custom Builds

**ID:** BT-0013  
**Issue Reference:** [#35](https://github.com/kidomarcostelo/budget-tracking/issues/35)  
**Status:** Ready for Agent / In Planning  
**Assignee / Agent:** AI Assistant  

---

## 1. Objective & Scope

- **Problem Statement:**  
  When users click "Google Drive" under Settings > Backups on custom, local, or GitHub Actions CI builds of Cashew, authentication fails immediately with the toast:
  > *"Check your connection and try again"*
  
  This happens because:
  1. The app is signed with an ephemeral debug keystore in CI/local runs whose SHA-1 fingerprint changes on every build.
  2. The committed `google-services.json` references upstream (`budget-app-flutter`), which does not recognize the fork maintainer's signing key.
  3. `accountAndBackup.dart` swallows the Google Play Services exception (`ApiException: 10: DEVELOPER_ERROR`) and displays a misleading connectivity error message.

- **Expected Behavior:**
  1. Builds in CI and local environments use a deterministic signing keystore with a known, fixed SHA-1 fingerprint.
  2. `google-services.json` and Firebase are configured to authorize both release (`com.budget.tracker_app`) and debug (`com.budget.tracker_app.debug`) variants using this SHA-1.
  3. Google Sign-In succeeds on device, allowing daily automated backups to Google Drive `appDataFolder`.
  4. Authentication errors in Cashew provide diagnostic feedback (e.g. distinguishing developer configuration errors `ApiException: 10`, user cancellations, and network drops).

---

## 2. Invariants & Constraints

- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- **Credentials & Keys:** Do not commit production release signing keys, private passwords, or Firebase service account tokens. Standard Android debug keystores (`alias: androiddebugkey`, `password: android`) are standard public developer artifacts and safe to track for development consistency.
- **Backwards Compatibility:** Custom `key.properties` for production release signing must remain respected if provided.
- **Quality Gates:** `flutter analyze` and `flutter test` must pass with 0 errors.

---

## 3. Plan & Implementation Steps (Vertical Slices)

### Slice 1: Keystore Determinism
- [x] Create a persistent, reproducible development keystore at `budget/android/app/debug.keystore` (or `dev-keystore.jks`) with known alias `androiddebugkey` and password `android`.
- [x] Update `budget/android/app/build.gradle` so both `debug` and fallback `release` builds sign with this persistent keystore when no external `key.properties` is supplied.
- [x] Extract and document the permanent SHA-1 and SHA-256 certificate fingerprints for Firebase registration.

### Slice 2: Diagnostic Sign-In Error Reporting
- [x] In [`budget/lib/widgets/accountAndBackup.dart`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/accountAndBackup.dart#L184-L214), inspect the caught error in `signInGoogle`:
  - When `e.toString()` contains `ApiException: 10` or `12500`: display a descriptive configuration error message explaining SHA-1 / package mismatch.
  - When user cancels account selection (`account == null` without exception): gracefully exit or show cancellation toast instead of claiming network failure.
  - Keep `sign-in-error-description` ("Check your connection and try again") strictly for real `SocketException` or network timeout errors.
- [x] Add unit / widget tests validating error message dispatching.

### Slice 3: Firebase Project & Google Cloud Configuration
- [x] Document step-by-step setup in `docs/guides/google-cloud-backup-setup.md`:
  1. Creating a Firebase project.
  2. Adding Android apps for `com.budget.tracker_app` and `com.budget.tracker_app.debug`.
  3. Adding the deterministic SHA-1 / SHA-256 fingerprints to both apps.
  4. Enabling Google Sign-In in Firebase Authentication.
  5. Enabling Google Drive API in Google Cloud Console.
  6. Configuring OAuth Consent Screen with scope `drive.appdata` and adding test users.
- [x] Generate and integrate the new `google-services.json` matching the fork's project.

### Slice 4: End-to-End Verification
- [ ] Trigger CI build (`build-apk.yml`) or local build and verify the produced APK has the expected SHA-1 fingerprint:
  ```bash
  python3 -c "import zipfile, hashlib; ..."
  ```
- [ ] Deploy to connected test device via Wireless ADB:
  ```bash
  bash .scratch/build-and-deploy.sh
  ```
- [ ] Navigate to Settings > Backups > tap **Google Drive**.
- [ ] Authenticate with Google account and verify:
  - Account email and profile display in Cashew.
  - Backup file creates in Google Drive `appDataFolder`.
  - Manual backup and restore operations succeed.

---

## 4. Verification & Testing

- [ ] `flutter analyze` returns 0 issues.
- [ ] `flutter test` passes.
- [ ] APK certificate SHA-1 verified via `python3` / `keytool` from downloaded artifact.
- [ ] End-to-end on-device verification of Google Drive backup creation and restoration.
