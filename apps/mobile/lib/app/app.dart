import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/banochki_theme.dart';
import '../core/ui/components.dart';
import '../features/accessibility_mode/presentation/large_home_screen.dart';
import '../features/batches/presentation/catalog_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/qr/presentation/qr_scanner_screen.dart';
import '../l10n/app_localizations.dart';
import '../features/inventory/domain/models.dart';
import 'app_controller.dart';

final class BanochkiApp extends ConsumerWidget {
  const BanochkiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final settings = app.value?.snapshot.settings ?? const AppSettings();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: banochkiLightTheme(),
      darkTheme: banochkiDarkTheme(),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: _AppGate(app: app),
    );
  }
}

final class _AppGate extends ConsumerWidget {
  const _AppGate({required this.app});

  final AsyncValue<AppViewState> app;

  @override
  Widget build(BuildContext context, WidgetRef ref) => app.when(
    loading: () => const SplashScreen(),
    error: (error, stackTrace) => Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BanochkiSpacing.lg),
          child: Center(
            child: InlineError(
              message: 'Не удалось открыть локальные данные: $error',
              onRetry: () => ref.invalidate(appControllerProvider),
            ),
          ),
        ),
      ),
    ),
    data: (state) {
      if (!state.snapshot.isOnboarded) return const OnboardingScreen();
      return state.snapshot.settings.largeMode
          ? const LargeHomeScreen()
          : const MainShell();
    },
  );
}

final class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Semantics(
        label: 'Баночки. Открываем локальные данные.',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 72),
            SizedBox(height: BanochkiSpacing.md),
            Text(
              'Баночки',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: BanochkiSpacing.sm),
            CircularProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}

final class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

final class _MainShellState extends State<MainShell> {
  var _index = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    CatalogScreen(),
    QrScannerScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final destinations = const <NavigationDestination>[
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Главная'),
      NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        label: 'Запасы',
      ),
      NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Сканер'),
      NavigationDestination(icon: Icon(Icons.history), label: 'История'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ещё'),
    ];
    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: [
                  for (final item in destinations)
                    NavigationRailDestination(
                      icon: item.icon,
                      label: Text(item.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _pages[_index]),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }
}
