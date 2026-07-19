import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';
import 'batch_details_screen.dart';
import 'edit_batch_screen.dart';

final class BatchConfirmationScreen extends ConsumerWidget {
  const BatchConfirmationScreen({required this.batchId, super.key});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref
        .watch(appControllerProvider)
        .requireValue
        .snapshot
        .batches
        .firstWhere((item) => item.batch.batchId == batchId);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(BanochkiSpacing.lg),
              child: Semantics(
                liveRegion: true,
                label:
                    '${view.batch.name}. ${view.projection.displayQuantity} банок. ${view.locationPath}. Партия сохранена.',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 76,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: BanochkiSpacing.lg),
                    Text(
                      view.batch.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BanochkiSpacing.lg),
                    Text(
                      '${view.projection.displayQuantity} БАНОК',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BanochkiSpacing.md),
                    Text(
                      view.locationPath,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: BanochkiSpacing.xl),
                    PrimaryActionButton(
                      label: 'Готово',
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                    ),
                    const SizedBox(height: BanochkiSpacing.xs),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => EditBatchScreen(batchId: batchId),
                        ),
                      ),
                      child: const Text('Исправить'),
                    ),
                    TextButton(
                      onPressed: () => _openDetails(context, replace: true),
                      child: const Text('Открыть партию'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, {required bool replace}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => BatchDetailsScreen(batchId: batchId),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }
}
