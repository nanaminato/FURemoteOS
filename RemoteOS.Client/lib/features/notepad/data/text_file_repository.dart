// Repository responsible for reading and writing remote text files through
// the RemoteOS file service (ARCHITECTURE.md § 11).
//
// The repository:
//   * owns encoding conversions via [TextFileEncodings];
//   * normalizes I/O errors into `RemoteOsFailure`-style messages (kept as
//     plain strings in this MVP because the feature already reuses the
//     existing localization keys for `notepad.status.open_failed` /
//     `notepad.status.save_failed`);
//   * exposes a simple Future-based interface (no caching — Notepad always
//     reads the latest bytes from the server).

import '../../files/data/remote_file_api.dart';
import '../../files/text_file_encodings.dart';

abstract class TextFileRepository {
  /// Reads and decodes a remote text file.
  ///
  /// Returns the decoded text, or `null` when the server reports an empty /
  /// missing byte payload (mirrors Avalonia's `bytes is null` branch).
  Future<String?> readText(String path, String encodingName);

  /// Encodes and writes text to a remote path.
  Future<void> writeText(String path, String text, String encodingName);
}

class RemoteTextFileRepository implements TextFileRepository {
  RemoteTextFileRepository(this._api);

  final RemoteFileApi _api;

  @override
  Future<String?> readText(String path, String encodingName) async {
    final bytes = await _api.readBytes(path);
    if (bytes.isEmpty) return null;
    return TextFileEncodings.decode(bytes, encodingName);
  }

  @override
  Future<void> writeText(String path, String text, String encodingName) {
    final bytes = TextFileEncodings.encode(text, encodingName);
    return _api.writeBytes(path, bytes);
  }
}
