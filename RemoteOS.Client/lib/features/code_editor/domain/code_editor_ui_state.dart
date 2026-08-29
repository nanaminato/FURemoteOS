// Code Editor UI state.
//
// The text buffer itself lives in Flutter's [TextEditingController] (a
// presentation concern per ARCHITECTURE.md § 8); state here tracks chrome
// metadata, editor preferences, and asynchronous I/O status.

import 'package:flutter/foundation.dart';

@immutable
class CodeEditorUiState {
  const CodeEditorUiState({
    required this.fileName,
    required this.remotePath,
    required this.showExplorer,
    required this.wordWrap,
    required this.fontSize,
    required this.searchText,
    required this.isDirty,
    required this.isLoading,
    required this.errorMessage,
    required this.documentText,
  });

  factory CodeEditorUiState.initial({
    String? remotePath,
    String? fileName,
    String initialDocument = '',
  }) =>
      CodeEditorUiState(
        fileName: fileName ?? 'welcome.dart',
        remotePath: remotePath,
        showExplorer: true,
        wordWrap: true,
        fontSize: 14,
        searchText: '',
        isDirty: false,
        isLoading: false,
        errorMessage: null,
        documentText: initialDocument,
      );

  final String fileName;
  final String? remotePath;
  final bool showExplorer;
  final bool wordWrap;
  final double fontSize;
  final String searchText;
  final bool isDirty;
  final bool isLoading;
  final String? errorMessage;
  final String documentText;

  CodeEditorUiState copyWith({
    String? fileName,
    String? remotePath,
    bool? showExplorer,
    bool? wordWrap,
    double? fontSize,
    String? searchText,
    bool? isDirty,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? documentText,
  }) {
    return CodeEditorUiState(
      fileName: fileName ?? this.fileName,
      remotePath: remotePath ?? this.remotePath,
      showExplorer: showExplorer ?? this.showExplorer,
      wordWrap: wordWrap ?? this.wordWrap,
      fontSize: fontSize ?? this.fontSize,
      searchText: searchText ?? this.searchText,
      isDirty: isDirty ?? this.isDirty,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      documentText: documentText ?? this.documentText,
    );
  }
}
