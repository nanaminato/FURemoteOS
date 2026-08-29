// Notepad domain models (ARCHITECTURE.md § 14 — JSON→DTO→Repository→Domain).
//
// Types here describe stable domain concepts used by the repository and the
// ViewModel.  They intentionally have zero Flutter UI imports.

import 'package:flutter/services.dart';

/// Snapshot used for undo/redo history.  A snapshot records the textual
/// content plus the editing cursor/selection.
@immutable
class DocSnapshot {
  const DocSnapshot({required this.text, required this.selection});

  final String text;
  final TextSelection selection;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocSnapshot &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          selection == other.selection;

  @override
  int get hashCode => Object.hash(text, selection);
}

/// Supported file name extensions opened by the built-in text editor.
///
/// Mirrors Avalonia's `Client.Apps.Notepad.NotepadApp.SupportedExtensions`.
const List<String> notepadSupportedExtensions = <String>[
  '.txt', '.text', '.md', '.markdown', '.mdx', '.rst', '.adoc', '.asciidoc',
  '.log', '.nfo', '.csv', '.tsv', '.tab', '.ini', '.cfg', '.conf', '.config',
  '.properties', '.yaml', '.yml', '.toml', '.xml', '.xsd', '.xsl', '.xslt',
  '.json', '.jsonc', '.json5', '.html', '.htm', '.xhtml', '.css', '.scss',
  '.sass', '.less', '.tex', '.bib', '.srt', '.vtt', '.ics', '.vcf', '.diff',
  '.patch', '.asc', '.pem', '.crt', '.cer', '.pub',
];

/// Font sizes offered by the Notepad settings dialog.
const List<double> notepadFontSizes = <double>[12, 13, 14, 16, 18, 20];

/// Result type returned by the "encoding action" dialog.
enum EncodingDialogAction {
  /// Reopen the current file with the chosen encoding.
  reopen,

  /// Re-encode and save the current file with the chosen encoding.
  save,
}

/// Cursor position information derived from the editing selection.
@immutable
class CursorPosition {
  const CursorPosition({
    required this.line,
    required this.column,
    required this.offset,
  });

  final int line;
  final int column;
  final int offset;

  static const CursorPosition initial =
      CursorPosition(line: 1, column: 1, offset: 0);
}

/// Find/replace options exposed as simple named flags (Avalonia keeps these
/// as properties on the view code-behind).
@immutable
class FindOptions {
  const FindOptions({
    required this.caseSensitive,
    required this.useRegex,
  });

  final bool caseSensitive;
  final bool useRegex;

  FindOptions copyWith({
    bool? caseSensitive,
    bool? useRegex,
  }) {
    return FindOptions(
      caseSensitive: caseSensitive ?? this.caseSensitive,
      useRegex: useRegex ?? this.useRegex,
    );
  }
}
