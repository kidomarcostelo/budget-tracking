import 'dart:async';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Model representing an individual deduplication ledger entry.
class DedupeEntryRecord {
  final String entryPk;
  final String eventKey;
  final String? packageName;
  final String? notificationId;
  final double? amount;
  final String? amountNormalized;
  final String? currency;
  final String? title;
  final String? rawContent;
  final String source;
  final DateTime dateTimeCreated;
  final DateTime? notificationTimestamp;
  String status;
  String? createdTransactionPk;
  String? matchedEntryPk;

  DedupeEntryRecord({
    String? entryPk,
    required this.eventKey,
    this.packageName,
    this.notificationId,
    this.amount,
    this.amountNormalized,
    this.currency,
    this.title,
    this.rawContent,
    this.source = 'notification',
    DateTime? dateTimeCreated,
    this.notificationTimestamp,
    this.status = 'created',
    this.createdTransactionPk,
    this.matchedEntryPk,
  })  : entryPk = entryPk ?? _uuid.v4(),
        dateTimeCreated = dateTimeCreated ?? DateTime.now();
}

/// Result returned by [DedupeLedger] when checking incoming events.
class DedupeCheckResult {
  final bool isDuplicate;
  final bool isUncertainMatch;
  final String? matchReason;
  final List<String> matchReasons;
  final DedupeEntryRecord? matchedEntry;
  final DedupeEntryRecord? uncertainEntry;
  final String? matchedKey;
  final DateTime? matchedTime;

  const DedupeCheckResult.unique({this.matchedEntry, this.uncertainEntry})
      : isDuplicate = false,
        isUncertainMatch = false,
        matchReason = null,
        matchReasons = const [],
        matchedKey = null,
        matchedTime = null;

  const DedupeCheckResult.duplicate({
    required this.matchReason,
    this.matchReasons = const [],
    this.matchedEntry,
    this.uncertainEntry,
    this.matchedKey,
    this.matchedTime,
  })  : isDuplicate = true,
        isUncertainMatch = false;

  const DedupeCheckResult.uncertain({
    required this.matchReason,
    this.matchReasons = const [],
    this.matchedEntry,
    this.uncertainEntry,
    this.matchedKey,
    this.matchedTime,
  })  : isDuplicate = false,
        isUncertainMatch = true;
}

/// Structured context holding merchant identification details for deduplication matching.
class DedupeMerchantContext {
  final String? title;
  final String? rawContent;
  final String? source;
  final String? packageName;

  const DedupeMerchantContext({
    this.title,
    this.rawContent,
    this.source,
    this.packageName,
  });

  DedupeMerchantContext.fromEntry(DedupeEntryRecord entry)
      : title = entry.title,
        rawContent = entry.rawContent,
        source = entry.source,
        packageName = entry.packageName;
}

/// In-memory and persistent ledger tracking notification and payment events to
/// prevent duplicate transaction prompts within a configurable time window.
class DedupeLedger {
  static DedupeLedger instance = DedupeLedger();

  final List<DedupeEntryRecord> entries = [];
  final List<DedupeEntryRecord> suppressedEntries = [];
  final List<DedupeEntryRecord> uncertainEntries = [];

  static const Duration defaultWindow = Duration(minutes: 5);
  static const int maxLedgerCapacity = 200;

  static const Set<String> genericMerchantTitles = {
    'google wallet',
    'google pay',
    'google',
    'wallet',
    'gpay',
    'payment',
    'purchase',
    'bank transfer',
    'money sent',
    'transfer sent',
    'card purchase',
    'transaction',
    'notification title',
  };

  static const Set<String> genericActionWords = {
    'purchase',
    'payment',
    'pay',
    'paid',
    'transfer',
    'transferred',
    'alert',
    'sent',
    'send',
    'received',
    'receive',
    'debit',
    'debited',
    'credit',
    'credited',
    'notification',
    'transaction',
    'notice',
    'update',
    'bank',
    'wallet',
    'card',
    'money',
    'successful',
    'success',
    'details',
    'info',
    'message',
    'fund',
    'funds',
    'online',
    'account',
    'balance',
    'available',
    'statement',
    'reference',
    'ref',
    'bill',
    'charge',
    'charged',
    'ending',
    'authorization',
    'auth',
    'total',
    'amount',
    'store',
    'shop',
    'mart',
    'market',
    'supermarket',
    'cafe',
    'restaurant',
    'bakery',
    'boutique',
  };

  static const Set<String> genericFillerWords = {
    'the',
    'a',
    'an',
    'to',
    'from',
    'of',
    'for',
    'in',
    'at',
    'on',
    'your',
    'my',
    'new',
    'via',
    'by',
    'with',
    'and',
    'or',
    'is',
    'was',
    'has',
    'have',
    'been',
  };

  static const Set<String> commonCurrencyCodes = {
    'php',
    'usd',
    'eur',
    'gbp',
    'jpy',
    'cad',
    'aud',
    'sgd',
    'inr',
    'cny',
    'hkd',
    'nzd',
  };

  /// Checks if a title is composed purely of generic banking / notification action terms.
  static bool isGenericTitle(String? title) {
    if (title == null || title.trim().isEmpty) return true;
    final lower = title.trim().toLowerCase();
    if (genericMerchantTitles.contains(lower)) return true;

    final words =
        lower.split(RegExp(r'[\s\-_:,.]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return true;

    // A title is generic ONLY if ALL its words are generic action or filler words!
    // (e.g. "Purchase Alert", "Payment Notification", "Debit Alert")
    // If it contains ANY specific entity or merchant name (e.g. "Apple Purchase", "Credit Union", "Starbucks"), it is not generic.
    return words.every((w) =>
        genericActionWords.contains(w) ||
        genericFillerWords.contains(w) ||
        commonCurrencyCodes.contains(w));
  }

  /// Clears in-memory ledger entries (primarily for test isolation).
  void clear() {
    entries.clear();
    suppressedEntries.clear();
    uncertainEntries.clear();
  }

  /// Normalizes monetary amounts to fixed 2-decimal strings to prevent IEEE 754 float comparison drift.
  static String? normalizeAmount(double? amount) {
    if (amount == null) return null;
    return amount.toStringAsFixed(2);
  }

  /// Strips gateway / aggregator prefixes like "SQ *MERCHANT", "PAYPAL *MERCHANT" (BT-2 §c).
  static String cleanMerchant(String text) {
    var s = text.trim().toLowerCase();
    s = s.replaceAll(
        RegExp(r'^[a-zA-Z0-9]{2,10}\s*\*\s*', caseSensitive: false), '');
    return s.trim();
  }

  /// Extracts potential merchant name from notification text after common prepositions.
  static String? extractMerchantFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;

    // Prioritize "at <merchant>" as it specifically designates merchant/business locations.
    Match? match =
        RegExp(r'\bat\s+([^,.\n]+)', caseSensitive: false).firstMatch(text);

    // Fallback: look for "to <payee/merchant>", skipping account/card destinations
    if (match == null) {
      final toMatches =
          RegExp(r'\bto\s+([^,.\n]+)', caseSensitive: false).allMatches(text);
      for (final m in toMatches) {
        final candidate = m.group(1)!.trim();
        if (!RegExp(
                r'^(?:account|card|wallet|\*{2,4}|\d{4}|your\s+account|savings|checking)\b',
                caseSensitive: false)
            .hasMatch(candidate)) {
          match = m;
          break;
        }
      }
    }

    if (match != null) {
      String m = match.group(1)!.trim();
      // Strip trailing clauses: with card, via rail, using wallet, on card/account, ref number, for description
      m = m
          .replaceAll(
              RegExp(r'\s+(?:with|via|using|for)\s+.*$', caseSensitive: false),
              '')
          .trim();
      m = m
          .replaceAll(
              RegExp(r'\s+on\s+(?:card|account|\*{2,4}|\d{4}).*$',
                  caseSensitive: false),
              '')
          .trim();
      m = m
          .replaceAll(
              RegExp(r'\s+ref(?:erence)?(?:\s*#|\s*:|\s+no|\s*\d+)?.*$',
                  caseSensitive: false),
              '')
          .trim();
      m = m.replaceAll(RegExp(r'[\.!\?]+$'), '').trim();

      // Strip aggregator prefix e.g. "SQ *MERCHANT"
      m = cleanMerchant(m);

      if (m.isNotEmpty && !isGenericTitle(m)) {
        return m.toLowerCase();
      }
    }
    return null;
  }

  /// Computes Jaro-Winkler similarity between two strings (returns 0.0 to 1.0).
  /// Performs case folding and trimming per BT-2 research §(c).
  static double jaroWinklerSimilarity(String s1, String s2) {
    final str1 = s1.trim().toLowerCase();
    final str2 = s2.trim().toLowerCase();
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    final int len1 = str1.length;
    final int len2 = str2.length;
    final int maxLen = len1 > len2 ? len1 : len2;
    final int matchDistance = maxLen ~/ 2 > 0 ? (maxLen ~/ 2 - 1) : 0;

    final List<bool> s1Matches = List<bool>.filled(len1, false);
    final List<bool> s2Matches = List<bool>.filled(len2, false);

    int matches = 0;
    for (int i = 0; i < len1; i++) {
      final int start = (i - matchDistance > 0) ? i - matchDistance : 0;
      final int end =
          (i + matchDistance + 1 < len2) ? i + matchDistance + 1 : len2;

      for (int j = start; j < end; j++) {
        if (s2Matches[j]) continue;
        if (str1[i] != str2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    int transpositions = 0;
    int k = 0;
    for (int i = 0; i < len1; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (str1[i] != str2[k]) {
        transpositions++;
      }
      k++;
    }

    final double jaro = (matches / len1 +
            matches / len2 +
            (matches - transpositions / 2) / matches) /
        3.0;

    // Winkler standard prefix bonus (up to 4 matching initial characters)
    int prefix = 0;
    const int maxPrefix = 4;
    for (int i = 0; i < len1 && i < len2 && i < maxPrefix; i++) {
      if (str1[i] == str2[i]) {
        prefix++;
      } else {
        break;
      }
    }

    return jaro + prefix * 0.1 * (1.0 - jaro);
  }

  /// Extracts significant non-generic tokens from a string.
  static Set<String> extractNonGenericTokens(String? text) {
    if (text == null || text.trim().isEmpty) return const {};
    final words = text
        .trim()
        .toLowerCase()
        .split(RegExp(r'[\s\-_:,.]+'))
        .where((w) => w.length >= 2)
        .toList();
    return words
        .where((w) =>
            !genericActionWords.contains(w) &&
            !genericFillerWords.contains(w) &&
            !commonCurrencyCodes.contains(w) &&
            !RegExp(r'^\d+$').hasMatch(w))
        .toSet();
  }

  /// Evaluates whether two events share corroborating merchant details.
  /// Accepts structured [DedupeMerchantContext] or [DedupeEntryRecord] instances.
  static bool hasCorroboratingMerchant({
    DedupeMerchantContext? first,
    DedupeMerchantContext? second,
    DedupeEntryRecord? entry1,
    DedupeEntryRecord? entry2,
  }) {
    final ctx1 = first ??
        (entry1 != null ? DedupeMerchantContext.fromEntry(entry1) : null);
    final ctx2 = second ??
        (entry2 != null ? DedupeMerchantContext.fromEntry(entry2) : null);
    if (ctx1 == null || ctx2 == null) return false;
    return hasCorroboratingContext(ctx1, ctx2);
  }

  /// Evaluates whether two structured contexts share corroborating merchant details.
  static bool hasCorroboratingContext(
    DedupeMerchantContext first,
    DedupeMerchantContext second,
  ) {
    final t1 = first.title?.trim().toLowerCase();
    final t2 = second.title?.trim().toLowerCase();
    final c1 = first.rawContent?.trim().toLowerCase() ?? '';
    final c2 = second.rawContent?.trim().toLowerCase() ?? '';

    // If both titles are identical non-generic strings, they corroborate
    if (t1 != null && t2 != null && t1.isNotEmpty && t1 == t2) {
      if (!isGenericTitle(t1)) {
        return true;
      }
    }

    final isGen1 = isGenericTitle(t1);
    final isGen2 = isGenericTitle(t2);

    final textM1 = extractMerchantFromText(first.rawContent);
    final textM2 = extractMerchantFromText(second.rawContent);

    // If both contents have extracted merchant names and they corroborate
    if (textM1 != null && textM2 != null) {
      final cleanText1 = cleanMerchant(textM1);
      final cleanText2 = cleanMerchant(textM2);
      if (cleanText1 == cleanText2 ||
          cleanText1.contains(cleanText2) ||
          cleanText2.contains(cleanText1)) {
        return true;
      }
      if (jaroWinklerSimilarity(cleanText1, cleanText2) >= 0.90) {
        return true;
      }
    }

    final rawM1 = textM1 ?? (!isGen1 ? t1 : null);
    final rawM2 = textM2 ?? (!isGen2 ? t2 : null);

    final m1 = rawM1 != null ? cleanMerchant(rawM1) : null;
    final m2 = rawM2 != null ? cleanMerchant(rawM2) : null;

    if (m1 != null && m2 != null && m1.isNotEmpty && m2.isNotEmpty) {
      if (m1 == m2 || m1.contains(m2) || m2.contains(m1)) {
        return true;
      }
      if (jaroWinklerSimilarity(m1, m2) >= 0.90) {
        return true;
      }
      if (c1.contains(m2) || c2.contains(m1)) {
        return true;
      }
      final tokens1 = extractNonGenericTokens(m1);
      final tokens2 = extractNonGenericTokens(m2);
      if (tokens1.isNotEmpty &&
          tokens2.isNotEmpty &&
          tokens1.intersection(tokens2).isNotEmpty) {
        return true;
      }
      // Both have distinct non-matching merchants -> conflicting details!
      return false;
    }

    if (m1 != null &&
        m1.isNotEmpty &&
        (c2.contains(m1) || (t2 != null && !isGen2 && t2.contains(m1)))) {
      return true;
    }

    if (m2 != null &&
        m2.isNotEmpty &&
        (c1.contains(m2) || (t1 != null && !isGen1 && t1.contains(m2)))) {
      return true;
    }

    // Check if token overlap from an identified merchant matches content
    if (m1 != null && m1.isNotEmpty) {
      final tokens1 = extractNonGenericTokens(m1);
      if (tokens1.isNotEmpty) {
        final cWords2 = extractNonGenericTokens(c2);
        if (tokens1.intersection(cWords2).isNotEmpty) {
          return true;
        }
      }
    }
    if (m2 != null && m2.isNotEmpty) {
      final tokens2 = extractNonGenericTokens(m2);
      if (tokens2.isNotEmpty) {
        final cWords1 = extractNonGenericTokens(c1);
        if (tokens2.intersection(cWords1).isNotEmpty) {
          return true;
        }
      }
    }

    return false;
  }

  /// Determines whether two events have distinct conflicting merchants.
  static bool hasConflictingMerchant(
    DedupeMerchantContext first,
    DedupeMerchantContext second,
  ) {
    final t1 = first.title?.trim().toLowerCase();
    final t2 = second.title?.trim().toLowerCase();
    final isGen1 = isGenericTitle(t1);
    final isGen2 = isGenericTitle(t2);

    final textM1 = extractMerchantFromText(first.rawContent);
    final textM2 = extractMerchantFromText(second.rawContent);

    final rawM1 = textM1 ?? (!isGen1 ? t1 : null);
    final rawM2 = textM2 ?? (!isGen2 ? t2 : null);

    final m1 = rawM1 != null ? cleanMerchant(rawM1) : null;
    final m2 = rawM2 != null ? cleanMerchant(rawM2) : null;

    if (m1 != null && m2 != null && m1.isNotEmpty && m2.isNotEmpty) {
      return !hasCorroboratingContext(first, second);
    }
    return false;
  }

  /// Builds a deterministic key for exact notification identity.
  static String generateExactNotificationKey(
    String? packageName,
    String? notificationId,
  ) {
    return 'notif:${packageName ?? ''}:${notificationId ?? ''}';
  }

  /// Builds a normalized payment key based on amount and currency.
  static String generatePaymentKey({
    required double amount,
    String? currency,
  }) {
    final normAmount = normalizeAmount(amount) ?? '0.00';
    final normCurrency = currency?.trim().toUpperCase() ?? '';
    return 'pay:$normAmount:$normCurrency';
  }

  void _pruneList(List<DedupeEntryRecord> list) {
    if (list.length > maxLedgerCapacity) {
      list.removeRange(0, list.length - maxLedgerCapacity);
    }
  }

  /// Safely attempts to persist an entry to Drift if the database is initialized.
  Future<void> _tryPersist(DedupeEntryRecord record) async {
    try {
      await database
          .insertDedupeEntry(
            DedupeEntriesCompanion(
              entryPk: Value(record.entryPk),
              eventKey: Value(record.eventKey),
              packageName: Value(record.packageName),
              notificationId: Value(record.notificationId),
              amount: Value(record.amount),
              amountNormalized: Value(record.amountNormalized),
              currency: Value(record.currency),
              title: Value(record.title),
              rawContent: Value(record.rawContent),
              source: Value(record.source),
              dateTimeCreated: Value(record.dateTimeCreated),
              notificationTimestamp: Value(record.notificationTimestamp),
              status: Value(record.status),
              createdTransactionPk: Value(record.createdTransactionPk),
              matchedEntryPk: Value(record.matchedEntryPk),
            ),
          )
          .timeout(const Duration(milliseconds: 200), onTimeout: () => -1);
    } catch (e) {
      // In tests or headless isolate where database might not be initialized, fail gracefully
    }
  }

  Future<void> _recordSuppressedEntry(DedupeEntryRecord suppressed) async {
    suppressedEntries.add(suppressed);
    _pruneList(suppressedEntries);
    await _tryPersist(suppressed);
  }

  Future<void> _recordUncertainEntry(DedupeEntryRecord uncertain) async {
    uncertainEntries.add(uncertain);
    _pruneList(uncertainEntries);
    await _tryPersist(uncertain);
  }

  /// Promotes an uncertain entry to confirmed [entries] (e.g. after user confirms/saves transaction).
  Future<void> confirmUncertainEntry(
    DedupeEntryRecord entry, {
    String? createdTransactionPk,
  }) async {
    uncertainEntries.removeWhere((e) => e.entryPk == entry.entryPk);
    entry.status = 'created';
    if (createdTransactionPk != null) {
      entry.createdTransactionPk = createdTransactionPk;
    }
    entries.add(entry);
    _pruneList(entries);
    try {
      final rowsUpdated = await database.updateDedupeEntryStatus(
        entry.entryPk,
        'created',
        createdTransactionPk: createdTransactionPk,
      );
      if (rowsUpdated == 0) {
        await _tryPersist(entry);
      }
    } catch (_) {
      // Ignored if running without Drift database
    }
  }

  /// Promotes an uncertain entry by its matched entry primary key (used by AddTransactionPage review save).
  Future<void> confirmUncertainEntryForMatchedPk(
    String matchedEntryPk, {
    String? createdTransactionPk,
  }) async {
    final matchIndex = uncertainEntries.lastIndexWhere(
      (e) => e.matchedEntryPk == matchedEntryPk,
    );
    if (matchIndex != -1) {
      final entry = uncertainEntries[matchIndex];
      await confirmUncertainEntry(
        entry,
        createdTransactionPk: createdTransactionPk,
      );
    }
  }

  Future<void> _recordEntry(DedupeEntryRecord entry) async {
    entries.add(entry);
    _pruneList(entries);
    await _tryPersist(entry);
  }

  /// Searches active ledger entries for an exact notification match within [window].
  DedupeEntryRecord? findExactNotificationMatch({
    required String? packageName,
    required String? notificationId,
    required DateTime now,
    required Duration window,
  }) {
    if (packageName == null ||
        packageName.isEmpty ||
        notificationId == null ||
        notificationId.isEmpty) {
      return null;
    }
    for (final existing in entries.reversed) {
      if (existing.packageName == packageName &&
          existing.notificationId == notificationId) {
        final diff = now.difference(existing.dateTimeCreated).abs();
        if (diff <= window) {
          return existing;
        }
      }
    }
    for (final existing in uncertainEntries.reversed) {
      if (existing.packageName == packageName &&
          existing.notificationId == notificationId) {
        final diff = now.difference(existing.dateTimeCreated).abs();
        if (diff <= window) {
          return existing;
        }
      }
    }
    return null;
  }

  /// Searches active ledger entries for all candidate payment matches by amount and currency within [window].
  List<DedupeEntryRecord> findPaymentCandidates({
    required String? normAmount,
    required String? normCurrency,
    required DateTime now,
    required Duration window,
  }) {
    if (normAmount == null) return const [];
    final candidates = <DedupeEntryRecord>[];
    for (final existing in entries.reversed) {
      if (existing.amountNormalized == normAmount) {
        if (normCurrency != null &&
            existing.currency != null &&
            normCurrency != existing.currency) {
          continue;
        }
        final diff = now.difference(existing.dateTimeCreated).abs();
        if (diff <= window) {
          candidates.add(existing);
        }
      }
    }
    return candidates;
  }

  /// Searches active ledger entries for the most recent payment match within [window].
  DedupeEntryRecord? findPaymentMatch({
    required String? normAmount,
    required String? normCurrency,
    required DateTime now,
    required Duration window,
  }) {
    final candidates = findPaymentCandidates(
      normAmount: normAmount,
      normCurrency: normCurrency,
      now: now,
      window: window,
    );
    return candidates.isNotEmpty ? candidates.first : null;
  }

  /// Loads recent deduplication entries from Drift if available.
  Future<void> loadFromDatabase({Duration? window = defaultWindow}) async {
    try {
      final dbEntries =
          await database.getAllDedupeEntries(limit: maxLedgerCapacity);
      final existingPks = {
        for (final e in entries) e.entryPk,
        for (final e in suppressedEntries) e.entryPk,
        for (final e in uncertainEntries) e.entryPk,
      };
      final cutoff = window != null ? DateTime.now().subtract(window) : null;
      for (final e in dbEntries.reversed) {
        if (existingPks.contains(e.entryPk)) continue;
        if (cutoff != null && e.dateTimeCreated.isBefore(cutoff)) continue;
        final rec = DedupeEntryRecord(
          entryPk: e.entryPk,
          eventKey: e.eventKey,
          packageName: e.packageName,
          notificationId: e.notificationId,
          amount: e.amount,
          amountNormalized: e.amountNormalized,
          currency: e.currency,
          title: e.title,
          rawContent: e.rawContent,
          source: e.source,
          dateTimeCreated: e.dateTimeCreated,
          notificationTimestamp: e.notificationTimestamp,
          status: e.status,
          createdTransactionPk: e.createdTransactionPk,
          matchedEntryPk: e.matchedEntryPk,
        );
        if (e.status == 'suppressed') {
          suppressedEntries.add(rec);
        } else if (e.status == 'uncertain') {
          uncertainEntries.add(rec);
        } else {
          entries.add(rec);
        }
      }
      _pruneList(entries);
      _pruneList(suppressedEntries);
      _pruneList(uncertainEntries);
    } catch (_) {
      // Ignored if database is unavailable
    }
  }

  /// Checks if a notification event is a duplicate within [window] and records it.
  Future<DedupeCheckResult> checkAndRecordNotification({
    required String? packageName,
    required String? notificationId,
    double? amount,
    String? currency,
    String? title,
    String? rawContent,
    DateTime? eventTime,
    Duration window = defaultWindow,
  }) async {
    final now = eventTime ?? DateTime.now();
    final normAmount = normalizeAmount(amount);
    final normCurrency = currency?.trim().toUpperCase();

    // 1. Tier 1: Exact Notification Check (same packageName and notificationId)
    final exactMatch = findExactNotificationMatch(
      packageName: packageName,
      notificationId: notificationId,
      now: now,
      window: window,
    );
    if (exactMatch != null) {
      final suppressed = DedupeEntryRecord(
        eventKey: generateExactNotificationKey(packageName, notificationId),
        packageName: packageName,
        notificationId: notificationId,
        amount: amount,
        amountNormalized: normAmount,
        currency: normCurrency,
        title: title,
        rawContent: rawContent,
        source: 'notification',
        dateTimeCreated: now,
        notificationTimestamp: eventTime,
        status: 'suppressed',
        matchedEntryPk: exactMatch.entryPk,
      );
      await _recordSuppressedEntry(suppressed);
      return DedupeCheckResult.duplicate(
        matchReason: 'exact_notification',
        matchReasons: const [
          'exact_notification',
          'package_and_id_exact',
        ],
        matchedEntry: exactMatch,
        matchedKey: exactMatch.eventKey,
        matchedTime: exactMatch.dateTimeCreated,
      );
    }

    // 2. Tier 2: Payment Window Match (same amount within time window across packages)
    if (amount != null && amount > 0 && normAmount != null) {
      final candidates = findPaymentCandidates(
        normAmount: normAmount,
        normCurrency: normCurrency,
        now: now,
        window: window,
      );
      if (candidates.isNotEmpty) {
        return await _resolvePaymentMatch(
          candidates: candidates,
          currentContext: DedupeMerchantContext(
            title: title,
            rawContent: rawContent,
            source: 'notification',
            packageName: packageName,
          ),
          eventKey: generateExactNotificationKey(packageName, notificationId),
          packageName: packageName,
          notificationId: notificationId,
          amount: amount,
          normAmount: normAmount,
          normCurrency: normCurrency,
          title: title,
          rawContent: rawContent,
          source: 'notification',
          now: now,
          eventTime: eventTime,
        );
      }
    }

    // 3. Unique event: record as created
    final newEntry = DedupeEntryRecord(
      eventKey: generateExactNotificationKey(packageName, notificationId),
      packageName: packageName,
      notificationId: notificationId,
      amount: amount,
      amountNormalized: normAmount,
      currency: normCurrency,
      title: title,
      rawContent: rawContent,
      source: 'notification',
      dateTimeCreated: now,
      notificationTimestamp: eventTime,
      status: 'created',
    );
    await _recordEntry(newEntry);

    return const DedupeCheckResult.unique();
  }

  /// Checks if a payment event (e.g. from App Link or Shortcut) is duplicate within [window].
  Future<DedupeCheckResult> checkAndRecordPayment({
    required double amount,
    String? currency,
    String? title,
    String source = 'app_link',
    String? packageName,
    String? notificationId,
    DateTime? eventTime,
    Duration window = defaultWindow,
  }) async {
    final now = eventTime ?? DateTime.now();
    final normAmount = normalizeAmount(amount);
    final normCurrency = currency?.trim().toUpperCase();

    if (normAmount != null) {
      final candidates = findPaymentCandidates(
        normAmount: normAmount,
        normCurrency: normCurrency,
        now: now,
        window: window,
      );
      if (candidates.isNotEmpty) {
        return await _resolvePaymentMatch(
          candidates: candidates,
          currentContext: DedupeMerchantContext(
            title: title,
            rawContent: null,
            source: source,
            packageName: packageName,
          ),
          eventKey: generatePaymentKey(
            amount: amount,
            currency: normCurrency,
          ),
          packageName: packageName,
          notificationId: notificationId,
          amount: amount,
          normAmount: normAmount,
          normCurrency: normCurrency,
          title: title,
          rawContent: null,
          source: source,
          now: now,
          eventTime: eventTime,
        );
      }
    }

    final newEntry = DedupeEntryRecord(
      eventKey: generatePaymentKey(
        amount: amount,
        currency: normCurrency,
      ),
      packageName: packageName,
      notificationId: notificationId,
      amount: amount,
      amountNormalized: normAmount,
      currency: normCurrency,
      title: title,
      source: source,
      dateTimeCreated: now,
      notificationTimestamp: eventTime,
      status: 'created',
    );
    await _recordEntry(newEntry);

    return const DedupeCheckResult.unique();
  }

  /// Resolves payment candidates into either a confirmed duplicate suppression or an uncertain match.
  Future<DedupeCheckResult> _resolvePaymentMatch({
    required List<DedupeEntryRecord> candidates,
    required DedupeMerchantContext currentContext,
    required String eventKey,
    required String? packageName,
    required String? notificationId,
    required double amount,
    required String? normAmount,
    required String? normCurrency,
    required String? title,
    required String? rawContent,
    required String source,
    required DateTime now,
    required DateTime? eventTime,
  }) async {
    DedupeEntryRecord? corroboratedMatch;
    for (final candidate in candidates) {
      if (hasCorroboratingMerchant(
        first: DedupeMerchantContext.fromEntry(candidate),
        second: currentContext,
      )) {
        corroboratedMatch = candidate;
        break;
      }
    }

    if (corroboratedMatch != null) {
      final suppressed = DedupeEntryRecord(
        eventKey: eventKey,
        packageName: packageName,
        notificationId: notificationId,
        amount: amount,
        amountNormalized: normAmount,
        currency: normCurrency,
        title: title,
        rawContent: rawContent,
        source: source,
        dateTimeCreated: now,
        notificationTimestamp: eventTime,
        status: 'suppressed',
        matchedEntryPk: corroboratedMatch.entryPk,
      );
      await _recordSuppressedEntry(suppressed);
      return DedupeCheckResult.duplicate(
        matchReason: 'payment_window_match',
        matchReasons: const [
          'payment_window_match',
          'amount_exact',
          'currency_exact',
          'time_within_window',
          'merchant_corroborated',
        ],
        matchedEntry: corroboratedMatch,
        matchedKey: corroboratedMatch.eventKey,
        matchedTime: corroboratedMatch.dateTimeCreated,
      );
    } else {
      final matchedCandidate = candidates.firstWhere(
        (c) => c.status == 'created',
        orElse: () => candidates.first,
      );
      final hasConflict = candidates.any((c) => hasConflictingMerchant(
            DedupeMerchantContext.fromEntry(c),
            currentContext,
          ));
      final uncertain = DedupeEntryRecord(
        eventKey: eventKey,
        packageName: packageName,
        notificationId: notificationId,
        amount: amount,
        amountNormalized: normAmount,
        currency: normCurrency,
        title: title,
        rawContent: rawContent,
        source: source,
        dateTimeCreated: now,
        notificationTimestamp: eventTime,
        status: 'uncertain',
        matchedEntryPk: matchedCandidate.entryPk,
      );
      await _recordUncertainEntry(uncertain);
      return DedupeCheckResult.uncertain(
        matchReason: 'uncertain_merchant',
        matchReasons: [
          'uncertain_merchant',
          'amount_exact',
          'currency_exact',
          'time_within_window',
          if (hasConflict) 'conflicting_merchant',
        ],
        matchedEntry: matchedCandidate,
        uncertainEntry: uncertain,
        matchedKey: matchedCandidate.eventKey,
        matchedTime: matchedCandidate.dateTimeCreated,
      );
    }
  }
}
