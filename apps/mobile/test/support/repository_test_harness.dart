import 'package:banochki/core/database/app_database.dart';
import 'package:banochki/core/ids/id_generator.dart';
import 'package:banochki/core/time/clock.dart';
import 'package:banochki/features/inventory/data/sqlite_inventory_repository.dart';
import 'package:banochki/features/inventory/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final class RepositoryTestHarness {
  RepositoryTestHarness({
    required this.database,
    required this.repository,
    this.location,
    this.batch,
  });

  final AppDatabase database;
  final SqliteInventoryRepository repository;
  StorageLocation? location;
  BatchView? batch;

  static Future<RepositoryTestHarness> create({
    bool bootstrap = true,
    int initialQuantity = 18,
    DateTime? now,
  }) async {
    sqfliteFfiInit();
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final repository = SqliteInventoryRepository(
      database: database,
      idGenerator: SequenceIdGenerator(),
      clock: FixedClock(now ?? DateTime.utc(2026, 7, 19, 12)),
    );
    final harness = RepositoryTestHarness(
      database: database,
      repository: repository,
    );
    if (bootstrap) {
      await repository.createLocalFamily(
        familyName: 'Семья Теста',
        memberName: 'Валя',
      );
      harness.location = await repository.createLocation(name: 'Погреб');
      harness.batch = await repository.createBatch(
        CreateBatchInput(
          name: 'Огурцы',
          initialQuantity: initialQuantity,
          storageLocationId: harness.location!.locationId,
          category: 'Овощи',
          jarVolumeMl: 1000,
          harvestYear: 2026,
        ),
      );
    }
    return harness;
  }

  Future<void> dispose() => repository.close();
}
