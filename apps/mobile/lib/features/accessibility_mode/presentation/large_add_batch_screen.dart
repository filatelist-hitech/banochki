import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';
import '../../batches/presentation/batch_details_screen.dart';
import '../../inventory/domain/models.dart';

final class LargeAddBatchScreen extends ConsumerStatefulWidget {
  const LargeAddBatchScreen({super.key});

  @override
  ConsumerState<LargeAddBatchScreen> createState() =>
      _LargeAddBatchScreenState();
}

final class _LargeAddBatchScreenState
    extends ConsumerState<LargeAddBatchScreen> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  var _step = 0;
  String? _locationId;
  String? _error;
  var _saving = false;
  BatchView? _created;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref
        .watch(appControllerProvider)
        .requireValue
        .snapshot
        .locations
        .where((item) => !item.isArchived)
        .toList();
    _locationId ??= locations.firstOrNull?.locationId;
    final content = _created == null
        ? _stepContent(context, locations)
        : _successContent(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () {
            if (_created != null || _step == 0) {
              Navigator.pop(context);
            } else {
              setState(() {
                _step--;
                _error = null;
              });
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_created == null ? 'Добавить банки' : 'Готово'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BanochkiSpacing.lg),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepContent(BuildContext context, List<StorageLocation> locations) {
    final title = switch (_step) {
      0 => 'Что заготовили?',
      1 => 'Сколько банок?',
      2 => 'Где поставить?',
      _ => 'Всё верно?',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: BanochkiSpacing.xl),
        if (_step == 0)
          TextField(
            key: const Key('large-batch-name'),
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 26),
            decoration: const InputDecoration(labelText: 'Название'),
          )
        else if (_step == 1)
          Column(
            children: [
              TextField(
                key: const Key('large-batch-quantity'),
                controller: _quantityController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                ),
                decoration: const InputDecoration(labelText: 'Количество'),
              ),
              const SizedBox(height: BanochkiSpacing.md),
              Row(
                children: [
                  Expanded(child: _quantityButton('−', -1)),
                  const SizedBox(width: BanochkiSpacing.md),
                  Expanded(child: _quantityButton('+', 1)),
                ],
              ),
            ],
          )
        else if (_step == 2)
          Column(
            children: [
              for (final location in locations)
                Padding(
                  padding: const EdgeInsets.only(bottom: BanochkiSpacing.sm),
                  child: Semantics(
                    selected: _locationId == location.locationId,
                    button: true,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(BanochkiSpacing.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          BanochkiRadius.control,
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      leading: Icon(
                        _locationId == location.locationId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text(
                        location.name,
                        style: const TextStyle(fontSize: 23),
                      ),
                      onTap: () =>
                          setState(() => _locationId = location.locationId),
                    ),
                  ),
                ),
            ],
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(BanochkiSpacing.lg),
              child: Column(
                children: [
                  Text(
                    _nameController.text,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: BanochkiSpacing.md),
                  Text(
                    '${_quantityController.text} банок',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: BanochkiSpacing.md),
                  Text(
                    locations
                        .firstWhere((item) => item.locationId == _locationId)
                        .name,
                    style: const TextStyle(fontSize: 24),
                  ),
                ],
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: BanochkiSpacing.md),
          InlineError(message: _error!),
        ],
        const SizedBox(height: BanochkiSpacing.xl),
        PrimaryActionButton(
          key: const Key('large-continue'),
          label: _step == 3 ? 'Сохранить партию' : 'Дальше',
          large: true,
          onPressed: _saving ? null : () => _continue(locations),
        ),
      ],
    );
  }

  Widget _quantityButton(String label, int delta) => SizedBox(
    height: BanochkiTargets.large,
    child: OutlinedButton(
      onPressed: () {
        final current = int.tryParse(_quantityController.text) ?? 1;
        final next = current + delta;
        if (next > 0) setState(() => _quantityController.text = '$next');
      },
      child: Text(label, style: const TextStyle(fontSize: 34)),
    ),
  );

  Future<void> _continue(List<StorageLocation> locations) async {
    if (_step == 0 && _nameController.text.trim().isEmpty) {
      setState(() => _error = 'Введите название.');
      return;
    }
    if (_step == 1 && (int.tryParse(_quantityController.text) ?? 0) <= 0) {
      setState(() => _error = 'Количество должно быть больше нуля.');
      return;
    }
    if (_step == 2 && _locationId == null) {
      setState(() => _error = 'Выберите место.');
      return;
    }
    if (_step < 3) {
      setState(() {
        _step++;
        _error = null;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await ref
          .read(appControllerProvider.notifier)
          .createBatch(
            CreateBatchInput(
              name: _nameController.text,
              initialQuantity: int.parse(_quantityController.text),
              storageLocationId: _locationId!,
              jarVolumeMl: 700,
              preservedAt: DateTime.now(),
              harvestYear: DateTime.now().year,
            ),
          );
      if (mounted) setState(() => _created = created);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _successContent(BuildContext context) {
    final view = _created!;
    return Semantics(
      liveRegion: true,
      label:
          '${view.batch.name}. ${view.projection.displayQuantity} банок. ${view.locationPath}. Сохранено.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle,
            size: 84,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: BanochkiSpacing.lg),
          Text(
            view.batch.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: BanochkiSpacing.lg),
          Text(
            '${view.projection.displayQuantity} БАНОК',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: BanochkiSpacing.md),
          Text(
            view.locationPath,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: BanochkiSpacing.xl),
          PrimaryActionButton(
            label: 'Готово',
            large: true,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: BanochkiSpacing.sm),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => BatchDetailsScreen(batchId: view.batch.batchId),
              ),
            ),
            child: const Text('Открыть партию', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}
