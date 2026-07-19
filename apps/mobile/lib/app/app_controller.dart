import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../features/inventory/data/sqlite_inventory_repository.dart';
import '../features/inventory/domain/inventory_repository.dart';
import '../features/inventory/domain/models.dart';
import '../features/qr/domain/qr_models.dart';

final inventoryRepositoryProvider = FutureProvider<InventoryRepository>((
  ref,
) async {
  final database = await AppDatabase.production();
  final repository = SqliteInventoryRepository(database: database);
  ref.onDispose(repository.close);
  return repository;
});

final appControllerProvider =
    AsyncNotifierProvider<AppController, AppViewState>(AppController.new);

final class AppViewState {
  const AppViewState({
    required this.snapshot,
    required this.catalog,
    this.query = const CatalogQuery(),
  });

  final AppSnapshot snapshot;
  final List<BatchView> catalog;
  final CatalogQuery query;

  AppViewState copyWith({
    AppSnapshot? snapshot,
    List<BatchView>? catalog,
    CatalogQuery? query,
  }) => AppViewState(
    snapshot: snapshot ?? this.snapshot,
    catalog: catalog ?? this.catalog,
    query: query ?? this.query,
  );
}

final class AppController extends AsyncNotifier<AppViewState> {
  @override
  Future<AppViewState> build() async {
    final repository = await ref.watch(inventoryRepositoryProvider.future);
    final snapshot = await repository.loadSnapshot();
    final query = const CatalogQuery();
    final catalog = await repository.searchCatalog(query);
    return AppViewState(snapshot: snapshot, catalog: catalog, query: query);
  }

  Future<InventoryRepository> get _repository =>
      ref.read(inventoryRepositoryProvider.future);

  Future<void> refresh() async {
    final repository = await _repository;
    final current = state.value;
    final query = current?.query ?? const CatalogQuery();
    final snapshot = await repository.loadSnapshot();
    final catalog = await repository.searchCatalog(query);
    state = AsyncData(
      AppViewState(snapshot: snapshot, catalog: catalog, query: query),
    );
  }

  Future<void> createFamily(String familyName, String memberName) async {
    await (await _repository).createLocalFamily(
      familyName: familyName,
      memberName: memberName,
    );
    await refresh();
  }

  Future<StorageLocation> createLocation({
    required String name,
    String? parentLocationId,
    String? description,
  }) async {
    final result = await (await _repository).createLocation(
      name: name,
      parentLocationId: parentLocationId,
      description: description,
    );
    await refresh();
    return result;
  }

  Future<void> updateLocation({
    required String locationId,
    required String name,
    String? parentLocationId,
    String? description,
  }) async {
    await (await _repository).updateLocation(
      locationId: locationId,
      name: name,
      parentLocationId: parentLocationId,
      description: description,
    );
    await refresh();
  }

  Future<void> archiveLocation(String locationId) async {
    await (await _repository).archiveLocation(locationId);
    await refresh();
  }

  Future<BatchView> createBatch(CreateBatchInput input) async {
    final result = await (await _repository).createBatch(input);
    await refresh();
    return result;
  }

  Future<void> updateBatchMetadata({
    required String batchId,
    required String name,
    required String category,
    int? jarVolumeMl,
    DateTime? preservedAt,
    int? harvestYear,
    String? recipeName,
    String? comment,
    int? spiciness,
    DateTime? checkAt,
  }) async {
    await (await _repository).updateBatchMetadata(
      batchId: batchId,
      name: name,
      category: category,
      jarVolumeMl: jarVolumeMl,
      preservedAt: preservedAt,
      harvestYear: harvestYear,
      recipeName: recipeName,
      comment: comment,
      spiciness: spiciness,
      checkAt: checkAt,
    );
    await refresh();
  }

  Future<void> recordEvent({
    required String batchId,
    required InventoryEventType type,
    int quantity = 0,
    String? toLocationId,
    String? comment,
    bool confirmUnderflow = false,
  }) async {
    await (await _repository).recordEvent(
      batchId: batchId,
      type: type,
      quantity: quantity,
      toLocationId: toLocationId,
      comment: comment,
      confirmUnderflow: confirmUnderflow,
    );
    await refresh();
  }

  Future<void> reconcile({
    required String batchId,
    required int actualQuantity,
    String? comment,
  }) async {
    await (await _repository).reconcile(
      batchId: batchId,
      actualQuantity: actualQuantity,
      comment: comment,
    );
    await refresh();
  }

  Future<void> setQuery(CatalogQuery query) async {
    final current = state.value;
    if (current == null) return;
    final catalog = await (await _repository).searchCatalog(query);
    state = AsyncData(current.copyWith(catalog: catalog, query: query));
  }

  Future<void> setSettings(AppSettings settings) async {
    await (await _repository).updateSettings(settings);
    await refresh();
  }

  Future<void> rebuildProjections() async {
    await (await _repository).rebuildProjections();
    await refresh();
  }

  Future<QrCode> generateQrForBatch(String batchId) async =>
      (await _repository).generateQrForBatch(batchId);

  Future<QrCode> generateQrForLocation(String locationId) async =>
      (await _repository).generateQrForStorageLocation(locationId);

  Future<QrCode> generateUnlinkedQr() async =>
      (await _repository).generateUnlinkedQr();

  Future<QrResolveResult> resolveQr(String payload) async =>
      (await _repository).resolveQr(payload);

  Future<QrResolveResult> resolveShortCode(String shortCode) async =>
      (await _repository).resolveShortCode(shortCode);

  Future<void> seedDebugData() async {
    await (await _repository).seedDebugData();
    await refresh();
  }
}
