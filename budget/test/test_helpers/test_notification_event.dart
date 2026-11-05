import 'package:notification_listener_service/notification_event.dart';

/// Helper factory to generate [ServiceNotificationEvent] instances for unit and widget testing.
ServiceNotificationEvent createTestEvent({
  int id = 1,
  String packageName = 'com.google.android.apps.walletnfcrel',
  String title = 'Google Wallet',
  String content = 'Paid PHP 250.00 at 7-Eleven with MariBank',
  bool hasRemoved = false,
  bool canReply = false,
  bool haveExtraPicture = false,
  bool onGoing = false,
  int timestamp = 0,
}) {
  return ServiceNotificationEvent(
    id: id,
    packageName: packageName,
    title: title,
    content: content,
    hasRemoved: hasRemoved,
    canReply: canReply,
    haveExtraPicture: haveExtraPicture,
    onGoing: onGoing,
    timestamp: timestamp,
    appIcon: null,
    extrasPicture: null,
    largeIcon: null,
  );
}
