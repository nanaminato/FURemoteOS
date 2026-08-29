import 'package:flutter/foundation.dart';

/// Window-local document state. Remote content remains on the server until a
/// user explicitly invokes save; this mirrors the Avalonia editor tabs.
@immutable
class CodeEditorDocument {
  const CodeEditorDocument({
    required this.id,
    required this.path,
    required this.text,
    required this.encodingName,
    required this.untitledName,
    this.isDirty = false,
  });

  final String id;
  final String? path;
  final String text;
  final String encodingName;
  final String untitledName;
  final bool isDirty;

  String get displayName {
    final value = path;
    if (value == null || value.isEmpty) return untitledName;
    final segments = value.replaceAll('\\', '/').split('/');
    return segments.lastWhere((segment) => segment.isNotEmpty,
        orElse: () => untitledName);
  }

  CodeEditorDocument copyWith({
    String? path,
    bool clearPath = false,
    String? text,
    String? encodingName,
    bool? isDirty,
  }) =>
      CodeEditorDocument(
        id: id,
        path: clearPath ? null : (path ?? this.path),
        text: text ?? this.text,
        encodingName: encodingName ?? this.encodingName,
        untitledName: untitledName,
        isDirty: isDirty ?? this.isDirty,
      );
}

/// Lazily populated workspace folder node. This is domain data rather than a
/// Flutter tree-widget model, so the ViewModel remains rendering-independent.
@immutable
class CodeEditorFolderNode {
  const CodeEditorFolderNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
    this.isExpanded = false,
    this.isLoading = false,
    this.isLoaded = false,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final List<CodeEditorFolderNode> children;
  final bool isExpanded;
  final bool isLoading;
  final bool isLoaded;

  CodeEditorFolderNode copyWith({
    List<CodeEditorFolderNode>? children,
    bool? isExpanded,
    bool? isLoading,
    bool? isLoaded,
  }) =>
      CodeEditorFolderNode(
        name: name,
        path: path,
        isDirectory: isDirectory,
        children: children ?? this.children,
        isExpanded: isExpanded ?? this.isExpanded,
        isLoading: isLoading ?? this.isLoading,
        isLoaded: isLoaded ?? this.isLoaded,
      );
}

enum CodeEditorSidebar { explorer, openEditors }
