import 'package:banochki/core/errors/domain_exception.dart';
import 'package:banochki/features/inventory/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/repository_test_harness.dart';

void main() {
  group('local inventory repository', () {
    late RepositoryTestHarness harness;

    setUp(() async {
      harness = await RepositoryTestHarness.create();
    });

    tearDown(() => harness.dispose());

    test('applies all quantity events and preserves history order', () async {
      final repository = harness.repository;
      final batchId = harness.batch!.batch.batchId;
      await repository.recordEvent(
        batchId: batchId,
        type: InventoryEventType.jarsTaken,
        quantity: 2,
      );
      await repository.recordEvent(
        batchId: batchId,
        type: InventoryEventType.jarsReturned,
        quantity: 1,
      );
      await repository.recordEvent(
        batchId: batchId,
        type: InventoryEventType.jarsSpoiled,
        quantity: 1,
      );

      final snapshot = await repository.loadSnapshot();
      expect(snapshot.batches.single.projection.computedQuantity, 16);
      expect(snapshot.history, hasLength(4));
      expect(snapshot.history.map((event) => event.eventType), [
        InventoryEventType.jarsSpoiled,
        InventoryEventType.jarsReturned,
        InventoryEventType.jarsTaken,
        InventoryEventType.batchCreated,
      ]);
    });

    test('same idempotency key has one domain effect', () async {
      final repository = harness.repository;
      final batchId = harness.batch!.batch.batchId;
      for (var index = 0; index < 10; index++) {
        await repository.recordEvent(
          batchId: batchId,
          type: InventoryEventType.jarsTaken,
          quantity: 2,
          idempotencyKey: 'same-operation',
        );
      }
      final snapshot = await repository.loadSnapshot();
      expect(snapshot.batches.single.projection.computedQuantity, 16);
      expect(snapshot.history, hasLength(2));
    });

    test('projection rebuild restores the same quantity and status', () async {
      final repository = harness.repository;
      final batchId = harness.batch!.batch.batchId;
      await repository.recordEvent(
        batchId: batchId,
        type: InventoryEventType.jarsTaken,
        quantity: 16,
      );
      final before = (await repository.loadSnapshot()).batches.single;
      final db = await harness.database.open();
      await db.delete('inventory_projections');
      await repository.rebuildProjections();
      final after = (await repository.loadSnapshot()).batches.single;

      expect(
        after.projection.computedQuantity,
        before.projection.computedQuantity,
      );
      expect(after.status, before.status);
      expect(
        after.projection.currentLocationId,
        before.projection.currentLocationId,
      );
    });

    test(
      'underflow requires confirmation and reconciliation clears it',
      () async {
        final repository = harness.repository;
        final batchId = harness.batch!.batch.batchId;
        expect(
          () => repository.recordEvent(
            batchId: batchId,
            type: InventoryEventType.jarsTaken,
            quantity: 20,
          ),
          throwsA(isA<UnderflowConfirmationRequired>()),
        );
        await repository.recordEvent(
          batchId: batchId,
          type: InventoryEventType.jarsTaken,
          quantity: 20,
          confirmUnderflow: true,
        );
        var view = (await repository.loadSnapshot()).batches.single;
        expect(view.projection.computedQuantity, -2);
        expect(view.projection.displayQuantity, 0);
        expect(view.status, BatchStatus.needsReconciliation);

        await repository.reconcile(batchId: batchId, actualQuantity: 3);
        view = (await repository.loadSnapshot()).batches.single;
        expect(view.projection.computedQuantity, 3);
        expect(view.projection.needsReconciliation, isFalse);
        expect(view.status, BatchStatus.runningLow);
      },
    );

    test('moving a batch is rebuilt from append-only events', () async {
      final repository = harness.repository;
      final shelf = await repository.createLocation(
        name: 'Полка 2',
        parentLocationId: harness.location!.locationId,
      );
      await repository.recordEvent(
        batchId: harness.batch!.batch.batchId,
        type: InventoryEventType.batchMoved,
        toLocationId: shelf.locationId,
      );
      await repository.rebuildProjections();
      final view = (await repository.loadSnapshot()).batches.single;
      expect(view.projection.currentLocationId, shelf.locationId);
      expect(view.locationPath, 'Погреб · Полка 2');
    });

    test('location cycle and non-empty archive are rejected', () async {
      final repository = harness.repository;
      final child = await repository.createLocation(
        name: 'Полка',
        parentLocationId: harness.location!.locationId,
      );
      expect(
        () => repository.updateLocation(
          locationId: harness.location!.locationId,
          name: 'Погреб',
          parentLocationId: child.locationId,
        ),
        throwsA(isA<LocationCycleException>()),
      );
      expect(
        () => repository.archiveLocation(harness.location!.locationId),
        throwsA(isA<LocationNotEmptyException>()),
      );
    });

    test('archive and restore are append-only events', () async {
      final repository = harness.repository;
      final batchId = harness.batch!.batch.batchId;
      await repository.recordEvent(
        batchId: batchId,
        type: InventoryEventType.batchArchived,
      );
      var snapshot = await repository.loadSnapshot();
      expect(snapshot.batches.single.status, BatchStatus.archived);
      await repository.recordEvent(
        batchId: batchId,
        type: InventoryEventType.batchRestored,
      );
      snapshot = await repository.loadSnapshot();
      expect(snapshot.batches.single.batch.isArchived, isFalse);
      expect(snapshot.history.take(2).map((event) => event.eventType), [
        InventoryEventType.batchRestored,
        InventoryEventType.batchArchived,
      ]);
    });

    test('quantity and volume validation leaves no partial batch', () async {
      final repository = harness.repository;
      final before = (await repository.loadSnapshot()).batches.length;
      expect(
        () => repository.createBatch(
          CreateBatchInput(
            name: 'Ошибка',
            initialQuantity: 0,
            storageLocationId: harness.location!.locationId,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => repository.createBatch(
          CreateBatchInput(
            name: 'Ошибка',
            initialQuantity: 1,
            jarVolumeMl: -1,
            storageLocationId: harness.location!.locationId,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect((await repository.loadSnapshot()).batches.length, before);
    });

    test('local search and combined filters work without network', () async {
      final repository = harness.repository;
      final shelf = await repository.createLocation(
        name: 'Полка Ёжика',
        parentLocationId: harness.location!.locationId,
      );
      await repository.createBatch(
        CreateBatchInput(
          name: 'Варенье из ёжевики',
          initialQuantity: 3,
          storageLocationId: shelf.locationId,
          category: 'Варенье',
          harvestYear: 2025,
        ),
      );
      final result = await repository.searchCatalog(
        CatalogQuery(
          search: 'ЕЖЕВИК',
          category: 'Варенье',
          harvestYear: 2025,
          locationId: harness.location!.locationId,
          availableOnly: true,
          sort: CatalogSort.leastRemaining,
        ),
      );
      expect(result.single.batch.name, 'Варенье из ёжевики');
    });

    test('metadata edit adds an immutable event', () async {
      final repository = harness.repository;
      final batchId = harness.batch!.batch.batchId;
      await repository.updateBatchMetadata(
        batchId: batchId,
        name: 'Огурцы с укропом',
        category: 'Овощи',
        jarVolumeMl: 700,
      );
      final snapshot = await repository.loadSnapshot();
      expect(snapshot.batches.single.batch.name, 'Огурцы с укропом');
      expect(
        snapshot.history.first.eventType,
        InventoryEventType.batchMetadataUpdated,
      );
    });
  });
}
