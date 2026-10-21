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
  final String? sourceName;
  final String? destinationAccount;
  final String? destinationName;
  final String? destinationBank;
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
    this.sourceName,
    this.destinationAccount,
    this.destinationName,
    this.destinationBank,
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
        'from: $sourceAccount ($sourceName) -> to: $destinationAccount ($destinationName, $destinationBank))';
  }
}

/// Robust on-device parser for Philippine banking receipts (OCR output).
class BankReceiptParser {
  /// Detect the bank institution from OCR text.
  static BankInstitution detectInstitution(String text) {
    final lower = text.toLowerCase();

    // 1. Strong issuer-specific markers
    if (lower.contains('receipt generated from maribank') ||
        lower.contains('maribank transaction receipt') ||
        lower.contains('maribank:')) {
      return BankInstitution.mariBank;
    }
    if (lower.contains('unionbank online') ||
        lower.contains('using unionbank') ||
        RegExp(r'\bUB\d{6,}', caseSensitive: false).hasMatch(text)) {
      return BankInstitution.unionBank;
    }
    if (lower.contains('gotyme bank') ||
        lower.contains('trace id') ||
        RegExp(r'\bITO\d{10,}', caseSensitive: false).hasMatch(text)) {
      return BankInstitution.goTyme;
    }
    if (lower.contains('source my wallet') ||
        lower.contains('my wallet') ||
        (lower.contains('sent money') && lower.contains('reference id'))) {
      return BankInstitution.maya;
    }

    // 2. Check headers / first 3 lines
    final firstLines = text.split('\n').take(3).join(' ').toLowerCase();
    if (firstLines.contains('maribank')) return BankInstitution.mariBank;
    if (firstLines.contains('unionbank') || firstLines.contains('union bank')) {
      return BankInstitution.unionBank;
    }
    if (firstLines.contains('gotyme')) return BankInstitution.goTyme;
    if (firstLines.contains('maya')) return BankInstitution.maya;

    // 3. Fallback: general keywords
    if (lower.contains('gotyme')) return BankInstitution.goTyme;
    if (lower.contains('unionbank') || lower.contains('union bank')) {
      return BankInstitution.unionBank;
    }
    if (lower.contains('maribank')) return BankInstitution.mariBank;
    if (lower.contains('maya') || lower.contains('paymaya')) {
      return BankInstitution.maya;
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
      RegExp(
        r'Date\s*([0-9]{1,2}\s+[A-Za-z]{3}\s+[0-9]{4}\s+at\s+'
        r'[0-9]{1,2}:[0-9]{2}\s+[AP]M)',
        caseSensitive: false,
      ),
      'd MMM yyyy \'at\' hh:mm a',
    );

    final destAccount = _extractFirstMatch(
      text,
      RegExp(r'To[\s\S]*?(?:^|\n)\s*([*Xx\s]{4,}\d{3,}|\d{4,})',
          multiLine: true),
    );

    final sourceAccount = _extractFirstMatch(
      text,
      RegExp(r'From[\s\S]*?(?:^|\n)\s*([*Xx\s]{4,}\d{3,}|\d{4,})',
          multiLine: true),
    );

    final destName = _extractFirstMatch(
      text,
      RegExp(r'To\s+([^\n\r]+)', caseSensitive: false),
    );

    final sourceName = _extractFirstMatch(
      text,
      RegExp(r'From\s+([^\n\r]+)', caseSensitive: false),
    );

    final destBank = _extractFirstMatch(
      text,
      RegExp(
        r'(?:To[\s\S]*?(?:[*Xx\s]{4,}\d{3,}|\d{4,})\s*\n\s*)([^\n\r]+?)(?:\s*\n\s*From)',
        multiLine: true,
      ),
    );

    return ParsedBankReceipt(
      institution: BankInstitution.goTyme,
      institutionName: 'GoTyme Bank',
      amount: amount,
      dateTime: date,
      referenceNumber: ref,
      sourceAccount: sourceAccount,
      sourceName: sourceName,
      destinationAccount: destAccount,
      destinationName: destName,
      destinationBank: destBank,
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

    final sourceName = note;

    final destBank = _extractFirstMatch(
      text,
      RegExp(r'(?:Bank|To Bank|Partner Bank)[:\s]*([^\n\r]+)',
          caseSensitive: false),
    );

    return ParsedBankReceipt(
      institution: BankInstitution.maya,
      institutionName: 'Maya',
      amount: amount,
      dateTime: DateTime.now(),
      referenceNumber: ref,
      sourceAccount: 'My Wallet',
      sourceName: sourceName,
      destinationAccount: destPhone,
      destinationName: destName,
      destinationBank: destBank,
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
      RegExp(
        r'Transaction Date & Time\s*'
        r'([0-9]{1,2}\s+[A-Za-z]{3}\s+[0-9]{4},\s+[0-9]{1,2}:[0-9]{2})',
        caseSensitive: false,
      ),
      'd MMM yyyy, HH:mm',
    );

    final sourceAccount = _extractFirstMatch(
      text,
      RegExp(
        r'From[\s\S]*?(?:^|\n)\s*(?:MariBank:\s*)?([*Xx\s]{4,}\d{3,}|\d{4,})',
        multiLine: true,
      ),
    );

    final destAccount = _extractFirstMatch(
      text,
      RegExp(
        r'To[\s\S]*?(?:^|\n)\s*(?:Mobile No\.:\s*|Account No\.:\s*)?'
        r'(09[0-9]{9}|[*Xx\s]{4,}\d{3,}|\d{4,})',
        multiLine: true,
      ),
    );

    final sourceName = _extractFirstMatch(
      text,
      RegExp(r'From\s+([^\n\r]+)', caseSensitive: false),
    );

    final toMatch = RegExp(
      r'To\s+([^\n\r]+)(?:\s*\n\s*([^\n\r]+))?',
      caseSensitive: false,
    ).firstMatch(text);

    final destName = toMatch?.group(1)?.trim();
    String? destBank = toMatch?.group(2)?.trim();
    if (destBank != null) {
      final lower = destBank.toLowerCase();
      if (lower.startsWith('mobile no') ||
          lower.startsWith('account no') ||
          lower.startsWith('transfer amount') ||
          lower.startsWith('php')) {
        destBank = null;
      }
    }

    final isTransfer = text.toLowerCase().contains('transfer') ||
        text.toLowerCase().contains('instapay');

    return ParsedBankReceipt(
      institution: BankInstitution.mariBank,
      institutionName: 'MariBank',
      amount: amount,
      dateTime: date,
      referenceNumber: ref,
      sourceAccount: sourceAccount,
      sourceName: sourceName,
      destinationAccount: destAccount,
      destinationName: destName,
      destinationBank: destBank,
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
      RegExp(
        r'([A-Za-z]{3}\s+[0-9]{1,2},\s+[0-9]{4}\s*\|\s*'
        r'[0-9]{1,2}:[0-9]{2}\s+[AP]M)',
      ),
      'MMM d, yyyy | hh:mm a',
    );

    final sourceAccount = _extractFirstMatch(
      text,
      RegExp(r'From[\s\S]*?(?:^|\n)\s*([*Xx\s]{4,}\d{3,}|\d{4,})',
          multiLine: true),
    );

    final destAccount = _extractFirstMatch(
      text,
      RegExp(r'To[\s\S]*?(?:^|\n)\s*([0-9\s]{8,})[\s\S]*?Amount',
          multiLine: true),
    )?.replaceAll(' ', '');

    String? destName;
    String? destBank;
    final toSection = _extractFirstMatch(
      text,
      RegExp(
        r'(?:^|\n)To\s*\n([\s\S]*?)(?:Amount|\n\s*\n)',
        caseSensitive: false,
      ),
    );
    if (toSection != null) {
      final lines = toSection
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        destName = lines[0];
      }
      if (lines.length > 1 && !RegExp(r'^\d[\d\s]+$').hasMatch(lines[1])) {
        destBank = lines[1];
      }
    }

    String? sourceName;
    final fromSection = _extractFirstMatch(
      text,
      RegExp(
        r'(?:^|\n)From\s*\n([\s\S]*?)(?:Thank you|\n\s*\n|$)',
        caseSensitive: false,
      ),
    );
    if (fromSection != null) {
      final lines = fromSection
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        sourceName = lines[0];
      }
    }

    return ParsedBankReceipt(
      institution: BankInstitution.unionBank,
      institutionName: 'UnionBank',
      amount: amount,
      dateTime: date,
      referenceNumber: ref,
      sourceAccount: sourceAccount,
      sourceName: sourceName,
      destinationAccount: destAccount,
      destinationName: destName,
      destinationBank: destBank,
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

    final destName = _extractFirstMatch(
      text,
      RegExp(r'(?:To|Recipient|Destination)[:\s]*([^\n\r]+)',
          caseSensitive: false),
    );

    final sourceName = _extractFirstMatch(
      text,
      RegExp(r'(?:From|Sender)[:\s]*([^\n\r]+)', caseSensitive: false),
    );

    return ParsedBankReceipt(
      institution: BankInstitution.unknown,
      institutionName: 'Receipt',
      amount: amount,
      dateTime: DateTime.now(),
      referenceNumber: ref,
      sourceName: sourceName,
      destinationName: destName,
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
