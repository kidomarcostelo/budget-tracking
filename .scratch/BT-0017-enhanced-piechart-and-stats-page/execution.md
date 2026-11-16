# Execution Plan: Enhanced Pie Chart, Category Spending Legend, and Dedicated Stats Page

> **Task ID:** BT-0017  
> **Status:** Ready for Implementation  
> **Target Branch:** `feat/enhanced-pie-chart-stats`  
> **Target PR Base:** `main`

---

## 1. File Touch List

| Action | Path | Description |
|--------|------|-------------|
| **Modify** | `budget/lib/widgets/pieChart.dart` | Heatmap color generator, callout line & label painting, replacement of `_Badge`. |
| **Create** | `budget/lib/widgets/categorySpendingLegend.dart` | High-density descriptive legend with subcategory accordion and percentage pills. |
| **Modify** | `budget/lib/pages/homePage/homePagePieChart.dart` | Remove `TopCategoriesSpentLegend` and old `CategoryEntry` block; insert `CategorySpendingLegend`. |
| **Create** | `budget/lib/pages/statsPage.dart` | Full-screen Stats tab with period header, Income/Expense switch, pie chart, and legend. |
| **Modify** | `budget/lib/struct/navBarIconsData.dart` | Register `"stats"` icon data pointing to index 18. |
| **Modify** | `budget/lib/widgets/navigationFramework.dart` | Mount `StatsPage` in `pagesExtended` at index 18; verify FAB excludes 18. |
| **Modify** | `budget/lib/widgets/bottomNavBar.dart` | Support 5-item bar (Slots 0..2 shortcuts, Slot 3 Stats, Slot 4 More). |
| **Modify** | `budget/assets/translations/generated/en.json` | Add `"stats": "Stats"` key. |
| **Modify** | `budget/assets/translations/translations.csv` | Add row for `stats,Stats`. |
| **Create** | `budget/test/category_spending_legend_test.dart` | Widget & logic tests for heatmap colors and legend rendering. |

---

## 2. Detailed Technical Specifications by File

### 2.1. `budget/lib/widgets/pieChart.dart`

#### Heatmap Color Generation
Add a top-level helper function:
```dart
Color getSpendingHeatmapColor(int index, int totalCount) {
  if (totalCount <= 1) {
    return const Color(0xFFFF6B6B); // Coral Red
  }
  // Hue sweep from 0 degrees (red/coral) to 160-180 degrees (teal/green)
  final double ratio = index / (totalCount - 1).clamp(1, double.infinity);
  final double hue = ratio * 165.0; // 0.0 (red) -> 40.0 (orange) -> 60.0 (yellow) -> 110.0 (lime) -> 165.0 (teal)
  final double saturation = 0.78;
  final double value = 0.95;
  return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
}
```

#### PieChartSectionData Updates
In `PieChartDisplayState.showingSections()`:
- Determine slice color using `getSpendingHeatmapColor(i, widget.data.length)` instead of `dynamicPastel(...)` with `category.colour`.
- Replace `_Badge` with callout label painting or an offset callout widget:
  ```dart
  final double percent = widget.totalSpent == 0
      ? 0
      : (widget.data[i].total / widget.totalSpent * 100).abs();
  ```
- If `percent < 1.0`, do not render callout text or line (to avoid visual collision).
- Slice touch listener remains intact, notifying `widget.setSelectedCategory(...)`.

#### Callout Line Painting Architecture
Either:
1. **Option A (CustomPaint Overlay):** Wrap the `PieChart` in a `CustomPaint(painter: PieChartCalloutPainter(...))` that draws radial tick lines from each slice center angle outward with an elbow to the category name + percentage text.
2. **Option B (Section Badge Offset):** Use `badgePositionPercentageOffset` (> 1.2) with a `CalloutBadge` widget containing an elbow path `CustomPaint` and text label.
*Recommendation:* **Option A** provides the cleanest line layout, prevents clipping, and matches `docs/expected.jpg` where lines originate at the outer edge of each slice, bend horizontally, and terminate next to the label.

---

### 2.2. `budget/lib/widgets/categorySpendingLegend.dart` (New File)

#### Widget Interface
```dart
class CategorySpendingLegend extends StatelessWidget {
  const CategorySpendingLegend({
    super.key,
    required this.categoriesWithTotal,
    required this.subcategoriesMap,
    required this.totalSpent,
    required this.selectedCategoryPk,
    required this.onCategoryTapped,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  final List<CategoryWithTotal> categoriesWithTotal;
  final Map<String, List<CategoryWithTotal>> subcategoriesMap;
  final double totalSpent;
  final String? selectedCategoryPk;
  final ValueChanged<String?> onCategoryTapped;
  final bool shrinkWrap;
  final ScrollPhysics physics;
```

#### Row Layout & Hierarchy
- Each row represents a category in descending total amount.
- **Left Column:** Heatmap Percentage Pill
  - Dimensions: ~42px width, ~24px height, 6px border radius.
  - Background color: `getSpendingHeatmapColor(index, categoriesWithTotal.length).withOpacity(0.85)`.
  - Content: `TextFont("${percent.round()}%", textColor: Colors.white, fontWeight: FontWeight.bold)`.
- **Center Column:** Category Name
  - `TextFont(category.name, fontSize: 16, fontWeight: FontWeight.w500)`.
- **Right Column:** Formatted Amount
  - `TextFont(convertToMoney(Provider.of<AllWallets>(context), category.total, currencyKey: ...), fontSize: 16, fontWeight: FontWeight.w600)`.
- **Subcategory Accordion:**
  - If `selectedCategoryPk == category.categoryPk`, render subcategories from `subcategoriesMap[category.categoryPk]`.
  - Indented with `Padding(padding: EdgeInsetsDirectional.only(start: 24))`.
  - Smaller percentage pill: `fontSize: 11`, `height: 20`.
  - Subcategory name & amount.
- **Tap Handling:**
  - If tapped category is already selected: call `onCategoryTapped(null)` (collapse accordion and remove pie highlight).
  - Otherwise: call `onCategoryTapped(category.categoryPk)`.

---

### 2.3. `budget/lib/pages/homePage/homePagePieChart.dart`

1. **Remove `TopCategoriesSpentLegend`:**
   - Remove the `TopCategoriesSpentLegend` widget from the layout.
   - Remove the two-column `Row` split inside `LayoutBuilder` in `PieChartHomeAndCategorySummary`.
   - The `PieChartWrapper` now expands cleanly in the center of the card.
2. **Remove Old `CategoryEntry` Drill-Through Block:**
   - Remove `categoryEntries` mapping loop and the `AnimatedSizeSwitcher` / `AnimatedSwitcher` rendering `categoryEntries`.
   - Per user decision: tapping pie slices or legend does not reveal the old `CategoryEntry` card list.
3. **Embed `CategorySpendingLegend`:**
   - Render `CategorySpendingLegend` below `PieChartWrapper`.
   - Pass `s.dataFilterUnassignedTransactions`, `s.subCategorySpendingIndexedByMainCategoryPk`, and `s.totalSpent`.
   - Wire `selectedCategory` to toggle both pie highlight and legend expansion.

---

### 2.4. `budget/lib/pages/statsPage.dart` (New File)

#### Page Layout
```
Scaffold(
  body: CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: StatsPeriodHeader()), // < Month Year > & Period Dropdown
      SliverToBoxAdapter(child: IncomeExpenseToggle()), // Income / Expenses
      SliverToBoxAdapter(child: StatsPieChartView()), // PieChartWrapper with Callouts
      SliverToBoxAdapter(child: CategorySpendingLegend()), // Full Scrollable List
    ],
  ),
)
```

#### Settings & Data Stream
- Independent cycle settings: `cycleSettingsExtension: "StatsPieChart"`.
- Stream: `database.watchTotalSpentInEachCategoryInTimeRangeFromCategories(...)` with `cycleSettingsExtension: "StatsPieChart"`.
- Tab state: `bool isIncome` (default `false` for Expenses).

---

### 2.5. Navigation Integration

#### `budget/lib/struct/navBarIconsData.dart`
Add:
```dart
    "stats": NavBarIconData(
      iconData: appStateSettings["outlinedIcons"]
          ? Icons.bar_chart_outlined
          : Icons.bar_chart_rounded,
      label: "stats",
      navigationIndexedStackIndex: 18,
    ),
```

#### `budget/lib/widgets/navigationFramework.dart`
1. Add `StatsPage` to `pagesExtended` (index 18):
   ```dart
   final List<Widget> pagesExtended = [
     ...
     CreditDebtTransactions(...), // 17
     StatsPage(key: statsPageStateKey), // 18
   ];
   ```
2. FAB Condition:
   Confirm `[0, 1, 2, 14].contains(currentPage)` remains unchanged so FAB is hidden on `StatsPage` (index 18).

#### `budget/lib/widgets/bottomNavBar.dart`
Update the bottom navigation bar to support 5 slots:
- Slot 0: Shortcut 0 (Home)
- Slot 1: Shortcut 1 (Transactions)
- Slot 2: Shortcut 2 (Budgets)
- Slot 3: Stats (Index 18)
- Slot 4: More (Index 3)

Update index mappings:
```dart
int getNavigationStackedIndexFromBarIndex(int barIndex) {
  if (barIndex == 0) return navBarIconsData[appStateSettings["customNavBarShortcut0"]]?.navigationIndexedStackIndex ?? 0;
  if (barIndex == 1) return navBarIconsData[appStateSettings["customNavBarShortcut1"]]?.navigationIndexedStackIndex ?? 1;
  if (barIndex == 2) return navBarIconsData[appStateSettings["customNavBarShortcut2"]]?.navigationIndexedStackIndex ?? 2;
  if (barIndex == 3) return 18; // Stats
  return 3; // More
}

int getNavigationBarIndexFromStackedIndex(int stackedIndex) {
  if (stackedIndex == (navBarIconsData[appStateSettings["customNavBarShortcut0"]]?.navigationIndexedStackIndex ?? 0)) return 0;
  if (stackedIndex == (navBarIconsData[appStateSettings["customNavBarShortcut1"]]?.navigationIndexedStackIndex ?? 1)) return 1;
  if (stackedIndex == (navBarIconsData[appStateSettings["customNavBarShortcut2"]]?.navigationIndexedStackIndex ?? 2)) return 2;
  if (stackedIndex == 18) return 3; // Stats
  return 4; // More
}
```

---

## 3. Testing & Verification Checklist

- [ ] Unit Test `getSpendingHeatmapColor`:
  - 1 category returns primary coral/red.
  - 5 categories produce expected sweep across red -> orange -> yellow -> lime -> teal.
- [ ] Widget Test `CategorySpendingLegend`:
  - Verify all categories display correct percentage and formatted amount.
  - Verify tapping a row triggers callback and expands subcategory items.
  - Verify tapping an already-expanded row collapses subcategories.
- [ ] Run `flutter analyze` inside `./budget/` — zero errors or warnings.
- [ ] Run `dart format --output=none --set-exit-if-changed .` inside `./budget/`.
- [ ] Ensure Git author is `kidomarcostelo@gmail.com`.
- [ ] No `Co-authored-by` trailers in commits.
