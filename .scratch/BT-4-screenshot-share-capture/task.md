# Task: Capture transactions from shared banking screenshots (Android first)

**Issue Reference:** [#8](https://github.com/kidomarcostelo/budget-tracking/issues/8)  
**Status:** Completed (All Map Sub-Issues Verified & Closed)  
**Assignee / Agent:** Antigravity  

---

## 1. Objective & Scope
- **Problem Statement:** Automatic transaction creation currently relies heavily on bank emails. Banks such as MariBank rarely send transaction emails, leaving gaps in automatic logging. However, banking apps present a "Share Receipt" action after a transaction completes.
- **Expected Behavior:** When a user taps "Share" on a transaction receipt in any supported banking app (MariBank, UnionBank, GCash, Maya, BPI) and selects Cashew:
  1. Cashew receives the incoming image via Android `ACTION_SEND`.
  2. Native on-device ML Kit OCR processes the image.
  3. Dart heuristics extract Amount, Recipient/Merchant, Reference Number, and Date/Time.
  4. Cashew opens `AddTransactionPage` prefilled with the parsed transaction details.
  5. The temporary screenshot image is deleted immediately for storage hygiene and privacy.

---

## 2. Invariants & Constraints
- **Zero Cloud Transmission:** 100% on-device OCR using bundled `com.google.mlkit:text-recognition:16.0.1`.
- **Flutter 3.19.6 & CI Compatibility:** Must not force AGP or Java upgrades that break Flutter 3.19.6 or GitHub Actions CI.
- **Domain Vocabulary:** Follow [`GLOSSARY.md`](../../GLOSSARY.md) (`Wallet`, `Transaction`, `Category`, `Budget`).
- **Temporary Cache Hygiene:** Never leave user banking screenshots in app cache after OCR extraction.

---

## 3. Wayfinder Map Breakdown & Progress
- [x] **Phase 1: Native Spike & Intent Receiver** ([#9](https://github.com/kidomarcostelo/budget-tracking/issues/9) `wayfinder:prototype`)
  - [x] Add `ACTION_SEND` intent filter for `image/*` to `android/app/src/main/AndroidManifest.xml`.
  - [x] Add `com.google.mlkit:text-recognition:16.0.1` to `android/app/build.gradle`.
  - [x] Implement Kotlin `MethodChannel` (`com.budget.tracker_app/ocr`) in `MainActivity.kt`.
  - [x] Verify clean build on Flutter 3.19.6 and passing GitHub Actions CI.
- [x] **Phase 2: Bank Receipt OCR Layout Analysis & Extraction Heuristics** ([#10](https://github.com/kidomarcostelo/budget-tracking/issues/10) `wayfinder:research`)
  - [x] Analyze OCR text block output for GoTyme, Maya, MariBank, and UnionBank.
  - [x] Formulate robust regex and spatial heuristics for `Amount`, `Timestamp`, `Accounts`, and `Reference Number`.
  - [x] Create unit tests and fixtures (`budget/test/receipt_parser_test.dart`).
- [x] **Phase 3: Integration & AddTransactionPage Prefill** ([#11](https://github.com/kidomarcostelo/budget-tracking/issues/11) `wayfinder:task`)
  - [x] Handle intent on cold-start (`getInitialSharedData`) and warm-resume (`sharedDataStream`).
  - [x] Pipe extracted fields to `AddTransactionPage` via `InitializeSharedReceiptCapture`.
  - [x] Delete temporary cached image immediately in `finally` block via `SharedReceiptProcessor`.

---

## 4. Verification & Testing
- [x] Unit tests for receipt regex extraction heuristics (all 12 assertions passing).
- [x] Unit tests for pipeline execution and guaranteed temp file cleanup (all 5 assertions passing).
- [x] Static analysis passes: `flutter analyze` (0 errors, 0 warnings).
- [x] Code formatted: `dart format --output=none --set-exit-if-changed .` (0 diffs).
- [x] GitHub Actions CI passes (Run 39275121004).
