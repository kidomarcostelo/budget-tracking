import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/spendingSummaryHelper.dart';
import 'package:budget/widgets/categorySpendingLegend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final defaultWallet = TransactionWallet(
    walletPk: '0',
    name: 'Main Wallet',
    currency: 'USD',
    decimals: 2,
    dateCreated: DateTime(2025, 1, 1),
    order: 0,
  );

  final testAllWallets = AllWallets(
    list: [defaultWallet],
    indexedByPk: {'0': defaultWallet},
  );

  TransactionCategory createCategory({
    required String pk,
    required String name,
    String? mainCategoryPk,
    bool isIncome = false,
  }) {
    return TransactionCategory(
      categoryPk: pk,
      name: name,
      dateCreated: DateTime(2025, 1, 1),
      order: 0,
      income: isIncome,
      mainCategoryPk: mainCategoryPk,
    );
  }

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Provider<AllWallets>.value(
          value: testAllWallets,
          child: child,
        ),
      ),
    );
  }

  group('Stats Category Spending & Pie Chart Regression Tests', () {
    test(
        'Main category total rolls up all subcategories without being 0, and subcategories are not top-level pie slices',
        () {
      final mainCat = createCategory(pk: 'cat-food', name: 'Food');
      final subCat1 = createCategory(
        pk: 'sub-groceries',
        name: 'Groceries',
        mainCategoryPk: 'cat-food',
      );
      final subCat2 = createCategory(
        pk: 'sub-dining',
        name: 'Dining Out',
        mainCategoryPk: 'cat-food',
      );

      final dataInput = [
        CategoryWithTotal(category: mainCat, total: -200),
        CategoryWithTotal(category: subCat1, total: -120),
        CategoryWithTotal(category: subCat2, total: -80),
      ];

      // Fix: statsPage passes showAllSubcategories: false
      final TotalSpentCategoriesSummary summary =
          watchTotalSpentInTimeRangeHelper(
        dataInput: dataInput,
        showAllSubcategories: false,
        multiplyTotalBy: 1,
        absoluteTotal: true,
      );

      // Verify Bug 1 Fix: Main category total must be 200 (not 0)
      final mainCatEntry = summary.dataFilterUnassignedTransactions.firstWhere(
        (c) => c.category.categoryPk == 'cat-food',
      );
      expect(mainCatEntry.total.abs(), equals(200.0));

      // Verify Bug 3 Fix: Only main category should be in the top-level pie slices list (length == 1)
      expect(summary.dataFilterUnassignedTransactions.length, equals(1));
      expect(
        summary.dataFilterUnassignedTransactions
            .any((c) => c.category.mainCategoryPk != null),
        isFalse,
      );

      // Subcategories are indexed for the legend accordion
      expect(
          summary
              .subCategorySpendingIndexedByMainCategoryPk['cat-food']?.length,
          equals(2));
    });

    testWidgets(
        'CategorySpendingLegend displays positive monetary values without negative symbols',
        (WidgetTester tester) async {
      final mainCat = createCategory(pk: 'cat-food', name: 'Food');
      final subCat1 = createCategory(
        pk: 'sub-groceries',
        name: 'Groceries',
        mainCategoryPk: 'cat-food',
      );

      final categoriesWithTotal = [
        CategoryWithTotal(category: mainCat, total: -200),
      ];
      final subcategoriesMap = {
        'cat-food': [
          CategoryWithTotal(category: subCat1, total: -120),
        ],
      };

      await tester.pumpWidget(
        buildTestableWidget(
          CategorySpendingLegend(
            categoriesWithTotal: categoriesWithTotal,
            subcategoriesMap: subcategoriesMap,
            totalSpent: 200,
            selectedCategoryPk: 'cat-food',
            onCategoryTapped: (_) {},
          ),
        ),
      );

      // Verify Bug 2 Fix: No negative symbol should be present on main or subcategory amounts
      expect(find.textContaining('-'), findsNothing);
      expect(find.textContaining('200'), findsOneWidget);
      expect(find.textContaining('120'), findsOneWidget);
    });
  });
}
