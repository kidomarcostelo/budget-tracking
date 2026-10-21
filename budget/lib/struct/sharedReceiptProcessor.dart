import 'dart:async';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/receiptParser.dart';
import 'package:budget/struct/shareIntentOcr.dart';

/// Processor orchestrating OCR extraction, bank receipt heuristics,
/// and entity resolution.
class SharedReceiptProcessor {
  /// Process a shared image file: run OCR, delete the temp file,
  /// and parse receipt.
  /// [recognizeText] and [deleteTempFile] can be overridden for testing.
  static Future<ParsedBankReceipt?> processSharedImage(
    String filePath, {
    Future<OcrResult?> Function(String)? recognizeText,
    Future<bool> Function(String)? deleteTempFile,
  }) async {
    final ocrFunc = recognizeText ?? ShareIntentOcrService.recognizeText;
    final deleteFunc = deleteTempFile ?? ShareIntentOcrService.deleteTempFile;

    try {
      final ocrResult = await ocrFunc(filePath);
      if (ocrResult == null || ocrResult.text.trim().isEmpty) {
        return null;
      }
      return BankReceiptParser.parse(ocrResult.text);
    } finally {
      // Clean up temporary shared cache file to preserve privacy and storage
      await deleteFunc(filePath);
    }
  }

  /// Suggest a matching source wallet based on bank institution name
  /// or account number.
  static Future<TransactionWallet?> resolveWallet(
      ParsedBankReceipt receipt) async {
    if (receipt.institutionName.isNotEmpty) {
      final wallet = await resolveWalletByName(receipt.institutionName);
      if (wallet != null) return wallet;
    }
    if (receipt.sourceAccount != null) {
      final digitsMatch = RegExp(r'\d{4,}').firstMatch(receipt.sourceAccount!);
      if (digitsMatch != null) {
        final wallet = await database.getRelatingWallet(digitsMatch.group(0)!);
        if (wallet != null) return wallet;
      }
    }
    return null;
  }

  /// Suggest a destination wallet for a transfer receipt based on
  /// destination bank or recipient account/name.
  static Future<TransactionWallet?> resolveDestinationWallet(
      ParsedBankReceipt receipt) async {
    if (receipt.destinationBank != null &&
        receipt.destinationBank!.trim().isNotEmpty) {
      final wallet = await resolveWalletByName(receipt.destinationBank!);
      if (wallet != null) return wallet;
    }

    if (receipt.destinationAccount != null) {
      final digitsMatch =
          RegExp(r'\d{4,}').firstMatch(receipt.destinationAccount!);
      if (digitsMatch != null) {
        final wallet = await database.getRelatingWallet(digitsMatch.group(0)!);
        if (wallet != null) return wallet;
      }
    }

    if (receipt.destinationName != null &&
        receipt.destinationName!.trim().isNotEmpty) {
      final wallet = await resolveWalletByName(receipt.destinationName!);
      if (wallet != null) return wallet;
    }

    return null;
  }

  /// Suggest a matching wallet given a bank, wallet, or institution name string.
  static Future<TransactionWallet?> resolveWalletByName(String name) async {
    if (name.trim().isEmpty) return null;

    final trimmed = name.trim();
    var wallet = await database.getRelatingWallet(trimmed);
    if (wallet != null) return wallet;

    // Check candidate keywords (e.g. "MariBank Philippines (SeaBank)" -> "MariBank", "SeaBank")
    final candidates = _extractBankCandidates(trimmed);
    for (final candidate in candidates) {
      wallet = await database.getRelatingWallet(candidate);
      if (wallet != null) return wallet;
    }

    // Check if any existing wallet name is contained inside the search string
    final allWallets = await database.getAllWallets();
    for (final w in allWallets) {
      if (w.name.isNotEmpty &&
          trimmed.toLowerCase().contains(w.name.toLowerCase())) {
        return w;
      }
    }
    return null;
  }

  static List<String> _extractBankCandidates(String raw) {
    final candidates = <String>[];
    final parts = raw
        .split(RegExp(r'[/,()]+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    for (final part in parts) {
      candidates.add(part);
      final stripped = part
          .replaceAll(
            RegExp(
              r'\b(Philippines|Inc\.?|Wallet|Bank|Online)\b',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      if (stripped.isNotEmpty && stripped != part) {
        candidates.add(stripped);
      }
    }
    return candidates;
  }

  /// Suggest a matching category based on transfer status or recipient name.
  static Future<TransactionCategory?> resolveCategory(
      ParsedBankReceipt receipt) async {
    if (receipt.isTransfer) {
      final cat = await database.getRelatingCategory('Transfer');
      if (cat != null) return cat;
    }
    if (receipt.destinationName != null &&
        receipt.destinationName!.trim().isNotEmpty) {
      final cleanName = receipt.destinationName!.trim();
      final found = (await database.getSimilarAssociatedTitles(
        title: cleanName,
        limit: 1,
      ))
          .firstOrNull;
      if (found?.category != null) return found!.category;
      return await database.getRelatingCategory(cleanName);
    }
    return null;
  }

  /// Formulate user-facing transaction title.
  static String formatTitle(ParsedBankReceipt receipt,
      {bool isTransfer = false}) {
    if (isTransfer) {
      final target = receipt.destinationBank ?? receipt.destinationName;
      if (target != null && target.trim().isNotEmpty) {
        return '${receipt.institutionName} → ${target.trim()}';
      }
      return 'Transfer - ${receipt.institutionName}';
    }
    if (receipt.destinationName != null &&
        receipt.destinationName!.trim().isNotEmpty) {
      return '${receipt.institutionName} - ${receipt.destinationName!.trim()}';
    }
    return receipt.institutionName;
  }

  /// Formulate metadata notes.
  static String formatNotes(ParsedBankReceipt receipt) {
    final lines = <String>[];
    if (receipt.referenceNumber != null &&
        receipt.referenceNumber!.isNotEmpty) {
      lines.add('Ref: ${receipt.referenceNumber}');
    }
    if (receipt.sourceAccount != null && receipt.sourceAccount!.isNotEmpty) {
      lines.add('From: ${receipt.sourceAccount}');
    }
    if (receipt.destinationAccount != null &&
        receipt.destinationAccount!.isNotEmpty) {
      lines.add('To: ${receipt.destinationAccount}');
    }
    if (receipt.destinationBank != null &&
        receipt.destinationBank!.isNotEmpty) {
      lines.add('To Bank: ${receipt.destinationBank}');
    }
    if (receipt.note != null && receipt.note!.isNotEmpty) {
      lines.add('Note: ${receipt.note}');
    }
    return lines.join('\n');
  }
}
