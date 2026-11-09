import 'dart:ffi';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/defaultPreferences.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/util/appLinks.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions, Value;
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

Future<void> popToHome(WidgetTester tester) async {
  while (navigatorKey.currentState?.canPop() == true) {
    navigatorKey.currentState?.pop();
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 20));
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

  group('Parameter Alias & Parsing Helpers Unit Tests', () {
    test('resolves title and name aliases, falling back if primary is empty',
        () {
      expect(getTitleFromParams({'title': 'Coffee'}), equals('Coffee'));
      expect(getTitleFromParams({'name': 'Coffee'}), equals('Coffee'));
      expect(getTitleFromParams({'title': '', 'name': 'Coffee'}),
          equals('Coffee'));
      expect(getTitleFromParams({'title': '   ', 'name': 'Coffee'}),
          equals('Coffee'));
      expect(getTitleFromParams({}), isNull);
    });

    test('resolves note and notes aliases, falling back if primary is empty',
        () {
      expect(getNotesFromParams({'note': 'Ref #123'}), equals('Ref #123'));
      expect(getNotesFromParams({'notes': 'Ref #123'}), equals('Ref #123'));
      expect(getNotesFromParams({'note': '', 'notes': 'Ref #123'}),
          equals('Ref #123'));
      expect(getNotesFromParams({'note': '   ', 'notes': 'Ref #123'}),
          equals('Ref #123'));
      expect(getNotesFromParams({}), isNull);
    });

    test('parses income and type parameters', () {
      expect(getIncomeFromParams({'income': 'true'}), isTrue);
      expect(getIncomeFromParams({'income': '1'}), isTrue);
      expect(getIncomeFromParams({'type': 'income'}), isTrue);
      expect(getIncomeFromParams({'type': 'expense'}), isFalse);
      expect(getIncomeFromParams({}), isNull);
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
      expect(getAmountFromParams({'amount': r' $45.99 '}), equals(45.99));
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
      appStateSettings['appAnimations'] = AppAnimations.disabled.index;
      appStateSettings['askForTransactionTitle'] = true;

      // Seed a wallet and a category
      await testDb.into(testDb.wallets).insert(
            WalletsCompanion.insert(
              walletPk: const Value('wallet-unionbank'),
              name: 'UnionBank',
              colour: const Value('0xFF0000'),
              dateCreated: Value(DateTime.now()),
              order: 0,
              currency: const Value('PHP'),
            ),
          );

      await testDb.into(testDb.categories).insert(
            CategoriesCompanion.insert(
              categoryPk: const Value('cat-dining'),
              name: 'Dining',
              colour: const Value('0xFF0000'),
              iconName: const Value(null),
              dateCreated: Value(DateTime.now()),
              order: 0,
              income: const Value(false),
            ),
          );

      final walletsList = await testDb.getAllWallets();
      final Map<String, TransactionWallet> indexedByPk = {
        for (final w in walletsList) w.walletPk: w,
      };
      allWallets = AllWallets(list: walletsList, indexedByPk: indexedByPk);
    });

    tearDown(() async {
      while (navigatorKey.currentState?.canPop() == true) {
        navigatorKey.currentState?.pop();
      }
      await testDb.close();
    });

    Future<void> runRouteTest(
      WidgetTester tester, {
      required Map<String, String?> params,
      required Future<void> Function(AddTransactionPage page) verify,
    }) async {
      await tester.runAsync(() async {
        try {
          await tester.pumpWidget(buildTestApp(allWallets: allWallets));
          await tester.pumpAndSettle();

          final context = navigatorKey.currentContext!;
          await processAddTransactionRouteFromParams(context, params);
          await tester.pumpAndSettle();

          final addTxFinder = find.byType(AddTransactionPage);
          expect(addTxFinder, findsOneWidget);
          final addTxWidget = tester.widget<AddTransactionPage>(addTxFinder);

          await verify(addTxWidget);
        } finally {
          await popToHome(tester);
        }
      });
    }

    testWidgets(
        'prefilled route sets startInitialAddTransactionSequence to false and pre-fills all fields',
        (WidgetTester tester) async {
      await runRouteTest(
        tester,
        params: {
          'title': 'GrabFood',
          'amount': '340.00',
          'note': 'UnionBank Debit •••• 5678',
          'wallet': 'UnionBank',
          'category': 'Dining',
        },
        verify: (addTxWidget) async {
          expect(addTxWidget.selectedTitle, equals('GrabFood'));
          expect(addTxWidget.selectedAmount, equals(340.0));
          expect(
              addTxWidget.selectedNotes, equals('UnionBank Debit •••• 5678'));
          expect(addTxWidget.selectedWallet?.name, equals('UnionBank'));
          expect(addTxWidget.selectedCategory?.name, equals('Dining'));

          // Verify blocking title wizard is disabled
          expect(addTxWidget.startInitialAddTransactionSequence, isFalse);
          expect(addTxWidget.useCategorySelectedIncome, isTrue);

          // Modal bottom sheet SelectTitle should NOT be open
          expect(find.byType(SelectTitle), findsNothing);
        },
      );
    });

    testWidgets('supports name alias and notes alias',
        (WidgetTester tester) async {
      await runRouteTest(
        tester,
        params: {
          'name': 'Jollibee',
          'amount': '150.00',
          'notes': 'Takeout lunch',
        },
        verify: (addTxWidget) async {
          expect(addTxWidget.selectedTitle, equals('Jollibee'));
          expect(addTxWidget.selectedNotes, equals('Takeout lunch'));
          expect(addTxWidget.startInitialAddTransactionSequence, isFalse);
        },
      );
    });

    testWidgets(
        'empty params leaves startInitialAddTransactionSequence as true',
        (WidgetTester tester) async {
      await runRouteTest(
        tester,
        params: {},
        verify: (addTxWidget) async {
          expect(addTxWidget.startInitialAddTransactionSequence, isTrue);
        },
      );
    });
  });
}
