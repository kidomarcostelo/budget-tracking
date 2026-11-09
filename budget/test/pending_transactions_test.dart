import 'dart:ffi';
import 'package:budget/database/tables.dart';
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

  group('Pending Transactions Infrastructure (VS1)', () {
    late FinanceDatabase testDb;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      appStateSettings["sharedBudgets"] = false;
      testDb = FinanceDatabase(NativeDatabase.memory());
      database = testDb;

      // Seed default wallet and category
      await testDb.createOrUpdateWallet(
        TransactionWallet(
          walletPk: '0',
          name: 'Main Wallet',
          colour: '0xff000000',
          dateCreated: DateTime.now(),
          order: 0,
          currency: 'USD',
          decimals: 2,
        ),
        insert: false,
      );

      await testDb.createOrUpdateCategory(
        TransactionCategory(
          categoryPk: 'cat-1',
          name: 'Food',
          colour: '0xffff0000',
          dateCreated: DateTime.now(),
          order: 0,
          income: false,
        ),
        insert: false,
        updateSharedEntry: false,
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    test('Transaction defaults to pending = false when omitted', () async {
      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-normal',
          name: 'Lunch',
          amount: 25.0,
          note: '',
          categoryFk: 'cat-1',
          walletFk: '0',
          dateCreated: DateTime.now(),
          income: false,
          paid: true,
          skipPaid: false,
        ),
        insert: false,
      );

      final tx = await testDb.getTransactionFromPk('tx-normal');
      expect(tx.pending, false);
    });

    test('Pending transaction can be explicitly created with pending = true',
        () async {
      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-pending-1',
          name: 'Coffee',
          amount: 5.50,
          note: 'Google Wallet detected',
          categoryFk: 'cat-1',
          walletFk: '0',
          dateCreated: DateTime.now(),
          income: false,
          paid: true,
          skipPaid: false,
          pending: true,
        ),
        insert: false,
      );

      final tx = await testDb.getTransactionFromPk('tx-pending-1');
      expect(tx.pending, true);
    });

    test('watchPendingTransactions and watchCountPendingTransactions',
        () async {
      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-norm',
          name: 'Normal Item',
          amount: 50.0,
          note: '',
          categoryFk: 'cat-1',
          walletFk: '0',
          dateCreated: DateTime.now(),
          income: false,
          paid: true,
          skipPaid: false,
        ),
        insert: false,
      );

      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-pend-1',
          name: 'Pending 1',
          amount: 10.0,
          note: '',
          categoryFk: 'cat-1',
          walletFk: '0',
          dateCreated: DateTime.now(),
          income: false,
          paid: true,
          skipPaid: false,
          pending: true,
        ),
        insert: false,
      );

      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-pend-2',
          name: 'Pending 2',
          amount: 20.0,
          note: '',
          categoryFk: 'cat-1',
          walletFk: '0',
          dateCreated: DateTime.now(),
          income: false,
          paid: true,
          skipPaid: false,
          pending: true,
        ),
        insert: false,
      );

      final pendingList = await testDb.watchPendingTransactions().first;
      expect(pendingList.length, 2);
      expect(pendingList.map((e) => e.transaction.transactionPk),
          containsAll(['tx-pend-1', 'tx-pend-2']));

      final count = await testDb.watchCountPendingTransactions().first;
      expect(count, 2);
    });

    test('watchAllTransactions excludes pending transactions', () async {
      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-active',
          name: 'Active',
          amount: 30.0,
          note: '',
          categoryFk: 'cat-1',
          walletFk: '0',
          dateCreated: DateTime.now(),
          income: false,
          paid: true,
          skipPaid: false,
        ),
        insert: false,
      );

      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-pending',
          name: 'Pending',
          amount: 40.0,
          note: '',
          categoryFk: 'cat-1',
          walletFk: '0',
          dateCreated: DateTime.now(),
          income: false,
          paid: true,
          skipPaid: false,
          pending: true,
        ),
        insert: false,
      );

      final transactions = await testDb.watchAllTransactions().first;
      expect(transactions.length, 1);
      expect(transactions.first.transactionPk, 'tx-active');
    });

    test('approvePendingTransaction flips pending to false', () async {
      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-approve-test',
          name: 'To Approve',
          amount: 15.0,
          note: '',
          categoryFk: 'cat-1',
          walletFk: '0',
          dateCreated: DateTime.now(),
          income: false,
          paid: true,
          skipPaid: false,
          pending: true,
        ),
        insert: false,
      );

      expect((await testDb.watchCountPendingTransactions().first), 1);

      await testDb.approvePendingTransaction('tx-approve-test');

      expect((await testDb.watchCountPendingTransactions().first), 0);
      final tx = await testDb.getTransactionFromPk('tx-approve-test');
      expect(tx.pending, false);

      final visible = await testDb.watchAllTransactions().first;
      expect(visible.map((e) => e.transactionPk), contains('tx-approve-test'));
    });

    test('dismissPendingTransaction deletes the pending transaction', () async {
      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-dismiss-test',
          name: 'To Dismiss',
          amount: 15.0,
          note: '',
          categoryFk: 'cat-1',
          walletFk: '0',
          dateCreated: DateTime.now(),
          income: false,
          paid: true,
          skipPaid: false,
          pending: true,
        ),
        insert: false,
      );

      expect((await testDb.watchCountPendingTransactions().first), 1);

      await testDb.dismissPendingTransaction('tx-dismiss-test');

      expect((await testDb.watchCountPendingTransactions().first), 0);
      final tx = await testDb.tryGetTransactionFromPk('tx-dismiss-test');
      expect(tx, isNull);
    });

    test('approveAllPendingTransactions approves all in bulk', () async {
      for (int i = 1; i <= 3; i++) {
        await testDb.createOrUpdateTransaction(
          Transaction(
            transactionPk: 'tx-bulk-$i',
            name: 'Bulk $i',
            amount: 10.0 * i,
            note: '',
            categoryFk: 'cat-1',
            walletFk: '0',
            dateCreated: DateTime.now(),
            income: false,
            paid: true,
            skipPaid: false,
            pending: true,
          ),
          insert: false,
        );
      }

      expect((await testDb.watchCountPendingTransactions().first), 3);

      final affected = await testDb.approveAllPendingTransactions();
      expect(affected, 3);
      expect((await testDb.watchCountPendingTransactions().first), 0);

      final visible = await testDb.watchAllTransactions().first;
      expect(visible.length, 3);
    });

    test('dismissAllPendingTransactions deletes all in bulk', () async {
      for (int i = 1; i <= 3; i++) {
        await testDb.createOrUpdateTransaction(
          Transaction(
            transactionPk: 'tx-dismiss-bulk-$i',
            name: 'Dismiss Bulk $i',
            amount: 10.0 * i,
            note: '',
            categoryFk: 'cat-1',
            walletFk: '0',
            dateCreated: DateTime.now(),
            income: false,
            paid: true,
            skipPaid: false,
            pending: true,
          ),
          insert: false,
        );
      }

      expect((await testDb.watchCountPendingTransactions().first), 3);

      final deletedCount = await testDb.dismissAllPendingTransactions();
      expect(deletedCount, 3);
      expect((await testDb.watchCountPendingTransactions().first), 0);

      final allTx = await testDb.watchAllTransactions().first;
      expect(allTx, isEmpty);
    });
  });
}
