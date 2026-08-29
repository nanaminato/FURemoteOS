// File Manager repository.
//
// The repository is the single owner of mapping from [RemoteFileApi] DTOs →
// domain [FileItem] / [TreeNodeItem] / [RemoteFileProperties].  It exposes
// simple Future-based I/O so the ViewModel doesn't need to know about HTTP,
// DTOs or byte formatting.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../files/data/remote_file_api.dart';
import '../domain/file_manager_models.dart';

abstract class FileManagerRepository {
  Future<List<FileItem>> listDirectory(String path);
  Future<List<RemoteSpecialLocation>> specialLocations();
  Future<List<RemoteDrive>> drives();

  Future<void> createDirectory(String path);
  Future<void> delete(String path);
  Future<void> rename(String sourcePath, String newName);
  Future<void> copy(String source, String targetDirectory);
  Future<void> move(String source, String targetDirectory);

  Future<RemoteFileProperties?> properties(String path);
  Future<List<int>> readBytes(String path);

  Future<void> upload(String targetDirectory, File file);
  Future<void> downloadToFile(String remotePath, File localFile);
}

class RemoteFileManagerRepository implements FileManagerRepository {
  RemoteFileManagerRepository(this._api);

  final RemoteFileApi _api;

  @override
  Future<List<FileItem>> listDirectory(String path) async {
    final entries = await _api.list(path);
    return entries.map(_toFileItem).toList(growable: false);
  }

  @override
  Future<List<RemoteSpecialLocation>> specialLocations() =>
      _api.specialLocations();

  @override
  Future<List<RemoteDrive>> drives() => _api.drives();

  @override
  Future<void> createDirectory(String path) => _api.createDirectory(path);

  @override
  Future<void> delete(String path) => _api.delete(path);

  @override
  Future<void> rename(String sourcePath, String newName) =>
      _api.rename(sourcePath, newName);

  @override
  Future<void> copy(String source, String targetDirectory) =>
      _api.copy(source, targetDirectory);

  @override
  Future<void> move(String source, String targetDirectory) =>
      _api.move(source, targetDirectory);

  @override
  Future<RemoteFileProperties?> properties(String path) =>
      _api.properties(path);

  @override
  Future<List<int>> readBytes(String path) => _api.readBytes(path);

  @override
  Future<void> upload(String targetDirectory, File file) =>
      _api.upload(targetDirectory, file);

  @override
  Future<void> downloadToFile(String remotePath, File localFile) =>
      _api.downloadToFile(remotePath, localFile);

  // ---- Mapping helpers ----

  static FileItem _toFileItem(RemoteFileEntry e) {
    final isDirectory = e.isDirectory;
    return FileItem(
      name: e.name,
      path: e.path,
      kind: isDirectory ? FileItemKind.folder : FileItemKind.file,
      sizeBytes: e.size,
      sizeText:
          isDirectory ? '—' : (e.size == null ? '—' : _formatBytes(e.size!)),
      modified: e.lastWriteTime,
      modifiedText: e.lastWriteTime == null
          ? '—'
          : e.lastWriteTime!.toLocal().toString().split('.').first,
      icon: isDirectory ? Icons.folder_rounded : Icons.description_outlined,
      mimeType: e.mimeType,
    );
  }

  static String _formatBytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
