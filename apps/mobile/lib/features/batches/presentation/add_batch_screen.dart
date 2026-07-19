import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';
import '../../inventory/domain/models.dart';
import 'batch_confirmation_screen.dart';

final class AddBatchScreen extends ConsumerStatefulWidget {
  const AddBatchScreen({this.initialLocationId, super.key});

  final String? initialLocationId;

  @override
  ConsumerState<AddBatchScreen> createState() => _AddBatchScreenState();
}

final class _AddBatchScreenState extends ConsumerState<AddBatchScreen> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _commentController = TextEditingController();
  final _customVolumeController = TextEditingController();
  late final TextEditingController _harvestYearController;
  String? _locationId;
  String _category = 'Другое';
  int? _volumeMl = 700;
  late int _harvestYear;
  late DateTime _preservedAt;
  var _advanced = false;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _harvestYear = now.year;
    _harvestYearController = TextEditingController(text: '$_harvestYear');
    _preservedAt = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _commentController.dispose();
    _customVolumeController.dispose();
    _harvestYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final locations = state.snapshot.locations
        .where((item) => !item.isArchived)
        .toList();
    _locationId ??=
        widget.initialLocationId ?? locations.firstOrNull?.locationId;
    return Scaffold(
      appBar: AppBar(title: const Text('Новая партия')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(BanochkiSpacing.md),
              children: [
                const Text(
                  'Три обязательных значения',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: BanochkiSpacing.md),
                TextField(
                  key: const Key('batch-name'),
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    hintText: 'Огурцы маринованные',
                  ),
                ),
                const SizedBox(height: BanochkiSpacing.md),
                TextField(
                  key: const Key('batch-quantity'),
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Количество банок',
                    suffixText: 'шт.',
                  ),
                ),
                const SizedBox(height: BanochkiSpacing.md),
                DropdownButtonFormField<String>(
                  key: const Key('batch-location'),
                  initialValue: _locationId,
                  decoration: const InputDecoration(
                    labelText: 'Место хранения',
                  ),
                  items: locations
                      .map(
                        (location) => DropdownMenuItem(
                          value: location.locationId,
                          child: Text(_locationPath(location, locations)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _locationId = value),
                ),
                const SizedBox(height: BanochkiSpacing.sm),
                if (state.snapshot.batches.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _repeatLast(state.snapshot.batches.first),
                    icon: const Icon(Icons.replay),
                    label: const Text('Повторить последнюю партию'),
                  ),
                const SizedBox(height: BanochkiSpacing.sm),
                ExpansionTile(
                  initiallyExpanded: _advanced,
                  onExpansionChanged: (value) => _advanced = value,
                  title: const Text('Дополнить сейчас'),
                  subtitle: const Text('Можно пропустить и вернуться позже.'),
                  children: [
                    const SizedBox(height: BanochkiSpacing.xs),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Категория'),
                      items:
                          const [
                                'Овощи',
                                'Фрукты',
                                'Варенье',
                                'Соусы',
                                'Другое',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => _category = value ?? 'Другое'),
                    ),
                    const SizedBox(height: BanochkiSpacing.md),
                    Text(
                      'Объём банки',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: BanochkiSpacing.xs,
                      children: [
                        for (final value in const [500, 700, 1000, 1500])
                          ChoiceChip(
                            label: Text(
                              value >= 1000 ? '${value / 1000} л' : '$value мл',
                            ),
                            selected: _volumeMl == value,
                            onSelected: (_) =>
                                setState(() => _volumeMl = value),
                          ),
                      ],
                    ),
                    const SizedBox(height: BanochkiSpacing.sm),
                    TextField(
                      controller: _customVolumeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Другой объём',
                        suffixText: 'мл',
                      ),
                      onChanged: (value) => setState(() {
                        _volumeMl = int.tryParse(value);
                      }),
                    ),
                    const SizedBox(height: BanochkiSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Дата заготовки'),
                      subtitle: Text(_formatDate(_preservedAt)),
                      trailing: FilledButton.tonal(
                        onPressed: () =>
                            setState(() => _preservedAt = DateTime.now()),
                        child: const Text('Сегодня'),
                      ),
                    ),
                    TextField(
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      controller: _harvestYearController,
                      decoration: const InputDecoration(
                        labelText: 'Год урожая',
                      ),
                      onChanged: (value) =>
                          _harvestYear = int.tryParse(value) ?? _harvestYear,
                    ),
                    const SizedBox(height: BanochkiSpacing.md),
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий',
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: BanochkiSpacing.md),
                  InlineError(message: _error!),
                ],
                const SizedBox(height: BanochkiSpacing.lg),
                PrimaryActionButton(
                  key: const Key('save-batch'),
                  label: 'Сохранить партию',
                  icon: Icons.check,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _repeatLast(BatchView view) {
    setState(() {
      _nameController.text = view.batch.name;
      _quantityController.text = '${view.batch.initialQuantity}';
      _locationId = view.projection.currentLocationId;
      _category = view.batch.category;
      _volumeMl = view.batch.jarVolumeMl;
      _harvestYear = DateTime.now().year;
      _harvestYearController.text = '$_harvestYear';
      _commentController.text = view.batch.comment ?? '';
    });
  }

  Future<void> _save() async {
    final quantity = int.tryParse(_quantityController.text);
    if (_nameController.text.trim().isEmpty ||
        quantity == null ||
        quantity <= 0 ||
        _locationId == null) {
      setState(
        () => _error = 'Заполните название, положительное количество и место.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(appControllerProvider.notifier)
          .createBatch(
            CreateBatchInput(
              name: _nameController.text,
              initialQuantity: quantity,
              storageLocationId: _locationId!,
              category: _category,
              jarVolumeMl: _volumeMl,
              preservedAt: _preservedAt,
              harvestYear: _harvestYear,
              comment: _commentController.text,
            ),
          );
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                BatchConfirmationScreen(batchId: created.batch.batchId),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _locationPath(StorageLocation location, List<StorageLocation> all) {
  final byId = {for (final item in all) item.locationId: item};
  final names = <String>[location.name];
  var parent = location.parentLocationId;
  while (parent != null) {
    final item = byId[parent];
    if (item == null) break;
    names.add(item.name);
    parent = item.parentLocationId;
  }
  return names.reversed.join(' · ');
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
