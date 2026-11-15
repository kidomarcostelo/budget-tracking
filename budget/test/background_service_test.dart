import 'package:budget/functions.dart';
import 'package:budget/struct/backgroundService.dart';
import 'package:budget/struct/notificationDispatcher.dart';
import 'package:budget/struct/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
