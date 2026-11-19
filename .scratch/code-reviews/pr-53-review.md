# Code Review: Pull Request #53 (BT-0020)

- **Target / PR:** Pull Request [#53](https://github.com/kidomarcostelo/budget-tracking/pull/53) — `fix(stats): aggregate subcategories into main categories, remove negative signs, and nest subcategories in pie chart (BT-0020) (#51)`
- **Branch:** `fix/BT-0020-stats-category-totals-and-pie-slices` → `main`
- **Head Commit:** [`8ba65883`](https://github.com/kidomarcostelo/budget-tracking/commit/8ba6588393c7d8b5f17eea9ba0d7bce9fcbce44e)
- **Base / Fixed Point:** `origin/main` ([`93c67492`](https://github.com/kidomarcostelo/budget-tracking/commit/93c67492f795d37bebb05cd5d08977bcd20026a6))
- **Originating Spec:** Issue [#51](https://github.com/kidomarcostelo/budget-tracking/issues/51), [`.scratch/BT-0020-stats-category-totals-and-pie-slices/task.md`](https://github.com/kidomarcostelo/budget-tracking/blob/fix/BT-0020-stats-category-totals-and-pie-slices/.scratch/BT-0020-stats-category-totals-and-pie-slices/task.md) & [`.scratch/BT-0020-stats-category-totals-and-pie-slices/diagnosis.md`](https://github.com/kidomarcostelo/budget-tracking/blob/fix/BT-0020-stats-category-totals-and-pie-slices/.scratch/BT-0020-stats-category-totals-and-pie-slices/diagnosis.md)
- **Review Date:** 2026-11-20
- **Review Type:** Two-Axis Code Review (Standards & Spec)

---

## Executive Summary

| Axis | Findings Count | Worst Issue | Status |
|:-----|:--------------:|:------------|:-------|
| **Standards** | 2 (1 documented violation, 1 baseline smell) | Commit author email uses GitHub noreply address (`111844659+kidomarcostelo@users.noreply.github.com`) instead of `kidomarcostelo@gmail.com` as mandated in `AGENTS.md`. | Needs Attention |
| **Spec** | 0 (0 missing/partial, 0 scope creep, 0 incorrect implementations) | None. All 3 reported issues in #51 are cleanly solved and verified with regression tests. | Pass |

---

## 1. Standards Axis

### (a) Documented Standards Violations

1. **Commit Author & Email**
   - **Standard:** [`AGENTS.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/AGENTS.md) (*Boundaries & Safety Guardrails — Commit Author & Email*)
   - **Rule:** *"Always ensure Git commits use the author email `kidomarcostelo@gmail.com` (`git config user.email "kidomarcostelo@gmail.com"`). Do not commit using another email address."*
   - **Violation:** Commit `8ba65883` was authored using `Kid Omar Costelo <111844659+kidomarcostelo@users.noreply.github.com>` rather than `kidomarcostelo@gmail.com`.
   - **Context:** Previously encountered in PR #48, #49, and #52 due to GitHub GH007 email privacy protection.

*All other documented standards (`CONSTRAINTS.md` zero-suppression, static analysis clean, `dart format` check, test suite integrity, `docs/adr/0005-stats-nav-tab.md`, and `GLOSSARY.md` domain vocabulary) are satisfied.*

---

### (b) Baseline Code Smells (Judgement Calls)

1. **Primitive Obsession / Duplicated Code — Ad-Hoc Magnitude Formatting**
   - **Smell:** Primitive Obsession / Duplicated Code (*Refactoring* ch. 3)
   - **Location:** [`budget/lib/widgets/categorySpendingLegend.dart:153-154, 210-211`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/widgets/categorySpendingLegend.dart#L153-L154)
   - **Hunk:**
     ```dart
     // Parent Category Row
     TextFont(
       text: convertToMoney(allWallets, categoryWithTotal.total.abs()),
       fontSize: 16,
       fontWeight: FontWeight.w600,
     ),
     ...
     // Subcategory Row
     TextFont(
       text: convertToMoney(allWallets, sub.total.abs()),
       fontSize: 14,
       fontWeight: FontWeight.w500,
     ),
     ```
   - **Observation:** `CategoryWithTotal.total` carries raw negative signs for expenses without polarity normalization at the helper/model boundary, leading presentation widgets to duplicate ad-hoc `.abs()` transformations across parent and subcategory row builders.
   - **Recommendation:** While calling `.abs()` in UI presentation avoids mutating underlying transaction totals, encapsulating magnitude or formatted values on `CategoryWithTotal` would prevent scattered `.abs()` calls in the future.

---

## 2. Spec Axis

### (a) Requirements Missing or Partial
**None.** All requirements and acceptance criteria from Issue #51 are fully satisfied:
1. **Category Rollup:**
   > Spec: *"Main categories in Stats (and legend) display the rolled-up total of all their subcategories (plus any direct transactions)."*
   - Implemented in `budget/lib/pages/statsPage.dart` by passing `showAllSubcategories: false` to `watchTotalSpentInTimeRangeHelper`. This retains the full parent total rather than subtracting subcategory amounts down to `0`.
2. **Positive Formatting:**
   > Spec: *"All category and subcategory amounts in the legend display positive monetary amounts without misleading negative signs."*
   - Implemented in `budget/lib/widgets/categorySpendingLegend.dart` (lines 153 & 210) by applying `.abs()` to both `categoryWithTotal.total` and `sub.total` before passing to `convertToMoney()`.
3. **Pie Chart Main Category Slices:**
   > Spec: *"In the pie chart, only main categories have slices representing the full aggregated category total. Subcategories do not get separate top-level pie slices."*
   - Implemented: `dataFilterUnassignedTransactions` contains only main categories when `showAllSubcategories: false`, while subcategories remain indexed under `subCategorySpendingIndexedByMainCategoryPk` for legend accordion expansion.
4. **Regression Tests:**
   > Spec: *"Regression tests added covering all three scenarios."*
   - Implemented in `budget/test/stats_category_pie_bugs_test.dart` covering aggregated rollup, top-level slice filtering, and positive legend formatting.

---

### (b) Behaviour in Diff Not Asked For (Scope Creep)
**None.**
- Setting `showAllSubcategories: false` for `incomeSummary` alongside `expenseSummary` in `statsPage.dart` ensures symmetric behavior between the Income and Expense tabs on Stats.
- Updating `.scratch/index.md` maintains required task tracking.

---

### (c) Requirements Implemented Incorrectly
**None.**
- Calling `.abs()` at the display seam in `_CategorySpendingRow` avoids altering underlying negative transaction values in the database while guaranteeing positive formatting in the legend.
- Tapping main categories continues to synchronize smoothly with `PieChartDisplay` callouts and accordion expansion.

---

## Summary

- **Total Findings:** Standards: 2 findings (1 violation, 1 smell) | Spec: 0 findings.
- **Worst Issue (Standards):** Commit author email (`111844659+kidomarcostelo@users.noreply.github.com`) does not match `kidomarcostelo@gmail.com` as required in `AGENTS.md`.
- **Worst Issue (Spec):** None (Clean pass across all functional specifications).
