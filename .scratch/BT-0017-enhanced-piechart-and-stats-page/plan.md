# Plan: Enhanced Pie Chart, Category Spending Legend, and Dedicated Stats Page

> **Task ID:** BT-0017  
> **Source Issue:** [#40](https://github.com/kidomarcostelo/budget-tracking/issues/40)  
> **Reference Design:** `docs/expected.jpg`  
> **Related ADRs:**
> - [`0003-spending-heatmap-gradient-overrides-category-color.md`](../../docs/adr/0003-spending-heatmap-gradient-overrides-category-color.md)
> - [`0004-callout-labels-replace-icon-badges-globally.md`](../../docs/adr/0004-callout-labels-replace-icon-badges-globally.md)
> - [`0005-stats-nav-tab.md`](../../docs/adr/0005-stats-nav-tab.md)
> **Glossary Context:** [`GLOSSARY.md`](../../GLOSSARY.md) (under `## Analytics`)

---

## 1. Summary & Goals

Transform Cashew's pie chart analytics from an undescriptive icon-badge chart into a high-density, highly descriptive financial breakdown as depicted in `docs/expected.jpg`:
1. **Spending Heatmap Gradient (Global):** Slice colors sweep from red/coral (largest percentage) to teal (smallest percentage) using an HSV hue model (0° to 180°), communicating size hierarchy instantly.
2. **Callout Labels (Global):** Outward elbow callout lines pointing from slices to category name + percentage text labels replace the cramped circular icon badges.
3. **Category Spending Legend:** A full, scrollable list rendered below the chart showing:
   - Rounded percentage badge with the slice's heatmap color
   - Category title
   - Monetary total in the active currency format
   - Inline subcategory accordion expansion on tap
   - Bidirectional slice highlight on tap (tapping legend row highlights pie slice and vice-versa)
4. **Dedicated Stats Page:** Full-screen analytics view accessible via bottom navigation bar (slot 3), with:
   - Date range / period selector (`< Sep 2025 > Monthly`) using independent cycle settings (`StatsPieChart`)
   - Income vs. Expenses selector toggle
   - Enhanced Pie Chart + full scrollable Category Spending Legend
   - No floating action button (read-only analytics surface)
5. **Homepage Pie Chart Card Alignment:** The existing left-side `TopCategoriesSpentLegend` and the old slice-tap drill-through `CategoryEntry` block are **removed**; the chart expands to full card width and is paired directly with the new `CategorySpendingLegend`.

---

## 2. Grilling Decisions Matrix (Settled Requirements)

| # | Topic | Selected Option | Description |
|---|-------|-----------------|-------------|
| **Q1** | Screen Location | Option 3 | Both: upgrade homepage card and introduce dedicated Stats page. |
| **Q2** | Slice Colors | Option 1 | Override category configured colors with a size-ranked Spending Heatmap Gradient. |
| **Q3** | Legend Style | Option 1 | Full scrollable legend below the chart replaces the top 3-5 dots legend. |
| **Q4** | Category Scope | All + subcategory expansion | Show all categories ordered descending; tapping row expands subcategories inline. |
| **Q5** | Pie Slice Badges | Option 1 | Callout lines with text labels (`Name` + `XX.X%`) replace icon badge circles. |
| **Q6** | Feature Boundary | Option 2 (Global) | Global upgrade across all pie charts in the app. |
| **Q7** | Chart Sizes | Option 1 (Global) | Callout labels rendered globally across chart instances. |
| **Q8** | Pie on Subcategory Expand | Option 1 | Pie stays intact; only the legend expands subcategories inline. |
| **Q9** | Stats Navigation | Option 1 | First-class bottom nav tab. |
| **Q10** | Gradient Model | Option 2 | HSV hue sweep (0° to 180°). |
| **Q11** | Currency Formatting | Option 1 | Standard `convertToMoney` / `getCurrencyString` with wallet currency. |
| **Q12** | Legend Row Tap Action | Option 1 | Tapping row expands subcategories + highlights corresponding pie slice. |
| **Q13** | Stats Period Settings | Option 2 | Independent cycle settings (`cycleSettingsExtension: "StatsPieChart"`). |
| **Q14** | Stats Income/Expense View | Option 2 | One at a time with tab toggle selector (`Income` / `Expenses`). |
| **Q15** | Accordion Behavior | Option 1 | Tapping an expanded row again collapses it and deselects pie highlight. |
| **Q16** | Subcategory Row Format | Option 3 | Indented row with smaller percentage badge and formatted amount. |
| **Q17** | Nav Tab Slot | Option 1 | Stats placed at slot 3; More shifted to slot 4 with dedicated icon. |
| **Q18** | Floating Action Button | Option 2 (No) | No FAB on Stats page (read-only analytics). |
| **Q-Final** | Homepage Old Drill-through | Removed | Remove old `CategoryEntry` block when tapping pie on home card. |

---

## 3. Architecture & Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                 StatsPage / HomePagePieChart                │
│                                                             │
│   StreamBuilder<List<CategoryWithTotal>>                    │
│   (watchTotalSpentInEachCategoryInTimeRangeFromCategories)  │
│                                │                            │
│                                ▼                            │
│                  TotalSpentCategoriesSummary                │
│             (ordered descending by category total)          │
│                                │                            │
│        ┌───────────────────────┴───────────────────────┐    │
│        ▼                                               ▼    │
│ ┌───────────────────────────┐         ┌───────────────────┐ │
│ │   PieChartWrapper         │         │ CategorySpending  │ │
│ │   (with callout painter   │         │ Legend            │ │
│ │    & heatmap gradient)    │◄───────►│ (scrollable rows  │ │
│ └───────────────────────────┘         │  + subcategories) │ │
│                                       └───────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Work Breakdown & Vertical Slices

### Slice 1: Heatmap Gradient & Callout Labels (`pieChart.dart`) — [#41](https://github.com/kidomarcostelo/budget-tracking/issues/41)
- Implement `getSpendingHeatmapColor(int rank, int totalCategories)` using HSV model (0° red/coral to 180° teal).
- Implement Callout Line Painter / Widget overlay for `PieChartDisplay`:
  - Calculate angle of slice midpoint from accumulated percentages.
  - Draw line from outer radius extending outward and bending horizontally.
  - Render category name and percentage (`XX.X%`).
  - Suppress callout for slices < 1% to avoid clutter.
  - Touch interaction highlights active slice and reports `setSelectedCategory`.

### Slice 2: Reusable `CategorySpendingLegend` Widget — [#42](https://github.com/kidomarcostelo/budget-tracking/issues/42)
- Create `budget/lib/widgets/categorySpendingLegend.dart`.
- Props:
  - `List<CategoryWithTotal> data`
  - `Map<String, List<CategoryWithTotal>> subcategoriesMap`
  - `double totalSpent`
  - `String? selectedCategoryPk`
  - `Function(String? categoryPk) onCategoryTapped`
- Render parent rows:
  - Rounded rectangular percentage pill colored with slice heatmap color.
  - Category title (`TextFont`).
  - Formatted currency string (`convertToMoney`).
- Expandable subcategory rows on tap (accordion):
  - 20dp start indentation.
  - Smaller percentage pill.
  - Subcategory title and amount.

### Slice 3: Upgrade `homePagePieChart.dart` — [#43](https://github.com/kidomarcostelo/budget-tracking/issues/43)
- Remove left-side `TopCategoriesSpentLegend` and horizontal two-column split.
- Center `PieChartWrapper` with full available width.
- Remove old conditional `CategoryEntry` drill-through block.
- Place `CategorySpendingLegend` directly below the pie chart.
- Connect bidirectional selection state between pie slices and legend rows.

### Slice 4: Create `StatsPage` (`budget/lib/pages/statsPage.dart`) — [#44](https://github.com/kidomarcostelo/budget-tracking/issues/44)
- Period navigation header (`< Month Year >` + period selector dropdown button).
- Cycle settings: `cycleSettingsExtension: "StatsPieChart"`.
- Income vs Expense tab toggle (`IncomeOutcomeTabSelector` / custom segmented buttons).
- Full stream query for `CategoryWithTotal` matching active period and filter.
- Layout: Pie Chart at top + scrollable `CategorySpendingLegend` below.

### Slice 5: Bottom Navigation Framework Integration — [#45](https://github.com/kidomarcostelo/budget-tracking/issues/45)
- Update `budget/lib/struct/navBarIconsData.dart`:
  - Add `"stats"` entry with `MoreIcons.chart_bar` / `Icons.bar_chart_rounded`.
  - Set `navigationIndexedStackIndex: 18`.
- Update `budget/lib/widgets/navigationFramework.dart`:
  - Append `StatsPage()` to `pagesExtended` (index 18).
  - Ensure FAB condition does not include index 18 (`[0, 1, 2, 14]`).
- Update `budget/lib/widgets/bottomNavBar.dart`:
  - Add 5th destination (Stats at slot 3, More at slot 4).
  - Update `getNavigationStackedIndexFromBarIndex` and `getNavigationBarIndexFromStackedIndex`.
  - Update iOS bottom nav bar row flex items.
- Update `assets/translations/generated/en.json` and `translations.csv` with `"stats": "Stats"`.

---

## 5. Verification & Acceptance Criteria

1. `flutter analyze` passes with 0 warnings/errors.
2. `dart format --output=none --set-exit-if-changed .` passes.
3. Unit/widget tests pass for `CategorySpendingLegend` and `getSpendingHeatmapColor`.
4. Visual verification against `docs/expected.jpg`:
   - Warm-to-cool heatmap gradient on slices.
   - External callout lines with name and percentage.
   - Descriptive legend with percentage badges and monetary amounts.
   - Accordion expansion of subcategories on row tap.
   - Independent period navigation in dedicated Stats tab.
