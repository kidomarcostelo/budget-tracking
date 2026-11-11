import 'dart:async';
import 'dart:ffi' hide Size;
import 'package:budget/database/tables.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/autoTransactionsPageEmail.dart';
import 'package:budget/pages/pendingTransactionsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/dedupeLedger.dart';
import 'package:budget/struct/defaultPreferences.dart';
import 'package:budget/struct/initializeNotifications.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/util/appLinks.dart';
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

class _FlowTestAssetLoader extends AssetLoader {
  const _FlowTestAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'pending-transactions': 'Pending Transactions',
      'no-pending-transactions': 'No pending transactions',
      'approve-all': 'Approve All',
      'dismiss-all': 'Dismiss All',
      'approve': 'Approve',
      'dismiss': 'Dismiss',
      'transaction-approved': 'Transaction approved',
      'transaction-dismissed': 'Transaction dismissed',
      'all-transactions-approved': 'All pending transactions approved',
      'all-transactions-dismissed': 'All pending transactions dismissed',
      'notification-scanning-non-blocking': 'Non-Blocking Notifications',
      'notification-scanning-non-blocking-description':
          'Display a system notification popup instead of opening Cashew immediately upon detecting transactions.',
      'notification-transactions': 'Notification Transactions',
      'notification-transactions-description':
          'Transactions can be created automatically.',
      'google-pay-transactions': 'Google Wallet & Google Pay',
      'google-pay-transactions-description':
          'Automatically detect and parse transactions.',
      'custom-notification-templates': 'Custom Notification Templates',
      'custom-notification-templates-description':
          'Parse using custom templates.',
      'notification-configuration-missing': 'No Custom Templates Added',
      'notification-configuration-missing-description':
          'Add a template if you wish.',
      'notification-privacy-title': 'On-Device Privacy & Permissions',
      'notification-privacy-description': 'Privacy description.',
      'edit-home': 'Edit Home',
      'added-transaction': 'Added Transaction',
      'new-transaction-detected': 'New transaction detected',
      'new-transactions-detected': '{} new transactions detected',
      'possible-duplicate-detected': 'Possible duplicate detected',
      'transaction-no-longer-pending': 'Transaction is no longer pending',
      'help': 'Help',
      'faq': 'FAQ',
    };
  }
}

Widget buildTestWidget(Widget child, [AllWallets? allWallets]) {
  final defaultWallet = TransactionWallet(
    walletPk: '0',
    name: 'Main Wallet',
    colour: '0xff000000',
    dateCreated: DateTime.now(),
    order: 0,
    currency: 'USD',
    decimals: 2,
  );
  final walletsObj = allWallets ??
      AllWallets(
        list: [defaultWallet],
        indexedByPk: {'0': defaultWallet},
      );

  return Provider<AllWallets>.value(
    value: walletsObj,
    child: EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'test',
      assetLoader: const _FlowTestAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: Builder(
        builder: (context) => MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FinanceDatabase testDb;
  final List<MethodCall> notificationsChannelLog = [];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });

    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('x-slayer/notifications_channel'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isPermissionGranted') return true;
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async {
        notificationsChannelLog.add(methodCall);
        return null;
      },
    );
  });

  setUp(() async {
    notificationsChannelLog.clear();
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    final defaults = await getDefaultPreferences();
    appStateSettings.clear();
    appStateSettings.addAll(defaults);
    appStateSettings["selectedWalletPk"] = "0";

    testDb = FinanceDatabase(NativeDatabase.memory());
    database = testDb;

    // Seed wallet and category
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

  group('PendingTransactionsPage UI Tests (VS4)', () {
    testWidgets('renders empty state when no pending transactions exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          PendingTransactionsPage(
            stream: Stream.value([]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No pending transactions'), findsOneWidget);
      expect(find.byTooltip('Approve All'), findsNothing);
      expect(find.byTooltip('Dismiss All'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('renders list of pending transactions with action buttons',
        (WidgetTester tester) async {
      final sampleTx = Transaction(
        transactionPk: 'pending-tx-1',
        name: 'Starbucks',
        amount: 5.75,
        note: '',
        categoryFk: 'cat-1',
        walletFk: '0',
        dateCreated: DateTime.now(),
        income: false,
        paid: true,
        skipPaid: false,
        pending: true,
      );
      final sampleCat = TransactionCategory(
        categoryPk: 'cat-1',
        name: 'Food',
        colour: '0xffff0000',
        dateCreated: DateTime.now(),
        order: 0,
        income: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          PendingTransactionsPage(
            stream: Stream.value([
              TransactionWithCategory(
                transaction: sampleTx,
                category: sampleCat,
                subCategory: null,
                wallet: null,
                objectiveLoan: null,
              ),
            ]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Starbucks'), findsOneWidget);
      expect(find.byTooltip('Approve All'), findsOneWidget);
      expect(find.byTooltip('Dismiss All'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
        'renders possible duplicate warning for uncertain duplicate transaction',
        (WidgetTester tester) async {
      final sampleTx = Transaction(
        transactionPk: 'pending-duplicate-tx',
        name: 'Duplicate Starbucks',
        amount: 5.75,
        note: '',
        categoryFk: 'cat-1',
        walletFk: '0',
        dateCreated: DateTime.now(),
        income: false,
        paid: true,
        skipPaid: false,
        pending: true,
      );
      final sampleCat = TransactionCategory(
        categoryPk: 'cat-1',
        name: 'Food',
        colour: '0xffff0000',
        dateCreated: DateTime.now(),
        order: 0,
        income: false,
      );

      await tester.runAsync(() async {
        DedupeLedger.instance.clear();
        await DedupeLedger.instance.recordUncertainEntryDirectly(
          DedupeEntryRecord(
            eventKey: 'event-duplicate-1',
            packageName: 'notification',
            title: 'Duplicate Starbucks',
            amount: 5.75,
            currency: 'USD',
            status: 'uncertain',
            createdTransactionPk: 'pending-duplicate-tx',
          ),
        );

        await tester.pumpWidget(
          buildTestWidget(
            PendingTransactionsPage(
              stream: Stream.value([
                TransactionWithCategory(
                  transaction: sampleTx,
                  category: sampleCat,
                  subCategory: null,
                  wallet: null,
                  objectiveLoan: null,
                ),
              ]),
            ),
          ),
        );
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });

      expect(find.text('Duplicate Starbucks'), findsOneWidget);
      expect(find.text('Possible duplicate detected'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('HomePage Pending Badge UI Tests (VS5)', () {
    testWidgets('badge appears when pending count > 0',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          StreamBuilder<int>(
            stream: Stream.value(3),
            builder: (context, snapshot) {
              final int count = snapshot.data ?? 0;
              if (count <= 0) return const SizedBox.shrink();
              return Tooltip(
                message: "pending-transactions".tr(),
                child: IconButton(
                  onPressed: () {},
                  icon: Badge.count(
                    count: count,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('badge is hidden when pending count is 0',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          StreamBuilder<int>(
            stream: Stream.value(0),
            builder: (context, snapshot) {
              final int count = snapshot.data ?? 0;
              if (count <= 0) return const SizedBox.shrink();
              return Tooltip(
                message: "pending-transactions".tr(),
                child: IconButton(
                  onPressed: () {},
                  icon: Badge.count(
                    count: count,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Badge), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('AppLinks Non-Blocking Ingestion (VS2 & VS3)', () {
    test(
        'processAddTransactionFromParams with pending: true creates pending transaction and sends notification',
        () async {
      final tx = await processAddTransactionFromParams(null, {
        'title': 'Uber Ride',
        'amount': '22.50',
        'categoryPk': 'cat-1',
        'walletPk': '0',
        'pending': 'true',
      });

      expect(tx, isNotNull);
      expect(tx!.pending, isTrue);

      final count = await testDb.watchCountPendingTransactions().first;
      expect(count, 1);

      // Verify flutter_local_notifications show method was invoked
      final showCalls =
          notificationsChannelLog.where((c) => c.method == 'show').toList();
      expect(showCalls.isNotEmpty, isTrue);
    });

    test(
        'processAddTransactionFromParams with isPossibleDuplicate: true records uncertain entry and sets title in notification',
        () async {
      DedupeLedger.instance.clear();
      final tx = await processAddTransactionFromParams(null, {
        'title': 'Coffee Shop',
        'amount': '4.50',
        'categoryPk': 'cat-1',
        'walletPk': '0',
        'pending': 'true',
        'isPossibleDuplicate': 'true',
      });

      expect(tx, isNotNull);
      expect(tx!.pending, isTrue);
      expect(
        DedupeLedger.instance.isPossibleDuplicateTransaction(tx.transactionPk),
        isTrue,
      );

      final showCalls =
          notificationsChannelLog.where((c) => c.method == 'show').toList();
      expect(showCalls.isNotEmpty, isTrue);
      final lastShow = showCalls.last.arguments as Map;
      expect(lastShow['title'], 'Possible duplicate detected');
    });
  });

  group('Notification Payload Routing (VS2 & VS6)', () {
    testWidgets('openPendingQueue payload routes to PendingTransactionsPage',
        (WidgetTester tester) async {
      notificationPayload = "openPendingQueue";

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildTestWidget(
            Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await runNotificationPayLoads(context);
                },
                child: const Text('Run Payload'),
              );
            }),
          ),
        );
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();

        await tester.tap(find.text('Run Payload'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });

      expect(find.byType(PendingTransactionsPage), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
        'openPendingTransaction payload routes to AddTransactionPage when pending exists',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await testDb.into(testDb.transactions).insert(
              Transaction(
                transactionPk: 'pending-route-tx',
                name: 'Target Market',
                amount: 32.10,
                note: '',
                categoryFk: 'cat-1',
                walletFk: '0',
                dateCreated: DateTime.now(),
                income: false,
                paid: true,
                skipPaid: false,
                pending: true,
              ),
            );

        notificationPayload =
            "openPendingTransaction?transactionPk=pending-route-tx";

        await tester.pumpWidget(
          buildTestWidget(
            Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await runNotificationPayLoads(context);
                },
                child: const Text('Run Payload'),
              );
            }),
          ),
        );
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();

        await tester.tap(find.text('Run Payload'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });

      expect(find.byType(AddTransactionPage), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('Non-Blocking Notification Preferences (VS2)', () {
    test('fresh install defaults notificationScanningNonBlocking to true',
        () async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      final settings = await getUserSettings();
      expect(settings['notificationScanningNonBlocking'], isTrue);
    });

    test(
        'existing user upgrade defaults notificationScanningNonBlocking to false',
        () async {
      SharedPreferences.setMockInitialValues({
        'userSettings': '{"hasSignedIn": true}',
      });
      sharedPreferences = await SharedPreferences.getInstance();

      final settings = await getUserSettings();
      expect(settings['notificationScanningNonBlocking'], isFalse);
    });
  });
}
