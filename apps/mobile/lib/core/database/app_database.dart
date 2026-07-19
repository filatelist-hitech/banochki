import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

final class AppDatabase {
  AppDatabase({required this.factory, required this.databasePath});

  final DatabaseFactory factory;
  final String databasePath;
  Database? _database;

  static Future<AppDatabase> production() async {
    final basePath = await getDatabasesPath();
    return AppDatabase(
      factory: databaseFactory,
      databasePath: path.join(basePath, 'banochki.sqlite'),
    );
  }

  Future<Database> open() async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    final opened = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: databaseSchemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          for (var migration = 1; migration <= version; migration++) {
            await applyMigration(db, migration);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          for (
            var migration = oldVersion + 1;
            migration <= newVersion;
            migration++
          ) {
            await applyMigration(db, migration);
          }
        },
      ),
    );
    _database = opened;
    return opened;
  }

  Future<void> close() async {
    final current = _database;
    if (current != null && current.isOpen) await current.close();
    _database = null;
  }
}
