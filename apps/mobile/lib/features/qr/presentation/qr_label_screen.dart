import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart' hide QrCode;

import '../../../core/ui/banochki_theme.dart';
import '../domain/qr_models.dart';
import '../domain/label_pdf.dart';

final class QrLabelScreen extends StatelessWidget {
  const QrLabelScreen({
    required this.qr,
    required this.title,
    this.subtitle,
    super.key,
  });

  final QrCode qr;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QR-этикетка')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(BanochkiSpacing.lg),
            children: [
              Semantics(
                label: 'QR-код. Короткий номер ${qr.shortCode}.',
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(
                    20,
                  ), // 4-module quiet zone at label scale.
                  child: QrImageView(
                    data: qr.payload,
                    size: 280,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: BanochkiSpacing.lg),
              Text(
                qr.shortCode,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: BanochkiSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (subtitle != null)
                Text(subtitle!, textAlign: TextAlign.center),
              const SizedBox(height: BanochkiSpacing.xl),
              FilledButton.icon(
                onPressed: () => _sharePdf(context),
                icon: const Icon(Icons.ios_share),
                label: const Text('Печать или поделиться PDF'),
              ),
              const SizedBox(height: BanochkiSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  final png = await pngBytes();
                  if (!context.mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('PNG QR-кода'),
                      content: Image.memory(png),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Закрыть'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.image_outlined),
                label: const Text('Проверить PNG'),
              ),
              const SizedBox(height: BanochkiSpacing.md),
              const Text(
                'Для печати QR должен быть не меньше 25 мм. Код чёрно-белый, без декоративных вставок.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<Uint8List> pngBytes() async {
    final image = await QrPainter(
      data: qr.payload,
      version: QrVersions.auto,
      gapless: false,
    ).toImageData(768);
    if (image == null) throw StateError('Не удалось подготовить PNG QR-кода.');
    return image.buffer.asUint8List();
  }

  Future<void> _sharePdf(BuildContext context) async {
    final bytes = await LabelPdf.build(
      labels: [PrintableLabel(qr: qr, name: title, location: subtitle)],
      template: LabelTemplate.large,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'banochki-${qr.shortCode}.pdf',
    );
  }
}
