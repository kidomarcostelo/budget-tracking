import 'package:budget/struct/ownerResolver.dart';
import 'package:budget/struct/receiptParser.dart';
import 'package:budget/struct/sharedReceiptProcessor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OwnerResolver.areNamesMatching', () {
    test('matches exact strings with different casing and whitespace', () {
      expect(
        OwnerResolver.areNamesMatching('Kid Omar Costelo', 'KID OMAR COSTELO'),
        isTrue,
      );
      expect(
        OwnerResolver.areNamesMatching('  kid omar  ', 'KID OMAR'),
        isTrue,
      );
    });

    test('matches initials with punctuation', () {
      expect(
        OwnerResolver.areNamesMatching('KID OMAR C.', 'Kid Omar Costelo'),
        isTrue,
      );
      expect(
        OwnerResolver.areNamesMatching('Kid Omar Costelo', 'K. O. Costelo'),
        isTrue,
      );
    });

    test('matches masked names with asterisks (GoTyme & Maya formats)', () {
      expect(
        OwnerResolver.areNamesMatching('KID O*** C******', 'Kid Omar Costelo'),
        isTrue,
      );
      expect(
        OwnerResolver.areNamesMatching('KID O*** C*', 'Kid Omar Costelo'),
        isTrue,
      );
      expect(
        OwnerResolver.areNamesMatching('KID O*** C******', 'KID O*** C*'),
        isTrue,
      );
      expect(
        OwnerResolver.areNamesMatching('K** O*** C******', 'Kid Omar Costelo'),
        isTrue,
      );
    });

    test('matches masked names with X / x characters', () {
      expect(
        OwnerResolver.areNamesMatching('KID OXXX CXXXXXX', 'Kid Omar Costelo'),
        isTrue,
      );
      expect(
        OwnerResolver.areNamesMatching('KID Oxxx Cxxxxxx', 'KID O*** C******'),
        isTrue,
      );
    });

    test('matches full legal name with middle name against shorter name', () {
      expect(
        OwnerResolver.areNamesMatching(
          'KID OMAR RENDON COSTELO',
          'Kid Omar Costelo',
        ),
        isTrue,
      );
      expect(
        OwnerResolver.areNamesMatching(
          'Kid Omar Costelo',
          'KID OMAR RENDON COSTELO',
        ),
        isTrue,
      );
    });

    test('matches surname first format with comma', () {
      expect(
        OwnerResolver.areNamesMatching(
          'Costelo, Kid Omar',
          'Kid Omar Costelo',
        ),
        isTrue,
      );
    });

    test('does not match different individuals or merchants', () {
      expect(
        OwnerResolver.areNamesMatching('KID OMAR', 'RICA T.'),
        isFalse,
      );
      expect(
        OwnerResolver.areNamesMatching('Kid Omar Costelo', 'Maria Santos'),
        isFalse,
      );
      expect(
        OwnerResolver.areNamesMatching('KID O*** C******', 'RICA T.'),
        isFalse,
      );
      expect(
        OwnerResolver.areNamesMatching('Kid Omar Costelo', 'Grab Philippines'),
        isFalse,
      );
      expect(
        OwnerResolver.areNamesMatching('Kid Omar Costelo', 'ShopeePay'),
        isFalse,
      );
      expect(
        OwnerResolver.areNamesMatching(null, 'Kid Omar Costelo'),
        isFalse,
      );
      expect(
        OwnerResolver.areNamesMatching('Kid Omar Costelo', ''),
        isFalse,
      );
    });
  });

  group('OwnerResolver.isOwnerMatch', () {
    test('matches against configured ownerName or googleDisplayName', () {
      expect(
        OwnerResolver.isOwnerMatch(
          'KID OMAR C.',
          ownerName: 'Kid Omar Costelo',
        ),
        isTrue,
      );
      expect(
        OwnerResolver.isOwnerMatch(
          'KID O*** C******',
          googleDisplayName: 'Kid Omar Costelo',
        ),
        isTrue,
      );
      expect(
        OwnerResolver.isOwnerMatch(
          'RICA T.',
          ownerName: 'Kid Omar Costelo',
          googleDisplayName: 'Kid Omar Costelo',
        ),
        isFalse,
      );
      expect(
        OwnerResolver.isOwnerMatch(
          'Kid Omar Costelo',
          ownerName: null,
          googleDisplayName: null,
        ),
        isFalse,
      );
    });

    test('matches against currentUserEmail prefix profile', () {
      expect(
        OwnerResolver.isOwnerMatch(
          'Kid Omar',
          currentUserEmail: 'kidomar@gmail.com',
        ),
        isTrue,
      );
    });
  });

  group('OwnerResolver.isSelfTransfer & SharedReceiptProcessor.isSelfTransfer',
      () {
    test(
        'classifies as self-transfer when sender and recipient match (GoTyme to MariBank)',
        () {
      const receipt = ParsedBankReceipt(
        institution: BankInstitution.goTyme,
        institutionName: 'GoTyme Bank',
        amount: 3600.0,
        sourceName: 'KID O*** C******',
        destinationName: 'KID O*** C*',
        destinationBank: 'MariBank Philippines (SeaBank)',
        isTransfer: true,
        rawText: '',
      );

      final isSelf = SharedReceiptProcessor.isSelfTransfer(
        receipt,
        ownerName: 'Kid Omar Costelo',
        destinationWalletExists: true,
        sourceWalletExists: true,
      );

      expect(isSelf, isTrue);
    });

    test(
        'classifies as self-transfer when sender and recipient match (MariBank to UnionBank)',
        () {
      const receipt = ParsedBankReceipt(
        institution: BankInstitution.mariBank,
        institutionName: 'MariBank',
        amount: 2500.0,
        sourceName: 'KID OMAR C.',
        destinationName: 'Kid Omar Costelo',
        destinationBank: 'UnionBank of the Philippines',
        isTransfer: true,
        rawText: '',
      );

      final isSelf = SharedReceiptProcessor.isSelfTransfer(
        receipt,
        ownerName: 'Kid Omar Costelo',
        destinationWalletExists: true,
      );

      expect(isSelf, isTrue);
    });

    test('falls back to sourceWalletExists when sender name is not extracted',
        () {
      const receipt = ParsedBankReceipt(
        institution: BankInstitution.unionBank,
        institutionName: 'UnionBank',
        amount: 1200.0,
        sourceAccount: '**** 9227',
        destinationName: 'Kid Omar Costelo',
        destinationBank: 'MariBank',
        isTransfer: true,
        rawText: '',
      );

      final isSelf = SharedReceiptProcessor.isSelfTransfer(
        receipt,
        ownerName: 'Kid Omar Costelo',
        destinationWalletExists: true,
        sourceWalletExists: true,
      );

      expect(isSelf, isTrue);
    });

    test(
        'classifies as expense when user pays an external recipient (Maya to Rica T.)',
        () {
      const receipt = ParsedBankReceipt(
        institution: BankInstitution.maya,
        institutionName: 'Maya',
        amount: 100.0,
        sourceName: 'KID OMAR',
        destinationName: 'RICA T.',
        isTransfer: false,
        rawText: '',
      );

      final isSelf = SharedReceiptProcessor.isSelfTransfer(
        receipt,
        ownerName: 'Kid Omar Costelo',
        destinationWalletExists: false,
      );

      expect(isSelf, isFalse);
    });

    test(
        'classifies as expense if destination is external even if a generic wallet happens to exist',
        () {
      const receipt = ParsedBankReceipt(
        institution: BankInstitution.unionBank,
        institutionName: 'UnionBank',
        amount: 500.0,
        sourceName: 'KID OMAR RENDON COSTELO',
        destinationName: 'Maria Santos',
        destinationBank: 'BDO',
        isTransfer: true,
        rawText: '',
      );

      final isSelf = SharedReceiptProcessor.isSelfTransfer(
        receipt,
        ownerName: 'Kid Omar Costelo',
        destinationWalletExists: true,
      );

      expect(isSelf, isFalse);
    });
  });
}
