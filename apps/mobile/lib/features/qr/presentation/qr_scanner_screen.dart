import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/app_controller.dart';
import '../../batches/presentation/batch_details_screen.dart';
import '../domain/qr_models.dart';
import 'manual_code_screen.dart';
import 'location_qr_details_screen.dart';

enum ScannerState {
  initial,
  requestingPermission,
  permissionDenied,
  cameraUnavailable,
  starting,
  scanning,
  codeDetected,
  resolving,
  resolved,
  unknownCode,
  invalidCode,
  unsupportedVersion,
  unlinkedCode,
  error,
  paused,
  closed,
}

final class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});
  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

final class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  ScannerState _state = ScannerState.initial;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _camera.stop();
    }
    if (state == AppLifecycleState.resumed && !_handling) {
      _camera.start();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Наведите на код'),
      actions: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          tooltip: 'Закрыть',
        ),
      ],
    ),
    body: Stack(
      children: [
        MobileScanner(
          controller: _camera,
          onDetect: _onDetect,
          errorBuilder: (_, error) {
            _state = error.errorCode == MobileScannerErrorCode.permissionDenied
                ? ScannerState.permissionDenied
                : ScannerState.cameraUnavailable;
            return _message(
              _state == ScannerState.permissionDenied
                  ? 'Камера не разрешена'
                  : 'Камера недоступна',
            );
          },
        ),
        Center(
          child: IgnorePointer(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _camera.toggleTorch(),
                      icon: const Icon(Icons.flashlight_on_outlined),
                      label: const Text('Фонарик'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ManualCodeScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Ввести номер'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _message(String value) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _camera.start(),
            child: const Text('Повторить'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ManualCodeScreen()),
            ),
            child: const Text('Ввести номер'),
          ),
        ],
      ),
    ),
  );

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null) return;
    _handling = true;
    setState(() => _state = ScannerState.codeDetected);
    await _camera.stop();
    setState(() => _state = ScannerState.resolving);
    final result = await ref
        .read(appControllerProvider.notifier)
        .resolveQr(raw);
    if (!mounted) return;
    switch (result.kind) {
      case QrResolutionKind.resolved:
        setState(() => _state = ScannerState.resolved);
        if (result.qrCode!.targetType == QrTargetType.batch) {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) =>
                  BatchDetailsScreen(batchId: result.qrCode!.targetId!),
            ),
          );
        } else {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) =>
                  LocationQrDetailsScreen(locationId: result.qrCode!.targetId!),
            ),
          );
        }
      case QrResolutionKind.unknown:
        _show('Этого кода пока нет на устройстве');
      case QrResolutionKind.invalid:
        _show('Неверный QR-код');
      case QrResolutionKind.unsupported:
        _show('Версия QR пока не поддерживается');
      case QrResolutionKind.unlinked:
        _show('Свободная этикетка: привяжите её к партии или месту.');
      case QrResolutionKind.revoked:
        _show('Этот QR-код отозван');
      case QrResolutionKind.replaced:
        _show('Этот QR-код перевыпущен');
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Повторить',
          onPressed: () {
            _handling = false;
            _camera.start();
            setState(() => _state = ScannerState.scanning);
          },
        ),
      ),
    );
  }
}
