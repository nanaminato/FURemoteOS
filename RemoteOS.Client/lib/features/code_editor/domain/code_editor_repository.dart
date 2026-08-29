import 'code_editor_models.dart';

/// Code editor's file boundary. It combines text I/O with the folder tree
/// used by its workspace sidebar, without exposing file-service DTOs.
abstract interface class CodeEditorRepository {
  Future<String?> readText(String path, String encodingName);
  Future<void> writeText(String path, String text, String encodingName);
  Future<List<CodeEditorFolderNode>> listFolder(String path);
}
