import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../features/inventory/domain/models.dart';

final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final settings = state.snapshot.settings;
    final controller = ref.read(appControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(BanochkiSpacing.md),
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BanochkiSpacing.md,
            ),
            title: const Text('Крупный режим'),
            subtitle: const Text(
              'Большой текст, кнопки и один главный выбор на экране.',
            ),
            value: settings.largeMode,
            onChanged: (value) =>
                controller.setSettings(settings.copyWith(largeMode: value)),
          ),
          const Divider(),
          ListTile(
            title: const Text('Оформление'),
            trailing: DropdownButton<AppThemeMode>(
              value: settings.themeMode,
              onChanged: (value) {
                if (value != null) {
                  controller.setSettings(settings.copyWith(themeMode: value));
                }
              },
              items: const [
                DropdownMenuItem(
                  value: AppThemeMode.system,
                  child: Text('Системное'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.light,
                  child: Text('Светлое'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.dark,
                  child: Text('Тёмное'),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Порог «Заканчивается»'),
            subtitle: Text('${settings.lowStockThreshold} банки'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Уменьшить порог',
                  onPressed: settings.lowStockThreshold <= 3
                      ? null
                      : () => controller.setSettings(
                          settings.copyWith(
                            lowStockThreshold: settings.lowStockThreshold - 1,
                          ),
                        ),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: 'Увеличить порог',
                  onPressed: () => controller.setSettings(
                    settings.copyWith(
                      lowStockThreshold: settings.lowStockThreshold + 1,
                    ),
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.replay),
            title: const Text('Пересобрать остатки'),
            subtitle: const Text('Полностью повторить журнал событий.'),
            onTap: () async {
              await controller.rebuildProjections();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Остатки пересобраны из истории.'),
                  ),
                );
              }
            },
          ),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Добавить debug-данные'),
              subtitle: const Text(
                'Только debug: семья, места, партия и события.',
              ),
              enabled: !settings.seedApplied,
              onTap: settings.seedApplied
                  ? null
                  : () async {
                      await controller.seedDebugData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Демо-данные добавлены.'),
                          ),
                        );
                      }
                    },
            ),
          const SizedBox(height: BanochkiSpacing.xl),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(BanochkiSpacing.md),
              child: Text(
                'Все изменения сохраняются локально. В R1 нет аккаунта, облака и сетевых запросов.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
