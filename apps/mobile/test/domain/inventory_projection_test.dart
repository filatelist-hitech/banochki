import 'package:banochki/features/inventory/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final batch = Batch(
    batchId: 'batch',
    familyId: 'family',
    name: 'Огурцы',
    category: 'Овощи',
    initialQuantity: 18,
    authorMemberId: 'member',
    storageLocationId: 'location',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  InventoryProjection projection(
    int quantity, {
    bool reconciliation = false,
    InventoryEventType? lastDecrease,
  }) => InventoryProjection(
    batchId: 'batch',
    computedQuantity: quantity,
    currentLocationId: 'location',
    needsReconciliation: reconciliation,
    spoiledQuantity: 0,
    lastDecreaseType: lastDecrease,
    updatedAt: DateTime.utc(2026),
  );

  test('status rules are deterministic and prioritized', () {
    expect(
      calculateBatchStatus(
        batch: batch,
        projection: projection(18),
        lowStockThreshold: 4,
        now: DateTime.utc(2026, 7, 19),
      ),
      BatchStatus.many,
    );
    expect(
      calculateBatchStatus(
        batch: batch,
        projection: projection(4),
        lowStockThreshold: 4,
        now: DateTime.utc(2026, 7, 19),
      ),
      BatchStatus.runningLow,
    );
    expect(
      calculateBatchStatus(
        batch: batch,
        projection: projection(2),
        lowStockThreshold: 4,
        now: DateTime.utc(2026, 7, 19),
      ),
      BatchStatus.lastOneOrTwo,
    );
    expect(
      calculateBatchStatus(
        batch: batch,
        projection: projection(0),
        lowStockThreshold: 4,
        now: DateTime.utc(2026, 7, 19),
      ),
      BatchStatus.finished,
    );
    expect(
      calculateBatchStatus(
        batch: batch,
        projection: projection(0, lastDecrease: InventoryEventType.jarsSpoiled),
        lowStockThreshold: 4,
        now: DateTime.utc(2026, 7, 19),
      ),
      BatchStatus.spoiled,
    );
    expect(
      calculateBatchStatus(
        batch: batch,
        projection: projection(-3, reconciliation: true),
        lowStockThreshold: 4,
        now: DateTime.utc(2026, 7, 19),
      ),
      BatchStatus.needsReconciliation,
    );
  });

  test(
    'display quantity explains underflow without corrupting computed value',
    () {
      final value = projection(-3, reconciliation: true);
      expect(value.computedQuantity, -3);
      expect(value.displayQuantity, 0);
    },
  );

  test('search normalization handles case, whitespace, and ё', () {
    expect(normalizeSearch('  Ёжики   в БАНКЕ '), 'ежики в банке');
  });
}
