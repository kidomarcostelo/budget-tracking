import 'dart:convert';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/dedupeLedger.dart';
import 'package:budget/struct/googlePayParser.dart';
import 'package:budget/struct/notificationDispatcher.dart';
import 'package:budget/struct/settings.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  final dispatcher = NotificationDispatcher.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    sharedPreferences = testPrefs;

    appStateSettings["googlePayNotificationScanning"] = true;
    appStateSettings["customTemplatesNotificationScanning"] = true;
    appStateSettings["selectedWalletPk"] = "0";

    DedupeLedger.instance.clear();
  });

  tearDown(() {
    dispatcher.queueHandler = null;
    dispatcher.onGooglePayTransaction = null;
    DedupeLedger.instance.clear();
  });

  group('GooglePayParser package recognition', () {
    test(
        'standard Google Wallet packages are recognized regardless of debug mode',
        () {
      expect(
        GooglePayParser.isRecognizedPackage(
          'com.google.android.apps.walletnfcrel',
          isDebug: false,
        ),
        isTrue,
      );
      expect(
        GooglePayParser.isRecognizedPackage(
          'com.google.android.apps.nbu.paisa.user',
          isDebug: false,
        ),
        isTrue,
      );
      expect(
        GooglePayParser.isRecognizedPackage(
          'com.google.android.gms',
          isDebug: false,
        ),
        isTrue,
      );
    });

    test(
        'debug simulation packages (android, com.android.shell) recognized when isDebug or notificationScanningDebug is true',
        () {
      // By default with isDebug: false and notificationScanningDebug unset
      appStateSettings["notificationScanningDebug"] = false;
      expect(
        GooglePayParser.isRecognizedPackage('android', isDebug: true),
        isTrue,
      );
      expect(
        GooglePayParser.isRecognizedPackage('android', isDebug: false),
        isFalse,
      );
      expect(
        GooglePayParser.isRecognizedPackage('com.android.shell', isDebug: true),
        isTrue,
      );
      expect(
        GooglePayParser.isRecognizedPackage('com.android.shell',
            isDebug: false),
        isFalse,
      );

      // When notificationScanningDebug is enabled in release mode (isDebug: false)
      appStateSettings["notificationScanningDebug"] = true;
      expect(
        GooglePayParser.isRecognizedPackage('android', isDebug: false),
        isTrue,
      );
      expect(
        GooglePayParser.isRecognizedPackage('com.android.shell',
            isDebug: false),
        isTrue,
      );

      // allowSimulationOverride takes precedence
      expect(
        GooglePayParser.isRecognizedPackage('com.android.shell',
            isDebug: false, allowSimulationOverride: false),
        isFalse,
      );
      expect(
        GooglePayParser.isRecognizedPackage('com.android.shell',
            isDebug: false, allowSimulationOverride: true),
        isTrue,
      );

      // Unrelated packages remain unrecognized even with simulation enabled
      expect(
        GooglePayParser.isRecognizedPackage('com.budget.tracker_app.debug',
            isDebug: true),
        isFalse,
      );
      expect(
        GooglePayParser.isRecognizedPackage('com.budget.tracker_app',
            isDebug: true),
        isFalse,
      );
      expect(
        GooglePayParser.isRecognizedPackage('com.random.unrelated',
            isDebug: true),
        isFalse,
      );

      // Reset setting
      appStateSettings["notificationScanningDebug"] = false;
    });
  });

  group('NotificationDispatcher.flushBufferedNotifications', () {
    test('returns 0 when buffer is empty or missing', () async {
      final countMissing = await dispatcher.flushBufferedNotifications(
        preferencesOverride: testPrefs,
      );
      expect(countMissing, equals(0));

      await testPrefs.setString(NotificationDispatcher.bufferStorageKey, '[]');
      final countEmpty = await dispatcher.flushBufferedNotifications(
        preferencesOverride: testPrefs,
      );
      expect(countEmpty, equals(0));
    });

    test(
        'recovers gracefully from corrupted/malformed JSON string without throwing',
        () async {
      await testPrefs.setString(
        NotificationDispatcher.bufferStorageKey,
        '{"corrupted": not a valid json',
      );

      final count = await dispatcher.flushBufferedNotifications(
        preferencesOverride: testPrefs,
      );
      expect(count, equals(0));
    });

    test('flushes and dispatches valid buffered Google Pay transaction',
        () async {
      GooglePayTransactionResult? capturedResult;
      dispatcher.onGooglePayTransaction = (result,
          {isPossibleDuplicate = false, possibleDuplicateEntry}) async {
        capturedResult = result;
        return true;
      };

      final bufferedData = [
        {
          'id': 101,
          'packageName': 'com.google.android.apps.walletnfcrel',
          'title': 'Google Wallet',
          'content': 'Paid PHP 350.00 at Starbucks with MariBank',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      ];

      await testPrefs.setString(
        NotificationDispatcher.bufferStorageKey,
        jsonEncode(bufferedData),
      );

      final flushedCount = await dispatcher.flushBufferedNotifications(
        preferencesOverride: testPrefs,
      );

      expect(flushedCount, equals(1));
      expect(capturedResult, isNotNull);
      expect(capturedResult!.merchant, equals('Starbucks'));
      expect(capturedResult!.amount, equals(350.00));
      expect(capturedResult!.currency, equals('PHP'));
      expect(capturedResult!.cardName, equals('MariBank'));

      // Buffer in SharedPreferences should be cleared
      final remainingBuffer =
          testPrefs.getString(NotificationDispatcher.bufferStorageKey);
      expect(remainingBuffer, equals('[]'));
    });

    test('processes multiple buffered transactions sequentially', () async {
      final List<String> capturedMerchants = [];
      dispatcher.onGooglePayTransaction = (result,
          {isPossibleDuplicate = false, possibleDuplicateEntry}) async {
        capturedMerchants.add(result.merchant);
        return true;
      };

      final bufferedData = [
        {
          'id': 201,
          'packageName': 'com.google.android.apps.walletnfcrel',
          'title': 'Google Wallet',
          'content': 'Paid PHP 120.00 at Jollibee with UnionBank',
          'timestamp': 1000,
        },
        {
          'id': 202,
          'packageName': 'com.google.android.apps.walletnfcrel',
          'title': 'Google Wallet',
          'content': 'Paid USD 15.50 at Amazon with Citi',
          'timestamp': 2000,
        },
      ];

      await testPrefs.setString(
        NotificationDispatcher.bufferStorageKey,
        jsonEncode(bufferedData),
      );

      final count = await dispatcher.flushBufferedNotifications(
        preferencesOverride: testPrefs,
      );

      expect(count, equals(2));
      expect(capturedMerchants, equals(['Jollibee', 'Amazon']));
      expect(testPrefs.getString(NotificationDispatcher.bufferStorageKey),
          equals('[]'));
    });

    test('suppresses duplicate events when already recorded in DedupeLedger',
        () async {
      int handlerInvocations = 0;
      dispatcher.onGooglePayTransaction = (result,
          {isPossibleDuplicate = false, possibleDuplicateEntry}) async {
        handlerInvocations++;
        return true;
      };

      final entry = {
        'id': 301,
        'packageName': 'com.google.android.apps.walletnfcrel',
        'title': 'Google Wallet',
        'content': 'Paid PHP 500.00 at Shell with UnionBank',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // First flush: successfully processed
      await testPrefs.setString(
        NotificationDispatcher.bufferStorageKey,
        jsonEncode([entry]),
      );
      final count1 = await dispatcher.flushBufferedNotifications(
        preferencesOverride: testPrefs,
      );
      expect(count1, equals(1));
      expect(handlerInvocations, equals(1));

      // Second flush with same event within time window: DedupeLedger suppresses it
      await testPrefs.setString(
        NotificationDispatcher.bufferStorageKey,
        jsonEncode([entry]),
      );
      final count2 = await dispatcher.flushBufferedNotifications(
        preferencesOverride: testPrefs,
      );
      expect(count2, equals(0));
      expect(handlerInvocations, equals(1));
    });

    test(
        'concurrent calls to flushBufferedNotifications share same Future lock',
        () async {
      final entry = {
        'id': 401,
        'packageName': 'com.google.android.apps.walletnfcrel',
        'title': 'Google Wallet',
        'content': 'Paid PHP 250.00 at Lawson with MariBank',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await testPrefs.setString(
        NotificationDispatcher.bufferStorageKey,
        jsonEncode([entry]),
      );

      // Trigger two flushes concurrently
      final future1 = dispatcher.flushBufferedNotifications(
        preferencesOverride: testPrefs,
      );
      final future2 = dispatcher.flushBufferedNotifications(
        preferencesOverride: testPrefs,
      );

      final results = await Future.wait([future1, future2]);
      // Both futures should yield the exact same single result without double-flushing
      expect(results[0], equals(results[1]));
    });

    test('nativePendingReviewNotificationId is 9992', () {
      expect(NotificationDispatcher.nativePendingReviewNotificationId,
          equals(9992));
    });
  });

  group('Template keywords sync and killed-state bank capture', () {
    late FinanceDatabase testDb;

    setUp(() async {
      testDb = FinanceDatabase(NativeDatabase.memory());
      database = testDb;

      await testDb.createOrUpdateWallet(
        TransactionWallet(
          walletPk: '0',
          name: 'Main Wallet',
          colour: '0xff000000',
          dateCreated: DateTime.now(),
          order: 0,
          currency: 'PHP',
          decimals: 2,
        ),
        insert: false,
      );

      await testDb.createOrUpdateCategory(
        TransactionCategory(
          categoryPk: '0',
          name: 'Default',
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

    test('syncTemplateKeywordsToPreferences writes scanner template keywords',
        () async {
      await testDb.createOrUpdateScannerTemplate(
        ScannerTemplate(
          scannerTemplatePk: '1',
          dateCreated: DateTime.now(),
          templateName: 'UnionBank Alert',
          contains: 'UnionBank',
          defaultCategoryFk: '0',
          ignore: false,
          walletFk: '0',
          titleTransactionBefore: '',
          titleTransactionAfter: '',
          amountTransactionBefore: 'PHP ',
          amountTransactionAfter: ' spent',
          dateTimeModified: DateTime.now(),
        ),
        insert: true,
      );

      await testDb.createOrUpdateScannerTemplate(
        ScannerTemplate(
          scannerTemplatePk: '2',
          dateCreated: DateTime.now(),
          templateName: 'BDO Pay',
          contains: 'BDO Pay',
          defaultCategoryFk: '0',
          ignore: false,
          walletFk: '0',
          titleTransactionBefore: '',
          titleTransactionAfter: '',
          amountTransactionBefore: 'PHP ',
          amountTransactionAfter: ' paid',
          dateTimeModified: DateTime.now(),
        ),
        insert: true,
      );

      await dispatcher.syncTemplateKeywordsToPreferences(
        preferencesOverride: testPrefs,
      );

      final rawKeywords = testPrefs
          .getString(NotificationDispatcher.templateKeywordsStorageKey);
      expect(rawKeywords, isNotNull);
      final decoded = jsonDecode(rawKeywords!) as List;
      expect(decoded, contains('UnionBank'));
      expect(decoded, contains('BDO Pay'));
    });

    test('findPendingTransaction matches by amount and merchant name in SQL',
        () async {
      final now = DateTime.now();
      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-1',
          name: 'Jollibee',
          amount: -175.0,
          note: 'Dinner',
          categoryFk: '0',
          walletFk: '0',
          dateCreated: now,
          income: false,
          paid: false,
          skipPaid: false,
          pending: true,
        ),
      );

      await testDb.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-2',
          name: 'Starbucks',
          amount: -220.0,
          note: 'Coffee',
          categoryFk: '0',
          walletFk: '0',
          dateCreated: now.add(const Duration(minutes: 1)),
          income: false,
          paid: false,
          skipPaid: false,
          pending: true,
        ),
      );

      // Match by amount
      final matchedByAmount =
          await testDb.findPendingTransaction(amount: 175.0);
      expect(matchedByAmount, isNotNull);
      expect(matchedByAmount!.name, equals('Jollibee'));

      // Match by name
      final matchedByName =
          await testDb.findPendingTransaction(name: 'Starbucks');
      expect(matchedByName, isNotNull);
      expect(matchedByName!.amount, equals(-220.0));

      // Match fallback to latest pending
      final latest = await testDb.findPendingTransaction();
      expect(latest, isNotNull);
      expect(latest!.name, equals('Starbucks'));
    });
  });

  group('DedupeLedger notification matching without test-harness pollution',
      () {
    test(
        'distinguishes consecutive notifications sharing notification ID if amounts differ',
        () async {
      final t0 = DateTime.now();
      // First transaction
      final res1 = await DedupeLedger.instance.checkAndRecordNotification(
        packageName: 'com.any.bank',
        notificationId: 'shared_id_100',
        amount: 150.0,
        currency: 'PHP',
        title: 'Jollibee',
        eventTime: t0,
      );
      expect(res1.isDuplicate, isFalse);

      // Second transaction sharing ID 100 but different amount
      final res2 = await DedupeLedger.instance.checkAndRecordNotification(
        packageName: 'com.any.bank',
        notificationId: 'shared_id_100',
        amount: 220.0,
        currency: 'PHP',
        title: 'Starbucks',
        eventTime: t0.add(const Duration(seconds: 10)),
      );
      expect(res2.isDuplicate, isFalse);

      // Third transaction with exact same amount within window IS duplicate
      final res3 = await DedupeLedger.instance.checkAndRecordNotification(
        packageName: 'com.any.bank',
        notificationId: 'shared_id_100',
        amount: 220.0,
        currency: 'PHP',
        title: 'Starbucks Updated',
        eventTime: t0.add(const Duration(seconds: 20)),
      );
      expect(res3.isDuplicate, isTrue);
    });
  });
}
