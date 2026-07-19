import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';
import '../../inventory/domain/models.dart';

final class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({this.batchId, super.key});

  final String? batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(appControllerProvider).requireValue.snapshot;
    final large = snapshot.settings.largeMode;
    final events = snapshot.history
        .where((event) => batchId == null || event.batchId == batchId)
        .toList();
    final batches = {
      for (final view in snapshot.batches) view.batch.batchId: view.batch.name,
    };
    final locations = {
      for (final location in snapshot.locations)
        location.locationId: location.name,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(batchId == null ? 'История семьи' : 'История партии'),
      ),
      body: events.isEmpty
          ? const EmptyState(
              title: 'История пока пуста',
              message: 'Действия появятся здесь и останутся после перезапуска.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(BanochkiSpacing.md),
              itemCount: events.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: BanochkiSpacing.xs),
              itemBuilder: (context, index) {
                final event = events[index];
                return HistoryEventRow(
                  event: event,
                  batchName: batches[event.batchId] ?? 'Партия',
                  actorName: snapshot.member?.displayName ?? 'Участник',
                  fromLocation: locations[event.fromLocationId],
                  toLocation: locations[event.toLocationId],
                  large: large,
                );
              },
            ),
    );
  }
}

final class HistoryEventRow extends StatelessWidget {
  const HistoryEventRow({
    required this.event,
    required this.batchName,
    required this.actorName,
    this.fromLocation,
    this.toLocation,
    this.large = false,
    super.key,
  });

  final InventoryEvent event;
  final String batchName;
  final String actorName;
  final String? fromLocation;
  final String? toLocation;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final description = _eventDescription(event, fromLocation, toLocation);
    return Semantics(
      label: '$actorName. $batchName. $description. ${_date(event.createdAt)}',
      child: Card(
        child: ListTile(
          contentPadding: EdgeInsets.all(
            large ? BanochkiSpacing.md : BanochkiSpacing.xs,
          ),
          leading: CircleAvatar(child: Icon(_eventIcon(event.eventType))),
          title: Text(
            description,
            style: TextStyle(fontSize: large ? 22 : null),
          ),
          subtitle: Text(
            '$batchName\n$actorName · ${_date(event.createdAt)}',
            style: TextStyle(fontSize: large ? 18 : null),
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}

String _eventDescription(
  InventoryEvent event,
  String? fromLocation,
  String? toLocation,
) => switch (event.eventType) {
  InventoryEventType.batchCreated => 'Добавлено ${event.quantityDelta} банок',
  InventoryEventType.jarsTaken => 'Взято ${-event.quantityDelta} банок',
  InventoryEventType.jarsReturned => 'Возвращено ${event.quantityDelta} банок',
  InventoryEventType.jarsSpoiled => 'Испорчено ${-event.quantityDelta} банок',
  InventoryEventType.batchMoved =>
    'Перемещено: ${fromLocation ?? 'прежнее место'} → ${toLocation ?? 'новое место'}',
  InventoryEventType.batchMetadataUpdated => 'Изменены данные партии',
  InventoryEventType.inventoryReconciled =>
    'Остаток уточнён${event.quantityDelta == 0 ? '' : ': ${event.quantityDelta > 0 ? '+' : ''}${event.quantityDelta}'}',
  InventoryEventType.noteAdded => 'Добавлена заметка',
  InventoryEventType.batchArchived => 'Партия перенесена в архив',
  InventoryEventType.batchRestored => 'Партия возвращена из архива',
};

IconData _eventIcon(InventoryEventType type) => switch (type) {
  InventoryEventType.batchCreated => Icons.add_box_outlined,
  InventoryEventType.jarsTaken => Icons.remove_circle_outline,
  InventoryEventType.jarsReturned => Icons.keyboard_return,
  InventoryEventType.jarsSpoiled => Icons.warning_amber,
  InventoryEventType.batchMoved => Icons.drive_file_move_outline,
  InventoryEventType.batchMetadataUpdated => Icons.edit_outlined,
  InventoryEventType.inventoryReconciled => Icons.fact_check_outlined,
  InventoryEventType.noteAdded => Icons.note_add_outlined,
  InventoryEventType.batchArchived => Icons.archive_outlined,
  InventoryEventType.batchRestored => Icons.unarchive_outlined,
};

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
