// Notepad domain models.
// Kept minimal to match Avalonia: only extensions list, font sizes, and
// EncodingDialogAction (used by encoding dialogs + chooseEncodingCommand).


/// Supported file name extensions opened by the built-in text editor.
///
/// Mirrors Avalonia's Client.Apps.Notepad.NotepadApp.SupportedExtensions.
const List<String> notepadSupportedExtensions = <String>[
  '.txt',
  '.text',
  '.md',
  '.markdown',
  '.mdx',
  '.rst',
  '.adoc',
  '.asciidoc',
  '.log',
  '.nfo',
  '.csv',
  '.tsv',
  '.tab',
  '.ini',
  '.cfg',
  '.conf',
  '.config',
  '.properties',
  '.yaml',
  '.yml',
  '.toml',
  '.xml',
  '.xsd',
  '.xsl',
  '.xslt',
  '.json',
  '.jsonc',
  '.json5',
  '.html',
  '.htm',
  '.xhtml',
  '.css',
  '.scss',
  '.sass',
  '.less',
  '.tex',
  '.bib',
  '.srt',
  '.vtt',
  '.ics',
  '.vcf',
  '.diff',
  '.patch',
  '.asc',
  '.pem',
  '.crt',
  '.cer',
  '.pub',
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

