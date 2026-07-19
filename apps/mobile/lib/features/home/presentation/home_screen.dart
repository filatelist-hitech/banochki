import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';
import '../../batches/presentation/add_batch_screen.dart';
import '../../batches/presentation/batch_details_screen.dart';
import '../../inventory/domain/models.dart';
import '../../locations/presentation/location_form_screen.dart';

final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final snapshot = state.snapshot;
    final active = snapshot.batches
        .where((item) => !item.batch.isArchived)
        .toList();
    final total = active.fold<int>(
      0,
      (sum, item) => sum + item.projection.displayQuantity,
    );
    final attention = active
        .where(
          (item) =>
              item.status == BatchStatus.needsReconciliation ||
              item.status == BatchStatus.needsCheck,
        )
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Что осталось'),
            Text(
              snapshot.family?.name ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: snapshot.locations.any((item) => !item.isArchived)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AddBatchScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Добавить партию'),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BanochkiSpacing.md,
            BanochkiSpacing.sm,
            BanochkiSpacing.md,
            96,
          ),
          children: [
            Wrap(
              spacing: BanochkiSpacing.sm,
              runSpacing: BanochkiSpacing.sm,
              children: [
                _MetricCard(label: 'Всего банок', value: '$total'),
                _MetricCard(
                  label: 'Активных партий',
                  value: '${active.length}',
                ),
                _MetricCard(label: 'Нужно внимания', value: '$attention'),
              ],
            ),
            const SizedBox(height: BanochkiSpacing.xl),
            Text(
              'Недавние партии',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: BanochkiSpacing.md),
            if (snapshot.locations.where((item) => !item.isArchived).isEmpty)
              EmptyState(
                title: 'Сначала добавим место',
                message: 'Например: Дача → Погреб → Полка 2.',
                actionLabel: 'Добавить место',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LocationFormScreen(),
                  ),
                ),
              )
            else if (active.isEmpty)
              EmptyState(
                title: 'Пока пусто',
                message: 'Первая партия создаётся из трёх значений.',
                actionLabel: 'Добавить партию',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AddBatchScreen(),
                  ),
                ),
              )
            else
              ...active
                  .take(4)
                  .map(
                    (view) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: BanochkiSpacing.sm,
                      ),
                      child: BatchCard(
                        view: view,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                BatchDetailsScreen(batchId: view.batch.batchId),
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 156,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(BanochkiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: BanochkiSpacing.xxs),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
