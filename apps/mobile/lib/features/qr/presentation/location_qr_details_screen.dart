import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../batches/presentation/add_batch_screen.dart';
import '../../batches/presentation/batch_details_screen.dart';

final class LocationQrDetailsScreen extends ConsumerWidget {
  const LocationQrDetailsScreen({required this.locationId, super.key});
  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(appControllerProvider).requireValue.snapshot;
    final byId = {for (final item in snapshot.locations) item.locationId: item};
    final location = byId[locationId];
    if (location == null) {
      return const Scaffold(body: Center(child: Text('Место не найдено')));
    }
    final names = <String>[location.name];
    var parentId = location.parentLocationId;
    while (parentId != null && byId[parentId] != null) {
      names.add(byId[parentId]!.name);
      parentId = byId[parentId]!.parentLocationId;
    }
    final children = snapshot.locations
        .where(
          (item) => item.parentLocationId == locationId && !item.isArchived,
        )
        .toList();
    final batches = snapshot.batches
        .where(
          (item) =>
              item.projection.currentLocationId == locationId &&
              !item.batch.isArchived,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Место хранения')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            names.reversed.join(' · '),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddBatchScreen(initialLocationId: locationId),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Добавить партию сюда'),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Вложенные места'),
            for (final child in children)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(child.name),
              ),
          ],
          if (batches.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Партии в этом месте'),
            for (final batch in batches)
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(batch.batch.name),
                subtitle: Text('Осталось ${batch.projection.displayQuantity}'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        BatchDetailsScreen(batchId: batch.batch.batchId),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
