import 'package:intl/intl.dart';

/// Supported banking and e-wallet institutions.
enum BankInstitution {
  goTyme,
  maya,
  mariBank,
  unionBank,
  unknown,
}

/// Parsed financial details from a banking receipt screenshot or OCR text.
class ParsedBankReceipt {
  final BankInstitution institution;
  final String institutionName;
  final double amount;
  final String currency;
  final DateTime? dateTime;
  final String? referenceNumber;
  final String? sourceAccount;
  final String? destinationAccount;
  final String? destinationName;
  final bool isTransfer;
  final String? note;
  final String rawText;

  const ParsedBankReceipt({
    required this.institution,
    required this.institutionName,
    required this.amount,
    this.currency = 'PHP',
    this.dateTime,
    this.referenceNumber,
    this.sourceAccount,
    this.destinationAccount,
    this.destinationName,
    this.isTransfer = false,
    this.note,
    required this.rawText,
  });

  @override
  String toString() {
    return 'ParsedBankReceipt('
        'institution: $institutionName, '
        'amount: $currency $amount, '
        'ref: $referenceNumber, '
        'date: $dateTime, '
        'isTransfer: $isTransfer, '
        'from: $sourceAccount -> to: $destinationAccount ($destinationName))';
  }
}

/// Robust on-device parser for Philippine banking receipts (OCR output).
class BankReceiptParser {
  /// Detect the bank institution from OCR text.
  static BankInstitution detectInstitution(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('gotyme')) return BankInstitution.goTyme;
    if (lower.contains('maya') || lower.contains('paymaya')) {
      return BankInstitution.maya;
    }
    if (lower.contains('maribank')) return BankInstitution.mariBank;
    if (lower.contains('unionbank') ||
        lower.contains('union bank') ||
        lower.contains('ub1') ||
        lower.contains('ub2')) {
      return BankInstitution.unionBank;
    }
    return BankInstitution.unknown;
  }

  /// Parse raw OCR text into a structured receipt.
  static ParsedBankReceipt? parse(String text) {
    if (text.trim().isEmpty) return null;

    final institution = detectInstitution(text);
    switch (institution) {
      case BankInstitution.goTyme:
        return _parseGoTyme(text);
      case BankInstitution.maya:
        return _parseMaya(text);
      case BankInstitution.mariBank:
        return _parseMariBank(text);
      case BankInstitution.unionBank:
        return _parseUnionBank(text);
      case BankInstitution.unknown:
        return _parseGeneric(text);
    }
  }

  static ParsedBankReceipt? _parseGoTyme(String text) {
    final amount = _extractAmount(text, [
      RegExp(r'(?:Amount|Transferred|Total)\s*[₱PHP]?\s*([0-9,]+\.[0-9]{2})',
          caseSensitive: false),
      RegExp(r'[₱PHP]\s*([0-9,]+\.[0-9]{2})'),
    ]);
    if (amount == null) return null;

    final ref = _extractFirstMatch(
      text,
      RegExp(r'Reference No\.\s*([A-Z0-9]+)', caseSensitive: false),
    );

    final date = _parseDateTime(
      text,
      RegExp(r'Date\s*([0-9]{1,2}\s+[A-Za-z]{3}\s+[0-9]{4}\s+at\s+[0-9]{1,2}:[0-9]{2}\s+[AP]M)',
          caseSensitive: false),
      'd MMM yyyy \'at\' hh:mm a',
    );

    final destAccount = _extractFirstMatch(
      text,
      RegExp(r'To[\s\S]*?([0-9*]{4,})'),
    );

    final sourceAccount = _extractFirstMatch(
      text,
      RegExp(r'From[\s\S]*?([0-9*]{4,})'),
    );

    return ParsedBankReceipt(
      institution: BankInstitution.goTyme,
      institutionName: 'GoTyme Bank',
      amount: amount,
      dateTime: date,
      referenceNumber: ref,
      sourceAccount: sourceAccount,
      destinationAccount: destAccount,
      destinationName: 'MariBank',
      isTransfer: true,
      rawText: text,
    );
  }

  static ParsedBankReceipt? _parseMaya(String text) {
    final amount = _extractAmount(text, [
      RegExp(r'(?:-\s*)?[₱PHP]\s*([0-9,]+\.[0-9]{2})'),
      RegExp(r'([0-9,]+\.[0-9]{2})'),
    ]);
    if (amount == null) return null;

    final ref = _extractFirstMatch(
      text,
      RegExp(r'Reference ID\s*([A-Z0-9]+)', caseSensitive: false),
    );

    final destName = _extractFirstMatch(
      text,
      RegExp(r'Destination\s*([^\n\r+]+)', caseSensitive: false),
    )?.trim();

    final destPhone = _extractFirstMatch(
      text,
      RegExp(r'(\+?63\s*[0-9]{10}|09[0-9]{9})'),
    );

    final note = _extractFirstMatch(
      text,
      RegExp(r'-\s*from\s*([^\n\r]+)', caseSensitive: false),
    )?.trim();

    return ParsedBankReceipt(
      institution: BankInstitution.maya,
      institutionName: 'Maya',
      amount: amount,
      dateTime: DateTime.now(),
      referenceNumber: ref,
      sourceAccount: 'My Wallet',
      destinationAccount: destPhone,
      destinationName: destName,
      isTransfer: false, // Maya P2P send money to another person is an Expense
      note: note,
      rawText: text,
    );
  }

  static ParsedBankReceipt? _parseMariBank(String text) {
    final amount = _extractAmount(text, [
      RegExp(r'(?:PHP|Total Amount)\s*([0-9,]+\.[0-9]{2})',
          caseSensitive: false),
      RegExp(r'[₱PHP]\s*([0-9,]+\.[0-9]{2})'),
    ]);
    if (amount == null) return null;

    final ref = _extractFirstMatch(
      text,
      RegExp(r'Reference Number\s*([0-9]+)', caseSensitive: false),
    );

    final date = _parseDateTime(
      text,
      RegExp(r'Transaction Date & Time\s*([0-9]{1,2}\s+[A-Za-z]{3}\s+[0-9]{4},\s+[0-9]{1,2}:[0-9]{2})',
          caseSensitive: false),
      'd MMM yyyy, HH:mm',
    );

    final sourceAccount = _extractFirstMatch(
      text,
      RegExp(r'From[\s\S]*?([0-9*]{4,})'),
    );

    final destAccount = _extractFirstMatch(
      text,
      RegExp(r'To[\s\S]*?(09[0-9]{9}|[0-9*]{4,})'),
    );

    final isTransfer = text.toLowerCase().contains('transfer') ||
        text.toLowerCase().contains('instapay');

    return ParsedBankReceipt(
      institution: BankInstitution.mariBank,
      institutionName: 'MariBank',
      amount: amount,
      dateTime: date,
      referenceNumber: ref,
      sourceAccount: sourceAccount,
      destinationAccount: destAccount,
      destinationName: 'Maya Wallet',
      isTransfer: isTransfer,
      rawText: text,
    );
  }

  static ParsedBankReceipt? _parseUnionBank(String text) {
    final amount = _extractAmount(text, [
      RegExp(r'Amount\s*PHP\s*([0-9,]+\.[0-9]{2})', caseSensitive: false),
      RegExp(r'[₱PHP]\s*([0-9,]+\.[0-9]{2})'),
    ]);
    if (amount == null) return null;

    final ref = _extractFirstMatch(
      text,
      RegExp(r'Reference Number\s*([A-Z0-9]+)', caseSensitive: false),
    );

    final date = _parseDateTime(
      text,
      RegExp(r'([A-Za-z]{3}\s+[0-9]{1,2},\s+[0-9]{4}\s*\|\s*[0-9]{1,2}:[0-9]{2}\s+[AP]M)'),
      'MMM d, yyyy | hh:mm a',
    );

    final sourceAccount = _extractFirstMatch(
      text,
      RegExp(r'From[\s\S]*?([0-9*]{4,})'),
    );

    final destAccount = _extractFirstMatch(
      text,
      RegExp(r'To[\s\S]*?([0-9\s]{8,})'),
    )?.replaceAll(' ', '');

    return ParsedBankReceipt(
      institution: BankInstitution.unionBank,
      institutionName: 'UnionBank',
      amount: amount,
      dateTime: date,
      referenceNumber: ref,
      sourceAccount: sourceAccount,
      destinationAccount: destAccount,
      destinationName: 'Maribank',
      isTransfer: true,
      rawText: text,
    );
  }

  static ParsedBankReceipt? _parseGeneric(String text) {
    final amount = _extractAmount(text, [
      RegExp(r'[₱PHP]\s*([0-9,]+\.[0-9]{2})'),
      RegExp(r'([0-9,]+\.[0-9]{2})'),
    ]);
    if (amount == null) return null;

    final ref = _extractFirstMatch(
      text,
      RegExp(r'(?:Ref|Reference|Trace|ID)[:\s#]*([A-Z0-9]+)',
          caseSensitive: false),
    );

    return ParsedBankReceipt(
      institution: BankInstitution.unknown,
      institutionName: 'Receipt',
      amount: amount,
      dateTime: DateTime.now(),
      referenceNumber: ref,
      rawText: text,
    );
  }

  static double? _extractAmount(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final clean = match.group(1)!.replaceAll(',', '');
        final val = double.tryParse(clean);
        if (val != null && val > 0) return val;
      }
    }
    return null;
  }

  static String? _extractFirstMatch(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim();
    }
    return null;
  }

  static DateTime? _parseDateTime(
      String text, RegExp pattern, String dateFormat) {
    final raw = _extractFirstMatch(text, pattern);
    if (raw == null) return null;
    try {
      final formatter = DateFormat(dateFormat, 'en_US');
      return formatter.parse(raw);
    } catch (_) {
      return null;
    }
  }
}
