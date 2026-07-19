import 'package:sqflite/sqflite.dart';

const databaseSchemaVersion = 5;

Future<void> applyMigration(DatabaseExecutor db, int version) async {
  switch (version) {
    case 1:
      await _createCoreSchema(db);
    case 2:
      await _createIndexesAndMetadata(db);
    case 3:
      await _createQrSchema(db);
    case 4:
      await _addQuantityUnits(db);
    case 5:
      await _createSyncSchema(db);
    default:
      throw StateError('Неизвестная миграция базы: $version');
  }
}

/// R3 keeps transport state separate from domain state. A local write is valid
/// before it reaches Supabase; the outbox merely records work still to send.
Future<void> _createSyncSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE sync_outbox (
      operation_id TEXT PRIMARY KEY,
      idempotency_key TEXT NOT NULL UNIQUE,
      family_id TEXT NOT NULL REFERENCES families(family_id) ON DELETE RESTRICT,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation_type TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count >= 0),
      next_retry_at TEXT,
      last_error TEXT,
      state TEXT NOT NULL DEFAULT 'pending'
        CHECK(state IN ('pending','sending','acknowledged','retry_wait','blocked','failed_permanently'))
    )
  ''');
  await db.execute('''
    CREATE INDEX sync_outbox_ready_idx
    ON sync_outbox(state, next_retry_at, created_at)
  ''');
  await db.execute('''
    CREATE TABLE sync_cursors (
      family_id TEXT PRIMARY KEY REFERENCES families(family_id) ON DELETE RESTRICT,
      server_sequence INTEGER NOT NULL DEFAULT 0 CHECK(server_sequence >= 0),
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE sync_failures (
      id TEXT PRIMARY KEY,
      operation_id TEXT REFERENCES sync_outbox(operation_id) ON DELETE RESTRICT,
      message TEXT NOT NULL,
      is_permanent INTEGER NOT NULL CHECK(is_permanent IN (0, 1)),
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE sync_conflicts (
      conflict_id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL REFERENCES families(family_id) ON DELETE RESTRICT,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      local_payload_json TEXT NOT NULL,
      remote_payload_json TEXT NOT NULL,
      state TEXT NOT NULL DEFAULT 'open' CHECK(state IN ('open','resolved')),
      created_at TEXT NOT NULL,
      resolved_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE remote_entity_versions (
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      version INTEGER NOT NULL CHECK(version >= 0),
      server_sequence INTEGER NOT NULL CHECK(server_sequence >= 0),
      PRIMARY KEY(entity_type, entity_id)
    )
  ''');
  // Events are the R3 synchronization unit. This trigger runs in the same
  // transaction as the domain write, so a visible local event can never miss
  // its outbox record. Existing R1/R2 history is queued by family onboarding.
  await db.execute('''
    CREATE TRIGGER inventory_events_enqueue_sync AFTER INSERT ON inventory_events
    BEGIN
      INSERT OR IGNORE INTO sync_outbox(
        operation_id, idempotency_key, family_id, entity_type, entity_id,
        operation_type, payload_json, created_at, state
      ) VALUES (
        NEW.event_id, NEW.idempotency_key, NEW.family_id, 'inventory_event', NEW.event_id,
        'append', NEW.payload_json, NEW.created_at, 'pending'
      );
    END
  ''');
  await db.update(
    'schema_metadata',
    <String, Object?>{'value': '$databaseSchemaVersion'},
    where: 'key = ?',
    whereArgs: ['schema_version'],
  );
}

Future<void> _createQrSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE qr_codes (
      id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL REFERENCES families(family_id) ON DELETE RESTRICT,
      public_token TEXT NOT NULL,
      short_code TEXT NOT NULL,
      checksum TEXT NOT NULL,
      protocol_version INTEGER NOT NULL CHECK(protocol_version = 1),
      target_type TEXT NOT NULL CHECK(target_type IN ('batch', 'storage_location', 'unlinked')),
      target_id TEXT,
      state TEXT NOT NULL CHECK(state IN ('unlinked', 'active', 'revoked', 'replaced')),
      created_at TEXT NOT NULL,
      linked_at TEXT,
      revoked_at TEXT,
      replaced_by_qr_id TEXT REFERENCES qr_codes(id) ON DELETE RESTRICT,
      created_by_member_id TEXT NOT NULL REFERENCES family_members(member_id) ON DELETE RESTRICT,
      device_id TEXT NOT NULL REFERENCES device_identities(device_id) ON DELETE RESTRICT,
      CHECK((target_type = 'unlinked' AND target_id IS NULL AND state = 'unlinked') OR
            (target_type IN ('batch', 'storage_location') AND target_id IS NOT NULL))
    )
  ''');
  await db.execute('''
    CREATE UNIQUE INDEX qr_codes_public_token_uq ON qr_codes(public_token)
  ''');
  await db.execute('''
    CREATE UNIQUE INDEX qr_codes_family_short_code_uq ON qr_codes(family_id, short_code)
  ''');
  await db.execute('''
    CREATE INDEX qr_codes_target_idx ON qr_codes(family_id, target_type, target_id, state)
  ''');
  await db.execute('''
    CREATE TABLE qr_events (
      event_id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL REFERENCES families(family_id) ON DELETE RESTRICT,
      qr_id TEXT NOT NULL REFERENCES qr_codes(id) ON DELETE RESTRICT,
      event_type TEXT NOT NULL CHECK(event_type IN ('QR_CREATED', 'QR_LINKED', 'QR_REVOKED', 'QR_REPLACED')),
      target_type TEXT NOT NULL,
      target_id TEXT,
      created_by_member_id TEXT NOT NULL REFERENCES family_members(member_id) ON DELETE RESTRICT,
      device_id TEXT NOT NULL REFERENCES device_identities(device_id) ON DELETE RESTRICT,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TRIGGER qr_events_no_update BEFORE UPDATE ON qr_events
    BEGIN SELECT RAISE(ABORT, 'qr_events are append-only'); END
  ''');
  await db.execute('''
    CREATE TRIGGER qr_events_no_delete BEFORE DELETE ON qr_events
    BEGIN SELECT RAISE(ABORT, 'qr_events are append-only'); END
  ''');
  await db.update(
    'schema_metadata',
    <String, Object?>{'value': '$databaseSchemaVersion'},
    where: 'key = ?',
    whereArgs: ['schema_version'],
  );
}

Future<void> _createCoreSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE local_profiles (
      profile_id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL CHECK(length(trim(display_name)) BETWEEN 1 AND 80),
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE families (
      family_id TEXT PRIMARY KEY,
      name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 80),
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE family_members (
      member_id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL REFERENCES families(family_id) ON DELETE RESTRICT,
      profile_id TEXT NOT NULL REFERENCES local_profiles(profile_id) ON DELETE RESTRICT,
      display_name TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE device_identities (
      device_id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      next_sequence INTEGER NOT NULL DEFAULT 1 CHECK(next_sequence > 0)
    )
  ''');
  await db.execute('''
    CREATE TABLE storage_locations (
      location_id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL REFERENCES families(family_id) ON DELETE RESTRICT,
      parent_location_id TEXT REFERENCES storage_locations(location_id) ON DELETE RESTRICT,
      name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
      description TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      archived_at TEXT,
      CHECK(parent_location_id IS NULL OR parent_location_id <> location_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE batches (
      batch_id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL REFERENCES families(family_id) ON DELETE RESTRICT,
      name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 160),
      category TEXT NOT NULL DEFAULT 'Другое',
      initial_quantity INTEGER NOT NULL CHECK(initial_quantity > 0),
      jar_volume_ml INTEGER CHECK(jar_volume_ml IS NULL OR jar_volume_ml > 0),
      preserved_at TEXT,
      harvest_year INTEGER CHECK(harvest_year IS NULL OR harvest_year BETWEEN 1900 AND 2200),
      author_member_id TEXT NOT NULL REFERENCES family_members(member_id) ON DELETE RESTRICT,
      storage_location_id TEXT NOT NULL REFERENCES storage_locations(location_id) ON DELETE RESTRICT,
      recipe_name TEXT,
      comment TEXT,
      spiciness INTEGER CHECK(spiciness IS NULL OR spiciness BETWEEN 0 AND 5),
      check_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      archived_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE inventory_events (
      event_id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL REFERENCES families(family_id) ON DELETE RESTRICT,
      batch_id TEXT NOT NULL REFERENCES batches(batch_id) ON DELETE RESTRICT,
      actor_member_id TEXT NOT NULL REFERENCES family_members(member_id) ON DELETE RESTRICT,
      event_type TEXT NOT NULL,
      quantity_delta INTEGER NOT NULL,
      from_location_id TEXT REFERENCES storage_locations(location_id) ON DELETE RESTRICT,
      to_location_id TEXT REFERENCES storage_locations(location_id) ON DELETE RESTRICT,
      comment TEXT,
      payload_json TEXT NOT NULL DEFAULT '{}',
      client_created_at TEXT NOT NULL,
      device_id TEXT NOT NULL REFERENCES device_identities(device_id) ON DELETE RESTRICT,
      idempotency_key TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE inventory_projections (
      batch_id TEXT PRIMARY KEY REFERENCES batches(batch_id) ON DELETE CASCADE,
      computed_quantity INTEGER NOT NULL,
      current_location_id TEXT NOT NULL REFERENCES storage_locations(location_id) ON DELETE RESTRICT,
      needs_reconciliation INTEGER NOT NULL DEFAULT 0 CHECK(needs_reconciliation IN (0, 1)),
      spoiled_quantity INTEGER NOT NULL DEFAULT 0 CHECK(spoiled_quantity >= 0),
      last_event_id TEXT,
      last_decrease_type TEXT,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE batch_photos (
      photo_id TEXT PRIMARY KEY,
      batch_id TEXT NOT NULL REFERENCES batches(batch_id) ON DELETE CASCADE,
      local_path TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE app_settings (
      settings_id INTEGER PRIMARY KEY CHECK(settings_id = 1),
      theme_mode TEXT NOT NULL DEFAULT 'system',
      large_mode INTEGER NOT NULL DEFAULT 0 CHECK(large_mode IN (0, 1)),
      low_stock_threshold INTEGER NOT NULL DEFAULT 4 CHECK(low_stock_threshold >= 2),
      seed_applied INTEGER NOT NULL DEFAULT 0 CHECK(seed_applied IN (0, 1))
    )
  ''');
  await db.execute('''
    CREATE TRIGGER inventory_events_no_update
    BEFORE UPDATE ON inventory_events
    BEGIN
      SELECT RAISE(ABORT, 'inventory_events are append-only');
    END
  ''');
  await db.execute('''
    CREATE TRIGGER inventory_events_no_delete
    BEFORE DELETE ON inventory_events
    BEGIN
      SELECT RAISE(ABORT, 'inventory_events are append-only');
    END
  ''');
  await db.insert('app_settings', const <String, Object?>{'settings_id': 1});
}

Future<void> _createIndexesAndMetadata(DatabaseExecutor db) async {
  await db.execute('''
    CREATE UNIQUE INDEX inventory_events_idempotency_uq
    ON inventory_events(family_id, device_id, idempotency_key)
  ''');
  await db.execute('''
    CREATE INDEX inventory_events_batch_order_idx
    ON inventory_events(batch_id, created_at, event_id)
  ''');
  await db.execute('''
    CREATE INDEX storage_locations_tree_idx
    ON storage_locations(family_id, parent_location_id, sort_order, name)
  ''');
  await db.execute('''
    CREATE INDEX batches_catalog_idx
    ON batches(family_id, archived_at, category, harvest_year, created_at)
  ''');
  await db.execute('''
    CREATE INDEX batches_location_idx
    ON batches(family_id, storage_location_id, archived_at)
  ''');
  await db.execute('''
    CREATE TABLE schema_metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
  await db.insert('schema_metadata', <String, Object?>{
    'key': 'schema_version',
    'value': '$databaseSchemaVersion',
  });
}

Future<void> _addQuantityUnits(DatabaseExecutor db) async {
  await db.execute(
    "ALTER TABLE batches ADD COLUMN quantity_unit TEXT NOT NULL DEFAULT 'шт.'",
  );
  await db.execute('''
    UPDATE batches
    SET quantity_unit = CASE category
      WHEN 'Варенье' THEN 'мл'
      WHEN 'Соусы' THEN 'мл'
      WHEN 'Напитки' THEN 'мл'
      WHEN 'Грибы' THEN 'г'
      WHEN 'Заморозка' THEN 'г'
      WHEN 'Сушка' THEN 'г'
      ELSE 'шт.'
    END
  ''');
  await db.update(
    'schema_metadata',
    <String, Object?>{'value': '$databaseSchemaVersion'},
    where: 'key = ?',
    whereArgs: ['schema_version'],
  );
}
