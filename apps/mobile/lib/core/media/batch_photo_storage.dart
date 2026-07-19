import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String> persistBatchPhoto(XFile source) async {
  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory(path.join(documents.path, 'batch_photos'));
  await directory.create(recursive: true);
  final extension = path.extension(source.path).toLowerCase();
  final safeExtension = switch (extension) {
    '.jpg' || '.jpeg' || '.png' || '.heic' => extension,
    _ => '.jpg',
  };
  final destination = File(
    path.join(
      directory.path,
      'batch-${DateTime.now().microsecondsSinceEpoch}$safeExtension',
    ),
  );
  await File(source.path).copy(destination.path);
  return destination.path;
}
