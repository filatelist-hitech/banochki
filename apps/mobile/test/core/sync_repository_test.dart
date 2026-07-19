import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:banochki/core/database/app_database.dart';
import 'package:banochki/core/ids/id_generator.dart';
import 'package:banochki/core/sync/sync_repository.dart';
import 'package:banochki/core/sync/sync_transport.dart';
import 'package:banochki/core/time/clock.dart';
import 'package:banochki/features/inventory/data/sqlite_inventory_repository.dart';
import 'package:banochki/features/inventory/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'receipt acknowledges operation; transient errors wait and permanent errors stop',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final transport = _MemoryTransport();
      final sync = SyncRepository(
        database: fixture.database,
        transport: transport,
        now: () => DateTime.utc(2026, 7, 19, 12),
        random: Random(1),
      );

      transport.failure = const SyncTransportFailure(
        SyncFailureKind.transient,
        'offline',
      );
      await sync.syncNow();
      var row = (await (await fixture.database.open()).query(
        'sync_outbox',
      )).single;
      expect(row['state'], 'retry_wait');
      expect(row['attempt_count'], 1);
      expect(row['next_retry_at'], isNotNull);

      await (await fixture.database.open()).update('sync_outbox', {
        'state': 'pending',
        'next_retry_at': null,
      });
      transport.failure = const SyncTransportFailure(
        SyncFailureKind.permanent,
        'invalid payload',
      );
      await sync.syncNow();
      row = (await (await fixture.database.open()).query('sync_outbox')).single;
      expect(row['state'], 'failed_permanently');

      await (await fixture.database.open()).update('sync_outbox', {
        'state': 'pending',
        'next_retry_at': null,
      });
      transport.failure = null;
      await sync.syncNow();
      row = (await (await fixture.database.open()).query('sync_outbox')).single;
      expect(row['state'], 'acknowledged');
    },
  );

  test(
    'two offline devices converge to 15 with three events and idempotent replay',
    () async {
      final server = _MemoryTransport();
      final a = await _Fixture.create();
      final b = await _Fixture.create(sharedIds: true);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final syncA = SyncRepository(database: a.database, transport: server);
      final syncB = SyncRepository(database: b.database, transport: server);
      await b.becomeSecondDevice();
      await a.addDevice('device-b');

      // Both devices begin with the same family/batch snapshot; their local
      // mutations happen while transport is deliberately not invoked.
      await a.repository.recordEvent(
        batchId: a.batchId,
        type: InventoryEventType.jarsTaken,
        quantity: 2,
      );
      await b.repository.recordEvent(
        batchId: b.batchId,
        type: InventoryEventType.jarsTaken,
        quantity: 1,
      );

      await syncA.syncNow();
      await syncB.syncNow();
      await syncA.syncNow();
      await syncB.syncNow();
      await syncA.syncNow(); // duplicate push/pull is a no-op.

      final aDb = await a.database.open();
      final bDb = await b.database.open();
      expect((await aDb.query('inventory_events')).length, 3);
      expect((await bDb.query('inventory_events')).length, 3);
      expect(
        (await a.repository.loadSnapshot())
            .batches
            .single
            .projection
            .computedQuantity,
        15,
      );
      expect(
        (await b.repository.loadSnapshot())
            .batches
            .single
            .projection
            .computedQuantity,
        15,
      );
      expect(server.changes, hasLength(3));
    },
  );
}

final class _Fixture {
  _Fixture._(
    this.database,
    this.repository,
    this.batchId,
    this._databasePath,
    this._ids,
  );
  final AppDatabase database;
  final SqliteInventoryRepository repository;
  final String batchId;
  final String _databasePath;
  final _StableIds _ids;

  static Future<_Fixture> create({bool sharedIds = false}) async {
    final databasePath = path.join(
      Directory.systemTemp.path,
      'banochki-sync-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}.sqlite',
    );
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final ids = _StableIds('shared');
    final repository = SqliteInventoryRepository(
      database: database,
      idGenerator: ids,
      clock: FixedClock(DateTime.utc(2026, 7, 19, 12)),
    );
    await repository.createLocalFamily(familyName: 'Семья', memberName: 'Валя');
    final location = await repository.createLocation(name: 'Погреб');
    final batch = await repository.createBatch(
      CreateBatchInput(
        name: 'Огурцы',
        initialQuantity: 18,
        storageLocationId: location.locationId,
      ),
    );
    return _Fixture._(
      database,
      repository,
      batch.batch.batchId,
      databasePath,
      ids,
    );
  }

  Future<void> becomeSecondDevice() async {
    final db = await database.open();
    final original = (await db.query('device_identities', limit: 1)).single;
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.update(
      'device_identities',
      {'device_id': 'device-b'},
      where: 'device_id = ?',
      whereArgs: [original['device_id']],
    );
    await db.insert('device_identities', {
      'device_id': original['device_id'],
      'created_at': original['created_at'],
      'next_sequence': 1,
    });
    await db.execute('PRAGMA foreign_keys = ON');
    _ids.prefix = 'device-b-event';
  }

  Future<void> addDevice(String deviceId) async {
    final db = await database.open();
    await db.insert('device_identities', {
      'device_id': deviceId,
      'created_at': DateTime.utc(2026, 7, 19).toIso8601String(),
      'next_sequence': 1,
    });
  }

  Future<void> dispose() async {
    await repository.close();
    final file = File(_databasePath);
    if (file.existsSync()) await file.delete();
  }
}

final class _StableIds implements IdGenerator {
  _StableIds(this.prefix);
  String prefix;
  var _index = 0;
  @override
  String next() => '$prefix-${++_index}';
}

final class _MemoryTransport implements SyncTransport {
  final changes = <SyncChange>[];
  Object? failure;

  @override
  Future<int> pushInventoryEvent({
    required String operationId,
    required Map<String, Object?> event,
  }) async {
    final error = failure;
    if (error != null) throw error;
    final existing = changes
        .where((change) => change.operationId == operationId)
        .firstOrNull;
    if (existing != null) return existing.serverSequence;
    final change = SyncChange(
      serverSequence: changes.length + 1,
      operationId: operationId,
      entityType: 'inventory_event',
      entityId: operationId,
      payload: Map<String, Object?>.from(jsonDecode(jsonEncode(event)) as Map),
      tombstone: false,
    );
    changes.add(change);
    return change.serverSequence;
  }

  @override
  Future<List<SyncChange>> pullChanges({
    required String familyId,
    required int after,
    int limit = 200,
  }) async => changes
      .where(
        (change) =>
            change.serverSequence > after &&
            change.payload['family_id'] == familyId,
      )
      .take(limit)
      .toList();

  @override
  Never subscribeToChanges({
    required String familyId,
    required void Function() onChange,
  }) => throw UnimplementedError(
    'Realtime is not part of deterministic transport tests.',
  );
}
