import 'package:banochki/features/qr/domain/qr_models.dart';
import 'package:banochki/features/qr/presentation/qr_scanner_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scanner resolution states are explicit and deterministic', () {
    expect(scannerStateFor(QrResolutionKind.resolved), ScannerState.resolved);
    expect(scannerStateFor(QrResolutionKind.unknown), ScannerState.unknownCode);
    expect(scannerStateFor(QrResolutionKind.invalid), ScannerState.invalidCode);
    expect(
      scannerStateFor(QrResolutionKind.unsupported),
      ScannerState.unsupportedVersion,
    );
    expect(
      scannerStateFor(QrResolutionKind.unlinked),
      ScannerState.unlinkedCode,
    );
    expect(scannerStateFor(QrResolutionKind.revoked), ScannerState.error);
    expect(scannerStateFor(QrResolutionKind.replaced), ScannerState.error);
  });
}
