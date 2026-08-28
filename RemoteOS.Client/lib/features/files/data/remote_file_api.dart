import 'dart:io';

import '../../../core/network/remoteos_api.dart';

/// Mirrors `RemoteOS.Protocol.Files.FileSystemEntryDto`.
class RemoteFileEntry {
  const RemoteFileEntry(
      {required this.name,
      required this.path,
      required this.isDirectory,
      this.size,
      this.lastWriteTime,
      this.mimeType});
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? lastWriteTime;
  final String? mimeType;

  factory RemoteFileEntry.fromJson(Map<String, dynamic> json) =>
      RemoteFileEntry(
        name: (json['name'] ?? '').toString(),
        path: (json['path'] ?? '').toString(),
        isDirectory: json['isDirectory'] == true ||
            json['entryType']?.toString().toLowerCase() == 'directory' ||
            json['type']?.toString().toLowerCase() == 'directory',
        size: (json['size'] as num?)?.toInt(),
        lastWriteTime: DateTime.tryParse(
            (json['lastWriteTime'] ?? json['modifiedAt'] ?? '').toString()),
        mimeType: json['mimeType']?.toString(),
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

/// Mirrors `DriveDto`; all paths originate at the remote host, so Windows
/// drive letters and Linux mount points work from either client platform.
class RemoteDrive {
  const RemoteDrive(
      {required this.name,
      required this.path,
      this.totalSize,
      required this.isReady});
  final String name;
  final String path;
  final int? totalSize;
  final bool isReady;

  factory RemoteDrive.fromJson(Map<String, dynamic> json) => RemoteDrive(
        name: (json['name'] ?? json['path'] ?? '').toString(),
        path: (json['path'] ?? '').toString(),
        totalSize: (json['totalSize'] as num?)?.toInt(),
        isReady: json['isReady'] != false,
      );
}

/// Typed client for `/api/v1/files`, retaining the old desktop protocol paths.
class RemoteFileApi {
  RemoteFileApi(this._api);
  final RemoteOsApi _api;

  Future<List<RemoteFileEntry>> list(String path) async {
    final body =
        await _api.getJson('/api/v1/files/list', query: {'path': path});
    if (body is List) return _entries(body);
    if (body is! Map) return const [];
    // `DirectoryDto` separates folders and files. The former Flutter port
    // looked only for `entries`, which is not part of the original contract.
    final directories =
        body['directories'] is List ? body['directories'] as List : const [];
    final files = body['files'] is List ? body['files'] as List : const [];
    if (directories.isNotEmpty || files.isNotEmpty) {
      return [
        ..._entries(directories, forceDirectory: true),
        ..._entries(files)
      ];
    }
    return _entries(
        body['entries'] is List ? body['entries'] as List : const []);
  }

  List<RemoteFileEntry> _entries(List values, {bool forceDirectory = false}) =>
      values.whereType<Map>().map((item) {
        final json = Map<String, dynamic>.from(item);
        if (forceDirectory) json['isDirectory'] = true;
        return RemoteFileEntry.fromJson(json);
      }).toList();

  Future<List<RemoteDrive>> drives() async {
    final body = await _api.getJson('/api/v1/files/drives');
    final values = body is List ? body : const [];
    return values
        .whereType<Map>()
        .map((item) => RemoteDrive.fromJson(Map<String, dynamic>.from(item)))
        .where((drive) => drive.path.isNotEmpty && drive.isReady)
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
          body: {'sourcePath': sourcePath, 'newName': name});
  Future<void> copy(String sourcePath, String targetDirectoryPath) =>
      _api.sendJson('POST', '/api/v1/files/copy', body: {
        'sourcePath': sourcePath,
        // The server contract calls this a destination path.  It accepts the
        // target directory for Explorer copy/paste operations.
        'destinationPath': targetDirectoryPath
      });
  Future<void> move(String sourcePath, String targetDirectoryPath) =>
      _api.sendJson('POST', '/api/v1/files/move', body: {
        'sourcePath': sourcePath,
        'destinationPath': targetDirectoryPath
      });

  Future<RemoteFileProperties?> properties(String path) async {
    final body =
        await _api.getJson('/api/v1/files/properties', query: {'path': path});
    return body is Map
        ? RemoteFileProperties.fromJson(Map<String, dynamic>.from(body))
        : null;
  }

  Future<void> upload(String targetDirectoryPath, File file) =>
      _api.sendFile('/api/v1/files/upload',
          file: file, query: {'path': targetDirectoryPath});

  Future<void> downloadToFile(String remotePath, File destination) async {
    final response = await _api
        .getStream('/api/v1/files/download', query: {'path': remotePath});
    await response.stream.pipe(destination.openWrite());
  }

  Future<List<int>> readBytes(String path) async {
    final response =
        await _api.getStream('/api/v1/files/content', query: {'path': path});
    return response.stream
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
  }

  /// Writes raw bytes to a remote file path. Mirrors
  /// `IFileService.WriteFileAsync` and `MapPut(FileApiRoutes.Content)` on the
  /// server; Notepad/Code editor save their encoded content through here.
  Future<void> writeBytes(String path, List<int> bytes) =>
      _api.sendBytes('PUT', '/api/v1/files/content',
          bytes: bytes, query: {'path': path});
}

/// The subset of `FilePropertiesDto` displayed by the Avalonia Explorer's
/// properties dialog.  Permission changes remain a separate server feature.
class RemoteFileProperties {
  const RemoteFileProperties({
    required this.path,
    required this.name,
    required this.type,
    this.size,
    this.created,
    this.modified,
    this.permissions,
    this.attributes,
  });

  final String path;
  final String name;
  final String type;
  final int? size;
  final DateTime? created;
  final DateTime? modified;
  final String? permissions;
  final String? attributes;

  factory RemoteFileProperties.fromJson(Map<String, dynamic> json) =>
      RemoteFileProperties(
        path: (json['path'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        size: (json['size'] as num?)?.toInt(),
        created: DateTime.tryParse((json['created'] ?? '').toString()),
        modified: DateTime.tryParse((json['modified'] ?? '').toString()),
        permissions: json['permissions']?.toString(),
        attributes: json['attributes']?.toString(),
      );
}
