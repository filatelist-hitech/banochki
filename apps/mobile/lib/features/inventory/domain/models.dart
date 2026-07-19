import 'dart:convert';

enum InventoryEventType {
  batchCreated('BATCH_CREATED'),
  jarsTaken('JARS_TAKEN'),
  jarsReturned('JARS_RETURNED'),
  jarsSpoiled('JARS_SPOILED'),
  batchMoved('BATCH_MOVED'),
  batchMetadataUpdated('BATCH_METADATA_UPDATED'),
  inventoryReconciled('INVENTORY_RECONCILED'),
  noteAdded('NOTE_ADDED'),
  batchArchived('BATCH_ARCHIVED'),
  batchRestored('BATCH_RESTORED');

  const InventoryEventType(this.dbValue);

  final String dbValue;

  static InventoryEventType fromDb(String value) => values.firstWhere(
    (type) => type.dbValue == value,
    orElse: () => throw FormatException('Неизвестный тип события: $value'),
  );

  bool get changesQuantity => switch (this) {
    batchCreated ||
    jarsTaken ||
    jarsReturned ||
    jarsSpoiled ||
    inventoryReconciled => true,
    _ => false,
  };
}

enum BatchStatus {
  many,
  runningLow,
  lastOneOrTwo,
  finished,
  needsCheck,
  spoiled,
  needsReconciliation,
  archived;

  String get label => switch (this) {
    many => 'Запас есть',
    runningLow => 'Заканчивается',
    lastOneOrTwo => 'Последние банки',
    finished => 'Закончилось',
    needsCheck => 'Пора проверить',
    spoiled => 'Испорчено',
    needsReconciliation => 'Нужно уточнить',
    archived => 'В архиве',
  };
}

enum CatalogSort {
  recentlyAdded('Недавно добавленные'),
  name('По названию'),
  leastRemaining('Меньше всего осталось'),
  preservedAt('По дате заготовки');

  const CatalogSort(this.label);
  final String label;
}

enum AppThemeMode { system, light, dark }

final class LocalProfile {
  const LocalProfile({
    required this.profileId,
    required this.displayName,
    required this.createdAt,
  });

  final String profileId;
  final String displayName;
  final DateTime createdAt;
}

final class Family {
  const Family({
    required this.familyId,
    required this.name,
    required this.createdAt,
  });

  final String familyId;
  final String name;
  final DateTime createdAt;
}

final class FamilyMember {
  const FamilyMember({
    required this.memberId,
    required this.familyId,
    required this.profileId,
    required this.displayName,
    required this.createdAt,
  });

  final String memberId;
  final String familyId;
  final String profileId;
  final String displayName;
  final DateTime createdAt;
}

final class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    required this.createdAt,
    required this.nextSequence,
  });

  final String deviceId;
  final DateTime createdAt;
  final int nextSequence;
}

final class StorageLocation {
  const StorageLocation({
    required this.locationId,
    required this.familyId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.parentLocationId,
    this.description,
    this.archivedAt,
  });

  final String locationId;
  final String familyId;
  final String? parentLocationId;
  final String name;
  final String? description;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
}

final class Batch {
  const Batch({
    required this.batchId,
    required this.familyId,
    required this.name,
    required this.category,
    required this.initialQuantity,
    this.quantityUnit = 'шт.',
    required this.authorMemberId,
    required this.storageLocationId,
    required this.createdAt,
    required this.updatedAt,
    this.jarVolumeMl,
    this.preservedAt,
    this.harvestYear,
    this.recipeName,
    this.comment,
    this.spiciness,
    this.checkAt,
    this.archivedAt,
  });

  final String batchId;
  final String familyId;
  final String name;
  final String category;
  final int initialQuantity;
  final String quantityUnit;
  final int? jarVolumeMl;
  final DateTime? preservedAt;
  final int? harvestYear;
  final String authorMemberId;
  final String storageLocationId;
  final String? recipeName;
  final String? comment;
  final int? spiciness;
  final DateTime? checkAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
}

final class InventoryEvent {
  const InventoryEvent({
    required this.eventId,
    required this.familyId,
    required this.batchId,
    required this.actorMemberId,
    required this.eventType,
    required this.quantityDelta,
    required this.clientCreatedAt,
    required this.deviceId,
    required this.idempotencyKey,
    required this.createdAt,
    this.fromLocationId,
    this.toLocationId,
    this.comment,
    this.payload = const <String, Object?>{},
  });

  final String eventId;
  final String familyId;
  final String batchId;
  final String actorMemberId;
  final InventoryEventType eventType;
  final int quantityDelta;
  final String? fromLocationId;
  final String? toLocationId;
  final String? comment;
  final Map<String, Object?> payload;
  final DateTime clientCreatedAt;
  final String deviceId;
  final String idempotencyKey;
  final DateTime createdAt;

  String get payloadJson => jsonEncode(payload);
}

final class InventoryProjection {
  const InventoryProjection({
    required this.batchId,
    required this.computedQuantity,
    required this.currentLocationId,
    required this.needsReconciliation,
    required this.spoiledQuantity,
    required this.updatedAt,
    this.lastEventId,
    this.lastDecreaseType,
  });

  final String batchId;
  final int computedQuantity;
  final String currentLocationId;
  final bool needsReconciliation;
  final int spoiledQuantity;
  final String? lastEventId;
  final InventoryEventType? lastDecreaseType;
  final DateTime updatedAt;

  int get displayQuantity => computedQuantity < 0 ? 0 : computedQuantity;
}

final class BatchPhoto {
  const BatchPhoto({
    required this.photoId,
    required this.batchId,
    required this.localPath,
    required this.createdAt,
  });

  final String photoId;
  final String batchId;
  final String localPath;
  final DateTime createdAt;
}

final class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.largeMode = false,
    this.lowStockThreshold = 4,
    this.seedApplied = false,
  });

  final AppThemeMode themeMode;
  final bool largeMode;
  final int lowStockThreshold;
  final bool seedApplied;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? largeMode,
    int? lowStockThreshold,
    bool? seedApplied,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    largeMode: largeMode ?? this.largeMode,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    seedApplied: seedApplied ?? this.seedApplied,
  );
}

final class BatchView {
  const BatchView({
    required this.batch,
    required this.projection,
    required this.locationPath,
    required this.status,
    this.photoPath,
  });

  final Batch batch;
  final InventoryProjection projection;
  final String locationPath;
  final BatchStatus status;
  final String? photoPath;
}

final class CatalogQuery {
  const CatalogQuery({
    this.search = '',
    this.category,
    this.harvestYear,
    this.locationId,
    this.status,
    this.availableOnly = false,
    this.needsReconciliationOnly = false,
    this.sort = CatalogSort.recentlyAdded,
  });

  final String search;
  final String? category;
  final int? harvestYear;
  final String? locationId;
  final BatchStatus? status;
  final bool availableOnly;
  final bool needsReconciliationOnly;
  final CatalogSort sort;

  CatalogQuery copyWith({
    String? search,
    String? category,
    int? harvestYear,
    String? locationId,
    BatchStatus? status,
    bool clearStatus = false,
    bool? availableOnly,
    bool? needsReconciliationOnly,
    CatalogSort? sort,
  }) => CatalogQuery(
    search: search ?? this.search,
    category: category ?? this.category,
    harvestYear: harvestYear ?? this.harvestYear,
    locationId: locationId ?? this.locationId,
    status: clearStatus ? null : status ?? this.status,
    availableOnly: availableOnly ?? this.availableOnly,
    needsReconciliationOnly:
        needsReconciliationOnly ?? this.needsReconciliationOnly,
    sort: sort ?? this.sort,
  );
}

final class CreateBatchInput {
  const CreateBatchInput({
    required this.name,
    required this.initialQuantity,
    required this.storageLocationId,
    this.category = 'Другое',
    this.quantityUnit = 'шт.',
    this.jarVolumeMl,
    this.preservedAt,
    this.harvestYear,
    this.recipeName,
    this.comment,
    this.spiciness,
    this.checkAt,
    this.idempotencyKey,
  });

  final String name;
  final int initialQuantity;
  final String storageLocationId;
  final String category;
  final String quantityUnit;
  final int? jarVolumeMl;
  final DateTime? preservedAt;
  final int? harvestYear;
  final String? recipeName;
  final String? comment;
  final int? spiciness;
  final DateTime? checkAt;
  final String? idempotencyKey;
}

final class AppSnapshot {
  const AppSnapshot({
    required this.locations,
    required this.batches,
    required this.history,
    required this.settings,
    this.profile,
    this.family,
    this.member,
    this.device,
  });

  final LocalProfile? profile;
  final Family? family;
  final FamilyMember? member;
  final DeviceIdentity? device;
  final List<StorageLocation> locations;
  final List<BatchView> batches;
  final List<InventoryEvent> history;
  final AppSettings settings;

  bool get isOnboarded => family != null && member != null;
}

String normalizeSearch(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'\s+'), ' ');

BatchStatus calculateBatchStatus({
  required Batch batch,
  required InventoryProjection projection,
  required int lowStockThreshold,
  required DateTime now,
}) {
  if (batch.isArchived) return BatchStatus.archived;
  if (projection.needsReconciliation) {
    return BatchStatus.needsReconciliation;
  }
  if (projection.displayQuantity == 0) {
    return projection.lastDecreaseType == InventoryEventType.jarsSpoiled
        ? BatchStatus.spoiled
        : BatchStatus.finished;
  }
  final checkAt = batch.checkAt;
  if (checkAt != null) {
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(checkAt.year, checkAt.month, checkAt.day);
    if (!checkDate.isAfter(today)) return BatchStatus.needsCheck;
  }
  if (projection.displayQuantity <= 2) return BatchStatus.lastOneOrTwo;
  if (projection.displayQuantity <= lowStockThreshold) {
    return BatchStatus.runningLow;
  }
  return BatchStatus.many;
}
