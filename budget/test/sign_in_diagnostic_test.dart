import 'package:budget/widgets/accountAndBackup.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveSignInErrorMessage', () {
    test('identifies user cancellation', () {
      expect(
        resolveSignInErrorMessage('Login failed'),
        'Sign-in was cancelled.',
      );
      expect(
        resolveSignInErrorMessage('User cancelled sign in flow'),
        'Sign-in was cancelled.',
      );
      expect(
        resolveSignInErrorMessage('Login cancelled'),
        'Sign-in was cancelled.',
      );
    });

    test('identifies developer configuration error ApiException: 10', () {
      const errorString =
          'PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)';
      final result = resolveSignInErrorMessage(errorString);
      expect(
        result,
        contains('ApiException 10'),
      );
      expect(
        result,
        contains('SHA-1 or package mismatch'),
      );

      final developerError =
          PlatformException(code: 'sign_in_failed', message: 'DEVELOPER_ERROR');
      expect(
        resolveSignInErrorMessage(developerError),
        contains('ApiException 10'),
      );
    });

    test('identifies Play Services error ApiException: 12500', () {
      const errorString =
          'PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 12500: , null, null)';
      final result = resolveSignInErrorMessage(errorString);
      expect(
        result,
        contains('ApiException 12500'),
      );
    });

    test('falls back to localized connection error for network or unknown errors', () {
      expect(
        resolveSignInErrorMessage('SocketException: Failed host lookup'),
        'sign-in-error-description'.tr(),
      );
      expect(
        resolveSignInErrorMessage('TimeoutException after 0:00:05.000000'),
        'sign-in-error-description'.tr(),
      );
      expect(
        resolveSignInErrorMessage('Some unexpected error'),
        'sign-in-error-description'.tr(),
      );
    });
  });
}
