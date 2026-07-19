import 'package:banochki/app/app.dart';
import 'package:banochki/app/app_controller.dart';
import 'package:banochki/core/database/app_database.dart';
import 'package:banochki/features/history/presentation/history_screen.dart';
import 'package:banochki/features/home/presentation/home_screen.dart';
import 'package:banochki/features/inventory/data/sqlite_inventory_repository.dart';
import 'package:banochki/features/inventory/domain/models.dart';
import 'package:banochki/features/qr/domain/qr_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R1 data survives a full local lifecycle and restart', (
    tester,
  ) async {
    final databasePath = path.join(
      await getDatabasesPath(),
      'banochki-r1-integration.sqlite',
    );
    await deleteDatabase(databasePath);
    final firstDatabase = AppDatabase(
      factory: databaseFactory,
      databasePath: databasePath,
    );
    final firstRepository = SqliteInventoryRepository(database: firstDatabase);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryRepositoryProvider.overrideWith(
            (ref) async => firstRepository,
          ),
        ],
        child: const BanochkiApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-field-0')),
      'Семья Филателиста',
    );
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-field-1')),
      'Бабушка Валя',
    );
    await tester.tap(find.text('Создать семью'));
    await _pumpUntil(tester, find.byType(HomeScreen));
    expect(find.byType(HomeScreen), findsOneWidget);

    final dacha = await firstRepository.createLocation(name: 'Дача');
    final cellar = await firstRepository.createLocation(
      name: 'Погреб',
      parentLocationId: dacha.locationId,
    );
    final wall = await firstRepository.createLocation(
      name: 'Левая стена',
      parentLocationId: cellar.locationId,
    );
    final shelf = await firstRepository.createLocation(
      name: 'Полка 2',
      parentLocationId: wall.locationId,
    );
    final batch = await firstRepository.createBatch(
      CreateBatchInput(
        name: 'Огурцы маринованные',
        initialQuantity: 18,
        storageLocationId: shelf.locationId,
        jarVolumeMl: 1000,
        harvestYear: 2026,
      ),
    );
    final qr = await firstRepository.generateQrForBatch(batch.batch.batchId);
    expect(qr.payload, startsWith('banochki://qr/v1/'));
    expect(ShortCode.isValid(qr.shortCode), isTrue);
    expect(
      (await firstRepository.resolveQr(qr.payload)).qrCode?.targetId,
      batch.batch.batchId,
    );
    await firstRepository.recordEvent(
      batchId: batch.batch.batchId,
      type: InventoryEventType.jarsTaken,
      quantity: 2,
    );
    await firstRepository.recordEvent(
      batchId: batch.batch.batchId,
      type: InventoryEventType.jarsReturned,
      quantity: 1,
    );
    await firstRepository.recordEvent(
      batchId: batch.batch.batchId,
      type: InventoryEventType.jarsSpoiled,
      quantity: 1,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    await container.read(appControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.text('Огурцы маринованные'), findsOneWidget);
    expect(find.text('16 из 18 банок · 1 л · 2026'), findsOneWidget);
    await tester.tap(find.text('Огурцы маринованные'));
    await tester.pumpAndSettle();
    expect(find.text('Дача · Погреб · Левая стена · Полка 2'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('История партии'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('История партии'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryEventRow), findsNWidgets(4));
    expect(find.text('Испорчено 1 банок'), findsOneWidget);
    expect(find.text('Возвращено 1 банок'), findsOneWidget);
    expect(find.text('Взято 2 банок'), findsOneWidget);
    expect(find.text('Добавлено 18 банок'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await firstRepository.close();

    final reopenedDatabase = AppDatabase(
      factory: databaseFactory,
      databasePath: databasePath,
    );
    final reopenedRepository = SqliteInventoryRepository(
      database: reopenedDatabase,
    );
    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('reopened-app'),
        overrides: [
          inventoryRepositoryProvider.overrideWith(
            (ref) async => reopenedRepository,
          ),
        ],
        child: const BanochkiApp(),
      ),
    );
    await _pumpUntil(tester, find.byType(HomeScreen));

    expect(find.text('Огурцы маринованные'), findsOneWidget);
    expect(find.text('16 из 18 банок · 1 л · 2026'), findsOneWidget);
    final snapshot = await reopenedRepository.loadSnapshot();
    expect(snapshot.batches.single.projection.computedQuantity, 16);
    expect(snapshot.history, hasLength(4));
    expect(
      (await reopenedRepository.resolveShortCode(qr.shortCode)).kind,
      QrResolutionKind.resolved,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await reopenedRepository.close();
    await deleteDatabase(databasePath);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 120,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}
