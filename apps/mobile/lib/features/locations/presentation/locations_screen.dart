import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';
import '../../inventory/domain/models.dart';
import 'location_form_screen.dart';

final class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(appControllerProvider).requireValue.snapshot;
    final locations = snapshot.locations
        .where((item) => !item.isArchived)
        .toList();
    final roots = locations
        .where((item) => item.parentLocationId == null)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Где лежит'),
        actions: [
          TextButton.icon(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Добавить'),
          ),
        ],
      ),
      body: roots.isEmpty
          ? EmptyState(
              title: 'Мест пока нет',
              message: 'Создайте дерево: Дача → Погреб → Полка.',
              actionLabel: 'Добавить место',
              onAction: () => _openForm(context),
            )
          : ListView(
              padding: const EdgeInsets.all(BanochkiSpacing.md),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(BanochkiSpacing.md),
                    child: Text(
                      'Управление — обычными кнопками. Перетаскивать ничего не требуется.',
                    ),
                  ),
                ),
                const SizedBox(height: BanochkiSpacing.md),
                for (final root in roots)
                  _LocationBranch(
                    location: root,
                    all: locations,
                    depth: 0,
                    large: snapshot.settings.largeMode,
                  ),
              ],
            ),
    );
  }

  void _openForm(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const LocationFormScreen()));
}

final class _LocationBranch extends ConsumerWidget {
  const _LocationBranch({
    required this.location,
    required this.all,
    required this.depth,
    required this.large,
  });

  final StorageLocation location;
  final List<StorageLocation> all;
  final int depth;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = all
        .where((item) => item.parentLocationId == location.locationId)
        .toList();
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, bottom: BanochkiSpacing.xs),
      child: Column(
        children: [
          Card(
            child: ListTile(
              minTileHeight: large ? BanochkiTargets.large : null,
              contentPadding: EdgeInsets.symmetric(
                horizontal: large ? BanochkiSpacing.lg : BanochkiSpacing.md,
                vertical: large ? BanochkiSpacing.sm : 0,
              ),
              leading: Icon(
                depth == 0
                    ? Icons.home_outlined
                    : Icons.subdirectory_arrow_right,
              ),
              title: Text(
                location.name,
                style: TextStyle(fontSize: large ? 23 : null),
              ),
              subtitle: location.description == null
                  ? null
                  : Text(location.description!),
              trailing: PopupMenuButton<String>(
                tooltip: 'Действия с местом ${location.name}',
                onSelected: (value) => _act(context, ref, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'child', child: Text('Добавить внутри')),
                  PopupMenuItem(value: 'edit', child: Text('Изменить')),
                  PopupMenuItem(value: 'archive', child: Text('Архивировать')),
                ],
              ),
            ),
          ),
          for (final child in children)
            _LocationBranch(
              location: child,
              all: all,
              depth: depth + 1,
              large: large,
            ),
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String action) async {
    if (action == 'child') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              LocationFormScreen(initialParentId: location.locationId),
        ),
      );
      return;
    }
    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LocationFormScreen(location: location),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Архивировать место?'),
        content: Text('${location.name} исчезнет из выбора новых партий.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Архивировать'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(appControllerProvider.notifier)
          .archiveLocation(location.locationId);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}
