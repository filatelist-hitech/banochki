import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/errors/domain_exception.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';
import '../../history/presentation/history_screen.dart';
import '../../inventory/domain/models.dart';
import '../../inventory/presentation/inventory_dialogs.dart';
import '../../inventory/presentation/reconcile_screen.dart';
import 'edit_batch_screen.dart';
import '../../qr/presentation/qr_label_screen.dart';

final class BatchDetailsScreen extends ConsumerWidget {
  const BatchDetailsScreen({required this.batchId, super.key});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final view = state.snapshot.batches.firstWhere(
      (item) => item.batch.batchId == batchId,
    );
    final large = state.snapshot.settings.largeMode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка партии'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'history') _openHistory(context);
              if (value == 'edit') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditBatchScreen(batchId: batchId),
                  ),
                );
              }
              if (value == 'archive') _toggleArchive(context, ref, view);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Изменить данные'),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Text('Открыть историю'),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  view.batch.isArchived ? 'Вернуть из архива' : 'Архивировать',
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(BanochkiSpacing.md),
          children: [
            Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(
                          BanochkiRadius.card,
                        ),
                      ),
                      child: Semantics(
                        label: 'Фото партии не добавлено',
                        child: const Icon(Icons.inventory_2_outlined, size: 72),
                      ),
                    ),
                    const SizedBox(height: BanochkiSpacing.lg),
                    Text(
                      view.batch.name,
                      style: TextStyle(
                        fontSize: large ? 34 : 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BanochkiSpacing.sm),
                    QuantityDisplay(
                      quantity: view.projection.displayQuantity,
                      initialQuantity: view.batch.initialQuantity,
                      large: large,
                    ),
                    const SizedBox(height: BanochkiSpacing.md),
                    LocationBreadcrumb(path: view.locationPath, large: large),
                    const SizedBox(height: BanochkiSpacing.sm),
                    StatusBadge(status: view.status),
                    if (view.projection.needsReconciliation) ...[
                      const SizedBox(height: BanochkiSpacing.md),
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(BanochkiSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Расчёт и физические действия разошлись. Посчитайте банки, история сохранится.',
                              ),
                              const SizedBox(height: BanochkiSpacing.sm),
                              FilledButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ReconcileScreen(batchId: batchId),
                                  ),
                                ),
                                child: const Text('Уточнить остаток'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: BanochkiSpacing.lg),
                    PrimaryActionButton(
                      key: const Key('take-one'),
                      label: 'Взял 1',
                      icon: Icons.remove_circle_outline,
                      large: large,
                      onPressed: view.batch.isArchived
                          ? null
                          : () => _performQuantity(
                              context,
                              ref,
                              view,
                              InventoryEventType.jarsTaken,
                              1,
                              'Взята 1 банка',
                            ),
                    ),
                    const SizedBox(height: BanochkiSpacing.sm),
                    OutlinedButton(
                      onPressed: view.batch.isArchived
                          ? null
                          : () => _askQuantity(
                              context,
                              ref,
                              view,
                              InventoryEventType.jarsTaken,
                              'Сколько взяли?',
                              'Банки взяты',
                            ),
                      child: const Text('Взял несколько'),
                    ),
                    const SizedBox(height: BanochkiSpacing.lg),
                    Wrap(
                      spacing: BanochkiSpacing.sm,
                      runSpacing: BanochkiSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: view.batch.isArchived
                              ? null
                              : () => _askQuantity(
                                  context,
                                  ref,
                                  view,
                                  InventoryEventType.jarsReturned,
                                  'Сколько вернули?',
                                  'Банки возвращены',
                                ),
                          icon: const Icon(Icons.keyboard_return),
                          label: const Text('Вернул банки'),
                        ),
                        OutlinedButton.icon(
                          onPressed: view.batch.isArchived
                              ? null
                              : () => _askQuantity(
                                  context,
                                  ref,
                                  view,
                                  InventoryEventType.jarsSpoiled,
                                  'Сколько испорчено?',
                                  'Порча отмечена',
                                ),
                          icon: const Icon(Icons.warning_amber),
                          label: const Text('Испорчено'),
                        ),
                        OutlinedButton.icon(
                          onPressed: view.batch.isArchived
                              ? null
                              : () => _move(context, ref, view),
                          icon: const Icon(Icons.drive_file_move_outline),
                          label: const Text('Переместить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: BanochkiSpacing.lg),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(BanochkiSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Детали',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: BanochkiSpacing.sm),
                            Text('Категория: ${view.batch.category}'),
                            Text('Объём: ${_volume(view.batch.jarVolumeMl)}'),
                            Text(
                              'Год: ${view.batch.harvestYear ?? 'не указан'}',
                            ),
                            if (view.batch.recipeName != null)
                              Text('Рецепт: ${view.batch.recipeName}'),
                            if (view.batch.comment != null)
                              Text('Комментарий: ${view.batch.comment}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: BanochkiSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () => _openHistory(context),
                      icon: const Icon(Icons.history),
                      label: const Text('История партии'),
                    ),
                    const SizedBox(height: BanochkiSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final qr = await ref
                            .read(appControllerProvider.notifier)
                            .generateQrForBatch(batchId);
                        if (!context.mounted) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => QrLabelScreen(
                              qr: qr,
                              title: view.batch.name,
                              subtitle:
                                  '${view.batch.harvestYear ?? 'Год не указан'} · ${_volume(view.batch.jarVolumeMl)}',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Показать QR'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _askQuantity(
    BuildContext context,
    WidgetRef ref,
    BatchView view,
    InventoryEventType type,
    String question,
    String success,
  ) async {
    final quantity = await showQuantityDialog(
      context,
      title: question,
      large: ref
          .read(appControllerProvider)
          .requireValue
          .snapshot
          .settings
          .largeMode,
    );
    if (quantity != null && context.mounted) {
      await _performQuantity(context, ref, view, type, quantity, success);
    }
  }

  Future<void> _performQuantity(
    BuildContext context,
    WidgetRef ref,
    BatchView view,
    InventoryEventType type,
    int quantity,
    String success,
  ) async {
    final controller = ref.read(appControllerProvider.notifier);
    try {
      await controller.recordEvent(
        batchId: batchId,
        type: type,
        quantity: quantity,
      );
    } on UnderflowConfirmationRequired {
      if (!context.mounted || !await showUnderflowWarning(context)) return;
      await controller.recordEvent(
        batchId: batchId,
        type: type,
        quantity: quantity,
        confirmUnderflow: true,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
      return;
    }
    if (!context.mounted) return;
    final updated = ref
        .read(appControllerProvider)
        .requireValue
        .snapshot
        .batches
        .firstWhere((item) => item.batch.batchId == batchId);
    final undo = await showQuantityConfirmation(
      context,
      title: success,
      remaining: updated.projection.displayQuantity,
      large:
          updated.batch.batchId == view.batch.batchId &&
          ref
              .read(appControllerProvider)
              .requireValue
              .snapshot
              .settings
              .largeMode,
    );
    if (undo && context.mounted) {
      final inverse = type == InventoryEventType.jarsReturned
          ? InventoryEventType.jarsTaken
          : InventoryEventType.jarsReturned;
      await controller.recordEvent(
        batchId: batchId,
        type: inverse,
        quantity: quantity,
        confirmUnderflow: true,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Исправление записано новым событием.')),
        );
      }
    }
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    BatchView view,
  ) async {
    final allLocations = ref
        .read(appControllerProvider)
        .requireValue
        .snapshot
        .locations;
    final locations = allLocations
        .where(
          (item) =>
              !item.isArchived &&
              item.locationId != view.projection.currentLocationId,
        )
        .toList();
    final target = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Куда переместить?')),
            for (final location in locations)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(_locationPath(location, allLocations)),
                onTap: () => Navigator.pop(context, location.locationId),
              ),
          ],
        ),
      ),
    );
    if (target == null || !context.mounted) return;
    await ref
        .read(appControllerProvider.notifier)
        .recordEvent(
          batchId: batchId,
          type: InventoryEventType.batchMoved,
          toLocationId: target,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Новое место сохранено.')));
    }
  }

  void _openHistory(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => HistoryScreen(batchId: batchId)),
  );

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    BatchView view,
  ) async {
    await ref
        .read(appControllerProvider.notifier)
        .recordEvent(
          batchId: batchId,
          type: view.batch.isArchived
              ? InventoryEventType.batchRestored
              : InventoryEventType.batchArchived,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            view.batch.isArchived ? 'Партия возвращена.' : 'Партия в архиве.',
          ),
        ),
      );
    }
  }
}

String _volume(int? ml) {
  if (ml == null) return 'не указан';
  if (ml == 1000) return '1 л';
  if (ml > 1000) {
    return '${(ml / 1000).toStringAsFixed(1).replaceAll('.', ',')} л';
  }
  return '$ml мл';
}

String _locationPath(StorageLocation location, List<StorageLocation> all) {
  final byId = {for (final item in all) item.locationId: item};
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
