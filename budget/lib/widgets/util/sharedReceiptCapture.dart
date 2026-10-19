import 'dart:async';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/shareIntentOcr.dart';
import 'package:budget/struct/sharedReceiptProcessor.dart';
import 'package:budget/struct/throttler.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openSnackbar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Throttler _shareIntentThrottler =
    Throttler(duration: const Duration(milliseconds: 500));

/// Widget listening for shared banking receipts (Android ACTION_SEND),
/// extracting transaction details via ML Kit OCR and launching
/// AddTransactionPage.
class InitializeSharedReceiptCapture extends StatefulWidget {
  const InitializeSharedReceiptCapture({required this.child, super.key});
  final Widget child;

  @override
  State<InitializeSharedReceiptCapture> createState() =>
      _InitializeSharedReceiptCaptureState();
}

class _InitializeSharedReceiptCaptureState
    extends State<InitializeSharedReceiptCapture> {
  StreamSubscription<SharedPayload>? _subscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && getPlatform(ignoreEmulation: true) == PlatformOS.isAndroid) {
      _initShareCapture();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initShareCapture() async {
    ShareIntentOcrService.initialize(onPayload: (payload) {
      _handlePayload(payload);
    });

    _subscription =
        ShareIntentOcrService.sharedDataStream.listen(_handlePayload);

    // Check cold-start launch intent
    Future.delayed(const Duration(milliseconds: 200), () async {
      final initial = await ShareIntentOcrService.getInitialSharedData();
      if (initial != null) {
        _handlePayload(initial);
      }
    });
  }

  Future<void> _handlePayload(SharedPayload payload) async {
    if (!payload.isImage || payload.filePath == null) return;
    if (!_shareIntentThrottler.canProceed()) return;

    final filePath = payload.filePath!;

    // Wait until app framework and navigator context are mounted
    int attempts = 0;
    while ((navigatorKey.currentContext == null || !entireAppLoaded) &&
        attempts < 40) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;
    if (appStateSettings['hasOnboarded'] != true) return;

    try {
      final receipt =
          await SharedReceiptProcessor.processSharedImage(filePath);
      if (receipt == null) {
        openSnackbar(SnackbarMessage(
          title: 'failed-to-preview-image'.tr(),
          icon: appStateSettings['outlinedIcons']
              ? Icons.receipt_long_outlined
              : Icons.receipt_long_rounded,
        ));
        return;
      }

      final matchedWallet =
          await SharedReceiptProcessor.resolveWallet(receipt);
      final matchedCategory =
          await SharedReceiptProcessor.resolveCategory(receipt);
      final title = SharedReceiptProcessor.formatTitle(receipt);
      final notes = SharedReceiptProcessor.formatNotes(receipt);

      await Future.delayed(const Duration(milliseconds: 100), () async {
        await pushRoute(
          context,
          AddTransactionPage(
            routesToPopAfterDelete: RoutesToPopAfterDelete.None,
            selectedAmount: receipt.amount,
            selectedDate: receipt.dateTime ?? DateTime.now(),
            selectedTitle: title,
            selectedNotes: notes,
            selectedIncome: false,
            selectedWallet: matchedWallet,
            selectedCategory: matchedCategory,
            startInitialAddTransactionSequence: false,
          ),
        );
      });

      openSnackbar(SnackbarMessage(
        title: 'added-transaction'.tr(),
        description: '${receipt.institutionName}: ${receipt.currency} '
            '${receipt.amount.toStringAsFixed(2)}',
        icon: appStateSettings['outlinedIcons']
            ? Icons.receipt_long_outlined
            : Icons.receipt_long_rounded,
      ));
    } catch (_) {
      // Gracefully ignore extraction errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
