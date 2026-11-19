import 'dart:convert';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/dedupeLedger.dart';
import 'package:budget/struct/googlePayParser.dart';
import 'package:budget/struct/notificationDispatcher.dart';
import 'package:budget/struct/settings.dart';
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
        'debug simulation packages (android, debug appId) recognized only when isDebug is true',
        () {
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
  });
}
