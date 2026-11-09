import 'package:budget/widgets/accountAndBackup.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveSignInErrorMessage', () {
    test('identifies user cancellation', () {
      expect(
        resolveSignInErrorMessage('Login failed'),
        'sign-in-cancelled'.tr(),
      );
      expect(
        resolveSignInErrorMessage('User cancelled sign in flow'),
        'sign-in-cancelled'.tr(),
      );
      expect(
        resolveSignInErrorMessage('Login cancelled'),
        'sign-in-cancelled'.tr(),
      );
      expect(
        resolveSignInErrorMessage(
          PlatformException(code: 'sign_in_canceled'),
        ),
        'sign-in-cancelled'.tr(),
      );
    });

    test('identifies developer configuration error ApiException: 10', () {
      const errorString = 'PlatformException(sign_in_failed, '
          'com.google.android.gms.common.api.ApiException: 10: , null, null)';
      expect(
        resolveSignInErrorMessage(errorString),
        'sign-in-config-error'.tr(),
      );

      final developerError = PlatformException(
        code: 'sign_in_failed',
        message: 'DEVELOPER_ERROR',
      );
      expect(
        resolveSignInErrorMessage(developerError),
        'sign-in-config-error'.tr(),
      );
    });

    test('identifies Play Services error ApiException: 12500', () {
      const errorString = 'PlatformException(sign_in_failed, '
          'com.google.android.gms.common.api.ApiException: 12500: '
          ', null, null)';
      expect(
        resolveSignInErrorMessage(errorString),
        'sign-in-play-services-error'.tr(),
      );

      final playServicesError = PlatformException(
        code: 'sign_in_failed',
        message: 'ApiException: 12500',
      );
      expect(
        resolveSignInErrorMessage(playServicesError),
        'sign-in-play-services-error'.tr(),
      );
    });

    test('identifies genuine network errors for connection description', () {
      expect(
        resolveSignInErrorMessage('SocketException: Failed host lookup'),
        'sign-in-error-description'.tr(),
      );
      expect(
        resolveSignInErrorMessage('TimeoutException after 0:00:05.000000'),
        'sign-in-error-description'.tr(),
      );
      expect(
        resolveSignInErrorMessage('NetworkException: network_error'),
        'sign-in-error-description'.tr(),
      );
    });

    test('falls back to generic sign-in error for unknown errors', () {
      expect(
        resolveSignInErrorMessage('Some unexpected internal error'),
        'sign-in-error'.tr(),
      );
    });
  });
}
