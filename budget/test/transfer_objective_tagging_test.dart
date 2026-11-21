import 'dart:ffi';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/addWalletPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });
  });

  group('createCorrectionTransaction & Transfer Objective Tagging (BT-0021)',
      () {
    late FinanceDatabase testDb;

    final payrollWallet = TransactionWallet(
      walletPk: 'wallet-payroll',
      name: 'Payroll Account',
      colour: '0xff000000',
      dateCreated: DateTime(2026, 1, 1),
      order: 0,
      currency: 'PHP',
      decimals: 2,
    );

    final efWallet = TransactionWallet(
      walletPk: 'wallet-ef',
      name: 'Emergency Fund',
      colour: '0xff00ff00',
      dateCreated: DateTime(2026, 1, 1),
      order: 1,
      currency: 'PHP',
      decimals: 2,
    );

    final allWallets = AllWallets(
      list: [payrollWallet, efWallet],
      indexedByPk: {
        'wallet-payroll': payrollWallet,
        'wallet-ef': efWallet,
      },
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      appStateSettings["selectedWalletPk"] = 'wallet-payroll';
      appStateSettings["sharedBudgets"] = false;
      appStateSettings["outlinedIcons"] = true;

      testDb = FinanceDatabase(NativeDatabase.memory());
      database = testDb;

      await testDb.createOrUpdateWallet(payrollWallet, insert: true);
      await testDb.createOrUpdateWallet(efWallet, insert: true);
    });

    tearDown(() async {
      await testDb.close();
    });

    test(
        'createCorrectionTransaction sets objectiveFk when objectivePk is provided',
        () async {
      final txPk = await createCorrectionTransaction(
        8000.0,
        efWallet,
        note: 'Transfer in',
        title: 'Emergency Fund transfer-in',
        objectivePk: 'obj-emergency-fund',
      );

      expect(txPk, isNotNull);
      final createdTx = await testDb.getTransactionFromPk(txPk!);
      expect(createdTx.amount, 8000.0);
      expect(createdTx.categoryFk, '0');
      expect(createdTx.walletFk, 'wallet-ef');
      expect(createdTx.objectiveFk, 'obj-emergency-fund');
      expect(createdTx.objectiveLoanFk, isNull);
      expect(createdTx.income, isTrue);
    });

    test('createCorrectionTransaction leaves objectiveFk null when omitted',
        () async {
      final txPk = await createCorrectionTransaction(
        -8000.0,
        payrollWallet,
        note: 'Transfer out',
        title: 'Payroll Account transfer-out',
      );

      expect(txPk, isNotNull);
      final createdTx = await testDb.getTransactionFromPk(txPk!);
      expect(createdTx.amount, -8000.0);
      expect(createdTx.categoryFk, '0');
      expect(createdTx.walletFk, 'wallet-payroll');
      expect(createdTx.objectiveFk, isNull);
      expect(createdTx.objectiveLoanFk, isNull);
      expect(createdTx.income, isFalse);
    });

    test('createCorrectionTransaction sets objectiveLoanFk when provided',
        () async {
      final txPk = await createCorrectionTransaction(
        500.0,
        efWallet,
        objectiveLoanPk: 'loan-123',
      );

      expect(txPk, isNotNull);
      final createdTx = await testDb.getTransactionFromPk(txPk!);
      expect(createdTx.objectiveLoanFk, 'loan-123');
      expect(createdTx.objectiveFk, isNull);
    });

    test(
        'createCorrectionTransaction cleanses mutually exclusive objectiveLoanFk and objectiveFk per schema invariants',
        () async {
      final txPk = await createCorrectionTransaction(
        500.0,
        efWallet,
        objectiveLoanPk: 'loan-123',
        objectivePk: 'obj-456',
      );

      expect(txPk, isNotNull);
      final createdTx = await testDb.getTransactionFromPk(txPk!);
      // tables.dart cleanseTransactionForLongTermLoan ensures loan and savings objective are mutually exclusive
      expect(createdTx.objectiveLoanFk, 'loan-123');
      expect(createdTx.objectiveFk, isNull);
    });

    test(
        'watchTotalTowardsObjective counts balance corrections with categoryFk "0" when objectiveFk matches',
        () async {
      final objective = Objective(
        objectivePk: 'obj-emergency-fund',
        type: ObjectiveType.goal,
        name: 'Emergency Fund',
        amount: 48000.0,
        order: 0,
        dateCreated: DateTime(2026, 1, 1),
        income: false,
        pinned: true,
        archived: false,
        walletFk: 'wallet-ef',
      );

      await testDb.createOrUpdateObjective(objective, insert: true);

      // Verify baseline is 0
      final initialTotal =
          await testDb.watchTotalTowardsObjective(allWallets, objective).first;
      expect(initialTotal, 0.0);

      // Create a balance correction transfer transaction tagged to this objective
      await createCorrectionTransaction(
        8000.0,
        efWallet,
        title: 'Transfer to EF',
        objectivePk: 'obj-emergency-fund',
      );

      // Verify watchTotalTowardsObjective stream emits updated total (+8000.0)
      final updatedTotal =
          await testDb.watchTotalTowardsObjective(allWallets, objective).first;
      expect(updatedTotal, 8000.0);

      // Add a second transfer
      await createCorrectionTransaction(
        8000.0,
        efWallet,
        title: 'Second Transfer to EF',
        objectivePk: 'obj-emergency-fund',
      );

      final secondTotal =
          await testDb.watchTotalTowardsObjective(allWallets, objective).first;
      expect(secondTotal, 16000.0);
    });

    test(
        'watchTotalTowardsObjective does NOT count transfers when objectiveFk is null or for another objective',
        () async {
      final objective = Objective(
        objectivePk: 'obj-emergency-fund',
        type: ObjectiveType.goal,
        name: 'Emergency Fund',
        amount: 48000.0,
        order: 0,
        dateCreated: DateTime(2026, 1, 1),
        income: false,
        pinned: true,
        archived: false,
        walletFk: 'wallet-ef',
      );

      await testDb.createOrUpdateObjective(objective, insert: true);

      // Create a transfer with no objective
      await createCorrectionTransaction(
        8000.0,
        efWallet,
        title: 'Untagged transfer',
      );

      // Create a transfer tagged to a different objective
      await createCorrectionTransaction(
        8000.0,
        efWallet,
        title: 'Other objective transfer',
        objectivePk: 'obj-travel-fund',
      );

      final total =
          await testDb.watchTotalTowardsObjective(allWallets, objective).first;
      expect(total, 0.0);
    });

    test(
        'executeBalanceTransfer tags incoming destination transaction with selected objective and leaves source untagged',
        () async {
      final objective = Objective(
        objectivePk: 'obj-emergency-fund',
        type: ObjectiveType.goal,
        name: 'Emergency Fund',
        amount: 48000.0,
        order: 0,
        dateCreated: DateTime(2026, 1, 1),
        income: false,
        pinned: true,
        archived: false,
        walletFk: 'wallet-ef',
      );
      await testDb.createOrUpdateObjective(objective, insert: true);

      await executeBalanceTransfer(
        allWallets: allWallets,
        walletFrom: payrollWallet,
        walletTo: efWallet,
        enteredAmount: 8000.0,
        isNegative: false,
        selectedTitle: '',
        initialNote: null,
        initialObjectiveLoanPk: null,
        selectedObjectivePk: 'obj-emergency-fund',
      );

      final transactions = await testDb.allTransactions;
      expect(transactions.length, 2);

      final destTx =
          transactions.firstWhere((t) => t.walletFk == efWallet.walletPk);
      final srcTx =
          transactions.firstWhere((t) => t.walletFk == payrollWallet.walletPk);

      // Destination wallet has positive income amount and is tagged with objective
      expect(destTx.amount, 8000.0);
      expect(destTx.income, isTrue);
      expect(destTx.categoryFk, '0');
      expect(destTx.objectiveFk, 'obj-emergency-fund');

      // Source wallet has negative expense amount and has NO objective tag
      expect(srcTx.amount, -8000.0);
      expect(srcTx.income, isFalse);
      expect(srcTx.categoryFk, '0');
      expect(srcTx.objectiveFk, isNull);

      // Objective reflects exactly the +8000.0 without source double-counting
      final objectiveTotal =
          await testDb.watchTotalTowardsObjective(allWallets, objective).first;
      expect(objectiveTotal, 8000.0);
    });

    test(
        'executeBalanceTransfer reversed transfer (isNegative: true) tags incoming source transaction with selected objective',
        () async {
      final objective = Objective(
        objectivePk: 'obj-emergency-fund',
        type: ObjectiveType.goal,
        name: 'Emergency Fund',
        amount: 48000.0,
        order: 0,
        dateCreated: DateTime(2026, 1, 1),
        income: false,
        pinned: true,
        archived: false,
        walletFk: 'wallet-payroll',
      );
      await testDb.createOrUpdateObjective(objective, insert: true);

      // Inverted transfer: payroll is receiving, ef is sending
      await executeBalanceTransfer(
        allWallets: allWallets,
        walletFrom: payrollWallet,
        walletTo: efWallet,
        enteredAmount: -8000.0,
        isNegative: true,
        selectedTitle: '',
        initialNote: null,
        initialObjectiveLoanPk: null,
        selectedObjectivePk: 'obj-emergency-fund',
      );

      final transactions = await testDb.allTransactions;
      expect(transactions.length, 2);

      final toTx =
          transactions.firstWhere((t) => t.walletFk == efWallet.walletPk);
      final fromTx =
          transactions.firstWhere((t) => t.walletFk == payrollWallet.walletPk);

      expect(toTx.amount, -8000.0);
      expect(toTx.income, isFalse);
      expect(toTx.objectiveFk, isNull);

      expect(fromTx.amount, 8000.0);
      expect(fromTx.income, isTrue);
      expect(fromTx.objectiveFk, 'obj-emergency-fund');

      final objectiveTotal =
          await testDb.watchTotalTowardsObjective(allWallets, objective).first;
      expect(objectiveTotal, 8000.0);
    });

    test(
        'executeBalanceTransfer suppresses savings objective when initialObjectiveLoanPk is present (prevents erasure)',
        () async {
      await executeBalanceTransfer(
        allWallets: allWallets,
        walletFrom: payrollWallet,
        walletTo: efWallet,
        enteredAmount: 500.0,
        isNegative: false,
        selectedTitle: '',
        initialNote: null,
        initialObjectiveLoanPk: 'loan-repayment-1',
        selectedObjectivePk: 'obj-savings-accidental',
      );

      final transactions = await testDb.allTransactions;
      expect(transactions.length, 2);

      final destTx =
          transactions.firstWhere((t) => t.walletFk == efWallet.walletPk);
      final srcTx =
          transactions.firstWhere((t) => t.walletFk == payrollWallet.walletPk);

      // Source is tagged with the loan objective
      expect(srcTx.objectiveLoanFk, 'loan-repayment-1');
      expect(srcTx.objectiveFk, isNull);

      // Destination is NOT tagged with savings objective because loan transfer took precedence
      expect(destTx.objectiveLoanFk, isNull);
      expect(destTx.objectiveFk, isNull);
    });
  });
}
