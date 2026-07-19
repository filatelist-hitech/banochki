import 'package:banochki/features/qr/domain/qr_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/repository_test_harness.dart';

void main() {
  group('local QR repository', () {
    late RepositoryTestHarness harness;
    setUp(() async => harness = await RepositoryTestHarness.create());
    tearDown(() => harness.dispose());

    test(
      'stable batch QR resolves locally and does not create inventory event',
      () async {
        final batchId = harness.batch!.batch.batchId;
        final first = await harness.repository.generateQrForBatch(batchId);
        final second = await harness.repository.generateQrForBatch(batchId);
        final result = await harness.repository.resolveQr(first.payload);
        expect(second.id, first.id);
        expect(first.publicToken, hasLength(43));
        expect(ShortCode.isValid(first.shortCode), isTrue);
        expect(result.kind, QrResolutionKind.resolved);
        expect(result.qrCode?.targetId, batchId);
        final snapshot = await harness.repository.loadSnapshot();
        expect(snapshot.history, hasLength(1));
      },
    );

    test(
      'unlinked label is explicitly linked and event history is append-only',
      () async {
        final unlinked = await harness.repository.generateUnlinkedQr();
        expect(
          (await harness.repository.resolveQr(unlinked.payload)).kind,
          QrResolutionKind.unlinked,
        );
        final linked = await harness.repository.linkQrToStorageLocation(
          qrId: unlinked.id,
          locationId: harness.location!.locationId,
        );
        expect(linked.state, QrCodeState.active);
        final db = await harness.database.open();
        expect((await db.query('qr_events')), hasLength(2));
      },
    );

    test('revoked and replaced codes never resolve as active', () async {
      final old = await harness.repository.generateQrForBatch(
        harness.batch!.batch.batchId,
      );
      final replacement = await harness.repository.replaceQr(old.id);
      expect(
        (await harness.repository.resolveQr(old.payload)).kind,
        QrResolutionKind.replaced,
      );
      expect(
        (await harness.repository.resolveQr(replacement.payload)).kind,
        QrResolutionKind.resolved,
      );
      await harness.repository.revokeQr(replacement.id);
      expect(
        (await harness.repository.resolveShortCode(replacement.shortCode)).kind,
        QrResolutionKind.revoked,
      );
    });
  });
}
