import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';

final class EditBatchScreen extends ConsumerStatefulWidget {
  const EditBatchScreen({required this.batchId, super.key});

  final String batchId;

  @override
  ConsumerState<EditBatchScreen> createState() => _EditBatchScreenState();
}

final class _EditBatchScreenState extends ConsumerState<EditBatchScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _volumeController;
  late final TextEditingController _yearController;
  late final TextEditingController _recipeController;
  late final TextEditingController _commentController;
  late String _category;
  DateTime? _preservedAt;
  DateTime? _checkAt;
  int? _spiciness;
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final batch = ref
        .read(appControllerProvider)
        .requireValue
        .snapshot
        .batches
        .firstWhere((item) => item.batch.batchId == widget.batchId)
        .batch;
    _nameController = TextEditingController(text: batch.name);
    _volumeController = TextEditingController(
      text: batch.jarVolumeMl?.toString(),
    );
    _yearController = TextEditingController(
      text: batch.harvestYear?.toString(),
    );
    _recipeController = TextEditingController(text: batch.recipeName);
    _commentController = TextEditingController(text: batch.comment);
    _category = batch.category;
    _preservedAt = batch.preservedAt;
    _checkAt = batch.checkAt;
    _spiciness = batch.spiciness;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _volumeController.dispose();
    _yearController.dispose();
    _recipeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Изменить партию')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(BanochkiSpacing.md),
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: BanochkiSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Категория'),
                items: const ['Овощи', 'Фрукты', 'Варенье', 'Соусы', 'Другое']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: BanochkiSpacing.md),
              TextField(
                controller: _volumeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Объём',
                  suffixText: 'мл',
                ),
              ),
              const SizedBox(height: BanochkiSpacing.md),
              TextField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Год урожая'),
              ),
              const SizedBox(height: BanochkiSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Дата заготовки'),
                subtitle: Text(_dateLabel(_preservedAt)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2200),
                      initialDate: _preservedAt ?? DateTime.now(),
                    );
                    if (picked != null) setState(() => _preservedAt = picked);
                  },
                  child: const Text('Выбрать'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Проверить после'),
                subtitle: Text(_dateLabel(_checkAt)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2200),
                      initialDate: _checkAt ?? DateTime.now(),
                    );
                    if (picked != null) setState(() => _checkAt = picked);
                  },
                  child: const Text('Выбрать'),
                ),
              ),
              DropdownButtonFormField<int?>(
                initialValue: _spiciness,
                decoration: const InputDecoration(labelText: 'Острота'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Не указана'),
                  ),
                  ...List.generate(
                    6,
                    (value) => DropdownMenuItem<int?>(
                      value: value,
                      child: Text('$value из 5'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _spiciness = value),
              ),
              const SizedBox(height: BanochkiSpacing.md),
              TextField(
                controller: _recipeController,
                decoration: const InputDecoration(
                  labelText: 'Название рецепта',
                ),
              ),
              const SizedBox(height: BanochkiSpacing.md),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
              if (_error != null) ...[
                const SizedBox(height: BanochkiSpacing.md),
                InlineError(message: _error!),
              ],
              const SizedBox(height: BanochkiSpacing.lg),
              PrimaryActionButton(
                label: 'Сохранить изменения',
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: BanochkiSpacing.sm),
              const Text(
                'Остаток и место меняются отдельными действиями — так история остаётся честной.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(appControllerProvider.notifier)
          .updateBatchMetadata(
            batchId: widget.batchId,
            name: _nameController.text,
            category: _category,
            jarVolumeMl: int.tryParse(_volumeController.text),
            preservedAt: _preservedAt,
            harvestYear: int.tryParse(_yearController.text),
            recipeName: _recipeController.text,
            comment: _commentController.text,
            spiciness: _spiciness,
            checkAt: _checkAt,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _dateLabel(DateTime? value) => value == null
    ? 'Не указана'
    : '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
