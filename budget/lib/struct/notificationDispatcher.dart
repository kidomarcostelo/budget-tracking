import 'dart:async';
import 'dart:convert';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/backgroundService.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/dedupeLedger.dart';
import 'package:budget/struct/googlePayParser.dart';
import 'package:budget/struct/settings.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef TransactionQueueHandler = Future<dynamic> Function(
  String messageString, {
  bool willPushRoute,
  DateTime? dateTime,
  bool isPossibleDuplicate,
  DedupeEntryRecord? possibleDuplicateEntry,
});

typedef GooglePayTransactionHandler = Future<bool> Function(
  GooglePayTransactionResult result, {
  bool isPossibleDuplicate,
  DedupeEntryRecord? possibleDuplicateEntry,
});

/// Extracted payment parameters for deduplication ledger recording.
class ExtractedNotificationDetails {
  final double? amount;
  final String? currency;
  final String? title;

  const ExtractedNotificationDetails({
    this.amount,
    this.currency,
    this.title,
  });
}

/// Centralized dispatcher for Android NotificationListenerService events.
///
/// Ensures a single subscription owner to avoid duplicate stream events and
/// filters out notification removal events (`hasRemoved == true`) so that
/// dismissals do not generate duplicate transactions.
class NotificationDispatcher {
  NotificationDispatcher._();
  static final NotificationDispatcher instance = NotificationDispatcher._();

  StreamSubscription<ServiceNotificationEvent>? _subscription;
  final List<String> recentCapturedNotifications = [];

  /// Indicates whether the dispatcher currently has an active listener subscription.
  bool get isListening => _subscription != null;

  TransactionQueueHandler? queueHandler;
  GooglePayTransactionHandler? onGooglePayTransaction;

  static final RegExp _currencyPrefixRegex = RegExp(
    r'(?:(?<![a-zA-Z])([₱$€£¥₹]|P)\s*|\b(PHP|USD|EUR|GBP|JPY|CAD|AUD|SGD|INR|php|usd|eur|gbp|jpy|cad|aud|sgd|inr)\s*)'
    r'([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})?|[0-9]+(?:\.[0-9]{2})?)',
  );

  static final RegExp _currencySuffixRegex = RegExp(
    r'([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})?|[0-9]+(?:\.[0-9]{2})?)'
    r'\s*([₱$€£¥₹]|\b(?:PHP|USD|EUR|GBP|JPY|CAD|AUD|SGD|INR|php|usd|eur|gbp|jpy|cad|aud|sgd|inr)\b)',
  );

  static final RegExp _financialContextRegex = RegExp(
    r'\b(?:debited|debit|credited|credit|paid|pay|payment|sent|transferred|transfer|spent|received|charge|charged|total|amount|balance|fee|purchase|withdrawn|withdraw)\b',
    caseSensitive: false,
  );

  static final RegExp _monetaryDecimalRegex = RegExp(
    r'\b([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}|[0-9]+\.[0-9]{2})\b(?!\s*%)',
  );

  /// Normalizes currency symbols and codes to standard 3-letter ISO uppercase codes.
  static String? normalizeCurrency(String? raw) {
    if (raw == null) return null;
    final upper = raw.trim().toUpperCase();
    if (upper == 'P' || upper == '₱' || upper == 'PHP') return 'PHP';
    if (upper == '\$' || upper == 'USD') return 'USD';
    if (upper == '€' || upper == 'EUR') return 'EUR';
    if (upper == '£' || upper == 'GBP') return 'GBP';
    if (upper == '¥' || upper == 'JPY') return 'JPY';
    if (upper == '₹' || upper == 'INR') return 'INR';
    if (upper == 'CAD') return 'CAD';
    if (upper == 'AUD') return 'AUD';
    if (upper == 'SGD') return 'SGD';
    return upper;
  }

  /// Extracts numeric amount substring between delimiters.
  static double? extractAmountFromDelimiters(
    String messageString,
    String before,
    String after,
  ) {
    try {
      int startIndex = messageString.indexOf(before) + before.length;
      int endIndex = after.isEmpty
          ? messageString.length
          : messageString.indexOf(after, startIndex);
      if (endIndex == -1) endIndex = messageString.length;
      String amountString = messageString.substring(startIndex, endIndex);
      return double.tryParse(amountString.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (_) {
      return null;
    }
  }

  /// Extracts title substring between delimiters.
  static String? extractTitleFromDelimiters(
    String messageString,
    String before,
    String after,
  ) {
    try {
      int startIndex = messageString.indexOf(before) + before.length;
      int endIndex = after.isEmpty
          ? messageString.length
          : messageString.indexOf(after, startIndex);
      if (endIndex == -1) endIndex = messageString.length;
      String title = messageString.substring(startIndex, endIndex);
      title = title.replaceAll("\n", " ");
      title = title.replaceAll("\r", " ");
      title = title.replaceAll(RegExp(r'\s+'), ' ');
      title = title.trim();
      if (title.isNotEmpty) {
        title = title.toLowerCase();
        title = title.capitalizeFirst;
      }
      return title;
    } catch (_) {
      return null;
    }
  }

  /// Extracts amount and optional currency from free-form notification text.
  static ExtractedNotificationDetails? extractAmountAndCurrencyFromText(
    String text,
  ) {
    if (text.trim().isEmpty) return null;

    // 1. Check for prefix currency e.g. ₱3,600.00 or PHP 1,000.00 or P123.00
    final prefixMatch = _currencyPrefixRegex.firstMatch(text);
    if (prefixMatch != null) {
      final rawCurrency = prefixMatch.group(1) ?? prefixMatch.group(2);
      final rawAmount = prefixMatch.group(3);
      if (rawAmount != null) {
        final cleanAmount = rawAmount.replaceAll(',', '');
        final parsed = double.tryParse(cleanAmount);
        if (parsed != null && parsed > 0) {
          return ExtractedNotificationDetails(
            amount: parsed,
            currency: normalizeCurrency(rawCurrency),
          );
        }
      }
    }

    // 2. Check for suffix currency e.g. 250.00 PHP or 500 PHP
    final suffixMatch = _currencySuffixRegex.firstMatch(text);
    if (suffixMatch != null) {
      final rawAmount = suffixMatch.group(1);
      final rawCurrency = suffixMatch.group(2);
      if (rawAmount != null) {
        final cleanAmount = rawAmount.replaceAll(',', '');
        final parsed = double.tryParse(cleanAmount);
        if (parsed != null && parsed > 0) {
          return ExtractedNotificationDetails(
            amount: parsed,
            currency: normalizeCurrency(rawCurrency),
          );
        }
      }
    }

    // 3. Fallback to standard 2-decimal monetary pattern only if financial context is present
    if (_financialContextRegex.hasMatch(text)) {
      final decimalMatch = _monetaryDecimalRegex.firstMatch(text);
      if (decimalMatch != null) {
        final rawAmount = decimalMatch.group(1);
        if (rawAmount != null) {
          final cleanAmount = rawAmount.replaceAll(',', '');
          final parsed = double.tryParse(cleanAmount);
          if (parsed != null && parsed > 0) {
            return ExtractedNotificationDetails(
              amount: parsed,
              currency: null,
            );
          }
        }
      }
    }

    return null;
  }

  /// Extracts payment details (amount, currency, merchant/title) from an event
  /// using Google Pay parser, user ScannerTemplates, or regex text fallback.
  Future<ExtractedNotificationDetails> extractPaymentDetails(
    ServiceNotificationEvent event, {
    GooglePayTransactionResult? googlePayResult,
  }) async {
    // 1. Google Pay parser result takes precedence if present
    if (googlePayResult != null && googlePayResult.amount > 0) {
      return ExtractedNotificationDetails(
        amount: googlePayResult.amount,
        currency: googlePayResult.currency,
        title: googlePayResult.merchant,
      );
    }

    double? amount;
    String? currency;
    String? title = event.title;

    final messageString = formatNotificationMessage(event);

    // 2. Check user-configured ScannerTemplates from database
    if (appStateSettings["customTemplatesNotificationScanning"] != false) {
      try {
        final templates = await database.getAllScannerTemplates();
        for (final template in templates) {
          if (messageString.contains(template.contains)) {
            final extractedAmount = extractAmountFromDelimiters(
              messageString,
              template.amountTransactionBefore,
              template.amountTransactionAfter,
            );
            if (extractedAmount != null && extractedAmount > 0) {
              amount = extractedAmount;
              final extractedTitle = extractTitleFromDelimiters(
                messageString,
                template.titleTransactionBefore,
                template.titleTransactionAfter,
              );
              if (extractedTitle != null && extractedTitle.isNotEmpty) {
                title = extractedTitle;
              }
              if (template.walletFk != "-1" && template.walletFk != "0") {
                final wallet =
                    await database.getWalletInstanceOrNull(template.walletFk);
                if (wallet?.currency != null && wallet!.currency!.isNotEmpty) {
                  currency = normalizeCurrency(wallet.currency);
                }
              }
              break;
            }
          }
        }
      } catch (_) {
        // Ignored if database is not initialized (e.g. unit tests)
      }
    }

    // 3. Regex fallback on notification text (content and title)
    if (amount == null || amount <= 0) {
      final text = '${event.content ?? ''} ${event.title ?? ''}';
      final parsed = extractAmountAndCurrencyFromText(text);
      if (parsed != null) {
        amount = parsed.amount;
        currency ??= parsed.currency;
      }
    } else if (currency == null) {
      final text = '${event.content ?? ''} ${event.title ?? ''}';
      final parsed = extractAmountAndCurrencyFromText(text);
      if (parsed?.currency != null) {
        currency = parsed!.currency;
      }
    }

    // 4. Default wallet currency fallback if currency remains unknown
    if (amount != null && amount > 0 && currency == null) {
      try {
        final selectedWalletPk = appStateSettings["selectedWalletPk"];
        if (selectedWalletPk != null) {
          final defaultWallet =
              await database.getWalletInstanceOrNull(selectedWalletPk);
          if (defaultWallet?.currency != null &&
              defaultWallet!.currency!.isNotEmpty) {
            currency = normalizeCurrency(defaultWallet.currency);
          }
        }
      } catch (_) {}
    }

    return ExtractedNotificationDetails(
      amount: amount,
      currency: currency,
      title: title,
    );
  }

  /// Checks if notification listener access has been granted by the user.
  Future<bool> isPermissionGranted() async {
    try {
      return await NotificationListenerService.isPermissionGranted();
    } catch (e) {
      return false;
    }
  }

  /// Requests notification listener permission via system settings.
  Future<bool> requestReadNotificationPermission() async {
    try {
      bool status = await isPermissionGranted();
      if (status != true) {
        status = await NotificationListenerService.requestPermission();
      }
      return status;
    } catch (e) {
      return false;
    }
  }

  /// Initializes the single notification listener subscription if permitted and enabled.
  Future<void> initNotificationScanning({PlatformOS? platformOverride}) async {
    final platform = platformOverride ?? getPlatform(ignoreEmulation: true);
    if (platform != PlatformOS.isAndroid) return;
    await stopListening(platformOverride: platform);
    if (appStateSettings["notificationScanning"] != true) return;

    await DedupeLedger.instance.loadFromDatabase();

    bool status = await isPermissionGranted();
    if (status == true) {
      await flushBufferedNotifications();
      _subscription = NotificationListenerService.notificationsStream.listen(
        (event) => handleEvent(event),
      );
      await BackgroundServiceManager.instance
          .startKeepAlive(platformOverride: platform);
    }
  }

  /// Cancels the active stream subscription and stops background keep-alive.
  Future<void> stopListening({PlatformOS? platformOverride}) async {
    await _subscription?.cancel();
    _subscription = null;
    final platform = platformOverride ?? getPlatform(ignoreEmulation: true);
    await BackgroundServiceManager.instance
        .stopKeepAlive(platformOverride: platform);
  }

  static const String bufferStorageKey = "cashew_notification_buffer";

  /// Flushes any pending notifications buffered in native SharedPreferences while
  /// Cashew was terminated or inactive.
  ///
  /// Returns the number of events successfully flushed and dispatched.
  Future<int> flushBufferedNotifications({
    SharedPreferences? preferencesOverride,
  }) async {
    SharedPreferences? prefs = preferencesOverride;
    if (prefs == null) {
      try {
        prefs = sharedPreferences;
      } catch (_) {
        return 0;
      }
    }

    try {
      await prefs.reload();
    } catch (_) {}

    final rawBuffer = prefs.getString(bufferStorageKey);
    if (rawBuffer == null || rawBuffer.trim().isEmpty || rawBuffer == "[]") {
      return 0;
    }

    // Immediately clear the buffer in SharedPreferences to prevent double-flushing
    await prefs.setString(bufferStorageKey, "[]");

    List<dynamic> entries;
    try {
      final decoded = jsonDecode(rawBuffer);
      if (decoded is List) {
        entries = decoded;
      } else {
        return 0;
      }
    } catch (e) {
      print(
          "NotificationDispatcher: Failed to decode notification buffer JSON: $e");
      return 0;
    }

    int processedCount = 0;
    for (final entry in entries) {
      if (entry is! Map) continue;
      try {
        final idVal = entry["id"];
        final timestampVal = entry["timestamp"];
        final event = ServiceNotificationEvent(
          id: idVal is int
              ? idVal
              : (int.tryParse(idVal?.toString() ?? '') ?? 0),
          packageName: entry["packageName"]?.toString() ?? '',
          title: entry["title"]?.toString() ?? '',
          content: entry["content"]?.toString() ?? '',
          hasRemoved: false,
          canReply: false,
          haveExtraPicture: false,
          onGoing: false,
          timestamp: timestampVal is int
              ? timestampVal
              : (int.tryParse(timestampVal?.toString() ?? '') ?? 0),
          appIcon: null,
          extrasPicture: null,
          largeIcon: null,
        );

        final handled = await handleEvent(event);
        if (handled) processedCount++;
      } catch (e) {
        print("NotificationDispatcher: Error handling buffered event: $e");
      }
    }

    return processedCount;
  }

  /// Appends a raw message string to [recentCapturedNotifications], maintaining a max size of 50.
  void addCapturedNotification(String messageString) {
    recentCapturedNotifications.insert(0, messageString);
    if (recentCapturedNotifications.length > 50) {
      recentCapturedNotifications.removeRange(
          50, recentCapturedNotifications.length);
    }
  }

  /// Formats a [ServiceNotificationEvent] into Cashew's standard notification message string.
  static String formatNotificationMessage(ServiceNotificationEvent event) {
    String output = "";
    output = output + "Package name: " + event.packageName.toString() + "\n";
    output =
        output + "Notification removed: " + event.hasRemoved.toString() + "\n";
    output = output + "\n----\n\n";
    output = output + "Notification Title: " + event.title.toString() + "\n\n";
    output = output + "Notification Content: " + event.content.toString();
    return output;
  }

  /// Checks if the package belongs to Google Wallet or Google Pay ecosystem.
  bool isGooglePayPackage(String? packageName) {
    return GooglePayParser.isRecognizedPackage(packageName);
  }

  /// Processes an incoming [ServiceNotificationEvent].
  ///
  /// Returns `true` if the event was an active notification and dispatched for
  /// transaction queuing, or `false` if ignored (e.g. `hasRemoved == true`).
  Future<bool> handleEvent(
    ServiceNotificationEvent event, {
    TransactionQueueHandler? customQueueHandler,
  }) async {
    // Ignore notification removal/dismissal events to prevent duplicate transactions.
    if (event.hasRemoved == true) {
      return false;
    }

    final isGPayPackage = isGooglePayPackage(event.packageName);
    final isGooglePayScanningEnabled =
        appStateSettings["googlePayNotificationScanning"] ?? true;

    // Critical Spec: When an event is from a Google Pay package and Google Pay
    // scanning is disabled, immediately return early without polluting the
    // deduplication ledger or falling through to generic templates.
    if (isGPayPackage && !isGooglePayScanningEnabled) {
      return false;
    }

    final isCustomTemplatesScanningEnabled =
        appStateSettings["customTemplatesNotificationScanning"] ?? true;

    // Parse potential payment fields for Google Pay if from a recognized package
    final googlePayResult = (isGPayPackage && isGooglePayScanningEnabled)
        ? GooglePayParser.parse(event.title, event.content)
        : null;

    // When custom templates scanning is disabled and this notification is not a
    // parsed Google Pay payment transaction, drop it early if no custom queue handler
    // was supplied (preventing unparseable notifications and non-Google-Pay events
    // from polluting the dedupe ledger).
    if (!isCustomTemplatesScanningEnabled &&
        googlePayResult == null &&
        customQueueHandler == null) {
      return false;
    }
    final details = await extractPaymentDetails(
      event,
      googlePayResult: googlePayResult,
    );
    final dedupeResult = await DedupeLedger.instance.checkAndRecordNotification(
      packageName: event.packageName,
      notificationId: event.id?.toString(),
      amount: details.amount,
      currency: details.currency,
      title: details.title ?? event.title,
      rawContent: event.content,
      eventTime: event.timestamp != null && event.timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(event.timestamp)
          : null,
    );

    // Suppress duplicate events within the time window
    if (dedupeResult.isDuplicate) {
      return false;
    }

    String messageString = formatNotificationMessage(event);
    addCapturedNotification(messageString);

    // If custom queue handler was supplied (e.g. in tests), prioritize it
    if (customQueueHandler != null) {
      await customQueueHandler(
        messageString,
        isPossibleDuplicate: dedupeResult.isUncertainMatch,
        possibleDuplicateEntry: dedupeResult.matchedEntry,
      );
      return true;
    }

    // Check if event is from Google Wallet / Google Pay
    if (isGooglePayScanningEnabled && GooglePayParser.isGooglePayEvent(event)) {
      // googlePayResult was parsed above for deduplication check
      if (googlePayResult != null) {
        if (onGooglePayTransaction != null) {
          await onGooglePayTransaction!(
            googlePayResult,
            isPossibleDuplicate: dedupeResult.isUncertainMatch,
            possibleDuplicateEntry: dedupeResult.matchedEntry,
          );
          return true;
        }
        await GooglePayParser.processGooglePayTransaction(
          googlePayResult,
          isPossibleDuplicate: dedupeResult.isUncertainMatch,
          possibleDuplicateEntry: dedupeResult.matchedEntry,
        );
        return true;
      }
    }

    if (!isCustomTemplatesScanningEnabled) {
      return false;
    }

    TransactionQueueHandler? handler = queueHandler;
    if (handler != null) {
      await handler(
        messageString,
        isPossibleDuplicate: dedupeResult.isUncertainMatch,
        possibleDuplicateEntry: dedupeResult.matchedEntry,
      );
    }

    return true;
  }
}
