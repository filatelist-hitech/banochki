import 'package:banochki/core/sync/sync_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retry grows exponentially and remains bounded', () {
    const policy = RetryPolicy();
    expect(policy.nextDelay(0, jitter: 0), const Duration(seconds: 2));
    expect(policy.nextDelay(1, jitter: 0), const Duration(seconds: 4));
    expect(policy.nextDelay(99, jitter: 0), const Duration(minutes: 5));
  });

  test('three way merge keeps independent changes', () {
    final merge = MetadataMerge.threeWay(
      base: {'name': 'Вишня', 'comment': 'старое'},
      local: {'name': 'Вишня', 'comment': 'местное'},
      remote: {'name': 'Вишня без косточек', 'comment': 'старое'},
    );
    expect(merge.value, {'name': 'Вишня без косточек', 'comment': 'местное'});
    expect(merge.hasConflict, isFalse);
  });

  test('same field concurrent edit creates an explicit conflict', () {
    final merge = MetadataMerge.threeWay(
      base: {'name': 'Вишня'},
      local: {'name': 'Вишня А'},
      remote: {'name': 'Вишня Б'},
    );
    expect(merge.conflictingFields, {'name'});
  });
}
