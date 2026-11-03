import 'dart:ffi';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/autoTransactionsPageEmail.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/defaultPreferences.dart';
import 'package:budget/struct/dedupeLedger.dart';
import 'package:budget/struct/googlePayParser.dart';
import 'package:budget/struct/notificationDispatcher.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/statusBox.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'auto-transactions-title': 'Auto Transactions',
      'auto-transactions-notifications-description':
          'Transactions can be created automatically based on notifications received on your device.',
      'notification-transactions': 'Notification Transactions',
      'notification-transactions-description':
          'When a transaction notification arrives, Cashew captures it locally on-device to prefill a transaction for confirmation. Create templates or use supported payment apps.',
      'google-pay-transactions': 'Google Wallet & Google Pay',
      'google-pay-transactions-description':
          'Automatically detect and parse transactions from Google Wallet and Google Pay notifications.',
      'notification-permission-granted': 'Notification Access Granted',
      'notification-permission-granted-description':
          'Cashew is listening for incoming transaction notifications.',
      'notification-permission-required': 'Notification Access Required',
      'notification-permission-required-description':
          'Cashew needs Notification Access to detect incoming payment alerts. Please enable it in system settings.',
      'open-notification-settings': 'Open Notification Settings',
      'notification-privacy-title': 'On-Device Privacy & Permissions',
      'notification-privacy-description':
          'All notification parsing occurs entirely on your device with zero cloud data transmission. Under Google Play policies, SMS permissions are restricted to default SMS apps. Android Notification Access provides a secure, privacy-preserving alternative to capture payment alerts locally without accessing your personal text messages.',
      'notification-configuration-missing': 'No Custom Templates Added',
      'notification-configuration-missing-description':
          'Add a template if you wish to parse notifications from other banking apps.',
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
        theme: getLightTheme(),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: child,
      ),
    ),
  );
}

ServiceNotificationEvent createTestEvent({
  int id = 1,
  String packageName = 'com.google.android.apps.walletnfcrel',
  String title = 'Google Wallet',
  String content = 'Paid PHP 250.00 at 7-Eleven with MariBank',
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

void main() {
  bool mockPermissionGranted = false;
  int requestPermissionCallCount = 0;
  late FinanceDatabase testDb;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();

    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });

    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('x-slayer/notifications_channel'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isPermissionGranted') {
          return mockPermissionGranted;
        } else if (methodCall.method == 'requestPermission') {
          requestPermissionCallCount++;
          mockPermissionGranted = true;
          return true;
        }
        return null;
      },
    );
  });

  setUp(() async {
    testDb = FinanceDatabase(NativeDatabase.memory());
    database = testDb;
    DedupeLedger.instance.clear();
    mockPermissionGranted = false;
    requestPermissionCallCount = 0;

    final defaults = await getDefaultPreferences();
    appStateSettings.clear();
    appStateSettings.addAll(defaults);

    appStateSettings["selectedWalletPk"] = "test-wallet";
    appStateSettings["notificationScanning"] = true;
    appStateSettings["googlePayNotificationScanning"] = true;
  });

  tearDown(() async {
    DedupeLedger.instance.clear();
  });

  group('NotificationDispatcher googlePayNotificationScanning gating', () {
    test(
        'dispatches to Google Pay handler when googlePayNotificationScanning is true',
        () async {
      appStateSettings["notificationScanning"] = true;
      appStateSettings["googlePayNotificationScanning"] = true;

      final dispatcher = NotificationDispatcher.instance;
      dispatcher.recentCapturedNotifications.clear();

      GooglePayTransactionResult? receivedGPayResult;
      int genericQueueCount = 0;

      dispatcher.onGooglePayTransaction = (
        res, {
        bool isPossibleDuplicate = false,
        DedupeEntryRecord? possibleDuplicateEntry,
      }) async {
        receivedGPayResult = res;
        return true;
      };

      dispatcher.queueHandler = (
        msg, {
        dateTime,
        willPushRoute = true,
        bool isPossibleDuplicate = false,
        DedupeEntryRecord? possibleDuplicateEntry,
      }) async {
        genericQueueCount++;
      };

      final event = createTestEvent();
      final handled = await dispatcher.handleEvent(event);

      expect(handled, isTrue);
      expect(receivedGPayResult, isNotNull);
      expect(receivedGPayResult!.merchant, equals('7-Eleven'));
      expect(receivedGPayResult!.amount, equals(250.0));
      expect(genericQueueCount, equals(0));
    });

    test(
        'bypasses Google Pay handler and falls through to generic queueHandler when googlePayNotificationScanning is false',
        () async {
      appStateSettings["notificationScanning"] = true;
      appStateSettings["googlePayNotificationScanning"] = false;

      final dispatcher = NotificationDispatcher.instance;
      dispatcher.recentCapturedNotifications.clear();

      GooglePayTransactionResult? receivedGPayResult;
      String? receivedGenericMessage;

      dispatcher.onGooglePayTransaction = (
        res, {
        bool isPossibleDuplicate = false,
        DedupeEntryRecord? possibleDuplicateEntry,
      }) async {
        receivedGPayResult = res;
        return true;
      };

      dispatcher.queueHandler = (
        msg, {
        dateTime,
        willPushRoute = true,
        bool isPossibleDuplicate = false,
        DedupeEntryRecord? possibleDuplicateEntry,
      }) async {
        receivedGenericMessage = msg;
      };

      final event = createTestEvent();
      final handled = await dispatcher.handleEvent(event);

      expect(handled, isTrue);
      expect(receivedGPayResult, isNull);
      expect(receivedGenericMessage, isNotNull);
      expect(receivedGenericMessage,
          contains('Package name: com.google.android.apps.walletnfcrel'));
    });
  });

  group(
      'AutoTransactionsPageNotifications Settings & Permission UX Widget Tests',
      () {
    testWidgets('renders legacy-updated description and primary toggle',
        (WidgetTester tester) async {
      appStateSettings["notificationScanning"] = false;

      await tester.pumpWidget(
        buildTestableWidget(
          const AutoTransactionsPageNotifications(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check header description
      expect(
        find.text(
          'Transactions can be created automatically based on notifications received on your device.',
        ),
        findsOneWidget,
      );

      // Check master switch title & description
      expect(find.text('Notification Transactions'), findsOneWidget);

      expect(
        find.text(
          'When a transaction notification arrives, Cashew captures it locally on-device to prefill a transaction for confirmation. Create templates or use supported payment apps.',
        ),
        findsOneWidget,
      );

      // When notificationScanning is false, Google Pay toggle and permission boxes are hidden
      expect(find.text('Google Wallet & Google Pay'), findsNothing);
      expect(find.text('Notification Access Required'), findsNothing);
      expect(find.text('Notification Access Granted'), findsNothing);

      // On-device privacy card is visible
      expect(find.text('On-Device Privacy & Permissions'), findsOneWidget);
      expect(
        find.text(
          'All notification parsing occurs entirely on your device with zero cloud data transmission. Under Google Play policies, SMS permissions are restricted to default SMS apps. Android Notification Access provides a secure, privacy-preserving alternative to capture payment alerts locally without accessing your personal text messages.',
        ),
        findsOneWidget,
      );

      // Default scanner templates empty state
      expect(find.text('No Custom Templates Added'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
        'displays Google Pay toggle and permission-required warning when notificationScanning is true but permission not granted',
        (WidgetTester tester) async {
      appStateSettings["notificationScanning"] = true;
      appStateSettings["googlePayNotificationScanning"] = true;
      mockPermissionGranted = false;

      await tester.pumpWidget(
        buildTestableWidget(
          const AutoTransactionsPageNotifications(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Google Pay toggle is visible
      expect(find.text('Google Wallet & Google Pay'), findsOneWidget);
      expect(
        find.text(
          'Automatically detect and parse transactions from Google Wallet and Google Pay notifications.',
        ),
        findsOneWidget,
      );

      // Permission required indicator and action button are visible
      expect(find.text('Notification Access Required'), findsOneWidget);
      expect(
        find.text(
          'Cashew needs Notification Access to detect incoming payment alerts. Please enable it in system settings.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open Notification Settings'), findsOneWidget);

      // Tapping "Open Notification Settings" requests permission
      await tester.tap(find.text('Open Notification Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(requestPermissionCallCount, equals(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
        'displays permission-granted indicator when notificationScanning is true and permission is granted',
        (WidgetTester tester) async {
      appStateSettings["notificationScanning"] = true;
      appStateSettings["googlePayNotificationScanning"] = true;
      mockPermissionGranted = true;

      await tester.pumpWidget(
        buildTestableWidget(
          const AutoTransactionsPageNotifications(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Permission granted indicator is visible
      expect(find.text('Notification Access Granted'), findsOneWidget);
      expect(
        find.text(
            'Cashew is listening for incoming transaction notifications.'),
        findsOneWidget,
      );

      // Warning and open settings button are not displayed
      expect(find.text('Notification Access Required'), findsNothing);
      expect(find.text('Open Notification Settings'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('toggling Google Pay switch updates preference',
        (WidgetTester tester) async {
      appStateSettings["notificationScanning"] = true;
      appStateSettings["googlePayNotificationScanning"] = true;
      mockPermissionGranted = true;

      await tester.pumpWidget(
        buildTestableWidget(
          const AutoTransactionsPageNotifications(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find the Google Pay switch by its title
      final gpaySwitchFinder = find.ancestor(
        of: find.text('Google Wallet & Google Pay'),
        matching: find.byType(SettingsContainerSwitch),
      );
      expect(gpaySwitchFinder, findsOneWidget);

      // Tap the switch to toggle it off
      await tester.tap(gpaySwitchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(appStateSettings["googlePayNotificationScanning"], isFalse);

      // Tap again to toggle it on
      await tester.tap(gpaySwitchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(appStateSettings["googlePayNotificationScanning"], isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
