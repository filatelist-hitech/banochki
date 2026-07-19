import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';
import '../../batches/presentation/add_batch_screen.dart';
import '../../batches/presentation/batch_details_screen.dart';
import '../../batches/presentation/catalog_screen.dart';
import '../../inventory/domain/models.dart';
import '../../locations/presentation/location_form_screen.dart';
import '../../settings/presentation/settings_screen.dart';

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
        toolbarHeight: 92,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Что осталось',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              snapshot.family?.name ?? '',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Настройки семьи',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: snapshot.locations.any((item) => !item.isArchived)
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 32,
                height: BanochkiTargets.standard,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AddBatchScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Добавить партию'),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BanochkiSpacing.md,
            BanochkiSpacing.sm,
            BanochkiSpacing.md,
            BanochkiSpacing.xl + BanochkiTargets.standard + 96,
          ),
          children: [
            _MetricGrid(
              total: total,
              batches: active.length,
              attention: attention,
            ),
            const SizedBox(height: BanochkiSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Недавние партии',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CatalogScreen(),
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Все'),
                ),
              ],
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
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(BanochkiSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: BanochkiSpacing.xxs),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: BanochkiSpacing.xxs),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ],
      ),
    ),
  );
}

final class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.total,
    required this.batches,
    required this.attention,
  });

  final int total;
  final int batches;
  final int attention;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricCard(
        label: 'Всего единиц',
        value: '$total',
        icon: Icons.inventory_2_outlined,
        color: BanochkiColors.support,
      ),
      _MetricCard(
        label: 'Партий',
        value: '$batches',
        icon: Icons.layers_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      _MetricCard(
        label: 'Внимание',
        value: '$attention',
        icon: Icons.priority_high_rounded,
        color: BanochkiColors.attention,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final columns = textScale > 1.4 ? 1 : 3;
        final width =
            (constraints.maxWidth - BanochkiSpacing.xs * (columns - 1)) /
            columns;
        return Wrap(
          spacing: BanochkiSpacing.xs,
          runSpacing: BanochkiSpacing.xs,
          children: [
            for (final metric in metrics) SizedBox(width: width, child: metric),
          ],
        );
      },
    );
  }
}
