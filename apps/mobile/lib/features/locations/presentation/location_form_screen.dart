import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';
import '../../inventory/domain/models.dart';

final class LocationFormScreen extends ConsumerStatefulWidget {
  const LocationFormScreen({this.location, this.initialParentId, super.key});

  final StorageLocation? location;
  final String? initialParentId;

  @override
  ConsumerState<LocationFormScreen> createState() => _LocationFormScreenState();
}

final class _LocationFormScreenState extends ConsumerState<LocationFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _parentId;
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.location?.name);
    _descriptionController = TextEditingController(
      text: widget.location?.description,
    );
    _parentId = widget.location?.parentLocationId ?? widget.initialParentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref
        .watch(appControllerProvider)
        .requireValue
        .snapshot
        .locations
        .where(
          (item) =>
              !item.isArchived &&
              item.locationId != widget.location?.locationId,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location == null ? 'Новое место' : 'Изменить место'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(BanochkiSpacing.md),
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    hintText: 'Например, Полка 2',
                  ),
                ),
                const SizedBox(height: BanochkiSpacing.md),
                DropdownButtonFormField<String?>(
                  initialValue: _parentId,
                  decoration: const InputDecoration(labelText: 'Вложить в'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Верхний уровень'),
                    ),
                    ...locations.map(
                      (location) => DropdownMenuItem<String?>(
                        value: location.locationId,
                        child: Text(_path(location, locations)),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _parentId = value),
                ),
                const SizedBox(height: BanochkiSpacing.md),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Описание — необязательно',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: BanochkiSpacing.md),
                  InlineError(message: _error!),
                ],
                const SizedBox(height: BanochkiSpacing.lg),
                PrimaryActionButton(
                  label: widget.location == null
                      ? 'Добавить место'
                      : 'Сохранить место',
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = ref.read(appControllerProvider.notifier);
      if (widget.location == null) {
        await controller.createLocation(
          name: _nameController.text,
          parentLocationId: _parentId,
          description: _descriptionController.text,
        );
      } else {
        await controller.updateLocation(
          locationId: widget.location!.locationId,
          name: _nameController.text,
          parentLocationId: _parentId,
          description: _descriptionController.text,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _path(StorageLocation location, List<StorageLocation> locations) {
  final byId = {for (final item in locations) item.locationId: item};
  final names = <String>[location.name];
  var parentId = location.parentLocationId;
  while (parentId != null) {
    final parent = byId[parentId];
    if (parent == null) break;
    names.add(parent.name);
    parentId = parent.parentLocationId;
  }
  return names.reversed.join(' · ');
}
