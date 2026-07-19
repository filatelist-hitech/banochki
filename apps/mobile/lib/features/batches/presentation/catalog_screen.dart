import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';
import '../../inventory/domain/models.dart';
import 'add_batch_screen.dart';
import 'batch_details_screen.dart';

final class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final controller = ref.read(appControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Все запасы'),
        actions: [
          IconButton(
            tooltip: 'Фильтры и сортировка',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _CatalogFilters(state: state),
            ),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.snapshot.locations.any((item) => !item.isArchived)
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AddBatchScreen()),
              )
            : null,
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BanochkiSpacing.md),
            child: SearchBar(
              key: const Key('catalog-search'),
              hintText: 'Название, категория или место',
              leading: const Icon(Icons.search),
              onChanged: (value) => controller.setQuery(
                CatalogQuery(
                  search: value,
                  category: state.query.category,
                  harvestYear: state.query.harvestYear,
                  locationId: state.query.locationId,
                  status: state.query.status,
                  availableOnly: state.query.availableOnly,
                  needsReconciliationOnly: state.query.needsReconciliationOnly,
                  sort: state.query.sort,
                ),
              ),
            ),
          ),
          Expanded(
            child: state.catalog.isEmpty
                ? EmptyState(
                    title: state.snapshot.batches.isEmpty
                        ? 'Пока пусто'
                        : 'Ничего не найдено',
                    message: state.snapshot.batches.isEmpty
                        ? 'Добавьте первую партию.'
                        : 'Сбросьте фильтры или измените запрос.',
                    actionLabel: state.snapshot.batches.isEmpty
                        ? 'Добавить партию'
                        : 'Сбросить фильтры',
                    onAction: state.snapshot.batches.isEmpty
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AddBatchScreen(),
                            ),
                          )
                        : () => controller.setQuery(const CatalogQuery()),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final large = state.snapshot.settings.largeMode;
                      final columns = constraints.maxWidth >= 900 ? 2 : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          BanochkiSpacing.md,
                          0,
                          BanochkiSpacing.md,
                          96,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: large ? 310 : 240,
                          crossAxisSpacing: BanochkiSpacing.md,
                          mainAxisSpacing: BanochkiSpacing.sm,
                        ),
                        itemCount: state.catalog.length,
                        itemBuilder: (context, index) {
                          final view = state.catalog[index];
                          return BatchCard(
                            view: view,
                            large: large,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BatchDetailsScreen(
                                  batchId: view.batch.batchId,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

final class _CatalogFilters extends ConsumerStatefulWidget {
  const _CatalogFilters({required this.state});
  final AppViewState state;

  @override
  ConsumerState<_CatalogFilters> createState() => _CatalogFiltersState();
}

final class _CatalogFiltersState extends ConsumerState<_CatalogFilters> {
  late String? category = widget.state.query.category;
  late int? year = widget.state.query.harvestYear;
  late String? locationId = widget.state.query.locationId;
  late BatchStatus? status = widget.state.query.status;
  late bool available = widget.state.query.availableOnly;
  late bool reconciliation = widget.state.query.needsReconciliationOnly;
  late CatalogSort sort = widget.state.query.sort;

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.state.snapshot.batches
            .map((item) => item.batch.category)
            .toSet()
            .toList()
          ..sort();
    final years =
        widget.state.snapshot.batches
            .map((item) => item.batch.harvestYear)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final locations = widget.state.snapshot.locations
        .where((item) => !item.isArchived)
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: BanochkiSpacing.md,
          right: BanochkiSpacing.md,
          top: BanochkiSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + BanochkiSpacing.md,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Фильтры', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: BanochkiSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Категория'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Все категории'),
                ),
                ...categories.map(
                  (value) => DropdownMenuItem<String?>(
                    value: value,
                    child: Text(value),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => category = value),
            ),
            const SizedBox(height: BanochkiSpacing.sm),
            DropdownButtonFormField<int?>(
              initialValue: year,
              decoration: const InputDecoration(labelText: 'Год'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Все годы'),
                ),
                ...years.map(
                  (value) => DropdownMenuItem<int?>(
                    value: value,
                    child: Text('$value'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => year = value),
            ),
            const SizedBox(height: BanochkiSpacing.sm),
            DropdownButtonFormField<String?>(
              initialValue: locationId,
              decoration: const InputDecoration(labelText: 'Место'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Все места'),
                ),
                ...locations.map(
                  (value) => DropdownMenuItem<String?>(
                    value: value.locationId,
                    child: Text(value.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => locationId = value),
            ),
            const SizedBox(height: BanochkiSpacing.sm),
            DropdownButtonFormField<BatchStatus?>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Статус'),
              items: [
                const DropdownMenuItem<BatchStatus?>(
                  value: null,
                  child: Text('Все статусы'),
                ),
                ...BatchStatus.values.map(
                  (value) => DropdownMenuItem<BatchStatus?>(
                    value: value,
                    child: Text(value.label),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => status = value),
            ),
            SwitchListTile(
              title: const Text('Есть в наличии'),
              value: available,
              onChanged: (value) => setState(() => available = value),
            ),
            SwitchListTile(
              title: const Text('Требует уточнения'),
              value: reconciliation,
              onChanged: (value) => setState(() => reconciliation = value),
            ),
            DropdownButtonFormField<CatalogSort>(
              initialValue: sort,
              decoration: const InputDecoration(labelText: 'Сортировка'),
              items: CatalogSort.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => sort = value ?? sort),
            ),
            const SizedBox(height: BanochkiSpacing.lg),
            PrimaryActionButton(
              label: 'Показать результаты',
              onPressed: () async {
                await ref
                    .read(appControllerProvider.notifier)
                    .setQuery(
                      CatalogQuery(
                        search: widget.state.query.search,
                        category: category,
                        harvestYear: year,
                        locationId: locationId,
                        status: status,
                        availableOnly: available,
                        needsReconciliationOnly: reconciliation,
                        sort: sort,
                      ),
                    );
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
