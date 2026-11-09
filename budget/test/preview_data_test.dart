import 'dart:ffi';
import 'package:budget/database/generatePreviewData.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/defaultPreferences.dart';
import 'package:budget/struct/settings.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

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

  group('Preview Data Generation and Teardown Tests', () {
    late FinanceDatabase testDb;

    setUp(() async {
      testDb = FinanceDatabase(NativeDatabase.memory());
      database = testDb;

      final defaults = await getDefaultPreferences();
      appStateSettings.clear();
      appStateSettings.addAll(defaults);
      appStateSettings['appAnimations'] = 0;
    });

    tearDown(() async {
      await testDb.close();
    });

    test(
        'generatePreviewData creates Philippine banks, budgets, objectives, and samples',
        () async {
      await generatePreviewData();

      // 1. Verify Preferences
      expect(appStateSettings['previewDemo'], isTrue);
      expect(appStateSettings['accountOwnerName'], equals('Kid Omar Costelo'));

      // 2. Verify Wallets
      final wallets = await testDb.getAllWallets();
      final Map<String, TransactionWallet> walletByPk = {
        for (final w in wallets) w.walletPk: w,
      };

      expect(walletByPk.containsKey('0'), isTrue);
      expect(walletByPk['0']!.name, equals('UnionBank'));
      expect(walletByPk['0']!.currency, equals('php'));
      expect(walletByPk['0']!.colour, equals('0xffff7900'));
      expect(walletByPk['0']!.iconName, equals('bank.png'));

      expect(walletByPk.containsKey('10'), isTrue);
      expect(walletByPk['10']!.name, equals('MariBank'));
      expect(walletByPk['10']!.currency, equals('php'));
      expect(walletByPk['10']!.colour, equals('0xfffa5a2a'));
      expect(walletByPk['10']!.iconName, equals('wallet.png'));

      expect(walletByPk.containsKey('11'), isTrue);
      expect(walletByPk['11']!.name, equals('GoTyme'));
      expect(walletByPk['11']!.currency, equals('php'));
      expect(walletByPk['11']!.colour, equals('0xff00d084'));
      expect(walletByPk['11']!.iconName, equals('credit-card.png'));

      expect(walletByPk.containsKey('12'), isTrue);
      expect(walletByPk['12']!.name, equals('Maya'));
      expect(walletByPk['12']!.currency, equals('php'));
      expect(walletByPk['12']!.colour, equals('0xff2bb673'));
      expect(walletByPk['12']!.iconName, equals('cards.png'));

      // 3. Verify Budgets
      final budgets = await testDb.getAllBudgets();
      final Map<String, Budget> budgetByPk = {
        for (final b in budgets) b.budgetPk: b,
      };
      expect(budgetByPk.containsKey('10'), isTrue);
      expect(budgetByPk['10']!.name, equals('Vacation'));
      expect(budgetByPk['10']!.amount, equals(25000.0));

      expect(budgetByPk.containsKey('11'), isTrue);
      expect(budgetByPk['11']!.name, equals('Monthly Spending'));
      expect(budgetByPk['11']!.amount, equals(35000.0));

      // 4. Verify Objectives
      final objectives = await testDb.getAllObjectivesWithoutType();
      final Map<String, Objective> objectiveByPk = {
        for (final o in objectives) o.objectivePk: o,
      };
      expect(objectiveByPk.containsKey('10'), isTrue);
      expect(objectiveByPk['10']!.name, equals('Emergency Fund'));
      expect(objectiveByPk['10']!.amount, equals(50000.0));
      expect(objectiveByPk['10']!.walletFk, equals('10'));

      expect(objectiveByPk.containsKey('11'), isTrue);
      expect(objectiveByPk['11']!.name, equals('Trip Savings Jar'));
      expect(objectiveByPk['11']!.amount, equals(20000.0));

      // 5. Verify Preview Transactions
      final previewTxs = await testDb.getAllPreviewTransactions();
      expect(previewTxs.isNotEmpty, isTrue);

      // Verify all preview transactions have MethodAdded.preview
      for (final tx in previewTxs) {
        expect(tx.methodAdded, equals(MethodAdded.preview));
      }

      // Check specific verified merchant transactions
      final has7Eleven = previewTxs.any((t) =>
          t.name == '7-Eleven' && t.amount == -123.0 && t.walletFk == '0');
      expect(has7Eleven, isTrue);

      final hasStarbucks = previewTxs.any((t) =>
          t.name == 'Starbucks Coffee' &&
          t.amount == -185.0 &&
          t.walletFk == '0');
      expect(hasStarbucks, isTrue);

      final hasGrabFood = previewTxs.any((t) =>
          t.name == 'GrabFood' && t.amount == -340.0 && t.walletFk == '0');
      expect(hasGrabFood, isTrue);

      final hasShopee = previewTxs.any((t) =>
          t.name == 'Shopee' && t.amount == -890.0 && t.walletFk == '10');
      expect(hasShopee, isTrue);

      final hasMercuryDrug = previewTxs.any((t) =>
          t.name == 'Mercury Drug' && t.amount == -450.0 && t.walletFk == '11');
      expect(hasMercuryDrug, isTrue);

      final hasGrabCar = previewTxs.any((t) =>
          t.name == 'GrabCar' && t.amount == -280.0 && t.walletFk == '12');
      expect(hasGrabCar, isTrue);

      final hasMeralco = previewTxs.any((t) =>
          t.name == 'Meralco Electricity' &&
          t.amount == -3450.0 &&
          t.walletFk == '0');
      expect(hasMeralco, isTrue);

      final hasConverge = previewTxs.any((t) =>
          t.name == 'Converge Fiber Internet' &&
          t.amount == -1699.0 &&
          t.walletFk == '0');
      expect(hasConverge, isTrue);

      final hasSalary = previewTxs.any((t) =>
          t.name == 'Payroll' && t.amount == 45000.0 && t.walletFk == '0');
      expect(hasSalary, isTrue);

      final hasNetflix = previewTxs.any((t) =>
          t.name == 'Netflix Subscription' &&
          t.amount == -549.0 &&
          t.walletFk == '12' &&
          t.type == TransactionSpecialType.subscription);
      expect(hasNetflix, isTrue);

      // Verify paired self-transfers
      final ubOut = previewTxs.firstWhere(
        (t) => t.name == 'UnionBank transfer-out' && t.amount == -15000.0,
      );
      expect(ubOut.walletFk, equals('0'));
      expect(ubOut.pairedTransactionFk, isNotNull);

      final mbIn = previewTxs.firstWhere(
        (t) => t.name == 'MariBank transfer-in' && t.amount == 15000.0,
      );
      expect(mbIn.walletFk, equals('10'));
      expect(ubOut.pairedTransactionFk, equals(mbIn.transactionPk));

      final mbOut = previewTxs.firstWhere(
        (t) => t.name == 'MariBank transfer-out' && t.amount == -1000.0,
      );
      expect(mbOut.walletFk, equals('10'));
      expect(mbOut.pairedTransactionFk, isNotNull);

      final mayaIn = previewTxs.firstWhere(
        (t) => t.name == 'Maya transfer-in' && t.amount == 1000.0,
      );
      expect(mayaIn.walletFk, equals('12'));
      expect(mbOut.pairedTransactionFk, equals(mayaIn.transactionPk));

      final gtOut = previewTxs.firstWhere(
        (t) => t.name == 'GoTyme transfer-out' && t.amount == -3600.0,
      );
      expect(gtOut.walletFk, equals('11'));
      expect(gtOut.pairedTransactionFk, isNotNull);

      final mbFromGt = previewTxs.firstWhere(
        (t) => t.name == 'MariBank transfer-in' && t.amount == 3600.0,
      );
      expect(mbFromGt.walletFk, equals('10'));
      expect(gtOut.pairedTransactionFk, equals(mbFromGt.transactionPk));
    });

    test(
        'deletePreviewData cleanly removes all preview wallets, budgets, and transactions',
        () async {
      await generatePreviewData();

      // Verify preview data exists
      expect((await testDb.getAllPreviewTransactions()).isNotEmpty, isTrue);
      expect((await testDb.getAllWallets()).length, equals(4));

      // Run teardown
      await deletePreviewData();

      // 1. Preview transactions purged
      final remainingPreviewTxs = await testDb.getAllPreviewTransactions();
      expect(remainingPreviewTxs.isEmpty, isTrue);

      // 2. Preview wallets deleted ("10", "11", "12")
      final remainingWallets = await testDb.getAllWallets();
      final remainingPks = remainingWallets.map((w) => w.walletPk).toList();
      expect(remainingPks.contains('10'), isFalse);
      expect(remainingPks.contains('11'), isFalse);
      expect(remainingPks.contains('12'), isFalse);

      // 3. Primary wallet "0" restored
      expect(remainingPks.contains('0'), isTrue);

      // 4. Budgets and objectives deleted
      final remainingBudgets = await testDb.getAllBudgets();
      expect(
          remainingBudgets.any((b) => b.budgetPk == '10' || b.budgetPk == '11'),
          isFalse);

      final remainingObjectives = await testDb.getAllObjectivesWithoutType();
      expect(
          remainingObjectives
              .any((o) => o.objectivePk == '10' || o.objectivePk == '11'),
          isFalse);

      // 5. Settings restored
      expect(appStateSettings['previewDemo'], isFalse);
      expect(appStateSettings['accountOwnerName'], isEmpty);
    });

    test('deletePreviewData restores preexisting accountOwnerName setting',
        () async {
      appStateSettings['accountOwnerName'] = 'Juan Dela Cruz';
      await generatePreviewData();
      expect(appStateSettings['accountOwnerName'], equals('Kid Omar Costelo'));

      await deletePreviewData();
      expect(appStateSettings['accountOwnerName'], equals('Juan Dela Cruz'));
      expect(appStateSettings['previewDemo'], isFalse);
    });
  });
}
