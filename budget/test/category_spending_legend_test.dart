import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
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
    dateCreated: DateTime(2025, 1, 1),
    order: 0,
  );

  final testAllWallets = AllWallets(
    list: [defaultWallet],
    indexedByPk: {'0': defaultWallet},
  );

  TransactionCategory createTestCategory({
    required String pk,
    required String name,
    String? mainCategoryPk,
  }) {
    return TransactionCategory(
      categoryPk: pk,
      name: name,
      dateCreated: DateTime(2025, 1, 1),
      order: 0,
      income: false,
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

  group('CategorySpendingLegend Widget', () {
    testWidgets('renders empty widget when categoriesWithTotal is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          CategorySpendingLegend(
            categoriesWithTotal: const [],
            subcategoriesMap: const {},
            totalSpent: 0,
            selectedCategoryPk: null,
            onCategoryTapped: (_) {},
          ),
        ),
      );

      expect(find.byType(CategorySpendingLegend), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders category rows with percentage, name, and total',
        (WidgetTester tester) async {
      final cat1 = createTestCategory(pk: 'cat-1', name: 'Rent');
      final cat2 = createTestCategory(pk: 'cat-2', name: 'Food');

      final categories = [
        CategoryWithTotal(category: cat1, total: 800),
        CategoryWithTotal(category: cat2, total: 200),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          CategorySpendingLegend(
            categoriesWithTotal: categories,
            subcategoriesMap: const {},
            totalSpent: 1000,
            selectedCategoryPk: null,
            onCategoryTapped: (_) {},
          ),
        ),
      );

      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    });

    testWidgets('tapping unselected row calls onCategoryTapped with categoryPk',
        (WidgetTester tester) async {
      final cat1 = createTestCategory(pk: 'cat-1', name: 'Rent');
      String? tappedPk;

      await tester.pumpWidget(
        buildTestableWidget(
          CategorySpendingLegend(
            categoriesWithTotal: [CategoryWithTotal(category: cat1, total: 500)],
            subcategoriesMap: const {},
            totalSpent: 500,
            selectedCategoryPk: null,
            onCategoryTapped: (pk) => tappedPk = pk,
          ),
        ),
      );

      await tester.tap(find.text('Rent'));
      expect(tappedPk, equals('cat-1'));
    });

    testWidgets('tapping selected row calls onCategoryTapped with null (collapse)',
        (WidgetTester tester) async {
      final cat1 = createTestCategory(pk: 'cat-1', name: 'Rent');
      String? tappedPk = 'init';

      await tester.pumpWidget(
        buildTestableWidget(
          CategorySpendingLegend(
            categoriesWithTotal: [CategoryWithTotal(category: cat1, total: 500)],
            subcategoriesMap: const {},
            totalSpent: 500,
            selectedCategoryPk: 'cat-1',
            onCategoryTapped: (pk) => tappedPk = pk,
          ),
        ),
      );

      await tester.tap(find.text('Rent'));
      expect(tappedPk, isNull);
    });

    testWidgets('expands subcategories accordion when selectedCategoryPk matches',
        (WidgetTester tester) async {
      final mainCat = createTestCategory(pk: 'cat-food', name: 'Food');
      final subCat1 = createTestCategory(
          pk: 'sub-groceries', name: 'Groceries', mainCategoryPk: 'cat-food');
      final subCat2 = createTestCategory(
          pk: 'sub-dining', name: 'Dining Out', mainCategoryPk: 'cat-food');

      final categories = [
        CategoryWithTotal(category: mainCat, total: 500),
      ];
      final subcategoriesMap = {
        'cat-food': [
          CategoryWithTotal(category: subCat1, total: 350),
          CategoryWithTotal(category: subCat2, total: 150),
        ],
      };

      // 1. Unselected -> subcategories are NOT visible
      await tester.pumpWidget(
        buildTestableWidget(
          CategorySpendingLegend(
            categoriesWithTotal: categories,
            subcategoriesMap: subcategoriesMap,
            totalSpent: 500,
            selectedCategoryPk: null,
            onCategoryTapped: (_) {},
          ),
        ),
      );

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
      expect(find.text('Dining Out'), findsNothing);

      // 2. Selected -> subcategories expand and are visible
      await tester.pumpWidget(
        buildTestableWidget(
          CategorySpendingLegend(
            categoriesWithTotal: categories,
            subcategoriesMap: subcategoriesMap,
            totalSpent: 500,
            selectedCategoryPk: 'cat-food',
            onCategoryTapped: (_) {},
          ),
        ),
      );

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Dining Out'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget); // 350 / 500 = 70%
      expect(find.text('30%'), findsOneWidget); // 150 / 500 = 30%
    });
  });
}
