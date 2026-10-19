import 'package:budget/struct/shareIntentOcr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharedPayload serialization', () {
    test('parses image payload correctly', () {
      final payload = SharedPayload.fromMap({
        'type': 'image',
        'filePath': '/cache/receipt.png',
        'uri': 'content://media/external/images/media/1234',
      });

      expect(payload.type, 'image');
      expect(payload.filePath, '/cache/receipt.png');
      expect(payload.uri, 'content://media/external/images/media/1234');
      expect(payload.isImage, isTrue);
      expect(payload.isText, isFalse);
    });

    test('parses text payload correctly', () {
      final payload = SharedPayload.fromMap({
        'type': 'text',
        'text': 'Transferred PHP 200.00 to MariBank Ref 720414',
      });

      expect(payload.type, 'text');
      expect(payload.text, 'Transferred PHP 200.00 to MariBank Ref 720414');
      expect(payload.isImage, isFalse);
      expect(payload.isText, isTrue);
    });

    test('handles unknown or empty payload gracefully', () {
      final payload = SharedPayload.fromMap({});
      expect(payload.type, 'unknown');
      expect(payload.isImage, isFalse);
      expect(payload.isText, isFalse);
    });
  });

  group('OcrResult serialization', () {
    test('parses nested blocks, lines, and elements', () {
      final data = {
        'text': 'MariBank\nTransfer amount: PHP 200.00',
        'blocks': [
          {
            'text': 'MariBank',
            'lines': [
              {
                'text': 'MariBank',
                'elements': ['MariBank'],
              }
            ],
          },
          {
            'text': 'Transfer amount: PHP 200.00',
            'lines': [
              {
                'text': 'Transfer amount: PHP 200.00',
                'elements': ['Transfer', 'amount:', 'PHP', '200.00'],
              }
            ],
          }
        ],
      };

      final result = OcrResult.fromMap(data);
      expect(result.text, 'MariBank\nTransfer amount: PHP 200.00');
      expect(result.blocks.length, 2);
      expect(result.blocks[0].lines[0].text, 'MariBank');
      expect(result.blocks[1].lines[0].elements,
          ['Transfer', 'amount:', 'PHP', '200.00']);
    });

    test('handles empty map without throwing', () {
      final result = OcrResult.fromMap({});
      expect(result.text, '');
      expect(result.blocks, isEmpty);
    });
  });
}
