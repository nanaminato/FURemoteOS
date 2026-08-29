// File Manager domain models.
//
// Domain types mirror the Avalonia `FileSystemEntryDto` / `TreeNodeModel` /
// `ExplorerPickerOptions` contracts so the repository + ViewModel can talk
// purely in domain terms (never raw DTOs, never widgets).

import 'package:flutter/material.dart';

/// Type of a listed entry.  Mirrors `FileSystemEntryDto.IsDirectory`.
enum FileItemKind { folder, file }

@immutable
class FileItem {
  const FileItem({
    required this.name,
    required this.path,
    required this.kind,
    required this.sizeText,
    required this.modifiedText,
    required this.icon,
    this.sizeBytes,
    this.modified,
    this.mimeType,
  });

  final String name;
  final String path;
  final FileItemKind kind;
  final String sizeText;
  final String modifiedText;
  final IconData icon;
  final int? sizeBytes;
  final DateTime? modified;
  final String? mimeType;

  bool get isFolder => kind == FileItemKind.folder;
}

/// Navigation side-rail tree node kind (matches Avalonia `TreeNodeIconKind`).
enum TreeNodeKind {
  home,
  desktop,
  documents,
  downloads,
  pictures,
  music,
  videos,
  folder,
  drive,
  computer,
  network,
}

@immutable
class TreeNodeItem {
  const TreeNodeItem({
    required this.name,
    required this.path,
    required this.kind,
    this.children = const [],
    this.isExpanded = false,
    this.isLoading = false,
    this.childrenLoaded = false,
    this.hasDummyChild = false,
  });

  final String name;
  final String? path;
  final TreeNodeKind kind;
  final List<TreeNodeItem> children;
  final bool isExpanded;
  final bool isLoading;
  final bool childrenLoaded;
  final bool hasDummyChild;

  bool get isDrive => kind == TreeNodeKind.drive;
  bool get isComputer => kind == TreeNodeKind.computer;
  bool get isNetwork => kind == TreeNodeKind.network;
  bool get isPlaceholder => hasDummyChild && !childrenLoaded;

  TreeNodeItem copyWith({
    String? name,
    String? path,
    bool clearPath = false,
    TreeNodeKind? kind,
    List<TreeNodeItem>? children,
    bool? isExpanded,
    bool? isLoading,
    bool? childrenLoaded,
    bool? hasDummyChild,
  }) {
    return TreeNodeItem(
      name: name ?? this.name,
      path: clearPath ? null : (path ?? this.path),
      kind: kind ?? this.kind,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
      isLoading: isLoading ?? this.isLoading,
      childrenLoaded: childrenLoaded ?? this.childrenLoaded,
      hasDummyChild: hasDummyChild ?? this.hasDummyChild,
    );
  }
}

/// Re-exported picker primitives from the legacy location so the new
/// feature module does not import `apps/explorer/explorer_picker.dart`.  The
/// concrete enum/classes are still re-used from the legacy file because
/// other modules already depend on them publicly.

/// Open-with candidate shown in the Explorer dialog.
@immutable
class OpenWithCandidate {
  const OpenWithCandidate(this.appId, this.label, this.icon);
  final String appId;
  final String label;
  final IconData icon;
}

@immutable
class OpenWithChoice {
  const OpenWithChoice(this.candidate, this.always);
  final OpenWithCandidate candidate;
  final bool always;
}
