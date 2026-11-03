import 'dart:ffi';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/dedupeLedger.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/possibleDuplicateBanner.dart';
import 'package:budget/widgets/util/appLinks.dart';
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
      'possible-duplicate-detected': 'Possible duplicate detected',
      'possible-duplicate-description':
          'A similar transaction was recorded recently. Please review details before saving.',
      'similar-transaction-found': 'Similar transaction found',
    };
  }
}

Widget buildTestableWidget(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('en')],
    path: 'test',
    assetLoader: const _TestAssetLoader(),
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(
          body: child,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();
    appStateSettings["materialYou"] = false;
    appStateSettings["selectedWalletPk"] = "test-wallet-1";
    appStateSettings["outlinedIcons"] = false;
    appStateSettings["askForTransactionTitle"] = false;
    appStateSettings["showMethodAdded"] = false;
    appStateSettings["showTransactionPk"] = false;
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });
  });

  group('PossibleDuplicateBanner Widget Tests', () {
    testWidgets('renders banner with warning icon, title, and matched details',
        (WidgetTester tester) async {
      final matchedEntry = DedupeEntryRecord(
        eventKey: 'notif:com.bank:123',
        amount: 250.0,
        amountNormalized: '250.00',
        currency: 'PHP',
        title: 'Starbucks Coffee',
      );

      bool dismissed = false;

      await tester.pumpWidget(
        buildTestableWidget(
          PossibleDuplicateBanner(
            matchedEntry: matchedEntry,
            onDismiss: () {
              dismissed = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify banner container exists
      expect(find.byKey(const ValueKey('possibleDuplicateBanner')),
          findsOneWidget);

      // Verify title or duplicate text exists
      expect(find.textContaining('Possible duplicate'), findsOneWidget);

      // Verify matched amount and title are visible
      expect(find.textContaining('250.00'), findsOneWidget);
      expect(find.textContaining('Starbucks Coffee'), findsOneWidget);

      // Tap dismiss icon
      final dismissButton =
          find.byKey(const ValueKey('dismissPossibleDuplicateBanner'));
      expect(dismissButton, findsOneWidget);
      await tester.tap(dismissButton);
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('renders fallback text when matchedEntry is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const PossibleDuplicateBanner(
            matchedEntry: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('possibleDuplicateBanner')),
          findsOneWidget);
      expect(find.textContaining('Possible duplicate'), findsOneWidget);
    });

    testWidgets('renders correctly when only amount is present',
        (WidgetTester tester) async {
      final matchedEntry = DedupeEntryRecord(
        eventKey: 'notif:com.bank:amount-only',
        amount: 500.0,
        amountNormalized: '500.00',
        currency: 'USD',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          PossibleDuplicateBanner(
            matchedEntry: matchedEntry,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('possibleDuplicateBanner')),
          findsOneWidget);
      expect(find.textContaining('USD 500.00'), findsOneWidget);
      // Dismiss button should not be present when onDismiss is null
      expect(find.byKey(const ValueKey('dismissPossibleDuplicateBanner')),
          findsNothing);
    });

    testWidgets('renders correctly when only title is present',
        (WidgetTester tester) async {
      final matchedEntry = DedupeEntryRecord(
        eventKey: 'notif:com.bank:title-only',
        title: 'Shell Gas Station',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          PossibleDuplicateBanner(
            matchedEntry: matchedEntry,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('possibleDuplicateBanner')),
          findsOneWidget);
      expect(find.textContaining('Shell Gas Station'), findsOneWidget);
    });
  });

  group('App Links checkPaymentDedupe and review routing', () {
    late FinanceDatabase testDb;

    setUp(() async {
      testDb = FinanceDatabase(NativeDatabase.memory());
      database = testDb;
      DedupeLedger.instance.clear();
      appStateSettings["notificationScanning"] = true;
    });

    tearDown(() async {
      await testDb.close();
      appStateSettings["notificationScanning"] = false;
    });

    test('checkPaymentDedupe detects uncertain match for conflicting titles',
        () async {
      final t0 = DateTime(2026, 10, 22, 10, 0, 0);
      final t1 = t0.add(const Duration(minutes: 1));

      // First payment: Starbucks for 250 PHP
      await DedupeLedger.instance.checkAndRecordPayment(
        amount: 250.0,
        currency: 'PHP',
        title: 'Starbucks Coffee',
        source: 'app_link',
        eventTime: t0,
      );

      // Second payment check: McDonald's for 250 PHP (conflicting merchant)
      final result = await checkPaymentDedupe(
        amount: 250.0,
        params: {'title': "McDonald's", 'currency': 'PHP'},
        platform: PlatformOS.isAndroid,
        eventTime: t1,
        currency: 'PHP',
      );

      expect(result, isNotNull);
      expect(result!.isDuplicate, isFalse);
      expect(result.isUncertainMatch, isTrue);
      expect(result.matchedEntry?.title, equals('Starbucks Coffee'));
    });

    test('checkPaymentDedupe detects duplicate for exact retry', () async {
      final t0 = DateTime(2026, 10, 22, 10, 0, 0);
      final t1 = t0.add(const Duration(seconds: 5));

      await DedupeLedger.instance.checkAndRecordPayment(
        amount: 250.0,
        currency: 'PHP',
        title: 'Starbucks Coffee',
        source: 'app_link',
        eventTime: t0,
      );

      final result = await checkPaymentDedupe(
        amount: 250.0,
        params: {'title': 'Starbucks Coffee', 'currency': 'PHP'},
        platform: PlatformOS.isAndroid,
        eventTime: t1,
        currency: 'PHP',
      );

      expect(result, isNotNull);
      expect(result!.isDuplicate, isTrue);
      expect(result.isUncertainMatch, isFalse);
    });
  });
}
