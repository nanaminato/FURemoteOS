// Remote Image Repository implementation — delegates byte reads to the
// existing RemoteFileApi service shared with File Manager.

import 'dart:typed_data';

import '../../../files/data/remote_file_api.dart';
import '../../domain/image_repository.dart';

class RemoteImageRepository implements ImageRepository {
  RemoteImageRepository(this._files);
  final RemoteFileApi _files;

  @override
  Future<Uint8List> readBytes(String remotePath) async {
    final bytes = await _files.readBytes(remotePath);
    return Uint8List.fromList(bytes);
  }

  @override
  Future<List<ImageFile>> listImages(String directoryPath) async {
    final entries = await _files.list(directoryPath);
    final images = entries
        .where((entry) => !entry.isDirectory && _isSupportedImage(entry.name))
        .map((entry) => ImageFile(name: entry.name, path: entry.path))
        .toList()
      ..sort((left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()));
    return images;
  }

  static bool _isSupportedImage(String name) {
    final normalized = name.toLowerCase();
    return imageViewerExtensions.any(normalized.endsWith);
  }
}
