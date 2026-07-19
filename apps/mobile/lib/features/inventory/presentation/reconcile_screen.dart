import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';

final class ReconcileScreen extends ConsumerStatefulWidget {
  const ReconcileScreen({required this.batchId, super.key});

  final String batchId;

  @override
  ConsumerState<ReconcileScreen> createState() => _ReconcileScreenState();
}

final class _ReconcileScreenState extends ConsumerState<ReconcileScreen> {
  late final TextEditingController _quantityController;
  final _commentController = TextEditingController();
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final view = ref
        .read(appControllerProvider)
        .requireValue
        .snapshot
        .batches
        .firstWhere((item) => item.batch.batchId == widget.batchId);
    _quantityController = TextEditingController(
      text: '${view.projection.displayQuantity}',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref
        .watch(appControllerProvider)
        .requireValue
        .snapshot
        .batches
        .firstWhere((item) => item.batch.batchId == widget.batchId);
    return Scaffold(
      appBar: AppBar(title: const Text('Уточнить остаток')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(BanochkiSpacing.lg),
              children: [
                Text(
                  view.batch.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: BanochkiSpacing.md),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(BanochkiSpacing.md),
                    child: Text(
                      'Посчитайте, сколько банок есть сейчас. Мы добавим компенсирующее событие, а прежняя история останется.',
                    ),
                  ),
                ),
                const SizedBox(height: BanochkiSpacing.lg),
                TextField(
                  key: const Key('reconcile-quantity'),
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Фактический остаток',
                  ),
                ),
                const SizedBox(height: BanochkiSpacing.md),
                TextField(
                  controller: _commentController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий — необязательно',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: BanochkiSpacing.md),
                  InlineError(message: _error!),
                ],
                const SizedBox(height: BanochkiSpacing.lg),
                PrimaryActionButton(
                  key: const Key('save-reconciliation'),
                  label: 'Сохранить остаток',
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final value = int.tryParse(_quantityController.text);
    if (value == null || value < 0) {
      setState(() => _error = 'Введите целое неотрицательное число.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(appControllerProvider.notifier)
          .reconcile(
            batchId: widget.batchId,
            actualQuantity: value,
            comment: _commentController.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
