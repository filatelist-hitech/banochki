import 'models.dart';

abstract interface class InventoryRepository {
  Future<AppSnapshot> loadSnapshot();

  Future<List<BatchView>> searchCatalog(CatalogQuery query);

  Future<void> createLocalFamily({
    required String familyName,
    required String memberName,
  });

  Future<StorageLocation> createLocation({
    required String name,
    String? parentLocationId,
    String? description,
    int sortOrder = 0,
  });

  Future<void> updateLocation({
    required String locationId,
    required String name,
    String? parentLocationId,
    String? description,
    int sortOrder = 0,
  });

  Future<void> archiveLocation(String locationId);

  Future<BatchView> createBatch(CreateBatchInput input);

  Future<void> updateBatchMetadata({
    required String batchId,
    required String name,
    required String category,
    int? jarVolumeMl,
    DateTime? preservedAt,
    int? harvestYear,
    String? recipeName,
    String? comment,
    int? spiciness,
    DateTime? checkAt,
  });

  Future<InventoryEvent> recordEvent({
    required String batchId,
    required InventoryEventType type,
    int quantity = 0,
    String? toLocationId,
    String? comment,
    String? idempotencyKey,
    bool confirmUnderflow = false,
  });

  Future<void> reconcile({
    required String batchId,
    required int actualQuantity,
    String? comment,
    String? idempotencyKey,
  });

  Future<void> rebuildProjections();

  Future<void> updateSettings(AppSettings settings);

  Future<void> seedDebugData();

  Future<void> close();
}
