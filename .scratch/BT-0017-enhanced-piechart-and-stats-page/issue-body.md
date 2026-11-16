## Summary

Implement an enhanced, descriptive pie chart analytics experience matching `docs/expected.jpg`:
- **Spending Heatmap Gradient (Global):** Slices sweep from red/coral (largest share) to teal (smallest share) using an HSV hue model (0° to 180°), communicating relative spending size at a glance.
- **Callout Labels (Global):** External elbow callout lines pointing from slices to category name + percentage text labels replace cramped circular icon badges.
- **Category Spending Legend:** A full, scrollable list rendered below the chart showing percentage pills, category names, monetary totals, and accordion subcategory expansion.
- **Dedicated Stats Page:** Full-screen analytics view accessible via bottom navigation bar (slot 3), with independent period selector (`StatsPieChart`), Income vs. Expenses toggle, and no FAB.
- **Homepage Card Upgrade:** Removed the left-side `TopCategoriesSpentLegend` and the old slice-tap `CategoryEntry` drill-through block; chart and new legend span the card.

## Design Decisions (Settled via /grilling)

| # | Topic | Selected Option | Description |
|---|-------|-----------------|-------------|
| **Q1** | Screen Location | Option 3 | Both: upgrade homepage card and introduce dedicated Stats page |
| **Q2** | Slice Colors | Option 1 | Override category configured colors with Spending Heatmap Gradient |
| **Q3** | Legend Style | Option 1 | Full scrollable legend below the chart replaces top 3-5 dots legend |
| **Q4** | Category Scope | All + subcategories | Show all categories ordered descending; tapping row expands subcategories |
| **Q5** | Pie Slice Badges | Option 1 | Callout lines with text labels (`Name` + `XX.X%`) replace icon badges |
| **Q6** | Feature Boundary | Option 2 (Global) | Global upgrade across all pie charts in the app |
| **Q7** | Chart Sizes | Option 1 (Global) | Callout labels rendered globally across chart instances |
| **Q8** | Pie on Expand | Option 1 | Pie stays intact; only the legend expands subcategories inline |
| **Q9** | Navigation | Option 1 | First-class bottom nav tab |
| **Q10** | Gradient Model | Option 2 | HSV hue sweep (0° to 180°) |
| **Q11** | Currency Format | Option 1 | Standard `convertToMoney` / `getCurrencyString` with wallet currency |
| **Q12** | Row Tap Action | Option 1 | Tapping row expands subcategories + highlights corresponding pie slice |
| **Q13** | Period Settings | Option 2 | Independent cycle settings (`cycleSettingsExtension: "StatsPieChart"`) |
| **Q14** | Income/Expense | Option 2 | One at a time with tab toggle selector (`Income` / `Expenses`) |
| **Q15** | Accordion Tap | Option 1 | Tapping an expanded row again collapses it and deselects pie highlight |
| **Q16** | Subcategory Row | Option 3 | Indented row with smaller percentage badge and formatted amount |
| **Q17** | Nav Tab Slot | Option 1 | Stats placed at slot 3; More shifted to slot 4 with dedicated icon |
| **Q18** | Action Button | Option 2 (No) | No FAB on Stats page (read-only analytics) |
| **Final** | Old Drill-down | Removed | Remove old `CategoryEntry` card list on homepage pie tap |

## Tasks & Sub-Issues

- [ ] #41 — VS1: Heatmap Gradient & Callout Labels in PieChartDisplay
- [ ] #42 — VS2: CategorySpendingLegend Widget with Subcategory Accordion
- [ ] #43 — VS3: Homepage Pie Chart Card Upgrade
- [ ] #44 — VS4: Dedicated Full-Screen Stats Page
- [ ] #45 — VS5: Bottom Navigation Framework & Translations Integration

## Key Files to Touch & Create

- `budget/lib/widgets/pieChart.dart` — Heatmap color helper + elbow callout line painter / labels
- `budget/lib/widgets/categorySpendingLegend.dart` (NEW) — High-density legend widget with accordion expansion
- `budget/lib/pages/homePage/homePagePieChart.dart` — Remove old legend & drill-down, embed new legend
- `budget/lib/pages/statsPage.dart` (NEW) — Full-screen stats analytics page
- `budget/lib/struct/navBarIconsData.dart` — Register `"stats"` icon data at index 18
- `budget/lib/widgets/navigationFramework.dart` — Mount `StatsPage` at index 18 in `pagesExtended`
- `budget/lib/widgets/bottomNavBar.dart` — 5-destination bottom nav bar layout
- `budget/assets/translations/generated/en.json` — Add `"stats": "Stats"`

## Local Artifacts
- Task Tracker: `.scratch/BT-0017-enhanced-piechart-and-stats-page/task.md`
- Detailed Plan: `.scratch/BT-0017-enhanced-piechart-and-stats-page/plan.md`
- Technical Execution Plan: `.scratch/BT-0017-enhanced-piechart-and-stats-page/execution.md`
- Architecture Decision Records:
  - `docs/adr/0003-spending-heatmap-gradient-overrides-category-color.md`
  - `docs/adr/0004-callout-labels-replace-icon-badges-globally.md`
  - `docs/adr/0005-stats-nav-tab.md`
