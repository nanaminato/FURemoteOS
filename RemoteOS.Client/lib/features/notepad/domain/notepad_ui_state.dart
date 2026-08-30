// Immutable presentation state for the Notepad feature.
//
// Localization rules (AGENTS.md §23.1):
//   * View is the only place that calls .tr(namedArgs: ...).
//   * Status / ViewModel carry only raw data + a stable semantic key +
//     a `Map<String, String>` of named placeholders (never positional {0}).

import 'package:flutter/foundation.dart';

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
    required this.statusNamedArgs,
    required this.text,
  });

  factory NotepadUiState.initial({
    String? defaultEncodingName,
    String? encodingName,
  }) {
    final defEnc =
        (defaultEncodingName != null && defaultEncodingName.isNotEmpty)
            ? defaultEncodingName
            : 'UTF-8';
    return NotepadUiState(
      currentPath: null,
      encodingName: (encodingName != null && encodingName.isNotEmpty)
          ? encodingName
          : defEnc,
      defaultEncodingName: defEnc,
      fontSize: 14,
      isDirty: false,
      isLoading: false,
      statusKey: 'notepad.status.ready',
      statusNamedArgs: const <String, String>{},
      text: '',
    );
  }

  final String? currentPath;
  final String encodingName;
  final String defaultEncodingName;
  final double fontSize;
  final bool isDirty;
  final bool isLoading;
  final String statusKey;

  /// Named placeholders passed to `statusKey.tr(namedArgs: ...)` in the View.
  ///
  /// Allowed keys (keep this list small and stable so all three locale
  /// JSONs stay in sync):
  ///   * `file`    – base file name displayed in opened / saved messages
  ///   * `encoding`– friendly encoding name, e.g. "UTF-8"
  ///   * `error`   – user-readable error text for open_failed / save_failed
  ///
  /// An empty map means the localized string takes no arguments.
  final Map<String, String> statusNamedArgs;

  final String text;

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

  NotepadUiState copyWith({
    String? currentPath,
    bool clearCurrentPath = false,
    String? encodingName,
    String? defaultEncodingName,
    double? fontSize,
    bool? isDirty,
    bool? isLoading,
    String? statusKey,
    Map<String, String>? statusNamedArgs,
    String? text,
  }) {
    return NotepadUiState(
      currentPath: clearCurrentPath ? null : (currentPath ?? this.currentPath),
      encodingName: encodingName ?? this.encodingName,
      defaultEncodingName: defaultEncodingName ?? this.defaultEncodingName,
      fontSize: fontSize ?? this.fontSize,
      isDirty: isDirty ?? this.isDirty,
      isLoading: isLoading ?? this.isLoading,
      statusKey: statusKey ?? this.statusKey,
      statusNamedArgs: statusNamedArgs ?? this.statusNamedArgs,
      text: text ?? this.text,
    );
  }
}