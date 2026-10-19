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

  /// Suggest a matching wallet based on bank institution name
  /// or account number.
  static Future<TransactionWallet?> resolveWallet(
      ParsedBankReceipt receipt) async {
    if (receipt.institutionName.isNotEmpty) {
      final wallet = await database.getRelatingWallet(receipt.institutionName);
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
  static String formatTitle(ParsedBankReceipt receipt) {
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
    if (receipt.note != null && receipt.note!.isNotEmpty) {
      lines.add('Note: ${receipt.note}');
    }
    return lines.join('\n');
  }
}
