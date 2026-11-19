# Task: Fix Stats Category Expenses, Negative Signs, and Subcategory Pie Slices

**ID:** BT-0020  
**Issue Reference:** [#51](https://github.com/kidomarcostelo/budget-tracking/issues/51)  
**Status:** In Progress  
**Assignee / Agent:** Antigravity  

---

## 1. Objective & Scope
- **Problem Statement:** 
  1. Main category expenses show as "0" on Stats when all expenses belong to subcategories. It should be the total expenses of all subcategories.
  2. Category and subcategory expense amounts display a misleading negative symbol (`-$XX.XX`). The negative symbol should be removed so expenses are formatted as positive monetary amounts.
  3. All subcategory expenses currently get dedicated slices in the pie chart. Subcategories should not be separate slices; they should be inside the main category slice.
- **Expected Behavior:**
  1. Main categories display the rolled-up total of all their subcategories (plus any directly assigned transactions).
  2. All expense amounts in `CategorySpendingLegend` are formatted with positive values (no `-` prefix).
  3. The pie chart displays slices exclusively for main categories, grouping subcategory expenses inside their parent slice. Subcategories remain accessible via accordion expansion in the spending legend.

---

## 2. Invariants & Constraints
- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- Do not edit past Drift migration steps or schema files.
- `flutter analyze` must pass with 0 errors and 0 warnings.
- `dart format --output=none --set-exit-if-changed .` must pass cleanly.
- Commits must use author email `kidomarcostelo@gmail.com`.
- No `Co-authored-by` trailers in commit messages.
- Work on a dedicated branch (`fix/BT-0020-stats-category-totals-and-pie-slices`), push branch, and open PR against `main`.
- Stop and pause for code review in a separate session once PR is opened.

---

## 3. Plan & Implementation Steps (Diagnosing Bugs Loop)
- [ ] Phase 1: Build a feedback loop (failing widget/unit test asserting main category rollup, positive amounts, and main-category-only pie slices).
- [ ] Phase 2: Reproduce & minimise the failure.
- [ ] Phase 3: Hypothesise & rank 3-5 falsifiable hypotheses.
- [ ] Phase 4: Instrument & verify data structures.
- [ ] Phase 5: Implement fix in `statsPage.dart`, `spendingSummaryHelper.dart`, and `categorySpendingLegend.dart`. Verify regression test goes green.
- [ ] Phase 6: Cleanup debug logs, format code, verify static analysis and test suite.

---

## 4. Verification & Testing
- [ ] Unit / Widget tests added under `budget/test/`
- [ ] Static analysis passes: `flutter analyze`
- [ ] Code formatted: `dart format --output=none --set-exit-if-changed .`
- [ ] All tests pass: `flutter test`
