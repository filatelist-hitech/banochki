import 'dart:io';

import 'package:flutter/material.dart';

import '../../features/inventory/domain/models.dart';
import 'batch_categories.dart';
import 'banochki_theme.dart';

final class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.large = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool large;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: large ? BanochkiTargets.large : BanochkiTargets.standard,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label, style: TextStyle(fontSize: large ? 23 : 18)),
    ),
  );
}

final class QuantityDisplay extends StatelessWidget {
  const QuantityDisplay({
    required this.quantity,
    required this.unit,
    this.initialQuantity,
    this.large = false,
    super.key,
  });

  final int quantity;
  final String unit;
  final int? initialQuantity;
  final bool large;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Осталось $quantity $unit',
    child: ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$quantity',
            style: TextStyle(
              fontSize: large ? 64 : 48,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: BanochkiSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              initialQuantity == null ? unit : 'из $initialQuantity $unit',
              style: TextStyle(fontSize: large ? 22 : 17),
            ),
          ),
        ],
      ),
    ),
  );
}

final class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final BatchStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      BatchStatus.needsReconciliation => (
        Icons.sync_problem,
        BanochkiColors.danger,
      ),
      BatchStatus.needsCheck => (
        Icons.visibility_outlined,
        BanochkiColors.attention,
      ),
      BatchStatus.runningLow || BatchStatus.lastOneOrTwo => (
        Icons.hourglass_bottom,
        BanochkiColors.attention,
      ),
      BatchStatus.finished || BatchStatus.spoiled => (
        Icons.inventory_2_outlined,
        Theme.of(context).colorScheme.outline,
      ),
      BatchStatus.archived => (
        Icons.archive_outlined,
        Theme.of(context).colorScheme.outline,
      ),
      BatchStatus.many => (Icons.check_circle_outline, BanochkiColors.support),
    };
    return Semantics(
      label: 'Статус: ${status.label}',
      child: Chip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(status.label),
        side: BorderSide(color: color),
        backgroundColor: color.withValues(alpha: 0.08),
      ),
    );
  }
}

final class LocationBreadcrumb extends StatelessWidget {
  const LocationBreadcrumb({required this.path, this.large = false, super.key});

  final String path;
  final bool large;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Место: $path',
    child: ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.place_outlined, size: large ? 28 : 22),
          const SizedBox(width: BanochkiSpacing.xs),
          Expanded(
            child: Text(path, style: TextStyle(fontSize: large ? 22 : 16)),
          ),
        ],
      ),
    ),
  );
}

final class BatchCard extends StatelessWidget {
  const BatchCard({
    required this.view,
    required this.onTap,
    this.large = false,
    super.key,
  });

  final BatchView view;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${view.batch.name}, осталось ${view.projection.displayQuantity} ${view.batch.quantityUnit}, ${view.locationPath}, ${view.status.label}',
    child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BanochkiRadius.card),
        child: Padding(
          padding: EdgeInsets.all(
            large ? BanochkiSpacing.lg : BanochkiSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: large ? 76 : 64,
                height: large ? 76 : 64,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer.withValues(alpha: 0.46),
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: Icon(
                    BatchCategories.iconFor(
                      name: view.batch.name,
                      category: view.batch.category,
                    ),
                    size: large ? 38 : 32,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(width: BanochkiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.batch.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: large ? 24 : 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: BanochkiSpacing.xs),
                    Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: '${view.projection.displayQuantity}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: large ? 28 : 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text:
                                ' из ${view.batch.initialQuantity} ${view.batch.quantityUnit}'
                                '${view.batch.jarVolumeMl == null ? '' : ' · ${_volume(view.batch.jarVolumeMl!)}'}'
                                '${view.batch.harvestYear == null ? '' : ' · ${view.batch.harvestYear}'}',
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: BanochkiSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: large ? 22 : 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: BanochkiSpacing.xxs),
                        Expanded(
                          child: Text(
                            view.locationPath.replaceAll(' → ', ' · '),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: BanochkiSpacing.xs),
                    StatusBadge(status: view.status),
                  ],
                ),
              ),
              if (view.photoPath != null) ...[
                const SizedBox(width: BanochkiSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(BanochkiRadius.control),
                  child: Image.file(
                    File(view.photoPath!),
                    width: large ? 120 : 96,
                    height: large ? 120 : 104,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: large ? 120 : 96,
                      height: large ? 120 : 104,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: Icon(
                        BatchCategories.iconFor(
                          name: view.batch.name,
                          category: view.batch.category,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: large ? 30 : 26,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(BanochkiSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shelves,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: BanochkiSpacing.md),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: BanochkiSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: BanochkiSpacing.lg),
              PrimaryActionButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    ),
  );
}

final class InlineError extends StatelessWidget {
  const InlineError({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Ошибка: $message',
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(BanochkiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Попробовать снова'),
              ),
          ],
        ),
      ),
    ),
  );
}

String _volume(int ml) {
  if (ml == 1000) return '1 л';
  if (ml > 1000 && ml % 100 == 0) {
    return '${(ml / 1000).toStringAsFixed(1).replaceAll('.', ',')} л';
  }
  return '$ml мл';
}
