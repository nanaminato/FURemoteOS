import '../../../core/network/remoteos_api.dart';

/// Mirrors `RemoteOS.Protocol.Files.FileSystemEntryDto`.
class RemoteFileEntry {
  const RemoteFileEntry(
      {required this.name,
      required this.path,
      required this.isDirectory,
      this.size,
      this.lastWriteTime});
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? lastWriteTime;

  factory RemoteFileEntry.fromJson(Map<String, dynamic> json) =>
      RemoteFileEntry(
        name: (json['name'] ?? '').toString(),
        path: (json['path'] ?? '').toString(),
        isDirectory: json['isDirectory'] == true ||
            json['entryType']?.toString().toLowerCase() == 'directory',
        size: (json['size'] as num?)?.toInt(),
        lastWriteTime: DateTime.tryParse(
            (json['lastWriteTime'] ?? json['modifiedAt'] ?? '').toString()),
      );
}

/// Mirrors the server's `SpecialLocationDto` and lets clients avoid assuming a
/// Linux home directory (the original desktop client supports Windows too).
class RemoteSpecialLocation {
  const RemoteSpecialLocation({required this.name, required this.path});
  final String name;
  final String path;

  factory RemoteSpecialLocation.fromJson(Map<String, dynamic> json) =>
      RemoteSpecialLocation(
        name: (json['name'] ?? json['displayName'] ?? json['kind'] ?? '')
            .toString(),
        path: (json['path'] ?? '').toString(),
      );
}

/// Typed client for `/api/v1/files`, retaining the old desktop protocol paths.
class RemoteFileApi {
  RemoteFileApi(this._api);
  final RemoteOsApi _api;

  Future<List<RemoteFileEntry>> list(String path) async {
    final body =
        await _api.getJson('/api/v1/files/list', query: {'path': path});
    final values = body is List
        ? body
        : body is Map && body['entries'] is List
            ? body['entries'] as List
            : const [];
    return values
        .whereType<Map>()
        .map(
            (item) => RemoteFileEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<RemoteSpecialLocation>> specialLocations() async {
    final body = await _api.getJson('/api/v1/files/special');
    final values = body is List
        ? body
        : body is Map && body['locations'] is List
            ? body['locations'] as List
            : const [];
    return values
        .whereType<Map>()
        .map((item) =>
            RemoteSpecialLocation.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.path.isNotEmpty)
        .toList();
  }

  Future<void> createDirectory(String path) =>
      _api.sendJson('POST', '/api/v1/files/directory', query: {'path': path});
  Future<void> delete(String path) =>
      _api.sendJson('DELETE', '/api/v1/files', query: {'path': path});
  Future<void> rename(String sourcePath, String name) =>
      _api.sendJson('POST', '/api/v1/files/rename',
          body: {'path': sourcePath, 'newName': name});
  Future<void> copy(String sourcePath, String targetDirectoryPath) =>
      _api.sendJson('POST', '/api/v1/files/copy', body: {
        'sourcePath': sourcePath,
        'targetDirectoryPath': targetDirectoryPath
      });
  Future<void> move(String sourcePath, String targetDirectoryPath) =>
      _api.sendJson('POST', '/api/v1/files/move', body: {
        'sourcePath': sourcePath,
        'targetDirectoryPath': targetDirectoryPath
      });
}
