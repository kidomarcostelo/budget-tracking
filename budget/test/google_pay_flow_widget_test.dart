import 'dart:ffi';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/defaultPreferences.dart';
import 'package:budget/struct/dedupeLedger.dart';
import 'package:budget/struct/googlePayParser.dart';
import 'package:budget/struct/notificationDispatcher.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/possibleDuplicateBanner.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notification_listener_service/notification_event.dart';
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
      'possible-duplicate-detected': 'Possible duplicate detected',
      'possible-duplicate-description':
          'A similar transaction was recorded recently. Please review details before saving.',
      'similar-transaction-found': 'Similar transaction found',
    };
  }
}

ServiceNotificationEvent createTestEvent({
  int id = 1,
  String packageName = 'com.google.android.apps.walletnfcrel',
  String title = 'Notification Title',
  String content = 'Notification Content',
  bool hasRemoved = false,
  int timestamp = 0,
}) {
  return ServiceNotificationEvent(
    id: id,
    packageName: packageName,
    title: title,
    content: content,
    hasRemoved: hasRemoved,
    canReply: false,
    haveExtraPicture: false,
    onGoing: false,
    timestamp: timestamp,
    appIcon: null,
    extrasPicture: null,
    largeIcon: null,
  );
}

Widget buildTestableApp({
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
          theme: getLightTheme(),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: home ??
              const Scaffold(
                body: Center(
                  child: Text('Home Screen'),
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

  group('Google Pay End-to-End Flow Widget Tests', () {
    late FinanceDatabase testDb;
    late TransactionWallet unionBankWallet;
    late TransactionWallet chaseWallet;
    late AllWallets allWallets;

    setUp(() async {
      testDb = FinanceDatabase(NativeDatabase.memory());
      database = testDb;
      DedupeLedger.instance.clear();

      final dispatcher = NotificationDispatcher.instance;
      dispatcher.recentCapturedNotifications.clear();
      dispatcher.queueHandler = null;
      dispatcher.onGooglePayTransaction = null;

      final defaults = await getDefaultPreferences();
      appStateSettings.clear();
      appStateSettings.addAll(defaults);

      appStateSettings['materialYou'] = false;
      appStateSettings['selectedWalletPk'] = 'wallet-unionbank';
      appStateSettings['outlinedIcons'] = false;
      appStateSettings['askForTransactionTitle'] = false;
      appStateSettings['showMethodAdded'] = false;
      appStateSettings['showTransactionPk'] = false;
      appStateSettings['notificationScanning'] = true;
      appStateSettings['googlePayNotificationScanning'] = true;
      appStateSettings['customTemplatesNotificationScanning'] = true;
      appStateSettings['currentUserEmail'] = 'tester@example.com';

      unionBankWallet = TransactionWallet(
        walletPk: 'wallet-unionbank',
        name: 'UnionBank',
        colour: null,
        dateCreated: DateTime(2026, 1, 1),
        order: 0,
        currency: 'PHP',
        decimals: 2,
      );
      await testDb.createOrUpdateWallet(unionBankWallet);

      chaseWallet = TransactionWallet(
        walletPk: 'wallet-chase',
        name: 'Chase Freedom',
        colour: null,
        dateCreated: DateTime(2026, 1, 1),
        order: 1,
        currency: 'USD',
        decimals: 2,
      );
      await testDb.createOrUpdateWallet(chaseWallet);

      allWallets = AllWallets(
        list: [unionBankWallet, chaseWallet],
        indexedByPk: {
          unionBankWallet.walletPk: unionBankWallet,
          chaseWallet.walletPk: chaseWallet,
        },
      );
    });

    tearDown(() {
      DedupeLedger.instance.clear();
      NotificationDispatcher.instance.recentCapturedNotifications.clear();
      NotificationDispatcher.instance.queueHandler = null;
      NotificationDispatcher.instance.onGooglePayTransaction = null;
    });

    testWidgets(
      'Interactive flow: incoming Google Pay notification renders AddTransactionPage with prefilled details',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp(allWallets: allWallets));
        await tester.pumpAndSettle();

        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.byType(AddTransactionPage), findsNothing);

        // Real device sample notification (Philippine 7-Eleven with UnionBank card)
        final gPayEvent = createTestEvent(
          id: 101,
          packageName: 'com.google.android.apps.walletnfcrel',
          title: '7-Eleveb-ST4594',
          content: 'P123.00 with UnionBank Rewards Platinum **3353',
          hasRemoved: false,
          timestamp: DateTime(2026, 10, 22, 10, 0, 0).millisecondsSinceEpoch,
        );

        final handled = await tester.runAsync(() async {
          return await NotificationDispatcher.instance.handleEvent(gPayEvent);
        });
        expect(handled, isTrue);

        await tester.pumpAndSettle();

        // 1. Verify AddTransactionPage is now rendered on screen
        expect(find.byType(AddTransactionPage), findsOneWidget);

        // 2. Verify prefilled merchant title in TitleInput
        expect(find.text('7-Eleveb-ST4594'), findsOneWidget);

        // 3. Verify prefilled amount
        expect(find.textContaining('123'), findsWidgets);

        // 4. Verify prefilled note/card hint
        expect(
          find.textContaining('UnionBank Rewards Platinum •••• 3353'),
          findsOneWidget,
        );

        // 5. Verify selected wallet is UnionBank
        expect(find.textContaining('UnionBank'), findsWidgets);

        // 6. Verify duplicate banner is not shown for unique payment
        expect(find.byKey(const ValueKey('possibleDuplicateBanner')),
            findsNothing);

        // Settle animation timers and clean up route
        await tester.pump(const Duration(milliseconds: 1200));

        if (navigatorKey.currentState?.canPop() == true) {
          navigatorKey.currentState?.pop();
          await tester.pumpAndSettle();
        }
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'Dismissal events (hasRemoved == true) are ignored and do not push duplicate page',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp(allWallets: allWallets));
        await tester.pumpAndSettle();

        // First notification arrived (posted)
        final postedEvent = createTestEvent(
          id: 102,
          packageName: 'com.google.android.apps.walletnfcrel',
          title: '7-Eleveb-ST4594',
          content: 'P123.00 with UnionBank Rewards Platinum **3353',
          hasRemoved: false,
          timestamp: DateTime(2026, 10, 22, 10, 0, 0).millisecondsSinceEpoch,
        );
        final postedHandled = await tester.runAsync(() async {
          return await NotificationDispatcher.instance.handleEvent(postedEvent);
        });
        expect(postedHandled, isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(AddTransactionPage), findsOneWidget);

        // Second notification: user dismissed the notification from status bar
        final removedEvent = createTestEvent(
          id: 102,
          packageName: 'com.google.android.apps.walletnfcrel',
          title: '7-Eleveb-ST4594',
          content: 'P123.00 with UnionBank Rewards Platinum **3353',
          hasRemoved: true,
          timestamp: DateTime(2026, 10, 22, 10, 0, 10).millisecondsSinceEpoch,
        );
        final removedHandled = await tester.runAsync(() async {
          return await NotificationDispatcher.instance
              .handleEvent(removedEvent);
        });

        // Should return false and not push any second page
        expect(removedHandled, isFalse);
        await tester.pumpAndSettle();

        // Still exactly one AddTransactionPage
        expect(find.byType(AddTransactionPage), findsOneWidget);

        // Settle animation timers and clean up route
        await tester.pump(const Duration(milliseconds: 1200));
        if (navigatorKey.currentState?.canPop() == true) {
          navigatorKey.currentState?.pop();
          await tester.pumpAndSettle();
        }
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'Deduplication suppression: identical notification within 5-min sliding window is suppressed',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp(allWallets: allWallets));
        await tester.pumpAndSettle();

        final t0 = DateTime(2026, 10, 22, 10, 0, 0);
        final firstEvent = createTestEvent(
          id: 103,
          packageName: 'com.google.android.apps.walletnfcrel',
          title: '7-Eleveb-ST4594',
          content: 'P123.00 with UnionBank Rewards Platinum **3353',
          hasRemoved: false,
          timestamp: t0.millisecondsSinceEpoch,
        );

        final handled1 = await tester.runAsync(() async {
          return await NotificationDispatcher.instance.handleEvent(firstEvent);
        });
        expect(handled1, isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(AddTransactionPage), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1200));

        // Identical notification 2 minutes later (within 5-minute sliding window)
        final duplicateEvent = createTestEvent(
          id: 103,
          packageName: 'com.google.android.apps.walletnfcrel',
          title: '7-Eleveb-ST4594',
          content: 'P123.00 with UnionBank Rewards Platinum **3353',
          hasRemoved: false,
          timestamp: t0.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
        );

        final handled2 = await tester.runAsync(() async {
          return await NotificationDispatcher.instance
              .handleEvent(duplicateEvent);
        });
        expect(handled2, isFalse);
        await tester.pumpAndSettle();

        // Still exactly one AddTransactionPage, no second route or prompt pushed
        expect(find.byType(AddTransactionPage), findsOneWidget);
        expect(DedupeLedger.instance.suppressedEntries.length, equals(1));

        // Settle animation timers and clean up route
        await tester.pump(const Duration(milliseconds: 1200));
        if (navigatorKey.currentState?.canPop() == true) {
          navigatorKey.currentState?.pop();
          await tester.pumpAndSettle();
        }
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'Uncertain match review flow: ambiguous notification renders AddTransactionPage with PossibleDuplicateBanner',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp(allWallets: allWallets));
        await tester.pumpAndSettle();

        final t0 = DateTime(2026, 10, 22, 10, 0, 0);

        // Pre-record a bank notification entry in DedupeLedger
        await tester.runAsync(() async {
          await DedupeLedger.instance.checkAndRecordNotification(
            packageName: 'com.bdo.bank',
            notificationId: 'bank-999',
            amount: 250.0,
            currency: 'PHP',
            title: 'Starbucks Coffee',
            rawContent: 'Debit alert: PHP 250.00 spent at Starbucks Coffee',
            eventTime: t0,
          );
        });

        // Now Google Pay event arrives for identical amount (250.00 PHP)
        // but conflicting merchant title ("Seattle's Best") 1 minute later
        final gPayEvent = createTestEvent(
          id: 104,
          packageName: 'com.google.android.apps.walletnfcrel',
          title: "Seattle's Best",
          content: 'Paid ₱250.00 at Seattle\'s Best',
          hasRemoved: false,
          timestamp: t0.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
        );

        final handled = await tester.runAsync(() async {
          return await NotificationDispatcher.instance.handleEvent(gPayEvent);
        });
        expect(handled, isTrue);
        await tester.pumpAndSettle();

        // 1. Verify AddTransactionPage is rendered
        expect(find.byType(AddTransactionPage), findsOneWidget);

        // 2. Verify PossibleDuplicateBanner is rendered
        expect(
          find.byKey(const ValueKey('possibleDuplicateBanner')),
          findsOneWidget,
        );
        expect(find.textContaining('Possible duplicate'), findsOneWidget);

        // 3. Matched entry details (prior Starbucks title) are displayed in banner
        expect(find.textContaining('Starbucks Coffee'), findsWidgets);

        // 4. Tap dismiss icon on PossibleDuplicateBanner
        final dismissBtn =
            find.byKey(const ValueKey('dismissPossibleDuplicateBanner'));
        expect(dismissBtn, findsOneWidget);
        await tester.tap(dismissBtn);
        await tester.pumpAndSettle();

        // 5. Banner is dismissed
        expect(find.byKey(const ValueKey('possibleDuplicateBanner')),
            findsNothing);

        // Settle animation timers and clean up route
        await tester.pump(const Duration(milliseconds: 1200));
        if (navigatorKey.currentState?.canPop() == true) {
          navigatorKey.currentState?.pop();
          await tester.pumpAndSettle();
        }
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'Pattern B: USD currency and masked card number prefills correctly',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp(allWallets: allWallets));
        await tester.pumpAndSettle();

        final usdEvent = createTestEvent(
          id: 105,
          packageName: 'com.google.android.apps.walletnfcrel',
          title: "Trader Joe's",
          content: '\$42.75 with Chase Freedom •••• 9876',
          hasRemoved: false,
          timestamp: DateTime(2026, 10, 22, 10, 0, 0).millisecondsSinceEpoch,
        );

        final handled = await tester.runAsync(() async {
          return await NotificationDispatcher.instance.handleEvent(usdEvent);
        });
        expect(handled, isTrue);
        await tester.pumpAndSettle();

        expect(find.byType(AddTransactionPage), findsOneWidget);
        expect(find.text("Trader Joe's"), findsOneWidget);
        expect(find.textContaining('42.75'), findsWidgets);
        expect(find.textContaining('Chase Freedom •••• 9876'), findsOneWidget);
        expect(find.textContaining('Chase Freedom'), findsWidgets);

        // Settle animation timers and clean up route
        await tester.pump(const Duration(milliseconds: 1200));
        if (navigatorKey.currentState?.canPop() == true) {
          navigatorKey.currentState?.pop();
          await tester.pumpAndSettle();
        }
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'Pattern C: Generic Google Wallet header parses merchant in body without card hint',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableApp(allWallets: allWallets));
        await tester.pumpAndSettle();

        final genericEvent = createTestEvent(
          id: 106,
          packageName: 'com.google.android.apps.walletnfcrel',
          title: 'Google Wallet',
          content: 'Paid ₱250.00 at Mercury Drug',
          hasRemoved: false,
          timestamp: DateTime(2026, 10, 22, 10, 0, 0).millisecondsSinceEpoch,
        );

        final handled = await tester.runAsync(() async {
          return await NotificationDispatcher.instance
              .handleEvent(genericEvent);
        });
        expect(handled, isTrue);
        await tester.pumpAndSettle();

        expect(find.byType(AddTransactionPage), findsOneWidget);
        expect(find.text('Mercury Drug'), findsOneWidget);
        expect(find.textContaining('250'), findsWidgets);

        // Settle animation timers and clean up route
        await tester.pump(const Duration(milliseconds: 1200));
        if (navigatorKey.currentState?.canPop() == true) {
          navigatorKey.currentState?.pop();
          await tester.pumpAndSettle();
        }
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'Google Pay disabled preference prevents page routing and ledger recording',
      (WidgetTester tester) async {
        appStateSettings['googlePayNotificationScanning'] = false;

        await tester.pumpWidget(buildTestableApp(allWallets: allWallets));
        await tester.pumpAndSettle();

        final gPayEvent = createTestEvent(
          id: 107,
          packageName: 'com.google.android.apps.walletnfcrel',
          title: '7-Eleveb-ST4594',
          content: 'P123.00 with UnionBank Rewards Platinum **3353',
        );

        final handled = await tester.runAsync(() async {
          return await NotificationDispatcher.instance.handleEvent(gPayEvent);
        });
        expect(handled, isFalse);
        await tester.pumpAndSettle();

        expect(find.byType(AddTransactionPage), findsNothing);
        expect(DedupeLedger.instance.entries.isEmpty, isTrue);

        await tester.pump(Duration.zero);
      },
    );
  });
}
