import 'package:flutter/foundation.dart';

import 'code_editor_models.dart';

@immutable
class CodeEditorUiState {
  const CodeEditorUiState({
    required this.documents,
    required this.activeDocumentId,
    required this.workspaceRoots,
    required this.sidebar,
    required this.isSidebarVisible,
    required this.wordWrap,
    required this.fontSize,
    required this.defaultEncodingName,
    required this.statusKey,
    required this.statusArgs,
    required this.isLoading,
  });

  factory CodeEditorUiState.initial({String defaultEncodingName = 'UTF-8'}) =>
      CodeEditorUiState(
        documents: const [],
        activeDocumentId: null,
        workspaceRoots: const [],
        sidebar: CodeEditorSidebar.explorer,
        isSidebarVisible: true,
        wordWrap: false,
        fontSize: 14,
        defaultEncodingName: defaultEncodingName,
        statusKey: 'code_editor.status.ready',
        statusArgs: const {},
        isLoading: false,
      );

  final List<CodeEditorDocument> documents;
  final String? activeDocumentId;
  final List<CodeEditorFolderNode> workspaceRoots;
  final CodeEditorSidebar sidebar;
  final bool isSidebarVisible;
  final bool wordWrap;
  final double fontSize;
  final String defaultEncodingName;
  final String statusKey;
  final Map<String, String> statusArgs;
  final bool isLoading;

  CodeEditorDocument? get activeDocument {
    final id = activeDocumentId;
    if (id == null) return null;
    for (final document in documents) {
      if (document.id == id) return document;
    }
    return null;
  }

  bool get hasOpenFile => activeDocument?.path?.isNotEmpty == true;
  int get lineCount {
    final text = activeDocument?.text ?? '';
    return text.isEmpty ? 1 : '\n'.allMatches(text).length + 1;
  }

  int get characterCount => activeDocument?.text.length ?? 0;

  CodeEditorUiState copyWith({
    List<CodeEditorDocument>? documents,
    String? activeDocumentId,
    bool clearActiveDocument = false,
    List<CodeEditorFolderNode>? workspaceRoots,
    CodeEditorSidebar? sidebar,
    bool? isSidebarVisible,
    bool? wordWrap,
    double? fontSize,
    String? defaultEncodingName,
    String? statusKey,
    Map<String, String>? statusArgs,
    bool? isLoading,
  }) {
    return CodeEditorUiState(
      documents: documents ?? this.documents,
      activeDocumentId: clearActiveDocument
          ? null
          : (activeDocumentId ?? this.activeDocumentId),
      workspaceRoots: workspaceRoots ?? this.workspaceRoots,
      sidebar: sidebar ?? this.sidebar,
      isSidebarVisible: isSidebarVisible ?? this.isSidebarVisible,
      wordWrap: wordWrap ?? this.wordWrap,
      fontSize: fontSize ?? this.fontSize,
      defaultEncodingName: defaultEncodingName ?? this.defaultEncodingName,
      statusKey: statusKey ?? this.statusKey,
      statusArgs: statusArgs ?? this.statusArgs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
