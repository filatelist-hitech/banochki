import 'dart:math';

enum SyncOperationState {
  pending,
  sending,
  acknowledged,
  retryWait,
  blocked,
  failedPermanently,
}

final class RetryPolicy {
  const RetryPolicy({
    this.base = const Duration(seconds: 2),
    this.max = const Duration(minutes: 5),
  });

  final Duration base;
  final Duration max;

  Duration nextDelay(int attempt, {double jitter = 0.5}) {
    final cappedAttempt = min(attempt, 20);
    final raw = min(
      max.inMilliseconds,
      base.inMilliseconds * (1 << cappedAttempt),
    );
    return Duration(milliseconds: (raw * (1 + jitter)).round());
  }
}

final class SyncOperation {
  const SyncOperation({
    required this.operationId,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    this.attemptCount = 0,
    this.state = SyncOperationState.pending,
  });

  final String operationId;
  final String idempotencyKey;
  final String entityType;
  final String entityId;
  final String operationType;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final int attemptCount;
  final SyncOperationState state;

  SyncOperation retry(DateTime now, RetryPolicy policy) => SyncOperation(
    operationId: operationId,
    idempotencyKey: idempotencyKey,
    entityType: entityType,
    entityId: entityId,
    operationType: operationType,
    payload: payload,
    createdAt: createdAt,
    attemptCount: attemptCount + 1,
    state: SyncOperationState.retryWait,
  );
}

/// Metadata merge never discards an incompatible local value: it becomes a conflict.
final class MetadataMerge {
  const MetadataMerge({required this.value, required this.conflictingFields});
  final Map<String, Object?> value;
  final Set<String> conflictingFields;
  bool get hasConflict => conflictingFields.isNotEmpty;

  static MetadataMerge threeWay({
    required Map<String, Object?> base,
    required Map<String, Object?> local,
    required Map<String, Object?> remote,
  }) {
    final result = <String, Object?>{};
    final conflicts = <String>{};
    final keys = {...base.keys, ...local.keys, ...remote.keys};
    for (final key in keys) {
      final before = base[key];
      final ours = local[key];
      final theirs = remote[key];
      if (ours == theirs || theirs == before) {
        result[key] = ours;
      } else if (ours == before) {
        result[key] = theirs;
      } else {
        result[key] = theirs;
        conflicts.add(key);
      }
    }
    return MetadataMerge(value: result, conflictingFields: conflicts);
  }
}
