import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../domain/qr_models.dart';
import 'location_qr_details_screen.dart';
import '../../batches/presentation/batch_details_screen.dart';

final class LinkUnlinkedQrScreen extends ConsumerWidget {
  const LinkUnlinkedQrScreen({required this.qr, super.key});

  final QrCode qr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(appControllerProvider).requireValue.snapshot;
    final batches = snapshot.batches
        .where((item) => !item.batch.isArchived)
        .toList();
    final locations = snapshot.locations
        .where((item) => !item.isArchived)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Привязать этикетку')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Свободный номер ${qr.shortCode}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Выберите цель. Ничего не привяжется без вашего подтверждения.',
          ),
          const SizedBox(height: 24),
          Text('К партии', style: Theme.of(context).textTheme.titleLarge),
          for (final view in batches)
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(view.batch.name),
              subtitle: Text(view.locationPath),
              onTap: () => _linkBatch(context, ref, view.batch.batchId),
            ),
          const SizedBox(height: 16),
          Text('К месту', style: Theme.of(context).textTheme.titleLarge),
          for (final location in locations)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(location.name),
              onTap: () => _linkLocation(context, ref, location.locationId),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  Future<void> _linkBatch(
    BuildContext context,
    WidgetRef ref,
    String batchId,
  ) async {
    final confirmed = await _confirm(context);
    if (confirmed != true) return;
    final linked = await ref
        .read(appControllerProvider.notifier)
        .linkQrToBatch(qrId: qr.id, batchId: batchId);
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BatchDetailsScreen(batchId: linked.targetId!),
      ),
    );
  }

  Future<void> _linkLocation(
    BuildContext context,
    WidgetRef ref,
    String locationId,
  ) async {
    final confirmed = await _confirm(context);
    if (confirmed != true) return;
    final linked = await ref
        .read(appControllerProvider.notifier)
        .linkQrToLocation(qrId: qr.id, locationId: locationId);
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LocationQrDetailsScreen(locationId: linked.targetId!),
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Привязать QR?'),
      content: const Text(
        'Операция сохранится в журнале QR. Позже код можно отозвать или перевыпустить.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Привязать'),
        ),
      ],
    ),
  );
}
