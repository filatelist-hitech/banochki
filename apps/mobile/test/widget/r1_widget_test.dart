import 'package:banochki/app/app.dart';
import 'package:banochki/app/app_controller.dart';
import 'package:banochki/core/ui/banochki_theme.dart';
import 'package:banochki/core/ui/components.dart';
import 'package:banochki/features/batches/presentation/add_batch_screen.dart';
import 'package:banochki/features/batches/presentation/catalog_screen.dart';
import 'package:banochki/features/inventory/domain/models.dart';
import 'package:banochki/features/inventory/presentation/inventory_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_inventory_repository.dart';

void main() {
  testWidgets('catalog renders a calm empty state', (tester) async {
    final repository = FakeInventoryRepository(fakeOnboardedSnapshot());

    await tester.pumpWidget(_withRepository(repository, const CatalogScreen()));
    await _pumpUntil(tester, find.text('Пока пусто'));

    expect(find.text('Пока пусто'), findsOneWidget);
    expect(find.text('Добавить партию'), findsOneWidget);
  });

  testWidgets('batch card exposes complete semantics at 200 percent text', (
    tester,
  ) async {
    final batch = Batch(
      batchId: 'batch',
      familyId: 'family',
      name: 'Огурцы',
      category: 'Овощи',
      initialQuantity: 18,
      jarVolumeMl: 1000,
      harvestYear: 2026,
      authorMemberId: 'member',
      storageLocationId: 'location',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final view = BatchView(
      batch: batch,
      projection: InventoryProjection(
        batchId: 'batch',
        computedQuantity: 16,
        currentLocationId: 'location',
        needsReconciliation: false,
        spoiledQuantity: 1,
        updatedAt: DateTime.utc(2026),
      ),
      locationPath: 'Дача · Погреб · Полка 2',
      status: BatchStatus.many,
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: banochkiLightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: BatchCard(view: view, onTap: () {}, large: true),
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Огурцы, осталось 16 банок, Дача · Погреб · Полка 2, Запас есть',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('add batch shows validation errors and then confirmation', (
    tester,
  ) async {
    final repository = FakeInventoryRepository(fakeOnboardedSnapshot());
    await tester.pumpWidget(
      _withRepository(repository, const AddBatchScreen()),
    );
    await _pumpUntil(tester, find.byKey(const Key('batch-name')));

    await tester.enterText(find.byKey(const Key('batch-name')), '');
    await tester.enterText(find.byKey(const Key('batch-quantity')), '0');
    await tester.tap(find.byKey(const Key('save-batch')));
    await tester.pump();
    expect(
      find.text('Заполните название, положительное количество и место.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('batch-name')), 'Лечо');
    await tester.enterText(find.byKey(const Key('batch-quantity')), '12');
    await tester.tap(find.byKey(const Key('save-batch')));
    await _pumpUntil(tester, find.text('ЛЕЧО'));
    expect(find.text('ЛЕЧО'), findsOneWidget);
    expect(find.text('12 БАНОК'), findsOneWidget);
  });

  testWidgets('quantity confirmation has explicit correction action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: banochkiLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showQuantityConfirmation(
                context,
                title: 'Банки взяты',
                remaining: 16,
                large: true,
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await _pumpUntil(tester, find.text('Осталось'));

    expect(find.text('Осталось'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('Исправить действие'), findsOneWidget);
  });

  testWidgets('large mode uses large labeled actions', (tester) async {
    final repository = FakeInventoryRepository(
      fakeOnboardedSnapshot(settings: const AppSettings(largeMode: true)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const BanochkiApp(),
      ),
    );
    await _pumpUntil(tester, find.text('Что делаем?'));

    expect(find.text('Что делаем?'), findsOneWidget);
    expect(find.text('Добавить банки'), findsOneWidget);
    expect(find.text('Что осталось'), findsOneWidget);
    expect(find.text('Где лежит'), findsOneWidget);
    expect(find.text('Последние действия'), findsOneWidget);
    expect(find.text('Обычный режим'), findsOneWidget);
    final button = tester.getSize(
      find.widgetWithText(FilledButton, 'Добавить банки'),
    );
    expect(button.height, greaterThanOrEqualTo(56));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('needs reconciliation is conveyed by text and semantics', (
    tester,
  ) async {
    final batch = Batch(
      batchId: 'batch',
      familyId: 'family',
      name: 'Томаты',
      category: 'Овощи',
      initialQuantity: 2,
      authorMemberId: 'member',
      storageLocationId: 'location',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final view = BatchView(
      batch: batch,
      projection: InventoryProjection(
        batchId: 'batch',
        computedQuantity: -1,
        currentLocationId: 'location',
        needsReconciliation: true,
        spoiledQuantity: 0,
        updatedAt: DateTime.utc(2026),
      ),
      locationPath: 'Погреб',
      status: BatchStatus.needsReconciliation,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: banochkiLightTheme(),
        home: Scaffold(
          body: BatchCard(view: view, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Нужно уточнить'), findsOneWidget);
    expect(find.textContaining('-1'), findsNothing);
  });
}

Widget _withRepository(FakeInventoryRepository repository, Widget child) =>
    ProviderScope(
      overrides: [
        inventoryRepositoryProvider.overrideWith((ref) async => repository),
      ],
      child: MaterialApp(
        theme: banochkiLightTheme(),
        home: _RepositoryReady(child: child),
      ),
    );

final class _RepositoryReady extends ConsumerWidget {
  const _RepositoryReady({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(appControllerProvider)
      .when(
        data: (_) => child,
        loading: () => const Scaffold(body: Text('Загрузка теста')),
        error: (error, stackTrace) => Scaffold(body: Text('Ошибка: $error')),
      );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}
