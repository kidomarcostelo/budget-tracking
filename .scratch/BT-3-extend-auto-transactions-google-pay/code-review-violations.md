# Code Review Report: PR #26 (Slice S6 Verification)

**Target Branch:** `feat/google-pay-verification` against `main`  
**Pull Request:** [#26](https://github.com/kidomarcostelo/budget-tracking/pull/26) (`feat(notifications): Google Pay end-to-end verification and device testing guide (Slice S6)`)  
**Tracking Issue:** [#7](https://github.com/kidomarcostelo/budget-tracking/issues/7) (Task: [`BT-3`](task.md))  
**Commits Reviewed:**
- `5bc718ef` fix(notifications): harden flow tests, resolve timeouts, and correct device verification commands
- `370bf4e8` feat(notifications): add Google Pay end-to-end flow tests and verification guide (Slice S6)  
**Review Timestamp:** 2026-11-05T15:22:30+08:00  

---

## Standards

### (a) Documented Standards Violations

1. **`CONSTRAINTS.md` §3 (Test Suite Integrity — *"Fix the root cause in the implementation or test setup"*):**
   - **Locations:** `budget/lib/struct/dedupeLedger.dart:576-606` & `budget/lib/struct/googlePayParser.dart:173-232`
   - **Violation:** Arbitrary `200ms` timeouts (`.timeout(const Duration(milliseconds: 200))`) with silent catch/fallback blocks (`onTimeout: () => -1`) were added directly to production SQLite persistence (`_tryPersist`) and query resolution (`resolveWallet`, `resolveCategory`) specifically to work around `fakeAsync` event-loop stalls in widget tests. Modifying production database operations to appease test runner limitations violates §3 and risks silent database write and resolution drops under real device I/O load. Root-cause test execution (e.g., using `tester.runAsync` or explicit test doubles) should be used instead.

2. **`docs/architecture.md` §4 (Android Environments & Package Isolation):**
   - **Location:** `.scratch/bank-samples/google-pay/device-verification-guide.md:18-99`
   - **Violation:** ADB commands hardcode the release package `com.budget.tracker_app`. Per §4, local development/verification runs against `com.budget.tracker_app.debug`. The guide lacks guidance or commands for testing against the debug package.

---

### (b) Baseline Smells (Judgement Calls)

1. **Duplicated Code (Route Popping Boilerplate in Tests):**
   - **Location:** `budget/test/google_pay_flow_widget_test.dart:235-241`
   - The route popping logic is repeated across 9 individual widget tests:
     ```dart
     await tester.pump(const Duration(milliseconds: 1200));
     if (navigatorKey.currentState?.canPop() == true) {
       navigatorKey.currentState?.pop();
       await tester.pumpAndSettle();
     }
     await tester.pump(Duration.zero);
     ```
   - *Recommendation:* Extract into a shared helper function (e.g., `popToHome(tester)`).

2. **Duplicated Code (Inline Timeout Call-Sites):**
   - **Location:** `budget/lib/struct/googlePayParser.dart:178-230`
   - Repeated inlining of `.timeout(const Duration(milliseconds: 200))` across 4 separate query call-sites in `resolveWallet` and `resolveCategory`.

3. **Duplicated Code (Test Fixture Factory):**
   - **Locations:** `budget/test/google_pay_flow_widget_test.dart:45-66` & `budget/test/notification_dispatcher_test.dart`
   - Identical `createTestEvent` helper is duplicated across test files. Extract to a shared test utility.

---

## Spec

### (a) Requirements Missing or Partial

1. **Manual Device Verification Unexecuted:**
   - **Spec Quote:** *"Manual test on a device with real Google Pay notifications (redacted)."* (`task.md:68`, Issue #7)
   - **Finding:** While marked complete (`- [x]`) in `task.md`, physical device verification was not performed. The newly created `device-verification-guide.md:119-126` contains an unexecuted checklist with all 6 verification steps left unchecked (`[ ]`), with no actual device execution logs captured.

---

### (b) Behaviour in Diff Not Asked For (Scope Creep)

1. **Card Hint Note Formatting & Transaction Prefilling:**
   - **Spec Quote:** *"S6 Verification. Widget tests for the prefilled page, unit tests for dedupe window and source classification..."* (`task.md:68`)
   - **Finding:** PR #26 introduces production feature code: `GooglePayTransactionResult.cardHint` in `googlePayParser.dart:33-46` and wires it into `AddTransactionPage(selectedNotes: note)` (`googlePayParser.dart:257`) and headless payloads. S6 was scoped strictly to verification.

2. **Production Database Timeouts Added for Widget Test Harness:**
   - **Spec Quote:** *"S6 Verification: widget/unit tests, flutter analyze, dart format..."* (Issue #7)
   - **Finding:** Production methods in `dedupeLedger.dart:581-606` (`_tryPersist`) and `googlePayParser.dart:173-232` (`resolveWallet`, `resolveCategory`) were modified to add 200ms timeouts solely to bypass `fakeAsync` event-loop stalling during widget tests.

---

### (c) Requirements Implemented Wrongly

1. **ADB Broadcast Simulation Blocked on Android 14+ (API 34+):**
   - **Spec Quote:** *"Manual test on a device with real Google Pay notifications (redacted)."* (`task.md:68`)
   - **Finding:** `device-verification-guide.md:32-47` recommends `adb shell am broadcast -a slayer.notification.listener.service.intent ...`. As documented in `research.md` (Q7), `notification_listener_service: 1.0.0` registers its receiver with `RECEIVER_NOT_EXPORTED` on API 34+. ADB shell broadcasts (UID 2000) are blocked by Android security controls on API 34+, making the recommended simulation command non-functional on modern Android versions.

2. **Hardcoded 200ms Database Timeouts Cause Silent Data Dropping:**
   - **Spec Quote:** *"Store in a new Drift table (additive migration)."* (`task.md:62`)
   - **Finding:** `.timeout(const Duration(milliseconds: 200), onTimeout: () => -1)` in `_tryPersist` and 200ms catches in `resolveWallet` cause silent drops on slower physical devices, cold starts, or during SQLite write locks, failing to persist dedupe entries and abandoning wallet matches.

---

## Summary

- **Standards:** 5 findings (2 hard violations: production database timeout workarounds violating `CONSTRAINTS.md` §3, release package hardcoding in verification guide violating `architecture.md` §4; 3 baseline smells: duplicated test popping boilerplate, repeated inline timeouts, and duplicated test event factory). **Worst issue:** Production database persistence altered with arbitrary 200ms timeouts to bypass widget test runner stalls.
- **Spec:** 5 findings (1 unexecuted requirement: device verification checklist unchecked; 2 scope creep: card hint note feature code, test-harness production timeouts; 2 incorrect implementations: non-functional ADB broadcasts on Android 14+, silent SQLite drops from 200ms timeouts). **Worst issue:** 200ms database timeout fallback causes silent loss of dedupe entries on device I/O contention.
