import 'dart:async';
import 'package:budget/functions.dart';
import 'package:flutter/services.dart';

/// Manages the native Android Keep-Alive foreground service and
/// battery optimization settings to ensure uninterrupted tap-to-pay
/// and transaction notification scanning.
class BackgroundServiceManager {
  BackgroundServiceManager._();
  static final BackgroundServiceManager instance = BackgroundServiceManager._();

  MethodChannel channel =
      const MethodChannel('com.budget.tracker_app/background_service');

  Future<bool> _invokeNativeAction(
    String method, {
    PlatformOS? platformOverride,
    bool nonAndroidFallback = false,
  }) async {
    final platform = platformOverride ?? getPlatform(ignoreEmulation: true);
    if (platform != PlatformOS.isAndroid) return nonAndroidFallback;
    try {
      final bool? result = await channel.invokeMethod<bool>(method);
      return result ?? true;
    } catch (e) {
      print('BackgroundServiceManager: Error invoking $method: $e');
      return false;
    }
  }

  /// Starts the Android keep-alive foreground service.
  ///
  /// Keeps the Flutter engine and [NotificationDispatcher] resident in memory
  /// while the screen is locked or Google Wallet is in the foreground.
  Future<bool> startKeepAlive({PlatformOS? platformOverride}) =>
      _invokeNativeAction('startKeepAlive', platformOverride: platformOverride);

  /// Stops the Android keep-alive foreground service.
  Future<bool> stopKeepAlive({PlatformOS? platformOverride}) =>
      _invokeNativeAction('stopKeepAlive', platformOverride: platformOverride);

  /// Checks if Cashew is currently exempt from Android battery optimizations.
  Future<bool> isIgnoringBatteryOptimizations({
    PlatformOS? platformOverride,
  }) async {
    final platform = platformOverride ?? getPlatform(ignoreEmulation: true);
    if (platform != PlatformOS.isAndroid) return true;
    try {
      final bool? result =
          await channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      print(
          'BackgroundServiceManager: Error checking battery optimizations: $e');
      return false;
    }
  }

  /// Prompts the Android system dialog/settings to exempt Cashew from battery optimizations.
  Future<bool> requestIgnoreBatteryOptimizations({
    PlatformOS? platformOverride,
  }) =>
      _invokeNativeAction(
        'requestIgnoreBatteryOptimizations',
        platformOverride: platformOverride,
      );
}
