import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../batches/presentation/catalog_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../locations/presentation/locations_screen.dart';
import 'large_add_batch_screen.dart';

final class LargeHomeScreen extends ConsumerWidget {
  const LargeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final settings = state.snapshot.settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Баночки',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(BanochkiSpacing.lg),
              children: [
                Text(
                  'Что делаем?',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: BanochkiSpacing.lg),
                _LargeTile(
                  label: 'Добавить банки',
                  icon: Icons.add_box_outlined,
                  enabled: state.snapshot.locations.any(
                    (item) => !item.isArchived,
                  ),
                  hint: state.snapshot.locations.any((item) => !item.isArchived)
                      ? null
                      : 'Сначала добавьте место',
                  onTap: () => _open(context, const LargeAddBatchScreen()),
                ),
                _LargeTile(
                  label: 'Что осталось',
                  icon: Icons.inventory_2_outlined,
                  onTap: () => _open(context, const CatalogScreen()),
                ),
                _LargeTile(
                  label: 'Где лежит',
                  icon: Icons.place_outlined,
                  onTap: () => _open(context, const LocationsScreen()),
                ),
                _LargeTile(
                  label: 'Последние действия',
                  icon: Icons.history,
                  onTap: () => _open(context, const HistoryScreen()),
                ),
                const SizedBox(height: BanochkiSpacing.md),
                SizedBox(
                  height: BanochkiTargets.large,
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(appControllerProvider.notifier)
                        .setSettings(settings.copyWith(largeMode: false)),
                    icon: const Icon(Icons.text_decrease),
                    label: const Text(
                      'Обычный режим',
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));
}

final class _LargeTile extends StatelessWidget {
  const _LargeTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.hint,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BanochkiSpacing.md),
    child: Semantics(
      button: true,
      enabled: enabled,
      label: hint == null ? label : '$label. $hint',
      child: SizedBox(
        height: 92,
        child: FilledButton.tonalIcon(
          onPressed: enabled ? onTap : null,
          icon: Icon(icon, size: 34),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    ),
  );
}
