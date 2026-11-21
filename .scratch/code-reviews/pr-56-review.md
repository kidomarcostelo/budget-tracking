# Code Review: Pull Request #56

- **Target / PR:** Pull Request [#56](https://github.com/kidomarcostelo/budget-tracking/pull/56) — `feat(objectives): allow tagging balance transfers to savings objectives in Transfer popup (BT-0021) (#55)`
- **Branch:** `feat/transfer-objective-tagging` → `main`
- **Head Commit:** [`935b95b3`](https://github.com/kidomarcostelo/budget-tracking/commit/935b95b30f7a870bdb502e250c7d9bf06d7f15d7)
- **Base / Fixed Point:** `origin/main` ([`cbcedd00`](https://github.com/kidomarcostelo/budget-tracking/commit/cbcedd000d00d46aefbccac4c553118a9ae50692))
- **Originating Spec:** Issue [#55](https://github.com/kidomarcostelo/budget-tracking/issues/55) / [`.scratch/BT-0021-tag-transfers-to-savings-objectives/task.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0021-tag-transfers-to-savings-objectives/task.md)
- **Review Date:** 2026-11-22
- **Review Type:** Two-Axis Code Review (Standards & Spec)

---

## Executive Summary

| Axis | Findings Count | Worst Issue | Status |
|:-----|:--------------:|:------------|:-------|
| **Standards** | 3 (1 documented standard violation, 2 baseline smells) | Forbidden domain vocabulary `goalTotal` violating `GLOSSARY.md` / `AGENTS.md`. | Needs Polish |
| **Spec** | 6 (2 missing/partial, 2 scope creep, 2 incorrect implementations) | Objective erasure under schema cleansing when `initialObjectiveLoanPk` collides with inverted transfer. | Needs Polish |

---

## Standards

### 1. Documented Standards Violations

- **`AGENTS.md` (Domain Vocabulary) & `GLOSSARY.md` (Objective: Avoid "Goal")** — *Hard Violation (Minor)*:
  In [`budget/test/transfer_objective_tagging_test.dart:298-300, 362-364`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/test/transfer_objective_tagging_test.dart#L298-L300):
  ```dart
  final goalTotal =
      await testDb.watchTotalTowardsObjective(allWallets, objective).first;
  ```
  Lines 299 & 363 name the variable `goalTotal` instead of `objectiveTotal`. `GLOSSARY.md` explicitly lists `Goal` as a forbidden term for `Objective`. Rename to `objectiveTotal`.

*(All constraints from `CONSTRAINTS.md` — zero suppressions, migrations untouched, test suite passing, format clean, analyze clean, no hardcoded secrets — are fully satisfied).*

---

### 2. Baseline Code Smells (Judgement Calls)

- **Duplicated Code** — [`budget/test/transfer_objective_tagging_test.dart:254-278`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/test/transfer_objective_tagging_test.dart#L254-L278):
  ```dart
  // Replicate the exact transferBalance logic in addWalletPage.dart
  final destinationTxPk = await createCorrectionTransaction(
    ...,
    objectivePk: isNegative ? null : selectedObjectivePk,
  );
  final sourceTxPk = await createCorrectionTransaction(
    ...,
    objectivePk: isNegative ? selectedObjectivePk : null,
    pairedTransactionFk: destinationTxPk,
  );
  ```
  The transfer pairing logic from `_TransferBalancePopupState.transferBalance()` in `addWalletPage.dart` is copy-pasted into two test cases (`L256–277` and `L327–350`). Because `transferBalance()` remains private inside widget state rather than extracted to a shared domain seam, the tests verify their own copy of the logic rather than the production method. Recommendation: extract the balance transfer transaction pairing into a shared helper function called by both `TransferBalancePopup` and the tests.

- **Speculative Generality** — [`budget/lib/pages/addWalletPage.dart:1011-1063`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/pages/addWalletPage.dart#L1011-L1063):
  ```dart
  this.initialObjectivePk,
  ...
  final String? initialObjectivePk;
  ...
  @override
  void didUpdateWidget(covariant TransferBalancePopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialObjectivePk != oldWidget.initialObjectivePk) {
      setState(() => selectedObjectivePk = widget.initialObjectivePk);
    }
  }
  ```
  `initialObjectivePk` and `didUpdateWidget` add parameter surface and lifecycle machinery for pre-selection, but no caller across the app currently passes `initialObjectivePk` to `TransferBalancePopup`, nor do any of the other `initial*` properties implement `didUpdateWidget`. Recommendation: delete until an actual caller requires pre-selection.

---

## Spec

### 1. Requirements Missing or Partial

- **Widget tests for `TransferBalancePopup` are missing:**
  > Spec: `"Add test cases in budget/test/ asserting that creating a balance transfer with a selected objective sets objectiveFk on the destination transaction and updates watchTotalTowardsObjective."` (`task.md` L48)
  - `budget/test/transfer_objective_tagging_test.dart` tests `createCorrectionTransaction`, but tests for `transferBalance()` only manually duplicate the method's code in a "simulated" test rather than pumping `TransferBalancePopup`. Actual UI widget execution is untested.

- **Details sheet selector not implemented:**
  > Spec: `"In TransferBalancePopup, provide an option (via SelectObjective chip or details sheet) to select a savings goal (ObjectiveType.goal)."` (`task.md` L22)
  - `SelectObjective` was only embedded directly on the main popup column; it was omitted from the "transaction-details" bottom sheet (`editTransferDetails`).

---

### 2. Behaviour in Diff Not Asked For (Scope Creep)

- **`initialObjectivePk` and `didUpdateWidget` on `TransferBalancePopup`:**
  > Spec: `"- Add state for String? selectedObjectivePk."` (`task.md` L42)
  - Added `this.initialObjectivePk` constructor parameter to `TransferBalancePopup` and `didUpdateWidget` lifecycle synchronization. These were not requested and remain unused by any caller in the codebase.

- **Inverted transfer (`isNegative`) direction branch:**
  > Spec: `"- When executing transferBalance(), the incoming transaction (walletTo) receives objectiveFk: selectedObjectivePk."` (`task.md` L24)
  - Added conditional logic swapping objective assignment between `walletTo` and `walletFrom` when `isNegative == true`. While good defensive coding, it was not asked for in the spec.

---

### 3. Requirements Implemented Where Implementation Looks Wrong

- **Objective erasure on inverted transfers when `initialObjectiveLoanPk` is present:**
  > Spec: `"- The outgoing transaction (walletFrom) remains an untagged transfer out so the objective is credited without being canceled out."` (`task.md` L25)
  - If `TransferBalancePopup` has `initialObjectiveLoanPk` and `isNegative == true`, `walletFrom` receives both `objectiveLoanPk` and `objectivePk`. Under `cleanseTransactionForLongTermLoan`, `objectiveFk` is forcibly cleared to `null` whenever `objectiveLoanFk != null`, silently discarding the savings objective.

- **Unconditional display of `SelectObjective(goal)` during loan transfers:**
  > Spec: `"- In TransferBalancePopup, provide an option (via SelectObjective chip or details sheet) to select a savings goal (ObjectiveType.goal)."` (`task.md` L22)
  - When paying off a loan (`initialObjectiveLoanPk != null`), `SelectObjective` for `ObjectiveType.goal` is still displayed, allowing users to configure conflicting objective types.

---

## Summary

- **Standards:** 3 findings (worst issue: forbidden domain vocabulary `goalTotal` in `transfer_objective_tagging_test.dart`).
- **Spec:** 6 findings (worst issue: objective erasure under `cleanseTransactionForLongTermLoan` when both `initialObjectiveLoanPk` and inverted savings transfer occur).
