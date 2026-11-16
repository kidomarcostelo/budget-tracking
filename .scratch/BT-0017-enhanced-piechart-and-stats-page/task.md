# Task: Enhanced Pie Chart, Category Spending Legend, and Dedicated Stats Page

**ID:** BT-0017  
**Issue Reference:** [#40](https://github.com/kidomarcostelo/budget-tracking/issues/40)  
**Pull Request:** [#48](https://github.com/kidomarcostelo/budget-tracking/pull/48)  
**Status:** In Review  
**Assignee / Agent:** Antigravity  

---

## 1. Objective & Scope
- **Problem Statement:** The current pie chart is not descriptive. Circular icon badges obscure slice sizes, colors are tied to category settings rather than relative proportions, the legend only displays dots for 3-5 categories without monetary amounts, and there is no dedicated, full-screen Stats view matching `docs/expected.jpg`.
- **Expected Behavior:** 
  1. Pie chart slices globally follow a Spending Heatmap Gradient (HSV sweep from red/coral to teal based on descending spending rank).
  2. Callout lines with category name and percentage (`XX.X%`) point outward from slices, replacing circular icon badges.
  3. A new `CategorySpendingLegend` renders below the chart displaying all categories with colored percentage pills, names, formatted monetary totals, and accordion subcategory expansion.
  4. Homepage pie chart card is upgraded (removes old dots legend and old `CategoryEntry` drill-through block; embeds `CategorySpendingLegend`).
  5. A new full-screen `StatsPage` is added with period navigation (`< Month Year >`), Income/Expenses toggle, enhanced pie chart, and scrollable legend.
  6. Bottom navigation bar gains a 5th tab for Stats at slot 3 (shifting More to slot 4 with dedicated icon; no FAB on Stats).

---

## 2. Invariants & Constraints
- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- Do NOT edit past Drift migration steps or schema files.
- All user-facing strings must be localized via `easy_localization` / translations files.
- Git commits must use author `kidomarcostelo@gmail.com`.
- No `Co-authored-by` trailers in commit messages.
- Work on feature branch `feat/enhanced-pie-chart-stats`, push branch, and open PR against `main`.
- Separate session for code review: pause after PR creation.

---

## 3. Plan & Implementation Steps (Vertical Slices)

### VS1: Heatmap Gradient & Callout Labels (`budget/lib/widgets/pieChart.dart`) — [#41](https://github.com/kidomarcostelo/budget-tracking/issues/41)
- [x] Add `getSpendingHeatmapColor(int index, int totalCount)`.
- [x] Replace category colors with heatmap gradient colors in `PieChartSectionData`.
- [x] Implement callout lines and label rendering pointing outward to `Category Name` + `XX.X%`.
- [x] Suppress callouts for slices < 1%.
- [x] Unit test color generation and verify `flutter analyze`.

### VS2: `CategorySpendingLegend` Widget (`budget/lib/widgets/categorySpendingLegend.dart`) — [#42](https://github.com/kidomarcostelo/budget-tracking/issues/42)
- [x] Build reusable `CategorySpendingLegend` widget.
- [x] Render percentage pill with heatmap color, category name, and localized amount.
- [x] Implement accordion tap interaction: expand/collapse subcategory rows.
- [x] Support bidirectional slice highlight synchronization.
- [x] Widget tests for legend rendering and tap interactions.

### VS3: Homepage Pie Chart Card Upgrade (`budget/lib/pages/homePage/homePagePieChart.dart`) — [#43](https://github.com/kidomarcostelo/budget-tracking/issues/43)
- [x] Remove `TopCategoriesSpentLegend` and horizontal split.
- [x] Remove old slice-tap `CategoryEntry` drill-through block.
- [x] Embed `CategorySpendingLegend` directly below the widened pie chart.
- [x] Connect selection state between pie chart and legend.

### VS4: Dedicated Stats Page (`budget/lib/pages/statsPage.dart`) — [#44](https://github.com/kidomarcostelo/budget-tracking/issues/44)
- [x] Implement `StatsPage` widget with period navigation header (`< Month Year >` & period bottom sheet).
- [x] Use independent cycle settings (`StatsPieChart`).
- [x] Implement Income vs. Expenses tab selector.
- [x] Embed `PieChartWrapper` and full scrollable `CategorySpendingLegend`.

### VS5: Navigation & Localization Integration — [#45](https://github.com/kidomarcostelo/budget-tracking/issues/45)
- [x] Add `"stats"` to `budget/lib/struct/navBarIconsData.dart` (index 18).
- [x] Mount `StatsPage` in `pagesExtended` (index 18) in `budget/lib/widgets/navigationFramework.dart`.
- [x] Verify FAB condition excludes index 18.
- [x] Update `budget/lib/widgets/bottomNavBar.dart` to support 5 destinations (Slot 3 Stats, Slot 4 More).
- [x] Add `"stats"` string to `budget/assets/translations/generated/en.json` and `translations.csv`.

---

## 4. Verification & Testing
- [x] Unit / Widget tests added under `budget/test/` (`pie_chart_test.dart`, `category_spending_legend_test.dart`)
- [ ] `flutter analyze` passes with 0 issues (CI Quality Gate)
- [ ] `dart format --output=none --set-exit-if-changed .` passes (CI Quality Gate)
- [x] Manual visual verification against `docs/expected.jpg`
