import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SyncTransport {
  Future<int> pushInventoryEvent({
    required String operationId,
    required Map<String, Object?> event,
  });

  Future<List<SyncChange>> pullChanges({
    required String familyId,
    required int after,
    int limit = 200,
  });

  RealtimeChannel subscribeToChanges({
    required String familyId,
    required void Function() onChange,
  });
}

final class SyncChange {
  const SyncChange({
    required this.serverSequence,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.tombstone,
  });

  final int serverSequence;
  final String operationId;
  final String entityType;
  final String entityId;
  final Map<String, Object?> payload;
  final bool tombstone;

  factory SyncChange.fromJson(Map<String, dynamic> row) => SyncChange(
    serverSequence: row['server_sequence'] as int,
    operationId: row['operation_id'] as String,
    entityType: row['entity_type'] as String,
    entityId: row['entity_id'] as String,
    payload: (row['payload'] as Map).cast<String, Object?>(),
    tombstone: row['tombstone'] as bool? ?? false,
  );
}

final class SupabaseRpcTransport implements SyncTransport {
  SupabaseRpcTransport(this._client);

  final SupabaseClient _client;

  @override
  Future<int> pushInventoryEvent({
    required String operationId,
    required Map<String, Object?> event,
  }) async =>
      await _client.rpc(
            'push_inventory_event',
            params: {'p_operation_id': operationId, 'p_event': event},
          )
          as int;

  @override
  Future<List<SyncChange>> pullChanges({
    required String familyId,
    required int after,
    int limit = 200,
  }) async {
    final rows =
        await _client.rpc(
              'pull_changes',
              params: {
                'p_family_id': familyId,
                'p_after': after,
                'p_limit': limit,
              },
            )
            as List;
    return rows
        .cast<Map>()
        .map((row) => SyncChange.fromJson(row.cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  RealtimeChannel subscribeToChanges({
    required String familyId,
    required void Function() onChange,
  }) => _client
      .channel('sync_changes:$familyId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'sync_changes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: familyId,
        ),
        callback: (_) => onChange(),
      )
      .subscribe();
}
