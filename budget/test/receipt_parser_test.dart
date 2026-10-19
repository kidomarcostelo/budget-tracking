import 'package:budget/struct/receiptParser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoTyme Receipt Parsing', () {
    const text = '''
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

    test('correctly parses GoTyme transfer details', () {
      final receipt = BankReceiptParser.parse(text);
      expect(receipt, isNotNull);
      expect(receipt!.institution, BankInstitution.goTyme);
      expect(receipt.amount, 3600.00);
      expect(receipt.referenceNumber, 'ITO261019143038004');
      expect(receipt.isTransfer, isTrue);
      expect(receipt.sourceAccount, contains('3887'));
      expect(receipt.destinationAccount, contains('6603'));
      expect(receipt.dateTime, isNotNull);
      expect(receipt.dateTime!.day, 19);
      expect(receipt.dateTime!.month, 10);
      expect(receipt.dateTime!.year, 2026);
    });
  });

  group('Maya Receipt Parsing', () {
    const text = '''
Sent money
RICA T.
+639206923443
- ₱100.00
Completed
Source My Wallet
+63 956 857 9768
Destination RICA T.
+639206923443
Transaction details
Transaction fee ₱0.00
Reference ID 456C6B393301
- from KID OMAR
maya
''';

    test('correctly parses Maya P2P send money details', () {
      final receipt = BankReceiptParser.parse(text);
      expect(receipt, isNotNull);
      expect(receipt!.institution, BankInstitution.maya);
      expect(receipt.amount, 100.00);
      expect(receipt.referenceNumber, '456C6B393301');
      expect(receipt.destinationName, 'RICA T.');
      expect(receipt.destinationAccount, contains('639206923443'));
      expect(receipt.note, 'KID OMAR');
      expect(receipt.isTransfer, isFalse);
    });
  });

  group('MariBank Receipt Parsing', () {
    const text = '''
MariBank
Transaction Receipt
PHP 1,000.00
From KID OMAR C.
MariBank: *******6603
To Kid Omar Costelo
Maya Philippines, Inc./Maya Wallet
Mobile No.: 09568579768
Transfer Amount PHP 1,000.00
Transfer Fee FREE
Total Amount PHP 1,000.00
Reference Number 454658
Transfer Method instaPay
Processing Time Realtime
Transaction Date & Time 19 Oct 2026, 22:26
Receipt generated from MariBank app
''';

    test('correctly parses MariBank transfer receipt', () {
      final receipt = BankReceiptParser.parse(text);
      expect(receipt, isNotNull);
      expect(receipt!.institution, BankInstitution.mariBank);
      expect(receipt.amount, 1000.00);
      expect(receipt.referenceNumber, '454658');
      expect(receipt.isTransfer, isTrue);
      expect(receipt.sourceAccount, contains('6603'));
      expect(receipt.destinationAccount, contains('09568579768'));
      expect(receipt.dateTime, isNotNull);
      expect(receipt.dateTime!.hour, 22);
      expect(receipt.dateTime!.minute, 26);
    });
  });

  group('UnionBank Receipt Parsing', () {
    const text = '''
Reference Number
UB1663112
Status
Successful
Oct 19, 2026 | 10:25 PM
Funds have been credited to the recipient.
Request Submitted
Oct 19, 2026 | 10:25 PM
Transfer Details
Sent Via
instaPay
Instapay Reference Number
995044
To
Kid Omar Costelo
Maribank
1953 0416 603
Amount
PHP 15,000.00
Purpose
Fund Transfer
From
KID OMAR RENDON COSTELO
Classic Savings ePaycard
**** **** 9227
Thank you for using UnionBank Online
''';

    test('correctly parses UnionBank transfer receipt', () {
      final receipt = BankReceiptParser.parse(text);
      expect(receipt, isNotNull);
      expect(receipt!.institution, BankInstitution.unionBank);
      expect(receipt.amount, 15000.00);
      expect(receipt.referenceNumber, 'UB1663112');
      expect(receipt.isTransfer, isTrue);
      expect(receipt.sourceAccount, contains('9227'));
      expect(receipt.destinationAccount, contains('19530416603'));
      expect(receipt.dateTime, isNotNull);
      expect(receipt.dateTime!.month, 10);
      expect(receipt.dateTime!.day, 19);
      expect(receipt.dateTime!.year, 2026);
    });
  });
}
