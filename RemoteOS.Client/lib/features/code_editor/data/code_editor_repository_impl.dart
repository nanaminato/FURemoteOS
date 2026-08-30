import '../../files/data/remote_file_api.dart';
import '../../files/text_file_encodings.dart';
import '../domain/code_editor_models.dart';
import '../domain/code_editor_repository.dart';

class RemoteCodeEditorRepository implements CodeEditorRepository {
  RemoteCodeEditorRepository({
    required RemoteFileApi files,
  }) : _files = files;

  final RemoteFileApi _files;

  @override
  Future<String?> readText(String path, String encodingName) =>
      _readText(path, encodingName);

  @override
  Future<void> writeText(String path, String text, String encodingName) async {
    final bytes = await TextFileEncodings.encode(text, encodingName);
    await _files.writeBytes(path, bytes);
  }

  @override
  Future<List<CodeEditorFolderNode>> listFolder(String path) async {
    final entries = await _files.list(path);
    return entries
        .map((entry) => CodeEditorFolderNode(
              name: entry.name,
              path: entry.path,
              isDirectory: entry.isDirectory,
            ))
        .toList(growable: false);
  }

  Future<String?> _readText(String path, String encodingName) async {
    final bytes = await _files.readBytes(path);
    if (bytes.isEmpty) return null;
    return await TextFileEncodings.decode(bytes, encodingName);
  }
}
