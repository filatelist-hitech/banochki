import 'package:banochki/features/qr/domain/qr_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QR protocol and short code', () {
    test('payload is versioned, opaque and round-trips', () {
      final token = QrTokenGenerator().nextToken();
      final payload = QrProtocol.payloadFor(token);
      final parsed = QrProtocol.parse(payload);
      expect(parsed?.version, 1);
      expect(parsed?.token, token);
      expect(payload, isNot(contains('Семья')));
      expect(payload, isNot(contains('Погреб')));
    });

    test('short code detects a one-digit typo', () {
      final code = ShortCode.create('042731');
      expect(ShortCode.isValid(code), isTrue);
      expect(ShortCode.isValid('042732-${code[7]}'), isFalse);
      expect(ShortCode.format(code.replaceAll('-', '')), code);
    });

    test('invalid and unsupported payloads are distinguishable', () {
      expect(QrProtocol.parse('https://example.org/qr'), isNull);
      final parsed = QrProtocol.parse('banochki://qr/v2/${'a' * 43}');
      expect(parsed?.version, 2);
    });
  });
}
