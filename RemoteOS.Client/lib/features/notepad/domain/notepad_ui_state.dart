// Immutable presentation state for the Notepad feature.
//
// A single `NotepadUiState` value is broadcast from [NotepadViewModel] to the
// presentation layer via `ValueNotifier<NotepadUiState>`.  The View only
// rebuilds in response to state changes; transient UI focus, scroll offsets
// and Flutter controllers remain owned by the View.

import 'package:flutter/foundation.dart';

import 'notepad_models.dart';

@immutable
class NotepadUiState {
  const NotepadUiState({
    required this.currentPath,
    required this.encodingName,
    required this.defaultEncodingName,
    required this.fontSize,
    required this.isDirty,
    required this.isLoading,
    required this.statusKey,
    required this.statusArgs,
    required this.wordWrap,
    required this.showLineNumbers,
    required this.cursor,
    required this.text,
    required this.showFindReplace,
    required this.isReplaceMode,
    required this.findKey,
    required this.findArgs,
    required this.findOptions,
  });

  factory NotepadUiState.initial({
    String defaultEncodingName = 'UTF-8',
  }) {
    return NotepadUiState(
      currentPath: null,
      encodingName: defaultEncodingName,
      defaultEncodingName: defaultEncodingName,
      fontSize: 14,
      isDirty: false,
      isLoading: false,
      statusKey: 'notepad.status.ready',
      statusArgs: const {},
      wordWrap: true,
      showLineNumbers: true,
      cursor: CursorPosition.initial,
      text: '',
      showFindReplace: false,
      isReplaceMode: false,
      findKey: '',
      findArgs: const {},
      findOptions: const FindOptions(caseSensitive: false, useRegex: false),
    );
  }

  // ---- Document properties ----

  final String? currentPath;
  final String encodingName;
  final String defaultEncodingName;
  final double fontSize;
  final bool isDirty;
  final bool isLoading;
  final String statusKey;
  final Map<String, String> statusArgs;

  // ---- Editor view preferences ----

  final bool wordWrap;
  final bool showLineNumbers;

  // ---- Cursor / text (presentation projection) ----

  final CursorPosition cursor;
  final String text;

  // ---- Find & replace ----

  final bool showFindReplace;
  final bool isReplaceMode;
  final String findKey;
  final Map<String, String> findArgs;
  final FindOptions findOptions;

  // ---- Derived helpers ----

  int get charCount => text.length;
  int get lineCount {
    if (text.isEmpty) return 1;
    return '\n'.allMatches(text).length + 1;
  }

  bool get hasOpenFile => currentPath != null && currentPath!.isNotEmpty;

  String get documentName {
    final path = currentPath;
    if (path == null || path.isEmpty) return '';
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }

  // ---- Copy-with ----

  NotepadUiState copyWith({
    String? currentPath,
    bool clearCurrentPath = false,
    String? encodingName,
    String? defaultEncodingName,
    double? fontSize,
    bool? isDirty,
    bool? isLoading,
    String? statusKey,
    Map<String, String>? statusArgs,
    bool? wordWrap,
    bool? showLineNumbers,
    CursorPosition? cursor,
    String? text,
    bool? showFindReplace,
    bool? isReplaceMode,
    String? findKey,
    Map<String, String>? findArgs,
    FindOptions? findOptions,
  }) {
    return NotepadUiState(
      currentPath: clearCurrentPath ? null : (currentPath ?? this.currentPath),
      encodingName: encodingName ?? this.encodingName,
      defaultEncodingName: defaultEncodingName ?? this.defaultEncodingName,
      fontSize: fontSize ?? this.fontSize,
      isDirty: isDirty ?? this.isDirty,
      isLoading: isLoading ?? this.isLoading,
      statusKey: statusKey ?? this.statusKey,
      statusArgs: statusArgs ?? this.statusArgs,
      wordWrap: wordWrap ?? this.wordWrap,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      cursor: cursor ?? this.cursor,
      text: text ?? this.text,
      showFindReplace: showFindReplace ?? this.showFindReplace,
      isReplaceMode: isReplaceMode ?? this.isReplaceMode,
      findKey: findKey ?? this.findKey,
      findArgs: findArgs ?? this.findArgs,
      findOptions: findOptions ?? this.findOptions,
    );
  }
}
