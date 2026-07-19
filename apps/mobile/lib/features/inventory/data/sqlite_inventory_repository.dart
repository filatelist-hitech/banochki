import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' hide Batch;

import '../../../core/database/app_database.dart';
import '../../../core/errors/domain_exception.dart';
import '../../../core/ids/id_generator.dart';
import '../../../core/time/clock.dart';
import '../domain/inventory_repository.dart';
import '../domain/models.dart';
import '../../qr/domain/qr_models.dart';

final class SqliteInventoryRepository implements InventoryRepository {
  factory SqliteInventoryRepository({
    required AppDatabase database,
    IdGenerator idGenerator = const UuidGenerator(),
    AppClock clock = const SystemClock(),
    QrTokenGenerator? qrTokens,
  }) => SqliteInventoryRepository._(
    database,
    idGenerator,
    clock,
    qrTokens ?? QrTokenGenerator(),
  );

  SqliteInventoryRepository._(
    this._database,
    this._ids,
    this._clock,
    this._qrTokens,
  );

  final AppDatabase _database;
  final IdGenerator _ids;
  final AppClock _clock;
  final QrTokenGenerator _qrTokens;

  @override
  Future<AppSnapshot> loadSnapshot() async {
    final db = await _database.open();
    final profileRows = await db.query('local_profiles', limit: 1);
    final familyRows = await db.query('families', limit: 1);
    final memberRows = await db.query('family_members', limit: 1);
    final deviceRows = await db.query('device_identities', limit: 1);
    final settingsRows = await db.query(
      'app_settings',
      where: 'settings_id = 1',
      limit: 1,
    );
    final locations = (await db.query(
      'storage_locations',
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    )).map(_locationFromRow).toList(growable: false);
    final batches = (await db.query(
      'batches',
      orderBy: 'created_at DESC',
    )).map(_batchFromRow).toList(growable: false);
    var projections = (await db.query(
      'inventory_projections',
    )).map(_projectionFromRow).toList(growable: false);
    if (projections.length != batches.length) {
      await rebuildProjections();
      projections = (await db.query(
        'inventory_projections',
      )).map(_projectionFromRow).toList(growable: false);
    }
    final history = (await db.query(
      'inventory_events',
      orderBy: 'created_at DESC, event_id DESC',
    )).map(_eventFromRow).toList(growable: false);

    final settings = settingsRows.isEmpty
        ? const AppSettings()
        : _settingsFromRow(settingsRows.single);
    final locationsById = {for (final item in locations) item.locationId: item};
    final projectionsByBatch = {
      for (final item in projections) item.batchId: item,
    };
    final views = <BatchView>[];
    for (final batch in batches) {
      final projection = projectionsByBatch[batch.batchId];
      if (projection == null) continue;
      views.add(
        BatchView(
          batch: batch,
          projection: projection,
          locationPath: _locationPath(
            projection.currentLocationId,
            locationsById,
          ),
          status: calculateBatchStatus(
            batch: batch,
            projection: projection,
            lowStockThreshold: settings.lowStockThreshold,
            now: _clock.nowUtc(),
          ),
        ),
      );
    }

    return AppSnapshot(
      profile: profileRows.firstOrNull == null
          ? null
          : _profileFromRow(profileRows.first),
      family: familyRows.firstOrNull == null
          ? null
          : _familyFromRow(familyRows.first),
      member: memberRows.firstOrNull == null
          ? null
          : _memberFromRow(memberRows.first),
      device: deviceRows.firstOrNull == null
          ? null
          : _deviceFromRow(deviceRows.first),
      locations: locations,
      batches: views,
      history: history,
      settings: settings,
    );
  }

  @override
  Future<List<BatchView>> searchCatalog(CatalogQuery query) async {
    final snapshot = await loadSnapshot();
    final normalized = normalizeSearch(query.search);
    final locationIds = _locationDescendants(
      query.locationId,
      snapshot.locations,
    );
    final result = snapshot.batches.where((view) {
      if (query.status == null && view.batch.isArchived) return false;
      if (normalized.isNotEmpty &&
          !normalizeSearch(view.batch.name).contains(normalized) &&
          !normalizeSearch(view.batch.category).contains(normalized) &&
          !normalizeSearch(view.locationPath).contains(normalized)) {
        return false;
      }
      if (query.category != null && view.batch.category != query.category) {
        return false;
      }
      if (query.harvestYear != null &&
          view.batch.harvestYear != query.harvestYear) {
        return false;
      }
      if (locationIds != null &&
          !locationIds.contains(view.projection.currentLocationId)) {
        return false;
      }
      if (query.status != null && view.status != query.status) return false;
      if (query.availableOnly && view.projection.displayQuantity <= 0) {
        return false;
      }
      if (query.needsReconciliationOnly &&
          !view.projection.needsReconciliation) {
        return false;
      }
      return true;
    }).toList();

    switch (query.sort) {
      case CatalogSort.recentlyAdded:
        result.sort((a, b) => b.batch.createdAt.compareTo(a.batch.createdAt));
      case CatalogSort.name:
        result.sort(
          (a, b) => normalizeSearch(
            a.batch.name,
          ).compareTo(normalizeSearch(b.batch.name)),
        );
      case CatalogSort.leastRemaining:
        result.sort(
          (a, b) => a.projection.displayQuantity.compareTo(
            b.projection.displayQuantity,
          ),
        );
      case CatalogSort.preservedAt:
        result.sort(
          (a, b) => (b.batch.preservedAt ?? b.batch.createdAt).compareTo(
            a.batch.preservedAt ?? a.batch.createdAt,
          ),
        );
    }
    return List.unmodifiable(result);
  }

  @override
  Future<void> createLocalFamily({
    required String familyName,
    required String memberName,
  }) async {
    final familyValue = _requiredName(familyName, 'Введите название семьи.');
    final memberValue = _requiredName(memberName, 'Введите имя участника.');
    final db = await _database.open();
    await db.transaction((tx) async {
      if ((await tx.query('families', limit: 1)).isNotEmpty) {
        throw const ValidationException('Локальная семья уже создана.');
      }
      final now = _iso(_clock.nowUtc());
      final profileId = _ids.next();
      final familyId = _ids.next();
      final memberId = _ids.next();
      final deviceId = _ids.next();
      await tx.insert('local_profiles', <String, Object?>{
        'profile_id': profileId,
        'display_name': memberValue,
        'created_at': now,
      });
      await tx.insert('families', <String, Object?>{
        'family_id': familyId,
        'name': familyValue,
        'created_at': now,
      });
      await tx.insert('family_members', <String, Object?>{
        'member_id': memberId,
        'family_id': familyId,
        'profile_id': profileId,
        'display_name': memberValue,
        'created_at': now,
      });
      await tx.insert('device_identities', <String, Object?>{
        'device_id': deviceId,
        'created_at': now,
        'next_sequence': 1,
      });
    });
  }

  @override
  Future<StorageLocation> createLocation({
    required String name,
    String? parentLocationId,
    String? description,
    int sortOrder = 0,
  }) async {
    final value = _requiredName(name, 'Введите название места.');
    final db = await _database.open();
    final locationId = _ids.next();
    await db.transaction((tx) async {
      final context = await _context(tx);
      final locations = await _loadLocations(tx);
      if (parentLocationId != null) {
        final parent = locations.firstWhereOrNull(
          (item) => item.locationId == parentLocationId && !item.isArchived,
        );
        if (parent == null) {
          throw const NotFoundException('Родительское место не найдено.');
        }
        if (_depthOf(parent.locationId, locations) >= 6) {
          throw const LocationDepthException();
        }
      }
      final now = _iso(_clock.nowUtc());
      await tx.insert('storage_locations', <String, Object?>{
        'location_id': locationId,
        'family_id': context.familyId,
        'parent_location_id': parentLocationId,
        'name': value,
        'description': _nullableText(description),
        'sort_order': sortOrder,
        'created_at': now,
        'updated_at': now,
      });
    });
    return (await loadSnapshot()).locations.firstWhere(
      (item) => item.locationId == locationId,
    );
  }

  @override
  Future<void> updateLocation({
    required String locationId,
    required String name,
    String? parentLocationId,
    String? description,
    int sortOrder = 0,
  }) async {
    final value = _requiredName(name, 'Введите название места.');
    final db = await _database.open();
    await db.transaction((tx) async {
      final locations = await _loadLocations(tx);
      final current = locations.firstWhereOrNull(
        (item) => item.locationId == locationId,
      );
      if (current == null) {
        throw const NotFoundException('Место не найдено.');
      }
      if (parentLocationId == locationId) throw const LocationCycleException();
      final descendants = _locationDescendants(locationId, locations)!;
      if (parentLocationId != null && descendants.contains(parentLocationId)) {
        throw const LocationCycleException();
      }
      final parentDepth = parentLocationId == null
          ? 0
          : _depthOf(parentLocationId, locations);
      final subtreeDepth = descendants
          .map((id) => _depthBelow(id, locationId, locations))
          .fold<int>(1, (max, value) => value > max ? value : max);
      if (parentDepth + subtreeDepth > 6) {
        throw const LocationDepthException();
      }
      await tx.update(
        'storage_locations',
        <String, Object?>{
          'parent_location_id': parentLocationId,
          'name': value,
          'description': _nullableText(description),
          'sort_order': sortOrder,
          'updated_at': _iso(_clock.nowUtc()),
        },
        where: 'location_id = ?',
        whereArgs: [locationId],
      );
    });
  }

  @override
  Future<void> archiveLocation(String locationId) async {
    final db = await _database.open();
    await db.transaction((tx) async {
      final locations = await _loadLocations(tx);
      final location = locations.firstWhereOrNull(
        (item) => item.locationId == locationId && !item.isArchived,
      );
      if (location == null) {
        throw const NotFoundException('Активное место не найдено.');
      }
      final descendants = _locationDescendants(locationId, locations)!;
      final activeChildren = locations.any(
        (item) =>
            item.parentLocationId == locationId && item.archivedAt == null,
      );
      final placeholders = List.filled(descendants.length, '?').join(',');
      final activeBatchCount = Sqflite.firstIntValue(
        await tx.rawQuery('''
          SELECT COUNT(*)
          FROM inventory_projections p
          JOIN batches b ON b.batch_id = p.batch_id
          WHERE p.current_location_id IN ($placeholders)
            AND b.archived_at IS NULL
          ''', descendants.toList()),
      );
      if (activeChildren || (activeBatchCount ?? 0) > 0) {
        throw const LocationNotEmptyException();
      }
      await tx.update(
        'storage_locations',
        <String, Object?>{
          'archived_at': _iso(_clock.nowUtc()),
          'updated_at': _iso(_clock.nowUtc()),
        },
        where: 'location_id = ?',
        whereArgs: [locationId],
      );
    });
  }

  @override
  Future<BatchView> createBatch(CreateBatchInput input) async {
    final name = _requiredName(input.name, 'Введите название партии.');
    if (input.initialQuantity <= 0) {
      throw const ValidationException('Количество должно быть больше нуля.');
    }
    if (input.jarVolumeMl != null && input.jarVolumeMl! <= 0) {
      throw const ValidationException('Объём должен быть больше нуля.');
    }
    final db = await _database.open();
    late String batchId;
    await db.transaction((tx) async {
      final context = await _context(tx);
      final locationRows = await tx.query(
        'storage_locations',
        where: 'location_id = ? AND family_id = ? AND archived_at IS NULL',
        whereArgs: [input.storageLocationId, context.familyId],
        limit: 1,
      );
      if (locationRows.isEmpty) {
        throw const ValidationException('Выберите активное место хранения.');
      }
      final key = input.idempotencyKey ?? await _nextIdempotency(tx, 'create');
      final duplicate = await _eventByIdempotency(tx, context, key);
      if (duplicate != null) {
        batchId = duplicate.batchId;
        return;
      }
      batchId = _ids.next();
      final now = _clock.nowUtc();
      final eventId = _ids.next();
      await tx.insert('batches', <String, Object?>{
        'batch_id': batchId,
        'family_id': context.familyId,
        'name': name,
        'category': _requiredName(input.category, 'Выберите категорию.'),
        'initial_quantity': input.initialQuantity,
        'jar_volume_ml': input.jarVolumeMl,
        'preserved_at': _date(input.preservedAt),
        'harvest_year': input.harvestYear,
        'author_member_id': context.memberId,
        'storage_location_id': input.storageLocationId,
        'recipe_name': _nullableText(input.recipeName),
        'comment': _nullableText(input.comment),
        'spiciness': input.spiciness,
        'check_at': _date(input.checkAt),
        'created_at': _iso(now),
        'updated_at': _iso(now),
      });
      final event = InventoryEvent(
        eventId: eventId,
        familyId: context.familyId,
        batchId: batchId,
        actorMemberId: context.memberId,
        eventType: InventoryEventType.batchCreated,
        quantityDelta: input.initialQuantity,
        toLocationId: input.storageLocationId,
        payload: <String, Object?>{
          'name': name,
          'initial_quantity': input.initialQuantity,
        },
        clientCreatedAt: now,
        deviceId: context.deviceId,
        idempotencyKey: key,
        createdAt: now,
      );
      await _insertEvent(tx, event);
      await _upsertProjection(
        tx,
        InventoryProjection(
          batchId: batchId,
          computedQuantity: input.initialQuantity,
          currentLocationId: input.storageLocationId,
          needsReconciliation: false,
          spoiledQuantity: 0,
          lastEventId: eventId,
          updatedAt: now,
        ),
      );
    });
    return (await loadSnapshot()).batches.firstWhere(
      (item) => item.batch.batchId == batchId,
    );
  }

  @override
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
  }) async {
    final nameValue = _requiredName(name, 'Введите название партии.');
    final categoryValue = _requiredName(category, 'Выберите категорию.');
    if (jarVolumeMl != null && jarVolumeMl <= 0) {
      throw const ValidationException('Объём должен быть больше нуля.');
    }
    final db = await _database.open();
    await db.transaction((tx) async {
      final context = await _context(tx);
      final projectionRows = await tx.query(
        'inventory_projections',
        where: 'batch_id = ?',
        whereArgs: [batchId],
        limit: 1,
      );
      if (projectionRows.isEmpty) {
        throw const NotFoundException('Партия не найдена.');
      }
      final projection = _projectionFromRow(projectionRows.single);
      final now = _clock.nowUtc();
      final event = InventoryEvent(
        eventId: _ids.next(),
        familyId: context.familyId,
        batchId: batchId,
        actorMemberId: context.memberId,
        eventType: InventoryEventType.batchMetadataUpdated,
        quantityDelta: 0,
        payload: <String, Object?>{
          'name': nameValue,
          'category': categoryValue,
          'jar_volume_ml': jarVolumeMl,
          'harvest_year': harvestYear,
        },
        clientCreatedAt: now,
        deviceId: context.deviceId,
        idempotencyKey: await _nextIdempotency(tx, 'metadata'),
        createdAt: now,
      );
      await _insertEvent(tx, event);
      await tx.update(
        'batches',
        <String, Object?>{
          'name': nameValue,
          'category': categoryValue,
          'jar_volume_ml': jarVolumeMl,
          'preserved_at': _date(preservedAt),
          'harvest_year': harvestYear,
          'recipe_name': _nullableText(recipeName),
          'comment': _nullableText(comment),
          'spiciness': spiciness,
          'check_at': _date(checkAt),
          'updated_at': _iso(now),
        },
        where: 'batch_id = ? AND family_id = ?',
        whereArgs: [batchId, context.familyId],
      );
      await _upsertProjection(
        tx,
        InventoryProjection(
          batchId: projection.batchId,
          computedQuantity: projection.computedQuantity,
          currentLocationId: projection.currentLocationId,
          needsReconciliation: projection.needsReconciliation,
          spoiledQuantity: projection.spoiledQuantity,
          lastEventId: event.eventId,
          lastDecreaseType: projection.lastDecreaseType,
          updatedAt: now,
        ),
      );
    });
  }

  @override
  Future<InventoryEvent> recordEvent({
    required String batchId,
    required InventoryEventType type,
    int quantity = 0,
    String? toLocationId,
    String? comment,
    String? idempotencyKey,
    bool confirmUnderflow = false,
  }) async {
    if (type == InventoryEventType.batchCreated ||
        type == InventoryEventType.inventoryReconciled) {
      throw const ValidationException(
        'Используйте специальный сценарий операции.',
      );
    }
    final requiresQuantity =
        type == InventoryEventType.jarsTaken ||
        type == InventoryEventType.jarsReturned ||
        type == InventoryEventType.jarsSpoiled;
    if (requiresQuantity && quantity <= 0) {
      throw const ValidationException('Количество должно быть больше нуля.');
    }
    final delta = switch (type) {
      InventoryEventType.jarsTaken ||
      InventoryEventType.jarsSpoiled => -quantity,
      InventoryEventType.jarsReturned => quantity,
      _ => 0,
    };
    return _recordRawEvent(
      batchId: batchId,
      type: type,
      delta: delta,
      toLocationId: toLocationId,
      comment: comment,
      idempotencyKey: idempotencyKey,
      confirmUnderflow: confirmUnderflow,
    );
  }

  @override
  Future<void> reconcile({
    required String batchId,
    required int actualQuantity,
    String? comment,
    String? idempotencyKey,
  }) async {
    if (actualQuantity < 0) {
      throw const ValidationException(
        'Фактический остаток не может быть отрицательным.',
      );
    }
    final db = await _database.open();
    final rows = await db.query(
      'inventory_projections',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      limit: 1,
    );
    if (rows.isEmpty) throw const NotFoundException('Партия не найдена.');
    final current = _projectionFromRow(rows.single);
    await _recordRawEvent(
      batchId: batchId,
      type: InventoryEventType.inventoryReconciled,
      delta: actualQuantity - current.computedQuantity,
      comment: comment,
      idempotencyKey: idempotencyKey,
      confirmUnderflow: true,
      payload: <String, Object?>{'actual_quantity': actualQuantity},
    );
  }

  Future<InventoryEvent> _recordRawEvent({
    required String batchId,
    required InventoryEventType type,
    required int delta,
    String? toLocationId,
    String? comment,
    String? idempotencyKey,
    bool confirmUnderflow = false,
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    final db = await _database.open();
    late InventoryEvent result;
    await db.transaction((tx) async {
      final context = await _context(tx);
      final key =
          idempotencyKey ??
          await _nextIdempotency(tx, type.dbValue.toLowerCase());
      final duplicate = await _eventByIdempotency(tx, context, key);
      if (duplicate != null) {
        result = duplicate;
        return;
      }
      final batchRows = await tx.query(
        'batches',
        where: 'batch_id = ? AND family_id = ?',
        whereArgs: [batchId, context.familyId],
        limit: 1,
      );
      final projectionRows = await tx.query(
        'inventory_projections',
        where: 'batch_id = ?',
        whereArgs: [batchId],
        limit: 1,
      );
      if (batchRows.isEmpty || projectionRows.isEmpty) {
        throw const NotFoundException('Партия не найдена.');
      }
      final projection = _projectionFromRow(projectionRows.single);
      if (type == InventoryEventType.batchMoved) {
        if (toLocationId == null ||
            toLocationId == projection.currentLocationId) {
          throw const ValidationException('Выберите новое место.');
        }
        final target = await tx.query(
          'storage_locations',
          where: 'location_id = ? AND family_id = ? AND archived_at IS NULL',
          whereArgs: [toLocationId, context.familyId],
          limit: 1,
        );
        if (target.isEmpty) {
          throw const ValidationException('Новое место недоступно.');
        }
      }
      final computed = projection.computedQuantity + delta;
      if (computed < 0 && !confirmUnderflow) {
        throw UnderflowConfirmationRequired(computed);
      }
      final now = _clock.nowUtc();
      result = InventoryEvent(
        eventId: _ids.next(),
        familyId: context.familyId,
        batchId: batchId,
        actorMemberId: context.memberId,
        eventType: type,
        quantityDelta: delta,
        fromLocationId: type == InventoryEventType.batchMoved
            ? projection.currentLocationId
            : null,
        toLocationId: toLocationId,
        comment: _nullableText(comment),
        payload: payload,
        clientCreatedAt: now,
        deviceId: context.deviceId,
        idempotencyKey: key,
        createdAt: now,
      );
      await _insertEvent(tx, result);
      final reconciled = type == InventoryEventType.inventoryReconciled;
      final nextProjection = InventoryProjection(
        batchId: batchId,
        computedQuantity: computed,
        currentLocationId: toLocationId ?? projection.currentLocationId,
        needsReconciliation: reconciled
            ? false
            : projection.needsReconciliation || computed < 0,
        spoiledQuantity:
            projection.spoiledQuantity +
            (type == InventoryEventType.jarsSpoiled ? -delta : 0),
        lastEventId: result.eventId,
        lastDecreaseType: delta < 0 ? type : projection.lastDecreaseType,
        updatedAt: now,
      );
      await _upsertProjection(tx, nextProjection);
      final batchChanges = <String, Object?>{'updated_at': _iso(now)};
      if (type == InventoryEventType.batchMoved) {
        batchChanges['storage_location_id'] = toLocationId;
      } else if (type == InventoryEventType.batchArchived) {
        batchChanges['archived_at'] = _iso(now);
      } else if (type == InventoryEventType.batchRestored) {
        batchChanges['archived_at'] = null;
      }
      await tx.update(
        'batches',
        batchChanges,
        where: 'batch_id = ?',
        whereArgs: [batchId],
      );
    });
    return result;
  }

  @override
  Future<void> rebuildProjections() async {
    final db = await _database.open();
    await db.transaction((tx) async {
      await tx.delete('inventory_projections');
      final batches = (await tx.query('batches')).map(_batchFromRow).toList();
      for (final batch in batches) {
        final events = (await tx.query(
          'inventory_events',
          where: 'batch_id = ?',
          whereArgs: [batch.batchId],
          orderBy: 'created_at ASC, event_id ASC',
        )).map(_eventFromRow);
        var quantity = 0;
        var locationId = batch.storageLocationId;
        var needsReconciliation = false;
        var spoiledQuantity = 0;
        String? lastEventId;
        InventoryEventType? lastDecreaseType;
        var updatedAt = batch.createdAt;
        for (final event in events) {
          quantity += event.quantityDelta;
          if (event.quantityDelta < 0) lastDecreaseType = event.eventType;
          if (event.eventType == InventoryEventType.jarsSpoiled) {
            spoiledQuantity += -event.quantityDelta;
          }
          if (event.eventType == InventoryEventType.inventoryReconciled) {
            needsReconciliation = false;
          } else if (quantity < 0) {
            needsReconciliation = true;
          }
          if (event.toLocationId != null &&
              (event.eventType == InventoryEventType.batchMoved ||
                  event.eventType == InventoryEventType.batchCreated)) {
            locationId = event.toLocationId!;
          }
          lastEventId = event.eventId;
          updatedAt = event.createdAt;
        }
        await _upsertProjection(
          tx,
          InventoryProjection(
            batchId: batch.batchId,
            computedQuantity: quantity,
            currentLocationId: locationId,
            needsReconciliation: needsReconciliation,
            spoiledQuantity: spoiledQuantity,
            lastEventId: lastEventId,
            lastDecreaseType: lastDecreaseType,
            updatedAt: updatedAt,
          ),
        );
        await tx.update(
          'batches',
          <String, Object?>{'storage_location_id': locationId},
          where: 'batch_id = ?',
          whereArgs: [batch.batchId],
        );
      }
    });
  }

  @override
  Future<void> updateSettings(AppSettings settings) async {
    final db = await _database.open();
    await db.update('app_settings', <String, Object?>{
      'theme_mode': settings.themeMode.name,
      'large_mode': settings.largeMode ? 1 : 0,
      'low_stock_threshold': settings.lowStockThreshold,
      'seed_applied': settings.seedApplied ? 1 : 0,
    }, where: 'settings_id = 1');
  }

  @override
  Future<void> seedDebugData() async {
    if (!kDebugMode) return;
    var snapshot = await loadSnapshot();
    if (snapshot.settings.seedApplied) return;
    if (!snapshot.isOnboarded) {
      await createLocalFamily(
        familyName: 'Семья Филателиста',
        memberName: 'Бабушка Валя',
      );
      snapshot = await loadSnapshot();
    }
    final db = await _database.open();
    await db.transaction((tx) async {
      final family = snapshot.family!;
      final profileId = _ids.next();
      final now = _iso(_clock.nowUtc());
      await tx.insert('local_profiles', <String, Object?>{
        'profile_id': profileId,
        'display_name': 'Миша',
        'created_at': now,
      });
      await tx.insert('family_members', <String, Object?>{
        'member_id': _ids.next(),
        'family_id': family.familyId,
        'profile_id': profileId,
        'display_name': 'Миша',
        'created_at': now,
      });
    });
    final dacha = await createLocation(name: 'Дача');
    final cellar = await createLocation(
      name: 'Погреб',
      parentLocationId: dacha.locationId,
    );
    final wall = await createLocation(
      name: 'Левая стена',
      parentLocationId: cellar.locationId,
    );
    final shelf = await createLocation(
      name: 'Полка 2',
      parentLocationId: wall.locationId,
    );
    final batch = await createBatch(
      CreateBatchInput(
        name: 'Огурцы маринованные',
        initialQuantity: 18,
        storageLocationId: shelf.locationId,
        category: 'Овощи',
        jarVolumeMl: 1000,
        preservedAt: _clock.nowUtc(),
        harvestYear: _clock.nowUtc().year,
      ),
    );
    await recordEvent(
      batchId: batch.batch.batchId,
      type: InventoryEventType.jarsTaken,
      quantity: 2,
      comment: 'Взяли к ужину',
    );
    await recordEvent(
      batchId: batch.batch.batchId,
      type: InventoryEventType.jarsReturned,
      quantity: 1,
    );
    await recordEvent(
      batchId: batch.batch.batchId,
      type: InventoryEventType.jarsSpoiled,
      quantity: 1,
    );
    await updateSettings(
      (await loadSnapshot()).settings.copyWith(seedApplied: true),
    );
  }

  @override
  Future<void> close() => _database.close();

  @override
  Future<QrCode> generateQrForBatch(String batchId) =>
      _generateForTarget(QrTargetType.batch, batchId);

  @override
  Future<QrCode> generateQrForStorageLocation(String locationId) =>
      _generateForTarget(QrTargetType.storageLocation, locationId);

  @override
  Future<QrCode> generateUnlinkedQr() async {
    final db = await _database.open();
    late QrCode result;
    await db.transaction((tx) async {
      final context = await _context(tx);
      result = await _insertNewQr(
        tx,
        context,
        targetType: QrTargetType.unlinked,
        targetId: null,
      );
    });
    return result;
  }

  Future<QrCode> _generateForTarget(QrTargetType type, String targetId) async {
    final db = await _database.open();
    late QrCode result;
    await db.transaction((tx) async {
      final context = await _context(tx);
      await _validateQrTarget(tx, context, type, targetId);
      final existing = await _activeQrForTarget(tx, context, type, targetId);
      result =
          existing ??
          await _insertNewQr(tx, context, targetType: type, targetId: targetId);
    });
    return result;
  }

  @override
  Future<QrCode> linkQrToBatch({
    required String qrId,
    required String batchId,
  }) => _linkQr(qrId: qrId, type: QrTargetType.batch, targetId: batchId);

  @override
  Future<QrCode> linkQrToStorageLocation({
    required String qrId,
    required String locationId,
  }) => _linkQr(
    qrId: qrId,
    type: QrTargetType.storageLocation,
    targetId: locationId,
  );

  Future<QrCode> _linkQr({
    required String qrId,
    required QrTargetType type,
    required String targetId,
  }) async {
    final db = await _database.open();
    late QrCode result;
    await db.transaction((tx) async {
      final context = await _context(tx);
      final qr = await _qrById(tx, context, qrId);
      if (qr == null || qr.state != QrCodeState.unlinked) {
        throw const ValidationException(
          'Можно привязать только свободную этикетку.',
        );
      }
      await _validateQrTarget(tx, context, type, targetId);
      final now = _clock.nowUtc();
      await tx.update(
        'qr_codes',
        <String, Object?>{
          'target_type': _targetTypeValue(type),
          'target_id': targetId,
          'state': 'active',
          'linked_at': _iso(now),
        },
        where: 'id = ?',
        whereArgs: [qrId],
      );
      await _insertQrEvent(tx, context, qrId, 'QR_LINKED', type, targetId, now);
      result = QrCode(
        id: qr.id,
        familyId: qr.familyId,
        publicToken: qr.publicToken,
        shortCode: qr.shortCode,
        checksum: qr.checksum,
        protocolVersion: qr.protocolVersion,
        targetType: type,
        targetId: targetId,
        state: QrCodeState.active,
        createdAt: qr.createdAt,
        linkedAt: now,
        createdByMemberId: qr.createdByMemberId,
        deviceId: qr.deviceId,
      );
    });
    return result;
  }

  @override
  Future<void> revokeQr(String qrId) async {
    final db = await _database.open();
    await db.transaction((tx) async {
      final context = await _context(tx);
      final qr = await _qrById(tx, context, qrId);
      if (qr == null) throw const NotFoundException('QR-код не найден.');
      if (qr.state == QrCodeState.revoked || qr.state == QrCodeState.replaced) {
        return;
      }
      final now = _clock.nowUtc();
      await tx.update(
        'qr_codes',
        <String, Object?>{'state': 'revoked', 'revoked_at': _iso(now)},
        where: 'id = ?',
        whereArgs: [qrId],
      );
      await _insertQrEvent(
        tx,
        context,
        qrId,
        'QR_REVOKED',
        qr.targetType,
        qr.targetId,
        now,
      );
    });
  }

  @override
  Future<QrCode> replaceQr(String qrId) async {
    final db = await _database.open();
    late QrCode replacement;
    await db.transaction((tx) async {
      final context = await _context(tx);
      final previous = await _qrById(tx, context, qrId);
      if (previous == null ||
          previous.targetId == null ||
          previous.state != QrCodeState.active) {
        throw const ValidationException(
          'Перевыпустить можно только активный QR-код.',
        );
      }
      replacement = await _insertNewQr(
        tx,
        context,
        targetType: previous.targetType,
        targetId: previous.targetId,
      );
      final now = _clock.nowUtc();
      await tx.update(
        'qr_codes',
        <String, Object?>{
          'state': 'replaced',
          'revoked_at': _iso(now),
          'replaced_by_qr_id': replacement.id,
        },
        where: 'id = ?',
        whereArgs: [qrId],
      );
      await _insertQrEvent(
        tx,
        context,
        qrId,
        'QR_REPLACED',
        previous.targetType,
        previous.targetId,
        now,
      );
    });
    return replacement;
  }

  @override
  Future<QrResolveResult> resolveQr(String payload) async {
    final parsed = QrProtocol.parse(payload);
    if (parsed == null) {
      return const QrResolveResult(kind: QrResolutionKind.invalid);
    }
    if (parsed.version != QrProtocol.currentVersion) {
      return const QrResolveResult(kind: QrResolutionKind.unsupported);
    }
    final db = await _database.open();
    final context = await _context(db);
    final rows = await db.query(
      'qr_codes',
      where: 'family_id = ? AND public_token = ?',
      whereArgs: [context.familyId, parsed.token],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const QrResolveResult(kind: QrResolutionKind.unknown);
    }
    final qr = _qrFromRow(rows.single);
    return QrResolveResult(kind: _resolutionKind(qr), qrCode: qr);
  }

  @override
  Future<QrResolveResult> resolveShortCode(String shortCode) async {
    if (!ShortCode.isValid(shortCode)) {
      return const QrResolveResult(kind: QrResolutionKind.invalid);
    }
    final db = await _database.open();
    final context = await _context(db);
    final normalized = ShortCode.format(shortCode);
    final rows = await db.query(
      'qr_codes',
      where: 'family_id = ? AND short_code = ?',
      whereArgs: [context.familyId, normalized],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const QrResolveResult(kind: QrResolutionKind.unknown);
    }
    final qr = _qrFromRow(rows.single);
    return QrResolveResult(kind: _resolutionKind(qr), qrCode: qr);
  }

  @override
  Future<QrCode?> activeQrForTarget(QrTargetType type, String targetId) async {
    final db = await _database.open();
    return _activeQrForTarget(db, await _context(db), type, targetId);
  }

  Future<QrCode?> _activeQrForTarget(
    DatabaseExecutor db,
    _LocalContext context,
    QrTargetType type,
    String targetId,
  ) async {
    final rows = await db.query(
      'qr_codes',
      where:
          'family_id = ? AND target_type = ? AND target_id = ? AND state = ?',
      whereArgs: [context.familyId, _targetTypeValue(type), targetId, 'active'],
      limit: 1,
    );
    return rows.firstOrNull == null ? null : _qrFromRow(rows.first);
  }

  Future<QrCode> _insertNewQr(
    DatabaseExecutor tx,
    _LocalContext context, {
    required QrTargetType targetType,
    required String? targetId,
  }) async {
    final now = _clock.nowUtc();
    for (var attempt = 0; attempt < 20; attempt++) {
      final base = List.generate(
        6,
        (_) => _qrTokens.nextToken().codeUnitAt(0) % 10,
      ).join();
      final shortCode = ShortCode.create(base);
      final existing = await tx.query(
        'qr_codes',
        where: 'family_id = ? AND short_code = ?',
        whereArgs: [context.familyId, shortCode],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      final token = _qrTokens.nextToken();
      final duplicateToken = await tx.query(
        'qr_codes',
        where: 'public_token = ?',
        whereArgs: [token],
        limit: 1,
      );
      if (duplicateToken.isNotEmpty) continue;
      final id = _ids.next();
      final state = targetType == QrTargetType.unlinked
          ? QrCodeState.unlinked
          : QrCodeState.active;
      await tx.insert('qr_codes', <String, Object?>{
        'id': id,
        'family_id': context.familyId,
        'public_token': token,
        'short_code': shortCode,
        'checksum': shortCode.substring(7),
        'protocol_version': QrProtocol.currentVersion,
        'target_type': _targetTypeValue(targetType),
        'target_id': targetId,
        'state': state.name,
        'created_at': _iso(now),
        'linked_at': targetType == QrTargetType.unlinked ? null : _iso(now),
        'created_by_member_id': context.memberId,
        'device_id': context.deviceId,
      });
      await _insertQrEvent(
        tx,
        context,
        id,
        'QR_CREATED',
        targetType,
        targetId,
        now,
      );
      return QrCode(
        id: id,
        familyId: context.familyId,
        publicToken: token,
        shortCode: shortCode,
        checksum: shortCode.substring(7),
        protocolVersion: 1,
        targetType: targetType,
        targetId: targetId,
        state: state,
        createdAt: now,
        linkedAt: targetType == QrTargetType.unlinked ? null : now,
        createdByMemberId: context.memberId,
        deviceId: context.deviceId,
      );
    }
    throw const ValidationException(
      'Не удалось подобрать уникальный короткий номер.',
    );
  }

  Future<void> _validateQrTarget(
    DatabaseExecutor tx,
    _LocalContext context,
    QrTargetType type,
    String targetId,
  ) async {
    final table = type == QrTargetType.batch ? 'batches' : 'storage_locations';
    final idColumn = type == QrTargetType.batch ? 'batch_id' : 'location_id';
    final rows = await tx.query(
      table,
      where: '$idColumn = ? AND family_id = ? AND archived_at IS NULL',
      whereArgs: [targetId, context.familyId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const NotFoundException('Активная QR-цель не найдена.');
    }
  }

  Future<QrCode?> _qrById(
    DatabaseExecutor db,
    _LocalContext context,
    String id,
  ) async {
    final rows = await db.query(
      'qr_codes',
      where: 'id = ? AND family_id = ?',
      whereArgs: [id, context.familyId],
      limit: 1,
    );
    return rows.firstOrNull == null ? null : _qrFromRow(rows.first);
  }

  Future<void> _insertQrEvent(
    DatabaseExecutor db,
    _LocalContext context,
    String qrId,
    String type,
    QrTargetType targetType,
    String? targetId,
    DateTime now,
  ) => db.insert('qr_events', <String, Object?>{
    'event_id': _ids.next(),
    'family_id': context.familyId,
    'qr_id': qrId,
    'event_type': type,
    'target_type': _targetTypeValue(targetType),
    'target_id': targetId,
    'created_by_member_id': context.memberId,
    'device_id': context.deviceId,
    'created_at': _iso(now),
  });

  Future<_LocalContext> _context(DatabaseExecutor db) async {
    final family = (await db.query('families', limit: 1)).firstOrNull;
    final member = (await db.query('family_members', limit: 1)).firstOrNull;
    final device = (await db.query('device_identities', limit: 1)).firstOrNull;
    if (family == null || member == null || device == null) {
      throw const ValidationException('Сначала создайте локальную семью.');
    }
    return _LocalContext(
      familyId: family['family_id']! as String,
      memberId: member['member_id']! as String,
      deviceId: device['device_id']! as String,
    );
  }

  Future<String> _nextIdempotency(DatabaseExecutor db, String prefix) async {
    final device = (await db.query('device_identities', limit: 1)).single;
    final sequence = device['next_sequence']! as int;
    final deviceId = device['device_id']! as String;
    await db.update(
      'device_identities',
      <String, Object?>{'next_sequence': sequence + 1},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    return '$prefix-$deviceId-${sequence.toString().padLeft(10, '0')}';
  }

  Future<InventoryEvent?> _eventByIdempotency(
    DatabaseExecutor db,
    _LocalContext context,
    String key,
  ) async {
    final rows = await db.query(
      'inventory_events',
      where: 'family_id = ? AND device_id = ? AND idempotency_key = ?',
      whereArgs: [context.familyId, context.deviceId, key],
      limit: 1,
    );
    return rows.firstOrNull == null ? null : _eventFromRow(rows.first);
  }

  Future<void> _insertEvent(DatabaseExecutor db, InventoryEvent event) =>
      db.insert('inventory_events', <String, Object?>{
        'event_id': event.eventId,
        'family_id': event.familyId,
        'batch_id': event.batchId,
        'actor_member_id': event.actorMemberId,
        'event_type': event.eventType.dbValue,
        'quantity_delta': event.quantityDelta,
        'from_location_id': event.fromLocationId,
        'to_location_id': event.toLocationId,
        'comment': event.comment,
        'payload_json': event.payloadJson,
        'client_created_at': _iso(event.clientCreatedAt),
        'device_id': event.deviceId,
        'idempotency_key': event.idempotencyKey,
        'created_at': _iso(event.createdAt),
      });

  Future<void> _upsertProjection(
    DatabaseExecutor db,
    InventoryProjection projection,
  ) => db.insert('inventory_projections', <String, Object?>{
    'batch_id': projection.batchId,
    'computed_quantity': projection.computedQuantity,
    'current_location_id': projection.currentLocationId,
    'needs_reconciliation': projection.needsReconciliation ? 1 : 0,
    'spoiled_quantity': projection.spoiledQuantity,
    'last_event_id': projection.lastEventId,
    'last_decrease_type': projection.lastDecreaseType?.dbValue,
    'updated_at': _iso(projection.updatedAt),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

final class _LocalContext {
  const _LocalContext({
    required this.familyId,
    required this.memberId,
    required this.deviceId,
  });

  final String familyId;
  final String memberId;
  final String deviceId;
}

String _requiredName(String value, String message) {
  final trimmed = value.trim().replaceAll(RegExp(r'[\u0000-\u001F]'), '');
  if (trimmed.isEmpty) throw ValidationException(message);
  return trimmed;
}

String? _nullableText(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _iso(DateTime value) => value.toUtc().toIso8601String();

String? _date(DateTime? value) => value == null
    ? null
    : DateTime(value.year, value.month, value.day).toIso8601String();

DateTime _time(Object? value) => DateTime.parse(value! as String).toUtc();

DateTime? _optionalTime(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

LocalProfile _profileFromRow(Map<String, Object?> row) => LocalProfile(
  profileId: row['profile_id']! as String,
  displayName: row['display_name']! as String,
  createdAt: _time(row['created_at']),
);

Family _familyFromRow(Map<String, Object?> row) => Family(
  familyId: row['family_id']! as String,
  name: row['name']! as String,
  createdAt: _time(row['created_at']),
);

FamilyMember _memberFromRow(Map<String, Object?> row) => FamilyMember(
  memberId: row['member_id']! as String,
  familyId: row['family_id']! as String,
  profileId: row['profile_id']! as String,
  displayName: row['display_name']! as String,
  createdAt: _time(row['created_at']),
);

DeviceIdentity _deviceFromRow(Map<String, Object?> row) => DeviceIdentity(
  deviceId: row['device_id']! as String,
  createdAt: _time(row['created_at']),
  nextSequence: row['next_sequence']! as int,
);

StorageLocation _locationFromRow(Map<String, Object?> row) => StorageLocation(
  locationId: row['location_id']! as String,
  familyId: row['family_id']! as String,
  parentLocationId: row['parent_location_id'] as String?,
  name: row['name']! as String,
  description: row['description'] as String?,
  sortOrder: row['sort_order']! as int,
  createdAt: _time(row['created_at']),
  updatedAt: _time(row['updated_at']),
  archivedAt: _optionalTime(row['archived_at']),
);

Batch _batchFromRow(Map<String, Object?> row) => Batch(
  batchId: row['batch_id']! as String,
  familyId: row['family_id']! as String,
  name: row['name']! as String,
  category: row['category']! as String,
  initialQuantity: row['initial_quantity']! as int,
  jarVolumeMl: row['jar_volume_ml'] as int?,
  preservedAt: _optionalTime(row['preserved_at']),
  harvestYear: row['harvest_year'] as int?,
  authorMemberId: row['author_member_id']! as String,
  storageLocationId: row['storage_location_id']! as String,
  recipeName: row['recipe_name'] as String?,
  comment: row['comment'] as String?,
  spiciness: row['spiciness'] as int?,
  checkAt: _optionalTime(row['check_at']),
  createdAt: _time(row['created_at']),
  updatedAt: _time(row['updated_at']),
  archivedAt: _optionalTime(row['archived_at']),
);

InventoryEvent _eventFromRow(Map<String, Object?> row) => InventoryEvent(
  eventId: row['event_id']! as String,
  familyId: row['family_id']! as String,
  batchId: row['batch_id']! as String,
  actorMemberId: row['actor_member_id']! as String,
  eventType: InventoryEventType.fromDb(row['event_type']! as String),
  quantityDelta: row['quantity_delta']! as int,
  fromLocationId: row['from_location_id'] as String?,
  toLocationId: row['to_location_id'] as String?,
  comment: row['comment'] as String?,
  payload: (jsonDecode(row['payload_json']! as String) as Map).cast(),
  clientCreatedAt: _time(row['client_created_at']),
  deviceId: row['device_id']! as String,
  idempotencyKey: row['idempotency_key']! as String,
  createdAt: _time(row['created_at']),
);

InventoryProjection _projectionFromRow(Map<String, Object?> row) =>
    InventoryProjection(
      batchId: row['batch_id']! as String,
      computedQuantity: row['computed_quantity']! as int,
      currentLocationId: row['current_location_id']! as String,
      needsReconciliation: row['needs_reconciliation'] == 1,
      spoiledQuantity: row['spoiled_quantity']! as int,
      lastEventId: row['last_event_id'] as String?,
      lastDecreaseType: row['last_decrease_type'] == null
          ? null
          : InventoryEventType.fromDb(row['last_decrease_type']! as String),
      updatedAt: _time(row['updated_at']),
    );

AppSettings _settingsFromRow(Map<String, Object?> row) => AppSettings(
  themeMode: AppThemeMode.values.firstWhere(
    (value) => value.name == row['theme_mode'],
    orElse: () => AppThemeMode.system,
  ),
  largeMode: row['large_mode'] == 1,
  lowStockThreshold: row['low_stock_threshold']! as int,
  seedApplied: row['seed_applied'] == 1,
);

QrCode _qrFromRow(Map<String, Object?> row) => QrCode(
  id: row['id']! as String,
  familyId: row['family_id']! as String,
  publicToken: row['public_token']! as String,
  shortCode: row['short_code']! as String,
  checksum: row['checksum']! as String,
  protocolVersion: row['protocol_version']! as int,
  targetType: _targetTypeFromValue(row['target_type']! as String),
  targetId: row['target_id'] as String?,
  state: QrCodeState.values.firstWhere((value) => value.name == row['state']),
  createdAt: _time(row['created_at']),
  linkedAt: _optionalTime(row['linked_at']),
  revokedAt: _optionalTime(row['revoked_at']),
  replacedByQrId: row['replaced_by_qr_id'] as String?,
  createdByMemberId: row['created_by_member_id']! as String,
  deviceId: row['device_id']! as String,
);

String _targetTypeValue(QrTargetType type) => switch (type) {
  QrTargetType.batch => 'batch',
  QrTargetType.storageLocation => 'storage_location',
  QrTargetType.unlinked => 'unlinked',
};

QrTargetType _targetTypeFromValue(String value) => switch (value) {
  'batch' => QrTargetType.batch,
  'storage_location' => QrTargetType.storageLocation,
  'unlinked' => QrTargetType.unlinked,
  _ => throw FormatException('Неизвестная QR-цель: $value'),
};

QrResolutionKind _resolutionKind(QrCode qr) => switch (qr.state) {
  QrCodeState.active => QrResolutionKind.resolved,
  QrCodeState.unlinked => QrResolutionKind.unlinked,
  QrCodeState.revoked => QrResolutionKind.revoked,
  QrCodeState.replaced => QrResolutionKind.replaced,
};

Future<List<StorageLocation>> _loadLocations(DatabaseExecutor db) async =>
    (await db.query(
      'storage_locations',
    )).map(_locationFromRow).toList(growable: false);

int _depthOf(String locationId, List<StorageLocation> locations) {
  final byId = {for (final item in locations) item.locationId: item};
  var depth = 0;
  String? current = locationId;
  final visited = <String>{};
  while (current != null) {
    if (!visited.add(current)) throw const LocationCycleException();
    depth++;
    current = byId[current]?.parentLocationId;
  }
  return depth;
}

int _depthBelow(
  String locationId,
  String rootId,
  List<StorageLocation> locations,
) {
  final byId = {for (final item in locations) item.locationId: item};
  var depth = 1;
  var current = byId[locationId]?.parentLocationId;
  while (current != null && current != rootId) {
    depth++;
    current = byId[current]?.parentLocationId;
  }
  return depth;
}

Set<String>? _locationDescendants(
  String? locationId,
  List<StorageLocation> locations,
) {
  if (locationId == null) return null;
  final result = <String>{locationId};
  var changed = true;
  while (changed) {
    changed = false;
    for (final location in locations) {
      if (location.parentLocationId != null &&
          result.contains(location.parentLocationId) &&
          result.add(location.locationId)) {
        changed = true;
      }
    }
  }
  return result;
}

String _locationPath(
  String locationId,
  Map<String, StorageLocation> locations,
) {
  final names = <String>[];
  String? current = locationId;
  final visited = <String>{};
  while (current != null) {
    if (!visited.add(current)) return 'Некорректный путь';
    final location = locations[current];
    if (location == null) break;
    names.add(location.name);
    current = location.parentLocationId;
  }
  return names.reversed.join(' · ');
}
