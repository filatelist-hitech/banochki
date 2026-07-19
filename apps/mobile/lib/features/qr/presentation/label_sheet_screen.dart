import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../app/app_controller.dart';
import '../../inventory/domain/models.dart';
import '../domain/label_pdf.dart';

final class LabelSheetScreen extends ConsumerStatefulWidget {
  const LabelSheetScreen({super.key});
  @override
  ConsumerState<LabelSheetScreen> createState() => _LabelSheetScreenState();
}

final class _LabelSheetScreenState extends ConsumerState<LabelSheetScreen> {
  var _template = LabelTemplate.medium;
  var _unlinked = false;
  var _showName = true;
  var _showYear = true;
  var _showVolume = true;
  var _showLocation = true;
  var _showAuthor = false;
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(appControllerProvider).requireValue.snapshot;
    final batches = snapshot.batches
        .where((item) => !item.batch.isArchived)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Печатные этикетки')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<LabelTemplate>(
            segments: const [
              ButtonSegment(value: LabelTemplate.large, label: Text('Одна')),
              ButtonSegment(
                value: LabelTemplate.medium,
                label: Text('Средние'),
              ),
              ButtonSegment(value: LabelTemplate.small, label: Text('Мелкие')),
            ],
            selected: {_template},
            onSelectionChanged: (value) =>
                setState(() => _template = value.single),
          ),
          SwitchListTile(
            value: _unlinked,
            onChanged: (value) => setState(() => _unlinked = value),
            title: const Text('Лист свободных QR-кодов'),
            subtitle: const Text(
              'После сканирования потребуется явная привязка',
            ),
          ),
          if (!_unlinked) ...[
            const SizedBox(height: 12),
            const Text('Выберите партии'),
            for (final view in batches)
              CheckboxListTile(
                value: _selected.contains(view.batch.batchId),
                onChanged: (value) => setState(
                  () => value == true
                      ? _selected.add(view.batch.batchId)
                      : _selected.remove(view.batch.batchId),
                ),
                title: Text(view.batch.name),
                subtitle: Text(view.locationPath),
              ),
          ],
          const SizedBox(height: 12),
          const Text('Строки на этикетке'),
          SwitchListTile(
            value: _showName,
            onChanged: (v) => setState(() => _showName = v),
            title: const Text('Показывать название'),
          ),
          SwitchListTile(
            value: _showYear,
            onChanged: (v) => setState(() => _showYear = v),
            title: const Text('Показывать год'),
          ),
          SwitchListTile(
            value: _showVolume,
            onChanged: (v) => setState(() => _showVolume = v),
            title: const Text('Показывать объём'),
          ),
          SwitchListTile(
            value: _showLocation,
            onChanged: (v) => setState(() => _showLocation = v),
            title: const Text('Показывать место'),
          ),
          SwitchListTile(
            value: _showAuthor,
            onChanged: (v) => setState(() => _showAuthor = v),
            title: const Text('Показывать автора'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                _preview(snapshot.batches, snapshot.member?.displayName),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Открыть preview PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _preview(List<BatchView> batches, String? author) async {
    final controller = ref.read(appControllerProvider.notifier);
    final chosen = batches
        .where((item) => _selected.contains(item.batch.batchId))
        .toList();
    if (!_unlinked && chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одну партию.')),
      );
      return;
    }
    final labels = <PrintableLabel>[];
    if (_unlinked) {
      final count = switch (_template) {
        LabelTemplate.large => 1,
        LabelTemplate.medium => 8,
        LabelTemplate.small => 24,
      };
      for (var index = 0; index < count; index++) {
        labels.add(PrintableLabel(qr: await controller.generateUnlinkedQr()));
      }
    } else {
      for (final item in chosen) {
        labels.add(
          PrintableLabel(
            qr: await controller.generateQrForBatch(item.batch.batchId),
            name: _showName ? item.batch.name : null,
            year: _showYear && item.batch.harvestYear != null
                ? '${item.batch.harvestYear}'
                : null,
            volume: _showVolume ? _volume(item.batch.jarVolumeMl) : null,
            location: _showLocation ? item.locationPath : null,
            author: _showAuthor ? author : null,
          ),
        );
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Preview PDF')),
          body: PdfPreview(
            build: (_) => LabelPdf.build(labels: labels, template: _template),
            canChangePageFormat: false,
            canChangeOrientation: false,
            allowPrinting: true,
            allowSharing: true,
          ),
        ),
      ),
    );
  }
}

String _volume(int? ml) => ml == null ? 'Объём не указан' : '$ml мл';
