import 'package:budget/struct/receiptParser.dart';
import 'package:budget/struct/shareIntentOcr.dart';
import 'package:budget/struct/sharedReceiptProcessor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharedReceiptProcessor formatting helpers', () {
    test('formatTitle includes institution and recipient', () {
      const receiptWithRecipient = ParsedBankReceipt(
        institution: BankInstitution.goTyme,
        institutionName: 'GoTyme Bank',
        amount: 500.0,
        destinationName: 'MariBank',
        rawText: 'sample',
      );
      expect(SharedReceiptProcessor.formatTitle(receiptWithRecipient),
          'GoTyme Bank - MariBank');

      const receiptWithoutRecipient = ParsedBankReceipt(
        institution: BankInstitution.unionBank,
        institutionName: 'UnionBank',
        amount: 1500.0,
        rawText: 'sample',
      );
      expect(SharedReceiptProcessor.formatTitle(receiptWithoutRecipient),
          'UnionBank');
    });

    test('formatNotes formats reference, source, destination, and note', () {
      const receipt = ParsedBankReceipt(
        institution: BankInstitution.maya,
        institutionName: 'Maya',
        amount: 250.0,
        referenceNumber: '456C6B393301',
        sourceAccount: 'My Wallet',
        destinationAccount: '+639206923443',
        note: 'Payment for lunch',
        rawText: 'sample',
      );

      final notes = SharedReceiptProcessor.formatNotes(receipt);
      expect(notes, contains('Ref: 456C6B393301'));
      expect(notes, contains('From: My Wallet'));
      expect(notes, contains('To: +639206923443'));
      expect(notes, contains('Note: Payment for lunch'));
    });
  });

  group('SharedReceiptProcessor.processSharedImage workflow and cleanup', () {
    test('processes OCR text and deletes temporary image file', () async {
      String? deletedPath;
      bool ocrCalled = false;

      const sampleOcrText = '''
Transferred
₱3,600.00
Share
instaPay Instant
To KID O*** C*
*******6603
MariBank Philippines (SeaBank)
From KID O*** C******
********3887
GoTyme Bank
Amount ₱3,600.00
Fee ₱0.00
Total ₱3,600.00
Trace ID 038004
Reference No. ITO261019143038004
Date 19 Oct 2026 at 10:30 PM
Get help
''';

      final receipt = await SharedReceiptProcessor.processSharedImage(
        '/cache/test_receipt.png',
        recognizeText: (path) async {
          ocrCalled = true;
          return const OcrResult(text: sampleOcrText, blocks: []);
        },
        deleteTempFile: (path) async {
          deletedPath = path;
          return true;
        },
      );

      expect(ocrCalled, isTrue);
      expect(deletedPath, '/cache/test_receipt.png');
      expect(receipt, isNotNull);
      expect(receipt!.institution, BankInstitution.goTyme);
      expect(receipt.amount, 3600.00);
      expect(receipt.referenceNumber, 'ITO261019143038004');
    });

    test('guarantees temp image deletion even when OCR returns empty text',
        () async {
      String? deletedPath;

      final receipt = await SharedReceiptProcessor.processSharedImage(
        '/cache/blank_image.png',
        recognizeText: (path) async => const OcrResult(text: '', blocks: []),
        deleteTempFile: (path) async {
          deletedPath = path;
          return true;
        },
      );

      expect(receipt, isNull);
      expect(deletedPath, '/cache/blank_image.png');
    });

    test('guarantees temp image deletion even when OCR throws', () async {
      String? deletedPath;

      expect(
        () async => await SharedReceiptProcessor.processSharedImage(
          '/cache/corrupt_image.png',
          recognizeText: (path) async => throw Exception('Native OCR crash'),
          deleteTempFile: (path) async {
            deletedPath = path;
            return true;
          },
        ),
        throwsA(isA<Exception>()),
      );

      expect(deletedPath, '/cache/corrupt_image.png');
    });
  });
}
