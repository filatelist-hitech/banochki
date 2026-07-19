import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../batches/presentation/batch_details_screen.dart';
import '../domain/qr_models.dart';

final class ManualCodeScreen extends ConsumerStatefulWidget {
  const ManualCodeScreen({super.key});
  @override
  ConsumerState<ManualCodeScreen> createState() => _ManualCodeScreenState();
}

final class _ManualCodeScreenState extends ConsumerState<ManualCodeScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Введите номер')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Шесть цифр и контрольная цифра',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(
              hintText: '042731-8',
              errorText: _error,
            ),
            onChanged: (value) {
              final formatted = ShortCode.format(value);
              if (formatted != value) {
                _controller.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _resolve, child: const Text('Открыть')),
        ],
      ),
    ),
  );

  Future<void> _resolve() async {
    final code = _controller.text;
    if (!ShortCode.isValid(code)) {
      setState(() => _error = 'Проверьте номер: контрольная цифра не совпала.');
      return;
    }
    final result = await ref
        .read(appControllerProvider.notifier)
        .resolveShortCode(code);
    if (!mounted) return;
    if (result.kind == QrResolutionKind.resolved &&
        result.qrCode?.targetType == QrTargetType.batch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BatchDetailsScreen(batchId: result.qrCode!.targetId!),
        ),
      );
      return;
    }
    setState(
      () => _error = result.kind == QrResolutionKind.unknown
          ? 'Такого номера пока нет на устройстве.'
          : 'Этот номер сейчас нельзя открыть.',
    );
  }
}
