import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'qr_models.dart';

enum LabelTemplate { large, medium, small }

final class PrintableLabel {
  const PrintableLabel({
    required this.qr,
    this.name,
    this.year,
    this.volume,
    this.location,
    this.author,
  });
  final QrCode qr;
  final String? name;
  final String? year;
  final String? volume;
  final String? location;
  final String? author;
}

final class LabelPdf {
  static Future<Uint8List> build({
    required List<PrintableLabel> labels,
    required LabelTemplate template,
  }) async {
    if (labels.isEmpty) {
      throw ArgumentError.value(
        labels,
        'labels',
        'Нужна хотя бы одна этикетка.',
      );
    }
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final doc = pw.Document();
    final size = switch (template) {
      LabelTemplate.large => 252.0,
      LabelTemplate.medium => 168.0,
      LabelTemplate.small => 112.0,
    };
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) => [
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final label in labels) _label(label, size)],
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _label(PrintableLabel label, double size) => pw.Container(
    width: size,
    height: size,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    child: pw.Column(
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: label.qr.payload,
          width: size * .62,
          height: size * .62,
        ),
        pw.Text(
          label.qr.shortCode,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        for (final line in [
          label.name,
          label.year,
          label.volume,
          label.location,
          label.author,
        ])
          if (line != null)
            pw.Text(
              line,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7),
            ),
      ],
    ),
  );
}
