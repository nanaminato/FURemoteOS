import 'package:flutter/foundation.dart';

/// Two-step encoding chooser result (mirrors Avalonia
/// `EncodingDialogAction`); kept local to this feature so the code editor
/// never imports the notepad feature.
enum CodeEditorEncodingAction { reopen, save }

/// Window-local document state. Remote content remains on the server until a
/// user explicitly invokes save; this mirrors the Avalonia editor tabs.
///
/// Localization (AGENTS.md §23.1 Rule B): the model carries the raw
/// [untitledSequence] number only. The View maps it to
/// `code_editor.document.untitled_number` so untitled names localize correctly.
@immutable
class CodeEditorDocument {
  const CodeEditorDocument({
    required this.id,
    required this.path,
    required this.text,
    required this.encodingName,
    required this.untitledSequence,
    this.isDirty = false,
  });

  final String id;
  final String? path;
  final String text;
  final String encodingName;
  final int untitledSequence;
  final bool isDirty;

  /// Base file name when a path is set. For untitled documents this is empty;
  /// the View localizes `code_editor.document.untitled_number` using
  /// [untitledSequence] instead.
  String get displayName {
    final value = path;
    if (value == null || value.isEmpty) return '';
    final segments = value.replaceAll('\\', '/').split('/');
    return segments.lastWhere((segment) => segment.isNotEmpty,
        orElse: () => '');
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
        untitledSequence: untitledSequence,
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