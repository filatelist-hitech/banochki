import 'package:banochki/features/inventory/domain/inventory_repository.dart';
import 'package:banochki/features/inventory/domain/models.dart';
import 'package:banochki/features/qr/domain/qr_models.dart';

final class FakeInventoryRepository implements InventoryRepository {
  FakeInventoryRepository(this.snapshot);

  AppSnapshot snapshot;
  var _nextId = 0;

  String get _id => 'fake-${++_nextId}';

  @override
  Future<AppSnapshot> loadSnapshot() async => snapshot;

  @override
  Future<List<BatchView>> searchCatalog(CatalogQuery query) async =>
      snapshot.batches;

  @override
  Future<BatchView> createBatch(CreateBatchInput input) async {
    if (input.name.trim().isEmpty || input.initialQuantity <= 0) {
      throw ArgumentError('Некорректная партия');
    }
    final now = DateTime.utc(2026, 7, 19);
    final batch = Batch(
      batchId: _id,
      familyId: snapshot.family!.familyId,
      name: input.name.trim(),
      category: input.category,
      initialQuantity: input.initialQuantity,
      quantityUnit: input.quantityUnit,
      jarVolumeMl: input.jarVolumeMl,
      preservedAt: input.preservedAt,
      harvestYear: input.harvestYear,
      authorMemberId: snapshot.member!.memberId,
      storageLocationId: input.storageLocationId,
      recipeName: input.recipeName,
      comment: input.comment,
      spiciness: input.spiciness,
      checkAt: input.checkAt,
      createdAt: now,
      updatedAt: now,
    );
    final location = snapshot.locations.firstWhere(
      (item) => item.locationId == input.storageLocationId,
    );
    final projection = InventoryProjection(
      batchId: batch.batchId,
      computedQuantity: input.initialQuantity,
      currentLocationId: location.locationId,
      needsReconciliation: false,
      spoiledQuantity: 0,
      updatedAt: now,
    );
    final view = BatchView(
      batch: batch,
      projection: projection,
      locationPath: location.name,
      status: BatchStatus.many,
    );
    final event = InventoryEvent(
      eventId: _id,
      familyId: batch.familyId,
      batchId: batch.batchId,
      actorMemberId: batch.authorMemberId,
      eventType: InventoryEventType.batchCreated,
      quantityDelta: input.initialQuantity,
      toLocationId: location.locationId,
      clientCreatedAt: now,
      deviceId: snapshot.device!.deviceId,
      idempotencyKey: _id,
      createdAt: now,
    );
    snapshot = AppSnapshot(
      profile: snapshot.profile,
      family: snapshot.family,
      member: snapshot.member,
      device: snapshot.device,
      locations: snapshot.locations,
      batches: [view, ...snapshot.batches],
      history: [event, ...snapshot.history],
      settings: snapshot.settings,
    );
    return view;
  }

  @override
  Future<List<BatchPhoto>> listBatchPhotos(String batchId) async => const [];

  @override
  Future<BatchPhoto> addBatchPhoto({
    required String batchId,
    required String localPath,
  }) async => BatchPhoto(
    photoId: _id,
    batchId: batchId,
    localPath: localPath,
    createdAt: DateTime.now().toUtc(),
  );

  @override
  Future<void> deleteBatchPhoto(String photoId) async {}

  @override
  Future<void> updateSettings(AppSettings settings) async {
    snapshot = AppSnapshot(
      profile: snapshot.profile,
      family: snapshot.family,
      member: snapshot.member,
      device: snapshot.device,
      locations: snapshot.locations,
      batches: snapshot.batches,
      history: snapshot.history,
      settings: settings,
    );
  }

  @override
  Future<void> archiveLocation(String locationId) async {}

  @override
  Future<void> close() async {}

  @override
  Future<QrCode?> activeQrForTarget(QrTargetType type, String targetId) async =>
      null;

  @override
  Future<QrCode> generateQrForBatch(String batchId) async =>
      _fakeQr(QrTargetType.batch, batchId);

  @override
  Future<QrCode> generateQrForStorageLocation(String locationId) async =>
      _fakeQr(QrTargetType.storageLocation, locationId);

  @override
  Future<QrCode> generateUnlinkedQr() async =>
      _fakeQr(QrTargetType.unlinked, null);

  QrCode _fakeQr(QrTargetType type, String? targetId) => QrCode(
    id: _id,
    familyId: 'family',
    publicToken: 'a' * 43,
    shortCode: '123456-6',
    checksum: '6',
    protocolVersion: 1,
    targetType: type,
    targetId: targetId,
    state: type == QrTargetType.unlinked
        ? QrCodeState.unlinked
        : QrCodeState.active,
    createdAt: DateTime.utc(2026, 7, 19),
    createdByMemberId: 'member',
    deviceId: 'device',
  );

  @override
  Future<QrCode> linkQrToBatch({
    required String qrId,
    required String batchId,
  }) async => _fakeQr(QrTargetType.batch, batchId);

  @override
  Future<QrCode> linkQrToStorageLocation({
    required String qrId,
    required String locationId,
  }) async => _fakeQr(QrTargetType.storageLocation, locationId);

  @override
  Future<QrCode> replaceQr(String qrId) async =>
      _fakeQr(QrTargetType.batch, 'batch');

  @override
  Future<void> revokeQr(String qrId) async {}

  @override
  Future<QrResolveResult> resolveQr(String payload) async =>
      const QrResolveResult(kind: QrResolutionKind.unknown);

  @override
  Future<QrResolveResult> resolveShortCode(String shortCode) async =>
      const QrResolveResult(kind: QrResolutionKind.unknown);

  @override
  Future<StorageLocation> createLocation({
    required String name,
    String? parentLocationId,
    String? description,
    int sortOrder = 0,
  }) async => throw UnimplementedError();

  @override
  Future<void> createLocalFamily({
    required String familyName,
    required String memberName,
  }) async => throw UnimplementedError();

  @override
  Future<void> rebuildProjections() async {}

  @override
  Future<void> reconcile({
    required String batchId,
    required int actualQuantity,
    String? comment,
    String? idempotencyKey,
  }) async => throw UnimplementedError();

  @override
  Future<InventoryEvent> recordEvent({
    required String batchId,
    required InventoryEventType type,
    int quantity = 0,
    String? toLocationId,
    String? comment,
    String? idempotencyKey,
    bool confirmUnderflow = false,
  }) async => throw UnimplementedError();

  @override
  Future<void> seedDebugData() async {}

  @override
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
  }) async => throw UnimplementedError();

  @override
  Future<void> updateLocation({
    required String locationId,
    required String name,
    String? parentLocationId,
    String? description,
    int sortOrder = 0,
  }) async => throw UnimplementedError();
}

AppSnapshot fakeOnboardedSnapshot({
  AppSettings settings = const AppSettings(),
  List<BatchView> batches = const [],
  List<InventoryEvent> history = const [],
}) {
  final now = DateTime.utc(2026, 7, 19);
  return AppSnapshot(
    profile: LocalProfile(
      profileId: 'profile',
      displayName: 'Валя',
      createdAt: now,
    ),
    family: Family(familyId: 'family', name: 'Семья', createdAt: now),
    member: FamilyMember(
      memberId: 'member',
      familyId: 'family',
      profileId: 'profile',
      displayName: 'Валя',
      createdAt: now,
    ),
    device: DeviceIdentity(deviceId: 'device', createdAt: now, nextSequence: 1),
    locations: [
      StorageLocation(
        locationId: 'location',
        familyId: 'family',
        name: 'Погреб',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    batches: batches,
    history: history,
    settings: settings,
  );
}
