import 'models.dart';
import '../../qr/domain/qr_models.dart';

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

  Future<List<BatchPhoto>> listBatchPhotos(String batchId);
  Future<BatchPhoto> addBatchPhoto({
    required String batchId,
    required String localPath,
  });
  Future<void> deleteBatchPhoto(String photoId);

  Future<void> updateBatchMetadata({
    required String batchId,
    required String name,
    required String category,
    required String quantityUnit,
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

  Future<QrCode> generateQrForBatch(String batchId);
  Future<QrCode> generateQrForStorageLocation(String locationId);
  Future<QrCode> generateUnlinkedQr();
  Future<QrCode> linkQrToBatch({required String qrId, required String batchId});
  Future<QrCode> linkQrToStorageLocation({
    required String qrId,
    required String locationId,
  });
  Future<void> revokeQr(String qrId);
  Future<QrCode> replaceQr(String qrId);
  Future<QrResolveResult> resolveQr(String payload);
  Future<QrResolveResult> resolveShortCode(String shortCode);
  Future<QrCode?> activeQrForTarget(QrTargetType type, String targetId);

  Future<void> updateSettings(AppSettings settings);

  Future<void> seedDebugData();

  Future<void> close();
}
