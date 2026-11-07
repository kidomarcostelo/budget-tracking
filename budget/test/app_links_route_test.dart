import 'dart:ffi';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/defaultPreferences.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/util/appLinks.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'add-transaction': 'Add Transaction',
      'edit-transaction': 'Edit Transaction',
      'save-changes': 'Save Changes',
      'enter-amount': 'Enter Amount',
      'select-category': 'Select Category',
      'notes-placeholder': 'Notes',
    };
  }
}

Widget buildTestApp({
  required AllWallets allWallets,
  Widget? home,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('en')],
    path: 'test',
    assetLoader: const _TestAssetLoader(),
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    child: Builder(
      builder: (context) => MultiProvider(
        providers: [
          Provider<AllWallets>.value(value: allWallets),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: home ??
              const Scaffold(
                body: Center(
                  child: Text('Home'),
                ),
              ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });
  });

  group('getAmountFromParams Unit Tests', () {
    test('parses decimal amount correctly', () {
      expect(getAmountFromParams({'amount': '340.00'}), equals(340.0));
    });

    test('parses integer amount correctly', () {
      expect(getAmountFromParams({'amount': '150'}), equals(150.0));
    });

    test('parses formatted amount with currency and commas', () {
      expect(getAmountFromParams({'amount': '₱340.00'}), equals(340.0));
      expect(getAmountFromParams({'amount': '1,250.50'}), equals(1250.5));
      expect(getAmountFromParams({'amount': ' $45.99 '}), equals(45.99));
    });

    test('returns 0 for missing or invalid amount', () {
      expect(getAmountFromParams({}), equals(0.0));
      expect(getAmountFromParams({'amount': ''}), equals(0.0));
      expect(getAmountFromParams({'amount': 'abc'}), equals(0.0));
    });
  });

  group('processAddTransactionRouteFromParams Route Tests', () {
    late FinanceDatabase testDb;
    late AllWallets allWallets;

    setUp(() async {
      testDb = FinanceDatabase(NativeDatabase.memory());
      database = testDb;

      final defaults = await getDefaultPreferences();
      appStateSettings.clear();
      appStateSettings.addAll(defaults);
      appStateSettings['askForTransactionTitle'] = true;

      // Seed a wallet and a category
      await testDb.into(testDb.wallets).insert(
            WalletsCompanion.insert(
              walletPk: 'wallet-unionbank',
              name: 'UnionBank',
              colour: '0xFF0000',
              dateCreated: DateTime.now(),
              currency: const Value('PHP'),
            ),
          );

      await testDb.into(testDb.categories).insert(
            CategoriesCompanion.insert(
              categoryPk: 'cat-dining',
              name: 'Dining',
              colour: '0xFF0000',
              iconName: 'fastfood',
              dateCreated: DateTime.now(),
              income: const Value(false),
            ),
          );

      final walletsList = await testDb.getAllWallets();
      allWallets = AllWallets();
      for (final w in walletsList) {
        allWallets.indexedByPk[w.walletPk] = w;
      }
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets(
        'prefilled route sets startInitialAddTransactionSequence to false and pre-fills all fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(allWallets: allWallets));
      await tester.pumpAndSettle();

      final context = navigatorKey.currentContext!;

      // Execute route with prefilled parameters (including singular note and Dining category)
      await processAddTransactionRouteFromParams(context, {
        'title': 'GrabFood',
        'amount': '340.00',
        'note': 'UnionBank Debit •••• 5678',
        'wallet': 'UnionBank',
        'category': 'Dining',
      });

      // Pump through the 50ms delay
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify AddTransactionPage is rendered
      final addTxFinder = find.byType(AddTransactionPage);
      expect(addTxFinder, findsOneWidget);

      final addTxWidget = tester.widget<AddTransactionPage>(addTxFinder);

      // Verify prefilled data
      expect(addTxWidget.selectedTitle, equals('GrabFood'));
      expect(addTxWidget.selectedAmount, equals(340.0));
      expect(addTxWidget.selectedNotes, equals('UnionBank Debit •••• 5678'));
      expect(addTxWidget.selectedWallet?.name, equals('UnionBank'));
      expect(addTxWidget.selectedCategory?.name, equals('Dining'));

      // Verify blocking title wizard is disabled
      expect(addTxWidget.startInitialAddTransactionSequence, isFalse);
      expect(addTxWidget.useCategorySelectedIncome, isTrue);

      // Modal bottom sheet SelectTitle should NOT be open
      expect(find.byType(SelectTitle), findsNothing);
    });

    testWidgets('supports name alias and notes alias',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(allWallets: allWallets));
      await tester.pumpAndSettle();

      final context = navigatorKey.currentContext!;

      await processAddTransactionRouteFromParams(context, {
        'name': 'Jollibee',
        'amount': '150.00',
        'notes': 'Takeout lunch',
      });

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final addTxFinder = find.byType(AddTransactionPage);
      expect(addTxFinder, findsOneWidget);

      final addTxWidget = tester.widget<AddTransactionPage>(addTxFinder);
      expect(addTxWidget.selectedTitle, equals('Jollibee'));
      expect(addTxWidget.selectedNotes, equals('Takeout lunch'));
      expect(addTxWidget.startInitialAddTransactionSequence, isFalse);
    });

    testWidgets(
        'empty params leaves startInitialAddTransactionSequence as true',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(allWallets: allWallets));
      await tester.pumpAndSettle();

      final context = navigatorKey.currentContext!;

      await processAddTransactionRouteFromParams(context, {});

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final addTxFinder = find.byType(AddTransactionPage);
      expect(addTxFinder, findsOneWidget);

      final addTxWidget = tester.widget<AddTransactionPage>(addTxFinder);
      expect(addTxWidget.startInitialAddTransactionSequence, isTrue);
    });
  });
}
