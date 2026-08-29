// Image Viewer repository interface (ARCHITECTURE.md § 11).

import 'dart:typed_data';

/// A supported image file in the directory being viewed.
class ImageFile {
  const ImageFile({required this.name, required this.path});

  final String name;
  final String path;
}

/// Keep this aligned with Explorer's image open-with support. SVG is omitted
/// because Image.memory cannot decode it without a separate renderer.
const imageViewerExtensions = [
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.bmp',
  '.webp',
];

abstract interface class ImageRepository {
  Future<Uint8List> readBytes(String remotePath);

  /// Returns only image files that the viewer can render from [directoryPath].
  Future<List<ImageFile>> listImages(String directoryPath);
}
