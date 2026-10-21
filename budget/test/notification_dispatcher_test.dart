import 'package:budget/struct/notificationDispatcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notification_listener_service/notification_event.dart';

void main() {
  group('NotificationDispatcher.formatNotificationMessage', () {
    test('formats event details according to Cashew standard notification format',
        () {
      final event = ServiceNotificationEvent.fromMap({
        'id': 42,
        'packageName': 'com.google.android.apps.walletnfcrel',
        'title': 'Google Wallet Payment',
        'content': 'Paid PHP 250.00 at Merchant',
        'hasRemoved': false,
      });

      final formatted = NotificationDispatcher.formatNotificationMessage(event);

      expect(formatted, contains('Package name: com.google.android.apps.walletnfcrel\n'));
      expect(formatted, contains('Notification removed: false\n'));
      expect(formatted, contains('Notification Title: Google Wallet Payment\n\n'));
      expect(formatted, contains('Notification Content: Paid PHP 250.00 at Merchant'));
    });
  });

  group('NotificationDispatcher.handleEvent', () {
    late NotificationDispatcher dispatcher;

    setUp(() {
      dispatcher = NotificationDispatcher.instance;
      dispatcher.recentCapturedNotifications.clear();
      dispatcher.queueHandler = null;
    });

    test('ignores notification removal events (hasRemoved == true)', () async {
      final removedEvent = ServiceNotificationEvent.fromMap({
        'id': 101,
        'packageName': 'com.bdo.bank',
        'title': 'Debit Alert',
        'content': 'PHP 1,000.00 withdrawn',
        'hasRemoved': true,
      });

      bool queueCalled = false;
      final handled = await dispatcher.handleEvent(
        removedEvent,
        customQueueHandler: (msg, {dateTime, willPushRoute = true}) async {
          queueCalled = true;
        },
      );

      expect(handled, isFalse);
      expect(queueCalled, isFalse);
      expect(dispatcher.recentCapturedNotifications, isEmpty);
    });

    test('dispatches active posted notification (hasRemoved == false)', () async {
      final postedEvent = ServiceNotificationEvent.fromMap({
        'id': 102,
        'packageName': 'com.maya',
        'title': 'Payment Sent',
        'content': 'You paid PHP 500.00 to Merchant',
        'hasRemoved': false,
      });

      String? queuedMessage;
      final handled = await dispatcher.handleEvent(
        postedEvent,
        customQueueHandler: (msg, {dateTime, willPushRoute = true}) async {
          queuedMessage = msg;
        },
      );

      expect(handled, isTrue);
      expect(queuedMessage, isNotNull);
      expect(queuedMessage, contains('Package name: com.maya'));
      expect(queuedMessage, contains('Notification Content: You paid PHP 500.00 to Merchant'));
      expect(dispatcher.recentCapturedNotifications.length, equals(1));
      expect(dispatcher.recentCapturedNotifications.first, equals(queuedMessage));
    });

    test('prevents duplicates when notification is posted then dismissed', () async {
      final postedEvent = ServiceNotificationEvent.fromMap({
        'id': 200,
        'packageName': 'com.gotyme',
        'title': 'Debit Card Purchase',
        'content': 'PHP 300.00 at Coffee Shop',
        'hasRemoved': false,
      });

      final removedEvent = ServiceNotificationEvent.fromMap({
        'id': 200,
        'packageName': 'com.gotyme',
        'title': 'Debit Card Purchase',
        'content': 'PHP 300.00 at Coffee Shop',
        'hasRemoved': true,
      });

      int queueCount = 0;
      Future<void> testHandler(String msg,
          {DateTime? dateTime, bool willPushRoute = true}) async {
        queueCount++;
      }

      // 1. Notification posted
      final postedResult = await dispatcher.handleEvent(
        postedEvent,
        customQueueHandler: testHandler,
      );
      expect(postedResult, isTrue);
      expect(queueCount, equals(1));
      expect(dispatcher.recentCapturedNotifications.length, equals(1));

      // 2. Notification subsequently dismissed by user
      final removedResult = await dispatcher.handleEvent(
        removedEvent,
        customQueueHandler: testHandler,
      );
      expect(removedResult, isFalse);
      // Queue count remains 1 (no duplicate transaction triggered)
      expect(queueCount, equals(1));
      expect(dispatcher.recentCapturedNotifications.length, equals(1));
    });
  });

  group('NotificationDispatcher.addCapturedNotification capping', () {
    test('caps recentCapturedNotifications to 50 items', () {
      final dispatcher = NotificationDispatcher.instance;
      dispatcher.recentCapturedNotifications.clear();

      for (int i = 0; i < 60; i++) {
        dispatcher.addCapturedNotification('Notification #$i');
      }

      expect(dispatcher.recentCapturedNotifications.length, equals(50));
      expect(dispatcher.recentCapturedNotifications.first, equals('Notification #59'));
      expect(dispatcher.recentCapturedNotifications.last, equals('Notification #10'));
    });
  });
}
