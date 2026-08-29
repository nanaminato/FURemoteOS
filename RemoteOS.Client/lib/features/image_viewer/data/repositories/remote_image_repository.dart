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
}
