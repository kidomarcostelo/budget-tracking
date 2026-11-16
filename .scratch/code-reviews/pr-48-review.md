# Code Review: Pull Request #48 (BT-0017)

- **Target / PR:** Pull Request [#48](https://github.com/kidomarcostelo/budget-tracking/pull/48) — `feat(analytics): add enhanced pie chart, category spending legend, and dedicated stats page (BT-0017)`
- **Branch:** `feat/enhanced-pie-chart-stats` → `main`
- **Head Commit:** [`0b886d1c`](https://github.com/kidomarcostelo/budget-tracking/commit/0b886d1c0e760b509fd16ed641deba620d58703a)
- **Fixed Point:** `origin/main` ([`1596a93c`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget))
- **Originating Spec:** Issue [#40](https://github.com/kidomarcostelo/budget-tracking/issues/40) (Sub-issues #41, #42, #43, #44, #45), [`.scratch/BT-0017-enhanced-piechart-and-stats-page/task.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0017-enhanced-piechart-and-stats-page/task.md), [`.scratch/BT-0017-enhanced-piechart-and-stats-page/plan.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0017-enhanced-piechart-and-stats-page/plan.md)
- **Review Date:** 2026-11-16
- **Review Type:** Two-Axis Code Review (Standards & Spec)

---

## Executive Summary

| Axis | Findings Count | Worst Issue | Status |
|:-----|:--------------:|:------------|:-------|
| **Standards** | 5 (2 hard violations, 3 baseline smells) | Hardcoded raw color hex `const Color(0xFFFF6B6B)` in [statsPage.dart:263, 304](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/pages/statsPage.dart#L263-L304) violating repo theme constraints. | Needs Attention |
| **Spec** | 5 (1 missing/partial, 3 scope creep, 1 incorrect) | `StatsPage` period cycle decoupling is partial: date range calculation hardcodes calendar months and ignores `WalletPickerPeriodCycle` custom cycles ([statsPage.dart:65–69, 103–115](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/pages/statsPage.dart#L65-L115)). | Needs Attention |

---

## 1. Standards Axis

### (a) Documented Standards Violations

1. **Hard Violation: Hardcoded Color Hex in Page Widget**
   - **Standard:** [`AGENTS.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/AGENTS.md) (*Color & Theming* — "Use theme palettes defined in budget/lib/colors.dart. Avoid hardcoded raw Color hex values in page widgets.")
   - **Location:** [`budget/lib/pages/statsPage.dart:263, 304`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/pages/statsPage.dart#L263-L304)
   - **Violation:**
     ```dart
     color: _isIncome ? const Color(0xFFFF6B6B) : Colors.transparent,
     // ...
     color: !_isIncome ? const Color(0xFFFF6B6B) : Colors.transparent,
     ```
   - **Remediation:** Replace hardcoded hex with theme color palette, e.g. `getColor(context, "expenseAmount")` or `Theme.of(context).colorScheme.primary`.

2. **Hard Violation: Unlocalized User-Facing Text**
   - **Standard:** [`AGENTS.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/AGENTS.md) (*Localization* — "All user-facing text must use localized strings via `app_localizations` or existing localization delegates.")
   - **Location:** [`budget/lib/pages/statsPage.dart:172, 185, 203`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/pages/statsPage.dart#L172-L203)
   - **Violation:**
     ```dart
     tooltip: "Previous month",
     tooltip: "Next month",
     text: "Monthly",
     ```
   - **Remediation:** Add corresponding keys to `translations.csv` and generated `en.json`, referencing them via `.tr()`.

---

### (b) Baseline Code Smells (Judgement Calls)

1. **Duplicated Code — Callout Painter Left/Right Branches**
   - **Smell:** Duplicated Code (*Refactoring* ch.3)
   - **Location:** [`budget/lib/widgets/pieChart.dart:512-579` vs `582-650`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/widgets/pieChart.dart#L512-L650)
   - **Observation:** Both the left and right candidate rendering loops duplicate the exact same `TextPainter`, bounding calculation, line path construction (`moveTo`, `lineTo`), and canvas drawing logic, differing only in sign direction (`-lineExtension` vs `+lineExtension`).
   - **Remediation:** Extract a shared `_drawCallout(...)` helper method taking direction sign.

2. **Duplicated Code — Dual Streams & Tab Buttons**
   - **Smell:** Duplicated Code (*Refactoring* ch.3)
   - **Location:** [`budget/lib/pages/statsPage.dart:103-154, 231-310`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/pages/statsPage.dart#L103-L310)
   - **Observation:** Two nested `StreamBuilder<List<CategoryWithTotal>>` calls duplicate query setups and fallback containers just to toggle `isIncome`. Similarly, the Income and Expense tab buttons duplicate identical widget sub-trees.
   - **Remediation:** Parameterize the query with `_isIncome` in a single `StreamBuilder` and extract a small tab button widget.

3. **Divergent Change / Monolithic Widget**
   - **Smell:** Divergent Change / Long Method (*Refactoring* ch.3; aligns with `AGENTS.md` *Widget Decomposition*)
   - **Location:** [`budget/lib/pages/statsPage.dart:93-395`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/pages/statsPage.dart#L93-L395)
   - **Observation:** A single ~300-line `build()` method orchestrates header date navigation, streams, tab selectors, chart rendering, and category legends.
   - **Remediation:** Decompose into `_StatsPeriodHeader` and `_StatsTabBar` widgets.

---

## 2. Spec Axis

### (a) Requirements Missing or Partial

1. **`StatsPage` period cycle decoupling is partial:**
   - **Spec Quote:** `plan.md` L50: `"Q13 | Stats Period Settings | Option 2 | Independent cycle settings (cycleSettingsExtension: 'StatsPieChart')."` & `task.md` L58: `"- [x] Use independent cycle settings (StatsPieChart)."`
   - **Finding:** In [`budget/lib/pages/statsPage.dart:65-69, 103-115`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/pages/statsPage.dart#L65-L115), `_getDateRange()` hardcodes calendar months (`DateTime(_currentDate.year, _currentDate.month, 1)` to end-of-month). The query omits `followCustomPeriodCycle: true`, causing Drift’s `onlyShowIfFollowCustomPeriodCycle` to evaluate to `Constant(true)`. Selecting custom cycles (weekly, bi-weekly, custom day) in `WalletPickerPeriodCycle` has no effect on the date range or queried data. Furthermore, the period pill text is hardcoded to `"Monthly"` (L203) instead of dynamically reflecting the active cycle setting.
   - **Remediation:** Wire `StatsPage` to resolve date ranges using `cycleSettingsExtension: "StatsPieChart"` helper functions or respect custom period cycle boundaries.

---

### (b) Scope Creep (Unasked-for Behaviour)

1. **Unrelated commit email update in `AGENTS.md`:**
   - **Finding:** [`AGENTS.md:35`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/AGENTS.md#L35) modifies repository-wide git commit email guidelines to use the GitHub noreply email address.
   - **Remediation:** Keep doc policy changes in a dedicated chore commit/PR rather than mixing into a feature PR.

2. **Extraneous PR #41 review artifact:**
   - **Finding:** Commit `e85b33e1` includes `.scratch/code-reviews/pr-41-review.md`, an artifact reviewing PR #41 (BT-0016 background keep-alive service), wholly unrelated to BT-0017.
   - **Remediation:** Remove unrelated review artifact from the PR branch.

3. **Unrelated BT-0016 index update:**
   - **Finding:** [`.scratch/index.md:28`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/index.md#L28) updates the issue reference for BT-0016 to `#46`.
   - **Remediation:** Revert unrelated line change in `.scratch/index.md`.

---

### (c) Requirements Implemented Incorrectly

1. **Hardcoded unlocalized strings in `StatsPage`:**
   - **Spec Quote:** `task.md` L26: `"All user-facing strings must be localized via easy_localization / translations files."`
   - **Finding:** `statsPage.dart` hardcodes raw English string literals instead of using localization delegates:
     - L172: `tooltip: "Previous month"`
     - L185: `tooltip: "Next month"`
     - L203: `text: "Monthly"`
   - **Remediation:** Localize tooltips and dynamic period label via `tr()`.

---

## 3. Summary & Recommended Action Plan

- **Standards Axis:** 5 findings (2 hard violations, 3 baseline smells); worst issue is hardcoded raw color hex `const Color(0xFFFF6B6B)` in `statsPage.dart`.
- **Spec Axis:** 5 findings (1 missing/partial, 3 scope creep, 1 incorrect); worst issue is `StatsPage` period cycle calculation ignoring custom cycle settings and hardcoding calendar months.
