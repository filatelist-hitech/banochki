import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/batch_categories.dart';
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
  final _customCategoryController = TextEditingController();
  final _customUnitController = TextEditingController(text: 'шт.');
  late final TextEditingController _harvestYearController;
  String? _locationId;
  String _category = 'Овощи';
  int? _volumeMl;
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
    _customCategoryController.dispose();
    _customUnitController.dispose();
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
                  decoration: InputDecoration(
                    labelText: 'Количество',
                    suffixText: _quantityUnit,
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
                      items: BatchCategories.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value.label,
                              child: Row(
                                children: [
                                  Icon(value.icon, size: 20),
                                  const SizedBox(width: BanochkiSpacing.sm),
                                  Text(value.label),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _category = value ?? 'Другое';
                        if (_category != 'Другое') {
                          _customUnitController.text = BatchCategories.unitFor(
                            _category,
                          );
                        }
                      }),
                    ),
                    const SizedBox(height: BanochkiSpacing.md),
                    if (_category == 'Другое') ...[
                      TextField(
                        controller: _customCategoryController,
                        decoration: const InputDecoration(
                          labelText: 'Своя категория',
                          hintText: 'Например, Специи',
                        ),
                      ),
                      const SizedBox(height: BanochkiSpacing.md),
                      TextField(
                        controller: _customUnitController,
                        decoration: const InputDecoration(
                          labelText: 'Единица измерения',
                          hintText: 'шт., г, мл',
                        ),
                      ),
                    ] else
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.straighten_outlined),
                        title: const Text('Единица измерения'),
                        trailing: Text(
                          BatchCategories.unitFor(_category),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
      if (!BatchCategories.isPreset(_category)) {
        _customCategoryController.text = _category;
        _category = 'Другое';
      }
      _customUnitController.text = view.batch.quantityUnit;
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
        _locationId == null ||
        _effectiveCategory.isEmpty ||
        _quantityUnit.isEmpty) {
      setState(
        () => _error =
            'Заполните название, количество, место, категорию и единицу измерения.',
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
              category: _effectiveCategory,
              quantityUnit: _quantityUnit,
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

  String get _effectiveCategory =>
      _category == 'Другое' ? _customCategoryController.text.trim() : _category;

  String get _quantityUnit => _category == 'Другое'
      ? _customUnitController.text.trim()
      : BatchCategories.unitFor(_category);
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
