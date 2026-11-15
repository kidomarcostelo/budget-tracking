import 'package:budget/functions.dart';
import 'package:budget/struct/backgroundService.dart';
import 'package:budget/struct/notificationDispatcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notification_listener_service/notification_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundServiceManager', () {
    late List<MethodCall> log;

    setUp(() {
      log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        BackgroundServiceManager.instance.channel,
        (MethodCall methodCall) async {
          log.add(methodCall);
          switch (methodCall.method) {
            case 'startKeepAlive':
              return true;
            case 'stopKeepAlive':
              return true;
            case 'isIgnoringBatteryOptimizations':
              return false;
            case 'requestIgnoreBatteryOptimizations':
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        BackgroundServiceManager.instance.channel,
        null,
      );
    });

    test('startKeepAlive invokes native method on Android', () async {
      final result = await BackgroundServiceManager.instance
          .startKeepAlive(platformOverride: PlatformOS.isAndroid);
      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, equals('startKeepAlive'));
    });

    test('stopKeepAlive invokes native method on Android', () async {
      final result = await BackgroundServiceManager.instance
          .stopKeepAlive(platformOverride: PlatformOS.isAndroid);
      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, equals('stopKeepAlive'));
    });

    test('isIgnoringBatteryOptimizations checks system status on Android',
        () async {
      final result = await BackgroundServiceManager.instance
          .isIgnoringBatteryOptimizations(
              platformOverride: PlatformOS.isAndroid);
      expect(result, isFalse);
      expect(log, hasLength(1));
      expect(log.first.method, equals('isIgnoringBatteryOptimizations'));
    });

    test('requestIgnoreBatteryOptimizations requests exemption on Android',
        () async {
      final result = await BackgroundServiceManager.instance
          .requestIgnoreBatteryOptimizations(
              platformOverride: PlatformOS.isAndroid);
      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, equals('requestIgnoreBatteryOptimizations'));
    });

    test('non-Android platform safely no-ops without invoking channel',
        () async {
      final startRes = await BackgroundServiceManager.instance
          .startKeepAlive(platformOverride: PlatformOS.isIOS);
      final stopRes = await BackgroundServiceManager.instance
          .stopKeepAlive(platformOverride: PlatformOS.isIOS);
      final optRes = await BackgroundServiceManager.instance
          .isIgnoringBatteryOptimizations(platformOverride: PlatformOS.isIOS);
      final reqRes = await BackgroundServiceManager.instance
          .requestIgnoreBatteryOptimizations(platformOverride: PlatformOS.isIOS);

      expect(startRes, isFalse);
      expect(stopRes, isFalse);
      expect(optRes, isTrue); // Non-Android treated as unaffected
      expect(reqRes, isFalse);
      expect(log, isEmpty);
    });

    test('stopListening triggers stopKeepAlive', () async {
      await NotificationDispatcher.instance
          .stopListening(platformOverride: PlatformOS.isAndroid);

      expect(log, hasLength(1));
      expect(log.first.method, equals('stopKeepAlive'));
    });

    test(
        'notification event is successfully processed by dispatcher while keep-alive is active',
        () async {
      final dispatcher = NotificationDispatcher.instance;
      String? queuedMessage;
      dispatcher.queueHandler = (messageString,
          {dateTime,
          isPossibleDuplicate = false,
          possibleDuplicateEntry,
          willPushRoute = true}) async {
        queuedMessage = messageString;
      };

      final keepAliveStarted = await BackgroundServiceManager.instance
          .startKeepAlive(platformOverride: PlatformOS.isAndroid);
      expect(keepAliveStarted, isTrue);
      expect(log.first.method, equals('startKeepAlive'));

      final event = ServiceNotificationEvent(
        id: 99,
        packageName: 'com.bank.app',
        title: 'Payment Sent',
        content: 'You paid PHP 500.00 at Store',
        hasRemoved: false,
        canReply: false,
        haveExtraPicture: false,
        onGoing: false,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        appIcon: null,
        extrasPicture: null,
        largeIcon: null,
      );

      final handled = await dispatcher.handleEvent(event);
      expect(handled, isTrue);
      expect(queuedMessage, contains('Package name: com.bank.app'));
      expect(queuedMessage, contains('You paid PHP 500.00 at Store'));
    });
  });
}
