import 'package:banochki/features/qr/domain/label_pdf.dart';
import 'package:banochki/features/qr/domain/qr_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('A4 label templates generate a PDF with vector QR payloads', () async {
    final qr = QrCode(
      id: 'qr',
      familyId: 'family',
      publicToken: 'a' * 43,
      shortCode: '123456-6',
      checksum: '6',
      protocolVersion: 1,
      targetType: QrTargetType.batch,
      targetId: 'batch',
      state: QrCodeState.active,
      createdAt: DateTime.utc(2026),
      createdByMemberId: 'member',
      deviceId: 'device',
    );
    for (final template in LabelTemplate.values) {
      final bytes = await LabelPdf.build(
        labels: [PrintableLabel(qr: qr, name: 'Лечо', year: '2026')],
        template: template,
      );
      expect(bytes.take(4), [0x25, 0x50, 0x44, 0x46]);
      expect(bytes.length, greaterThan(500));
    }
  });
}
