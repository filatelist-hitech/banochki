import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_controller.dart';
import '../../../core/media/batch_photo_storage.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/batch_categories.dart';
import '../../inventory/domain/models.dart';

final class BatchPhotoGallery extends ConsumerStatefulWidget {
  const BatchPhotoGallery({
    required this.batchId,
    required this.batchName,
    required this.category,
    super.key,
  });

  final String batchId;
  final String batchName;
  final String category;

  @override
  ConsumerState<BatchPhotoGallery> createState() => _BatchPhotoGalleryState();
}

final class _BatchPhotoGalleryState extends ConsumerState<BatchPhotoGallery> {
  final _picker = ImagePicker();
  final _pageController = PageController();
  late Future<List<BatchPhoto>> _photos;
  var _saving = false;
  var _page = 0;

  @override
  void initState() {
    super.initState();
    _photos = _load();
  }

  Future<List<BatchPhoto>> _load() =>
      ref.read(appControllerProvider.notifier).listBatchPhotos(widget.batchId);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final localPath = await persistBatchPhoto(picked);
      await ref
          .read(appControllerProvider.notifier)
          .addBatchPhoto(batchId: widget.batchId, localPath: localPath);
      if (mounted) {
        setState(() {
          _photos = _load();
          _page = 0;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось добавить фото: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Выбрать из галереи'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Снять камерой'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<BatchPhoto>>(
    future: _photos,
    builder: (context, snapshot) {
      final photos = snapshot.data ?? const <BatchPhoto>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 188,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(BanochkiRadius.card),
            ),
            clipBehavior: Clip.antiAlias,
            child: photos.isEmpty
                ? Semantics(
                    label: 'Фото партии не добавлено',
                    child: Icon(
                      BatchCategories.iconFor(
                        name: widget.batchName,
                        category: widget.category,
                      ),
                      size: 72,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  )
                : Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: photos.length,
                        onPageChanged: (value) => setState(() => _page = value),
                        itemBuilder: (context, index) => Image.file(
                          File(photos[index].localPath),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined, size: 56),
                        ),
                      ),
                      if (photos.length > 1)
                        Positioned(
                          right: BanochkiSpacing.sm,
                          bottom: BanochkiSpacing.sm,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: BanochkiSpacing.sm,
                                vertical: BanochkiSpacing.xxs,
                              ),
                              child: Text(
                                '${_page + 1} / ${photos.length}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: BanochkiSpacing.sm),
          OutlinedButton.icon(
            onPressed: _saving ? null : _chooseSource,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(photos.isEmpty ? 'Добавить фото' : 'Добавить ещё фото'),
          ),
        ],
      );
    },
  );
}
