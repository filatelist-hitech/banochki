import 'dart:io';

import 'package:banochki/core/database/app_database.dart';
import 'package:banochki/core/database/migrations.dart';
import 'package:banochki/core/ids/id_generator.dart';
import 'package:banochki/core/time/clock.dart';
import 'package:banochki/features/inventory/data/sqlite_inventory_repository.dart';
import 'package:banochki/features/inventory/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' show DatabaseException, Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('database schema', () {
    late Directory tempDirectory;
    late String databasePath;
    late AppDatabase database;
    late SqliteInventoryRepository repository;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'banochki-db-test-',
      );
      databasePath = path.join(tempDirectory.path, 'test.sqlite');
      database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      repository = SqliteInventoryRepository(
        database: database,
        idGenerator: SequenceIdGenerator(),
        clock: FixedClock(DateTime.utc(2026, 7, 19, 12)),
      );
    });

    tearDown(() async {
      await repository.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
      'creates a fresh versioned database with foreign keys and indexes',
      () async {
        final db = await database.open();
        expect(
          Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')),
          4,
        );
        expect(
          Sqflite.firstIntValue(await db.rawQuery('PRAGMA foreign_keys')),
          1,
        );
        final metadata = await db.query(
          'schema_metadata',
          where: 'key = ?',
          whereArgs: ['schema_version'],
        );
        expect(metadata.single['value'], '4');
        final indexes = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index'",
        )).map((row) => row['name']).toSet();
        expect(indexes, contains('inventory_events_idempotency_uq'));
        expect(indexes, contains('inventory_events_batch_order_idx'));
        expect(indexes, contains('batches_catalog_idx'));
        expect(indexes, contains('storage_locations_tree_idx'));
      },
    );

    test('upgrades a v1 fixture to v4', () async {
      final v1 = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) => applyMigration(db, 1),
        ),
      );
      await v1.close();

      final upgraded = await database.open();
      expect(
        Sqflite.firstIntValue(await upgraded.rawQuery('PRAGMA user_version')),
        4,
      );
      expect(await upgraded.query('schema_metadata'), isNotEmpty);
    });

    test(
      'family, batch, first event, and projection are committed atomically',
      () async {
        await repository.createLocalFamily(
          familyName: 'Семья',
          memberName: 'Миша',
        );
        final location = await repository.createLocation(name: 'Погреб');
        await repository.createBatch(
          CreateBatchInput(
            name: 'Лечо',
            initialQuantity: 12,
            storageLocationId: location.locationId,
          ),
        );
        final db = await database.open();
        expect(
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM batches'),
          ),
          1,
        );
        expect(
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM inventory_events'),
          ),
          1,
        );
        expect(
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM inventory_projections'),
          ),
          1,
        );

        await expectLater(
          repository.createBatch(
            CreateBatchInput(
              name: 'Сломанная партия',
              initialQuantity: 2,
              storageLocationId: 'missing-location',
            ),
          ),
          throwsException,
        );
        expect(
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM batches'),
          ),
          1,
        );
        expect(
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM inventory_events'),
          ),
          1,
        );
      },
    );

    test('data survives closing and reopening the database', () async {
      await repository.createLocalFamily(
        familyName: 'Семья',
        memberName: 'Валя',
      );
      final location = await repository.createLocation(name: 'Погреб');
      final batch = await repository.createBatch(
        CreateBatchInput(
          name: 'Томаты',
          initialQuantity: 8,
          storageLocationId: location.locationId,
        ),
      );
      await repository.recordEvent(
        batchId: batch.batch.batchId,
        type: InventoryEventType.jarsTaken,
        quantity: 3,
      );
      await repository.close();

      final reopenedDatabase = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final reopened = SqliteInventoryRepository(database: reopenedDatabase);
      final snapshot = await reopened.loadSnapshot();
      expect(snapshot.family?.name, 'Семья');
      expect(snapshot.batches.single.batch.name, 'Томаты');
      expect(snapshot.batches.single.projection.computedQuantity, 5);
      expect(snapshot.history, hasLength(2));
      await reopened.close();
    });

    test('foreign keys reject orphan rows', () async {
      final db = await database.open();
      await expectLater(
        db.insert('storage_locations', <String, Object?>{
          'location_id': 'location',
          'family_id': 'missing-family',
          'name': 'Погреб',
          'sort_order': 0,
          'created_at': DateTime.utc(2026).toIso8601String(),
          'updated_at': DateTime.utc(2026).toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('event id and scoped idempotency key are unique', () async {
      await repository.createLocalFamily(
        familyName: 'Семья',
        memberName: 'Валя',
      );
      final location = await repository.createLocation(name: 'Погреб');
      await repository.createBatch(
        CreateBatchInput(
          name: 'Огурцы',
          initialQuantity: 4,
          storageLocationId: location.locationId,
          idempotencyKey: 'created-once',
        ),
      );
      final db = await database.open();
      final row = (await db.query('inventory_events')).single;
      await expectLater(
        db.insert('inventory_events', row),
        throwsA(isA<DatabaseException>()),
      );
      final sameKey = Map<String, Object?>.from(row)
        ..['event_id'] = 'another-event';
      await expectLater(
        db.insert('inventory_events', sameKey),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('accepted events cannot be updated or deleted', () async {
      await repository.createLocalFamily(
        familyName: 'Семья',
        memberName: 'Валя',
      );
      final location = await repository.createLocation(name: 'Погреб');
      await repository.createBatch(
        CreateBatchInput(
          name: 'Огурцы',
          initialQuantity: 4,
          storageLocationId: location.locationId,
        ),
      );
      final db = await database.open();
      await expectLater(
        db.update('inventory_events', {'comment': 'переписано'}),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.delete('inventory_events'),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM inventory_events'),
        ),
        1,
      );
    });
  });
}
