import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/pieChart.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<CategoryWithTotal> categoriesWithTotal;
  final Map<String, List<CategoryWithTotal>> subcategoriesMap;
  final double totalSpent;
  final String? selectedCategoryPk;
  final ValueChanged<String?> onCategoryTapped;
  final bool shrinkWrap;
  final ScrollPhysics physics;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (categoriesWithTotal.isEmpty) {
      return const SizedBox.shrink();
    }

    final allWallets = Provider.of<AllWallets>(context);

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      itemCount: categoriesWithTotal.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.8,
        color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
      ),
      itemBuilder: (context, index) {
        final categoryWithTotal = categoriesWithTotal[index];
        final category = categoryWithTotal.category;
        final bool isSelected = selectedCategoryPk == category.categoryPk;
        final double percent = totalSpent == 0
            ? 0
            : (categoryWithTotal.totalMagnitude / totalSpent.abs() * 100);
        final Color pillColor =
            getSpendingHeatmapColor(index, categoriesWithTotal.length);
        final List<CategoryWithTotal> subcategories =
            subcategoriesMap[category.categoryPk] ?? [];

        return _CategorySpendingRow(
          categoryWithTotal: categoryWithTotal,
          percent: percent,
          pillColor: pillColor,
          isSelected: isSelected,
          subcategories: subcategories,
          totalSpent: totalSpent,
          allWallets: allWallets,
          onTap: () {
            if (isSelected) {
              onCategoryTapped(null);
            } else {
              onCategoryTapped(category.categoryPk);
            }
          },
        );
      },
    );
  }
}

class _CategorySpendingRow extends StatelessWidget {
  const _CategorySpendingRow({
    required this.categoryWithTotal,
    required this.percent,
    required this.pillColor,
    required this.isSelected,
    required this.subcategories,
    required this.totalSpent,
    required this.allWallets,
    required this.onTap,
  });

  final CategoryWithTotal categoryWithTotal;
  final double percent;
  final Color pillColor;
  final bool isSelected;
  final List<CategoryWithTotal> subcategories;
  final double totalSpent;
  final AllWallets allWallets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = categoryWithTotal.category;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color:
                  isSelected ? pillColor.withOpacity(0.08) : Colors.transparent,
            ),
            child: Row(
              children: [
                // Percentage pill
                Container(
                  width: 44,
                  height: 24,
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: TextFont(
                    text: "${percent.round()}%",
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    textColor: Colors.black.withOpacity(0.85),
                  ),
                ),
                const SizedBox(width: 14),
                // Category name
                Expanded(
                  child: TextFont(
                    text: category.name,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 10),
                // Formatted amount
                TextFont(
                  text: convertToMoney(
                      allWallets, categoryWithTotal.totalMagnitude),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                if (subcategories.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Icon(
                    isSelected
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Subcategory Accordion Expansion
        if (isSelected && subcategories.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(
                start: 24, end: 8, bottom: 8, top: 2),
            child: Column(
              children: subcategories.map((sub) {
                final double subPercent = totalSpent == 0
                    ? 0
                    : (sub.totalMagnitude / totalSpent.abs() * 100);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 20,
                        decoration: BoxDecoration(
                          color: pillColor.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: TextFont(
                          text: "${subPercent.round()}%",
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          textColor: Colors.black.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFont(
                          text: sub.category.name,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextFont(
                        text: convertToMoney(allWallets, sub.totalMagnitude),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
