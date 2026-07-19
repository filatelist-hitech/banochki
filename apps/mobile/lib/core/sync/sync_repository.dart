import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import 'sync_protocol.dart';
import 'sync_transport.dart';

final class SyncDiagnostics {
  const SyncDiagnostics({
    required this.status,
    required this.cursor,
    required this.outboxCount,
    required this.deviceId,
    this.lastPushAt,
    this.lastPullAt,
    this.lastError,
  });

  final String status;
  final int cursor;
  final int outboxCount;
  final String? deviceId;
  final DateTime? lastPushAt;
  final DateTime? lastPullAt;
  final String? lastError;
}

enum SyncFailureKind { transient, permanent, blocked }

final class SyncTransportFailure implements Exception {
  const SyncTransportFailure(this.kind, this.message);
  final SyncFailureKind kind;
  final String message;
  @override
  String toString() => message;
}

/// The only component allowed to cross the SQLite/Supabase boundary. Widgets
/// call application methods; they never call RPC or Realtime directly.
final class SyncRepository {
  factory SyncRepository({
    required AppDatabase database,
    required SyncTransport transport,
    DateTime Function()? now,
    Random? random,
    RetryPolicy retryPolicy = const RetryPolicy(),
  }) => SyncRepository._(
    database,
    transport,
    now ?? DateTime.now,
    random ?? Random(),
    retryPolicy,
  );

  SyncRepository._(
    this._database,
    this._transport,
    this._now,
    this._random,
    this._retryPolicy,
  );

  final AppDatabase _database;
  final SyncTransport _transport;
  final DateTime Function() _now;
  final Random _random;
  final RetryPolicy _retryPolicy;
  RealtimeChannel? _channel;
  DateTime? _lastPushAt;
  DateTime? _lastPullAt;
  String? _lastError;
  var _status = 'idle';
  var _syncing = false;

  Future<SyncDiagnostics> diagnostics() async {
    final db = await _database.open();
    final family = (await db.query('families', limit: 1)).firstOrNull;
    final device = (await db.query('device_identities', limit: 1)).firstOrNull;
    if (family == null) {
      return SyncDiagnostics(
        status: 'local_only',
        cursor: 0,
        outboxCount: 0,
        deviceId: null,
      );
    }
    final familyId = family['family_id']! as String;
    final cursor = (await db.query(
      'sync_cursors',
      where: 'family_id = ?',
      whereArgs: [familyId],
      limit: 1,
    )).firstOrNull;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM sync_outbox WHERE state != 'acknowledged'",
      ),
    )!;
    return SyncDiagnostics(
      status: _status,
      cursor: cursor?['server_sequence'] as int? ?? 0,
      outboxCount: count,
      deviceId: device?['device_id'] as String?,
      lastPushAt: _lastPushAt,
      lastPullAt: _lastPullAt,
      lastError: _lastError,
    );
  }

  Future<void> reconnect() async {
    final db = await _database.open();
    final family = (await db.query('families', limit: 1)).firstOrNull;
    await _channel?.unsubscribe();
    _channel = null;
    if (family == null) return;
    try {
      _channel = _transport.subscribeToChanges(
        familyId: family['family_id']! as String,
        onChange: () {
          syncNow();
        },
      );
    } on UnimplementedError {
      // File-based transports are pull-on-reconnect only.
    }
    await syncNow();
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    _status = 'syncing';
    try {
      await _pushReady();
      await _pullAll();
      _status = 'idle';
      _lastError = null;
    } catch (error) {
      _status = 'error';
      _lastError = '$error';
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pushReady() async {
    final db = await _database.open();
    final now = _now().toUtc();
    final operations = await db.rawQuery(
      '''
      SELECT * FROM sync_outbox
      WHERE state = 'pending' OR (state = 'retry_wait' AND next_retry_at <= ?)
      ORDER BY created_at, operation_id
    ''',
      [now.toIso8601String()],
    );
    for (final operation in operations) {
      final id = operation['operation_id']! as String;
      await db.update(
        'sync_outbox',
        {'state': 'sending'},
        where: 'operation_id = ?',
        whereArgs: [id],
      );
      try {
        final event = await _eventForOperation(db, id);
        await _transport.pushInventoryEvent(operationId: id, event: event);
        await db.update(
          'sync_outbox',
          {'state': 'acknowledged', 'last_error': null, 'next_retry_at': null},
          where: 'operation_id = ?',
          whereArgs: [id],
        );
        _lastPushAt = _now().toUtc();
      } catch (error) {
        await _recordPushFailure(db, operation, error);
      }
    }
  }

  Future<Map<String, Object?>> _eventForOperation(
    Database db,
    String id,
  ) async {
    final event = (await db.query(
      'inventory_events',
      where: 'event_id = ?',
      whereArgs: [id],
      limit: 1,
    )).single;
    return {
      'family_id': event['family_id'],
      'batch_id': event['batch_id'],
      'actor_member_id': event['actor_member_id'],
      'event_type': event['event_type'],
      'quantity_delta': event['quantity_delta'],
      'payload': jsonDecode(event['payload_json']! as String),
      'client_created_at': event['client_created_at'],
      'device_id': event['device_id'],
      'idempotency_key': event['idempotency_key'],
    };
  }

  Future<void> _recordPushFailure(
    Database db,
    Map<String, Object?> operation,
    Object error,
  ) async {
    final message = '$error';
    final permanent = _isPermanent(error);
    final blocked = _isBlocked(error);
    final attempt = (operation['attempt_count']! as int) + 1;
    final state = blocked
        ? 'blocked'
        : (permanent ? 'failed_permanently' : 'retry_wait');
    final retry = state == 'retry_wait'
        ? _now().toUtc().add(
            _retryPolicy.nextDelay(
              attempt - 1,
              jitter: (_random.nextDouble() * 0.5) - 0.25,
            ),
          )
        : null;
    await db.transaction((tx) async {
      await tx.update(
        'sync_outbox',
        {
          'state': state,
          'attempt_count': attempt,
          'next_retry_at': retry?.toIso8601String(),
          'last_error': message,
        },
        where: 'operation_id = ?',
        whereArgs: [operation['operation_id']],
      );
      await tx.insert('sync_failures', {
        'id': '${operation['operation_id']}:$attempt',
        'operation_id': operation['operation_id'],
        'message': message,
        'is_permanent': (permanent || blocked) ? 1 : 0,
        'created_at': _now().toUtc().toIso8601String(),
      });
    });
    _lastError = message;
  }

  Future<void> _pullAll() async {
    final db = await _database.open();
    final family = (await db.query('families', limit: 1)).firstOrNull;
    if (family == null) return;
    final familyId = family['family_id']! as String;
    while (true) {
      final cursor = (await db.query(
        'sync_cursors',
        where: 'family_id = ?',
        whereArgs: [familyId],
        limit: 1,
      )).firstOrNull;
      final after = cursor?['server_sequence'] as int? ?? 0;
      final changes = await _transport.pullChanges(
        familyId: familyId,
        after: after,
      );
      if (changes.isEmpty) return;
      await db.transaction((tx) async {
        for (final change in changes) {
          if (change.entityType == 'inventory_event' && !change.tombstone) {
            await _applyRemoteEvent(tx, change);
          }
        }
        await tx.insert('sync_cursors', {
          'family_id': familyId,
          'server_sequence': changes.last.serverSequence,
          'updated_at': _now().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
      _lastPullAt = _now().toUtc();
      if (changes.length < 200) return;
    }
  }

  Future<void> _applyRemoteEvent(Transaction tx, SyncChange change) async {
    final event = change.payload;
    await tx.insert('inventory_events', {
      'event_id': change.operationId,
      'family_id': event['family_id'],
      'batch_id': event['batch_id'],
      'actor_member_id': event['actor_member_id'],
      'event_type': event['event_type'],
      'quantity_delta': event['quantity_delta'],
      'payload_json': jsonEncode(event['payload'] ?? const {}),
      'client_created_at': event['client_created_at'],
      'device_id': event['device_id'],
      'idempotency_key': event['idempotency_key'],
      'created_at': event['client_created_at'],
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    // The R3 trigger enqueues every inserted event. A remotely accepted event
    // is already acknowledged by definition, so remove this local echo.
    await tx.delete(
      'sync_outbox',
      where: 'operation_id = ?',
      whereArgs: [change.operationId],
    );
    await tx.rawUpdate(
      '''
      UPDATE inventory_projections
      SET computed_quantity = COALESCE((
            SELECT SUM(quantity_delta) FROM inventory_events
            WHERE batch_id = inventory_projections.batch_id
          ), 0),
          updated_at = ?
      WHERE batch_id = ?
    ''',
      [_now().toUtc().toIso8601String(), event['batch_id']],
    );
  }

  bool _isBlocked(Object error) =>
      error is SyncTransportFailure && error.kind == SyncFailureKind.blocked ||
      error is PostgrestException &&
          (error.code == '42501' || error.message.contains('not_allowed'));
  bool _isPermanent(Object error) =>
      error is SyncTransportFailure &&
          error.kind == SyncFailureKind.permanent ||
      error is PostgrestException &&
          !_isBlocked(error) &&
          ((error.code?.startsWith('22') ?? false) || error.code == '23503');

  Future<void> dispose() async => await _channel?.unsubscribe();
}
