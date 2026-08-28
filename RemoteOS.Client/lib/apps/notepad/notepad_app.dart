import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/network/remoteos_api.dart';
import '../../core/theme/theme_service.dart';
import '../../core/window_manager/modal_manager.dart';
import '../../core/window_manager/window_manager.dart';
import '../../features/files/data/remote_file_api.dart';
import '../../features/files/text_file_encodings.dart';
import '../../features/workspace/application/workspace_sync_coordinator.dart';
import '../explorer/explorer_picker.dart';

/// Mirrors `Client.Apps.Notepad.NotepadApp.SupportedExtensions`. The built-in
/// text editor accepts all of these extensions (and extension-less files)
/// when opened from Explorer or via the open-file picker.
const List<String> _supportedExtensions = [
  '.txt', '.text', '.md', '.markdown', '.mdx', '.rst', '.adoc', '.asciidoc',
  '.log', '.nfo', '.csv', '.tsv', '.tab', '.ini', '.cfg', '.conf', '.config',
  '.properties', '.yaml', '.yml', '.toml', '.xml', '.xsd', '.xsl', '.xslt',
  '.json', '.jsonc', '.json5', '.html', '.htm', '.xhtml', '.css', '.scss',
  '.sass', '.less', '.tex', '.bib', '.srt', '.vtt', '.ics', '.vcf', '.diff',
  '.patch', '.asc', '.pem', '.crt', '.cer', '.pub',
];

/// The Notepad application, migrated from the Avalonia
/// `Client.Apps.Notepad.NotepadApp` + `NotepadViewModel`. It edits remote
/// text files through the file API and supports reopen/save with an
/// explicit encoding, mirroring the original capabilities.
class NotepadApp extends ConsumerStatefulWidget {
  const NotepadApp({super.key, this.initialPath});

  /// Optional remote path opened directly at activation, mirroring the
  /// original `NotepadApp.OpenFile(context, path)` entry point.
  final String? initialPath;

  @override
  ConsumerState<NotepadApp> createState() => _NotepadAppState();
}

class _NotepadAppState extends ConsumerState<NotepadApp> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _lineNumberScrollController = ScrollController();
  final _focusNode = FocusNode();

  // Document state — mirrors `NotepadViewModel` observable properties.
  String? _currentPath;
  String _encodingName = 'UTF-8';
  String _defaultEncodingName = 'UTF-8';
  bool _isDirty = false;
  bool _isLoading = false;
  String _statusText = '';
  double _fontSize = 14;
  bool _wordWrap = true;
  bool _showLineNumbers = true;

  // Simple undo/redo stack (text snapshotting).
  final List<_DocSnapshot> _undoStack = [];
  final List<_DocSnapshot> _redoStack = [];
  bool _isApplyingHistory = false;
  static const int _maxHistory = 500;

  // Cursor position shown in status bar.
  int _cursorLine = 1;
  int _cursorColumn = 1;
  int _cursorOffset = 0;

  // Find/replace model.
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  bool _findCaseSensitive = false;
  bool _findRegex = false;
  bool _showFindReplace = false;
  bool _isReplaceMode = false;
  String _findStatus = '';

  static const List<double> _fontSizes = [12, 13, 14, 16, 18, 20];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _controller.addListener(_onSelectionChanged);
    _statusText = 'notepad.status.ready'.tr();
    final preferences = ref.read(workspaceSyncProvider).preferences;
    final stored = preferences?.notepadDefaultEncoding;
    _defaultEncodingName = TextFileEncodings.isSupported(stored)
        ? stored!
        : TextFileEncodings.defaultEncoding;
    _encodingName = _defaultEncodingName;
    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openPath(widget.initialPath!, _encodingName));
    } else {
      _pushUndoSnapshot(silent: true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.removeListener(_onSelectionChanged);
    _controller.dispose();
    _scrollController.dispose();
    _lineNumberScrollController.dispose();
    _focusNode.dispose();
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    final sel = _controller.selection;
    final offset = sel.baseOffset.clamp(0, _controller.text.length);
    final textBefore = _controller.text.substring(0, offset);
    final line = '\n'.allMatches(textBefore).length + 1;
    final lastLf = textBefore.lastIndexOf('\n');
    final column = offset - (lastLf < 0 ? 0 : lastLf + 1) + 1;
    if (_cursorLine != line ||
        _cursorColumn != column ||
        _cursorOffset != offset) {
      setState(() {
        _cursorLine = line;
        _cursorColumn = column;
        _cursorOffset = offset;
      });
    }
  }

  void _onTextChanged() {
    if (_isLoading || _isApplyingHistory) return;
    _pushUndoSnapshot();
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  void _pushUndoSnapshot({bool silent = false}) {
    final current = _DocSnapshot(
      text: _controller.text,
      selection: _controller.selection,
    );
    if (_undoStack.isNotEmpty && _undoStack.last.text == current.text) {
      if (!silent) _undoStack[_undoStack.length - 1] = current;
      return;
    }
    _undoStack.add(current);
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.length < 2) return;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    final prev = _undoStack.last;
    _applySnapshot(prev);
    setState(() => _isDirty = true);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    _applySnapshot(next);
  }

  void _applySnapshot(_DocSnapshot snapshot) {
    _isApplyingHistory = true;
    _controller.value = TextEditingValue(
      text: snapshot.text,
      selection: snapshot.selection,
    );
    _isApplyingHistory = false;
  }

  int get _lineCount => '\n'.allMatches(_controller.text).length + 1;
  int get _charCount => _controller.text.length;
  bool get _hasOpenFile => _currentPath != null && _currentPath!.isNotEmpty;
  String get _documentName {
    if (_currentPath == null || _currentPath!.isEmpty) {
      return 'notepad.document.untitled'.tr();
    }
    final normalized = _currentPath!.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? _currentPath! : parts.last;
  }

  // ---- Document commands ----

  Future<void> _newDocument() async {
    if (_isDirty && !await _confirmDiscard(
        'notepad.reopen_dirty_title'.tr(),
        'notepad.reopen_dirty_message'.tr())) {
      return;
    }
    _isLoading = true;
    _controller.clear();
    _undoStack.clear();
    _redoStack.clear();
    _pushUndoSnapshot(silent: true);
    setState(() {
      _currentPath = null;
      _encodingName = _defaultEncodingName;
      _isDirty = false;
      _statusText = 'notepad.status.new_document'.tr();
    });
    _isLoading = false;
  }

  Future<void> _openDocument() async {
    final path = await showRemoteFilePicker(
      ref,
      context,
      filters: [
        ExplorerFileFilter(
          label: 'notepad.text_file_filter'.tr(),
          patterns: [
            for (final extension in _supportedExtensions) '*$extension',
          ],
          includeExtensionlessFiles: true,
        ),
        ExplorerFileFilter.allFiles,
      ],
    );
    if (path == null || path.isEmpty) return;
    await _openPath(path, _defaultEncodingName);
  }

  Future<void> _openPath(String path, String requestedEncoding) async {
    if (!TextFileEncodings.isSupported(requestedEncoding)) return;
    try {
      final bytes = await RemoteFileApi(ref.read(remoteOsApiProvider))
          .readBytes(path);
      if (bytes.isEmpty) {
        setState(() {
          _statusText = 'notepad.status.file_missing'.tr();
        });
        return;
      }
      _isLoading = true;
      final decoded = TextFileEncodings.decode(bytes, requestedEncoding);
      _controller.text = decoded;
      _undoStack.clear();
      _redoStack.clear();
      _pushUndoSnapshot(silent: true);
      setState(() {
        _currentPath = path;
        _encodingName = requestedEncoding;
        _isDirty = false;
        _statusText = 'notepad.status.opened'
            .tr(args: [_baseName(path), requestedEncoding]);
      });
    } catch (error) {
      setState(() {
        _statusText =
            'notepad.status.open_failed'.tr(args: [error.toString()]);
      });
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _save() async {
    var path = _currentPath;
    if (path == null || path.isEmpty) {
      path = await _requestSavePath('untitled.txt');
      if (path == null || path.isEmpty) return;
    }
    await _saveToPath(path);
  }

  Future<void> _saveAs() async {
    final suggested = (_currentPath == null || _currentPath!.isEmpty)
        ? 'untitled.txt'
        : _baseName(_currentPath!);
    final path = await _requestSavePath(suggested);
    if (path == null || path.isEmpty) return;
    await _saveToPath(path);
  }

  Future<void> _saveToPath(String path) async {
    try {
      final bytes =
          TextFileEncodings.encode(_controller.text, _encodingName);
      await RemoteFileApi(ref.read(remoteOsApiProvider))
          .writeBytes(path, bytes);
      setState(() {
        _currentPath = path;
        _isDirty = false;
        _statusText = 'notepad.status.saved'
            .tr(args: [_baseName(path), _encodingName]);
      });
    } catch (error) {
      setState(() {
        _statusText =
            'notepad.status.save_failed'.tr(args: [error.toString()]);
      });
    }
  }

  Future<String?> _requestSavePath(String defaultName) async {
    return ref.read(modalManagerProvider).open<String>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'notepad.save_remote_file'.tr(),
        icon: Icons.save_outlined,
        preferredSize: const Size(440, 230),
        child: _SavePathDialog(
          prompt: 'notepad.remote_path_prompt'.tr(),
          initialValue: defaultName,
        ),
      ),
    );
  }

  Future<void> _chooseEncoding() async {
    if (!_hasOpenFile) return;
    final action = await ref.read(modalManagerProvider).open<_EncodingAction>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: 'common.file_encoding'.tr(),
            icon: Icons.translate_rounded,
            preferredSize: const Size(420, 220),
            child: const _EncodingActionDialog(),
          ),
        );
    if (action == null) return;
    final encoding = await ref.read(modalManagerProvider).open<String>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: 'common.file_encoding'.tr(),
            icon: Icons.translate_rounded,
            preferredSize: const Size(420, 360),
            child: _EncodingDialog(currentEncoding: _encodingName),
          ),
        );
    if (encoding == null || encoding.trim().isEmpty) return;
    if (action == _EncodingAction.reopen) {
      await _reopenWithEncoding(encoding);
    } else {
      await _saveWithEncoding(encoding);
    }
  }

  Future<void> _reopenWithEncoding(String encodingName) async {
    if (!_hasOpenFile || !TextFileEncodings.isSupported(encodingName)) return;
    if (_isDirty && !await _confirmDiscard(
        'notepad.reopen_dirty_title'.tr(),
        'notepad.reopen_dirty_message'.tr())) {
      return;
    }
    setState(() => _encodingName = encodingName);
    await _openPath(_currentPath!, encodingName);
  }

  Future<void> _saveWithEncoding(String encodingName) async {
    if (!_hasOpenFile || !TextFileEncodings.isSupported(encodingName)) return;
    setState(() => _encodingName = encodingName);
    await _saveToPath(_currentPath!);
  }

  Future<bool> _confirmDiscard(String title, String message) {
    return ref
        .read(modalManagerProvider)
        .open<bool>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: title,
            icon: Icons.warning_amber_rounded,
            preferredSize: const Size(440, 230),
            child: _ConfirmDialog(
              title: title,
              message: message,
              confirmLabel: 'notepad.discard_changes'.tr(),
            ),
          ),
        )
        .then((value) => value == true);
  }

  Future<void> _openSettings() async {
    await ref.read(modalManagerProvider).open<void>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: 'notepad.settings.title'.tr(),
            icon: Icons.tune_outlined,
            preferredSize: const Size(440, 320),
            child: _SettingsDialog(
              fontSize: _fontSize,
              defaultEncoding: _defaultEncodingName,
              onFontSizeChanged: (size) => setState(() => _fontSize = size),
              onDefaultEncodingChanged: (encoding) {
                setState(() => _defaultEncodingName = encoding);
                _saveDefaultEncoding(encoding);
              },
            ),
          ),
        );
  }

  void _saveDefaultEncoding(String encoding) {
    final current = ref.read(workspaceSyncProvider).preferences;
    if (current == null) return;
    ref
        .read(workspaceSyncProvider.notifier)
        .queuePreferences(current.copyWith(notepadDefaultEncoding: encoding));
  }

  String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? normalized : parts.last;
  }

  // ---- Edit commands ----

  void _cut() {
    if (!_controller.selection.isCollapsed) {
      Clipboard.setData(ClipboardData(text: _controller.selection.textInside(_controller.text) ?? ''));
      _deleteSelection();
    }
  }

  Future<void> _copy() async {
    if (!_controller.selection.isCollapsed) {
      await Clipboard.setData(ClipboardData(text: _controller.selection.textInside(_controller.text) ?? ''));
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return;
    final sel = _controller.selection;
    final newText = _controller.text.replaceRange(
      sel.start,
      sel.end,
      text,
    );
    final newOffset = sel.start + text.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void _selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _deleteSelection() {
    final sel = _controller.selection;
    if (sel.isCollapsed) return;
    final text = _controller.text;
    final newText = text.replaceRange(sel.start, sel.end, '');
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start),
    );
  }

  // ---- Find & Replace ----

  void _openFind() {
    setState(() {
      _showFindReplace = true;
      _isReplaceMode = false;
      _findStatus = '';
    });
    Future.delayed(Duration.zero, () {
      if (mounted) FocusScope.of(context).requestFocus(_findFocusNode);
    });
  }

  void _openReplace() {
    setState(() {
      _showFindReplace = true;
      _isReplaceMode = true;
      _findStatus = '';
    });
    Future.delayed(Duration.zero, () {
      if (mounted) FocusScope.of(context).requestFocus(_findFocusNode);
    });
  }

  void _closeFindReplace() {
    setState(() {
      _showFindReplace = false;
      _findStatus = '';
    });
  }

  final _findFocusNode = FocusNode();

  List<TextSelection> _findAllMatches() {
    final query = _findController.text;
    if (query.isEmpty) return const [];
    final text = _controller.text;
    final matches = <TextSelection>[];
    try {
      final pattern = _findRegex
          ? RegExp(query, caseSensitive: _findCaseSensitive)
          : RegExp(RegExp.escape(query), caseSensitive: _findCaseSensitive);
      for (final match in pattern.allMatches(text)) {
        matches.add(TextSelection(baseOffset: match.start, extentOffset: match.end));
      }
    } catch (_) {
      // Invalid regex — ignore silently; UI shows status.
    }
    return matches;
  }

  int _findNextIndex(List<TextSelection> matches) {
    if (matches.isEmpty) return -1;
    final caret = _controller.selection.baseOffset.clamp(0, _controller.text.length);
    for (var i = 0; i < matches.length; i++) {
      if (matches[i].start >= caret && !matches[i].isCollapsed) {
        return i;
      }
    }
    return 0;
  }

  void _findNext() {
    final matches = _findAllMatches();
    if (matches.isEmpty) {
      setState(() => _findStatus = 'notepad.find.not_found'.tr());
      return;
    }
    final idx = _findNextIndex(matches);
    _selectMatch(matches[idx]);
    setState(() => _findStatus =
        'notepad.found_n_of_m'.tr(args: ['${idx + 1}', '${matches.length}']));
  }

  void _findPrev() {
    final matches = _findAllMatches();
    if (matches.isEmpty) {
      setState(() => _findStatus = 'notepad.find.not_found'.tr());
      return;
    }
    final caret = _controller.selection.baseOffset.clamp(0, _controller.text.length);
    var idx = matches.length - 1;
    for (var i = matches.length - 1; i >= 0; i--) {
      if (matches[i].end <= caret && !matches[i].isCollapsed) {
        idx = i;
        break;
      }
    }
    _selectMatch(matches[idx]);
    setState(() => _findStatus =
        'notepad.found_n_of_m'.tr(args: ['${idx + 1}', '${matches.length}']));
  }

  void _selectMatch(TextSelection match) {
    _controller.selection = match;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.buildTextSpan?.call(context: context, withComposing: false);
      // Best effort scroll by jumping to selection offset.
    });
  }

  void _replaceNext() {
    final matches = _findAllMatches();
    if (matches.isEmpty) {
      setState(() => _findStatus = 'notepad.find.not_found'.tr());
      return;
    }
    final idx = _findNextIndex(matches);
    final match = matches[idx];
    final replacement = _replaceController.text;
    final newText = _controller.text.replaceRange(match.start, match.end, replacement);
    final newSelection = TextSelection.collapsed(offset: match.start + replacement.length);
    _controller.value = TextEditingValue(text: newText, selection: newSelection);
    setState(() => _findStatus =
        'notepad.replace.replaced_one'.tr(args: ['${idx + 1}']));
  }

  void _replaceAll() {
    final matches = _findAllMatches();
    if (matches.isEmpty) {
      setState(() => _findStatus = 'notepad.find.not_found'.tr());
      return;
    }
    final replacement = _replaceController.text;
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in matches) {
      buffer.write(_controller.text.substring(cursor, match.start));
      buffer.write(replacement);
      cursor = match.end;
    }
    buffer.write(_controller.text.substring(cursor));
    final newText = buffer.toString();
    _controller.value = TextEditingValue(
      text: newText,
      selection: const TextSelection.collapsed(offset: 0),
    );
    setState(() => _findStatus =
        'notepad.replace.replaced_all'.tr(args: ['${matches.length}']));
  }

  // ---- Print (placeholder — RemoteOS shell currently has no local printer) ----

  Future<void> _printDocument() async {
    setState(() {
      _statusText = 'notepad.print.not_available'.tr();
    });
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Column(
        children: [
          _buildMenuBar(palette),
          if (_showFindReplace) _buildFindReplaceToolbar(palette),
          Expanded(
            child: Container(
              color: palette.surface,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showLineNumbers) _buildLineNumbersGutter(palette),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: _wordWrap ? Axis.vertical : Axis.horizontal,
                      child: _wordWrap
                          ? _buildTextField(palette, null)
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: _buildTextField(palette, null),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildStatusBar(palette),
        ],
      ),
    );
  }

  Widget _buildLineNumbersGutter(ThemePalette palette) {
    return Container(
      width: 52,
      padding: const EdgeInsets.only(top: 14, right: 8),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        border: Border(right: BorderSide(color: palette.borderSubtle)),
      ),
      child: Text(
        List.generate(_lineCount, (i) => '${i + 1}').join('\n'),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'Consolas',
          fontFamilyFallback: const ['Courier New', 'monospace'],
          fontSize: _fontSize,
          height: 1.35,
          color: palette.textTertiary,
        ),
      ),
    );
  }

  Widget _buildTextField(ThemePalette palette, ScrollController? _ignored) {
    final contentPadding = EdgeInsets.only(
      left: _showLineNumbers ? 8 : 14,
      right: 14,
      top: 14,
      bottom: 14,
    );
    final text = _controller.text;
    double? intrinsicWidth;
    if (!_wordWrap && text.isNotEmpty) {
      // Directionality is required for TextPainter layout.
      final direction = Directionality.maybeOf(context);
      if (direction != null) {
        final painter = TextPainter(
          text: TextSpan(
            text: _longestLine(text),
            style: TextStyle(
              fontFamily: 'Consolas',
              fontFamilyFallback: const ['Courier New', 'monospace'],
              fontSize: _fontSize,
              height: 1.35,
            ),
          ),
          maxLines: 1,
          textDirection: direction,
        )..layout();
        intrinsicWidth = painter.width + 28;
      }
    }
    return Container(
      width: intrinsicWidth,
      constraints: _wordWrap
          ? null
          : BoxConstraints(minWidth: MediaQuery.of(context).size.width),
      child: TextField(
        controller: _controller,
        expands: false,
        maxLines: _wordWrap ? null : _lineCount,
        minLines: _wordWrap ? null : _lineCount,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          fontFamily: 'Consolas',
          fontFamilyFallback: const ['Courier New', 'monospace'],
          fontSize: _fontSize,
          height: 1.35,
          color: palette.textPrimary,
        ),
        cursorColor: palette.accent,
        cursorWidth: 2,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          border: InputBorder.none,
          filled: true,
          fillColor: palette.surface,
          contentPadding: contentPadding,
          hintText: 'notepad.hint.start_typing'.tr(),
          hintStyle:
              TextStyle(color: palette.textTertiary, fontSize: _fontSize),
          isCollapsed: true,
          isDense: false,
        ),
      ),
    );
  }

  String _longestLine(String text) {
    if (text.isEmpty) return '';
    return text.split('\n').reduce((a, b) => a.length > b.length ? a : b);
  }

  Widget _buildFindReplaceToolbar(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: _findController,
              focusNode: _findFocusNode,
              style: TextStyle(color: palette.textPrimary, fontSize: 13),
              onSubmitted: (_) => _findNext(),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'notepad.find.find'.tr(),
                labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'common.previous'.tr(),
            onPressed: _findPrev,
            icon: Icon(Icons.arrow_upward_rounded, size: 18, color: palette.textSecondary),
          ),
          IconButton(
            tooltip: 'common.next'.tr(),
            onPressed: _findNext,
            icon: Icon(Icons.arrow_downward_rounded, size: 18, color: palette.textSecondary),
          ),
          if (_isReplaceMode) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _replaceController,
                style: TextStyle(color: palette.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'notepad.find.replace_with'.tr(),
                  labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _replaceNext,
              child: Text('notepad.find.replace'.tr(), style: const TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: _replaceAll,
              child: Text('notepad.find.replace_all'.tr(), style: const TextStyle(fontSize: 12)),
            ),
          ],
          const SizedBox(width: 10),
          FilterChip(
            label: Text('Aa', style: TextStyle(fontSize: 11, color: _findCaseSensitive ? palette.textOnAccent : palette.textSecondary)),
            backgroundColor: palette.surfaceRaised,
            selectedColor: palette.accent,
            selected: _findCaseSensitive,
            onSelected: (v) => setState(() => _findCaseSensitive = v),
            side: BorderSide(color: _findCaseSensitive ? palette.accent : palette.borderDefault),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: Text('.*', style: TextStyle(fontSize: 11, color: _findRegex ? palette.textOnAccent : palette.textSecondary)),
            backgroundColor: palette.surfaceRaised,
            selectedColor: palette.accent,
            selected: _findRegex,
            onSelected: (v) => setState(() => _findRegex = v),
            side: BorderSide(color: _findRegex ? palette.accent : palette.borderDefault),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _findStatus,
              style: TextStyle(color: palette.textTertiary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'common.close'.tr(),
            onPressed: _closeFindReplace,
            icon: Icon(Icons.close_rounded, size: 18, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---- Keyboard shortcuts ----

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final key = event.logicalKey;

    // Ctrl + F / Ctrl + H / F3 / Shift+F3 handled even when focus is in editor.
    if (key == LogicalKeyboardKey.f3) {
      if (shift) {
        _findPrev();
      } else {
        _findNext();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _showFindReplace) {
      _closeFindReplace();
      return KeyEventResult.handled;
    }

    if (!ctrl) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.keyN && !shift) {
      _newDocument();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyO && !shift) {
      _openDocument();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS && !shift) {
      _save();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS && shift) {
      _saveAs();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyZ && !shift) {
      _undo();
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.keyY) ||
        (key == LogicalKeyboardKey.keyZ && shift)) {
      _redo();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX) {
      _cut();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyC && !alt) {
      _copy();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV) {
      _paste();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA) {
      _selectAll();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      _openFind();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH) {
      _openReplace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyP) {
      _printDocument();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildMenuBar(ThemePalette palette) {
    return Container(
      height: 32,
      color: palette.windowTitleBarBackground,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          _menuButton(palette, Icons.description_outlined, 'common.file'.tr(), [
            MenuItemButton(
              onPressed: _newDocument,
              leadingIcon: const Icon(Icons.note_add_outlined, size: 16),
              child: Text(
                  '${'common.new'.tr()}    Ctrl+N',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _openDocument,
              leadingIcon: const Icon(Icons.folder_open_outlined, size: 16),
              child: Text(
                  '${'common.open_ellipsis'.tr()}    Ctrl+O',
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: _save,
              leadingIcon: const Icon(Icons.save_outlined, size: 16),
              child: Text(
                  '${'common.save'.tr()}    Ctrl+S',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _saveAs,
              leadingIcon: const Icon(Icons.save_as_outlined, size: 16),
              child: Text('${'common.save_as_ellipsis'.tr()}    Ctrl+Shift+S',
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: _chooseEncoding,
              leadingIcon: const Icon(Icons.translate_rounded, size: 16),
              child: Text('common.file_encoding'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _printDocument,
              leadingIcon: const Icon(Icons.print_outlined, size: 16),
              child: Text('${'common.print'.tr()}    Ctrl+P',
                  style: const TextStyle(fontSize: 13)),
            ),
          ]),
          _menuButton(palette, Icons.edit_note_outlined, 'common.edit'.tr(), [
            MenuItemButton(
              onPressed: _undo,
              leadingIcon: const Icon(Icons.undo_outlined, size: 16),
              child: Text('${'common.undo'.tr()}    Ctrl+Z',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _redo,
              leadingIcon: const Icon(Icons.redo_outlined, size: 16),
              child: Text('${'common.redo'.tr()}    Ctrl+Y',
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: _cut,
              leadingIcon: const Icon(Icons.content_cut_outlined, size: 16),
              child: Text('${'common.cut'.tr()}    Ctrl+X',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _copy,
              leadingIcon: const Icon(Icons.content_copy_outlined, size: 16),
              child: Text('${'common.copy'.tr()}    Ctrl+C',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _paste,
              leadingIcon: const Icon(Icons.content_paste_outlined, size: 16),
              child: Text('${'common.paste'.tr()}    Ctrl+V',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _selectAll,
              leadingIcon: const Icon(Icons.select_all_outlined, size: 16),
              child: Text('${'common.select_all'.tr()}    Ctrl+A',
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: _openFind,
              leadingIcon: const Icon(Icons.search_outlined, size: 16),
              child: Text('${'common.find'.tr()}    Ctrl+F',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _openReplace,
              leadingIcon: const Icon(Icons.find_replace_outlined, size: 16),
              child: Text('${'common.replace'.tr()}    Ctrl+H',
                  style: const TextStyle(fontSize: 13)),
            ),
          ]),
          _menuButton(palette, Icons.visibility_outlined, 'common.view'.tr(), [
            MenuItemButton(
              onPressed: () => setState(() => _wordWrap = !_wordWrap),
              trailingIcon: Icon(
                _wordWrap ? Icons.check_box : Icons.check_box_outline_blank,
                size: 16,
                color: palette.accent,
              ),
              child: Text('common.word_wrap'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: () => setState(() => _showLineNumbers = !_showLineNumbers),
              trailingIcon: Icon(
                _showLineNumbers ? Icons.check_box : Icons.check_box_outline_blank,
                size: 16,
                color: palette.accent,
              ),
              child: Text('common.line_numbers'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: _openSettings,
              leadingIcon: const Icon(Icons.settings_outlined, size: 16),
              child: Text('common.preferences_ellipsis'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _documentName,
              style: TextStyle(
                fontSize: 12,
                color: palette.windowTitleForeground.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButton(ThemePalette palette, IconData icon, String label,
      List<Widget> children) {
    return MenuAnchor(
      builder: (context, controller, _) => InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, size: 14, color: palette.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: palette.windowTitleForeground)),
            ],
          ),
        ),
      ),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(palette.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: palette.borderSubtle)),
        ),
      ),
      menuChildren: children,
    );
  }

  Widget _buildStatusBar(ThemePalette palette) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _statusText,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textTertiary, fontSize: 11),
            ),
          ),
          Text(
            'notepad.status.ln_col'.tr(args: ['$_cursorLine', '$_cursorColumn']),
            style: TextStyle(color: palette.textTertiary, fontSize: 11),
          ),
          const SizedBox(width: 14),
          Text(
            'notepad.status.offset'.tr(args: ['$_cursorOffset']),
            style: TextStyle(color: palette.textTertiary, fontSize: 11),
          ),
          const SizedBox(width: 14),
          if (_hasOpenFile) ...[
            TextButton(
              onPressed: _chooseEncoding,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: palette.textTertiary,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: Text(_encodingName),
            ),
            const SizedBox(width: 14),
          ],
          Text(
            'common.line_count_format'.tr(args: ['$_lineCount']),
            style: TextStyle(color: palette.textTertiary, fontSize: 11),
          ),
          const SizedBox(width: 14),
          Text(
            'common.character_count_format'.tr(args: ['$_charCount']),
            style: TextStyle(color: palette.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Snapshot used for undo/redo history.
class _DocSnapshot {
  const _DocSnapshot({required this.text, required this.selection});
  final String text;
  final TextSelection selection;
}

/// Save-as path input dialog. Mirrors Avalonia's `TextInputDialogView` used
/// by `NotepadApp.RequestSavePathAsync`.
class _SavePathDialog extends ConsumerStatefulWidget {
  const _SavePathDialog({required this.prompt, required this.initialValue});
  final String prompt;
  final String initialValue;

  @override
  ConsumerState<_SavePathDialog> createState() => _SavePathDialogState();
}

class _SavePathDialogState extends ConsumerState<_SavePathDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..selection = TextSelection(
          baseOffset: 0, extentOffset: widget.initialValue.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.prompt,
              style: TextStyle(color: palette.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: (value) =>
                modals.complete(dialogId, value.trim().isEmpty ? null : value),
            style: TextStyle(color: palette.textPrimary),
            decoration: const InputDecoration(labelText: 'Path'),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => modals.dismiss(dialogId),
                child: Text('common.cancel'.tr()),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => modals.complete(
                    dialogId,
                    _controller.text.trim().isEmpty
                        ? null
                        : _controller.text.trim()),
                child: Text('common.save'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Confirmation dialog used for "discard unsaved changes?" prompts. Mirrors
/// `ConfirmDialogView`.
class _ConfirmDialog extends ConsumerWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });
  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: palette.textPrimary)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => modals.dismiss(dialogId),
                child: Text('common.cancel'.tr()),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => modals.complete(dialogId, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Step 1 of the encoding chooser: asks the user whether to reopen or save
/// with the new encoding. Mirrors `EncodingActionDialogView`.
enum _EncodingAction { reopen, save }

class _EncodingActionDialog extends ConsumerWidget {
  const _EncodingActionDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'common.encoding_action_hint'.tr(),
              style: TextStyle(color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: 10),
          _actionTile(palette, 'common.reopen'.tr(),
              () => modals.complete(dialogId, _EncodingAction.reopen)),
          _actionTile(palette, 'common.save'.tr(),
              () => modals.complete(dialogId, _EncodingAction.save)),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => modals.dismiss(dialogId),
              child: Text('common.cancel'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(ThemePalette palette, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: TextStyle(color: palette.textPrimary, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

/// Step 2 of the encoding chooser: lists all supported encodings and returns
/// the picked one. Mirrors `EncodingDialogView`.
class _EncodingDialog extends ConsumerStatefulWidget {
  const _EncodingDialog({required this.currentEncoding});
  final String currentEncoding;

  @override
  ConsumerState<_EncodingDialog> createState() => _EncodingDialogState();
}

class _EncodingDialogState extends ConsumerState<_EncodingDialog> {
  late String _selected = TextFileEncodings.isSupported(widget.currentEncoding)
      ? widget.currentEncoding
      : TextFileEncodings.available.first;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('common.encoding_selection_hint'.tr(),
              style: TextStyle(color: palette.textPrimary)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: TextFileEncodings.available.length,
              itemBuilder: (context, index) {
                final encoding = TextFileEncodings.available[index];
                return RadioListTile<String>(
                  value: encoding,
                  groupValue: _selected,
                  title: Text(encoding),
                  dense: true,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selected = value);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => modals.dismiss(dialogId),
                child: Text('common.cancel'.tr()),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => modals.complete(dialogId, _selected),
                child: Text('common.ok'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settings dialog with font-size + default-encoding selectors. Mirrors the
/// Avalonia `NotepadSettingsView` (kept on the same `NotepadViewModel`).
class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog({
    required this.fontSize,
    required this.defaultEncoding,
    required this.onFontSizeChanged,
    required this.onDefaultEncodingChanged,
  });
  final double fontSize;
  final String defaultEncoding;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<String> onDefaultEncodingChanged;

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late double _fontSize = widget.fontSize;
  late String _defaultEncoding = widget.defaultEncoding;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('notepad.settings.title'.tr(),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary)),
          const SizedBox(height: 18),
          Row(children: [
            SizedBox(
                width: 150,
                child: Text('common.font_size'.tr(),
                    style: TextStyle(color: palette.textSecondary))),
            Expanded(
              child: DropdownButton<double>(
                value: _fontSize,
                isExpanded: true,
                items: [
                  for (final size in _NotepadAppState._fontSizes)
                    DropdownMenuItem(
                        value: size, child: Text('${size.toInt()} pt')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _fontSize = value);
                  widget.onFontSizeChanged(value);
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            SizedBox(
                width: 150,
                child: Text('notepad.settings.default_encoding'.tr(),
                    style: TextStyle(color: palette.textSecondary))),
            Expanded(
              child: DropdownButton<String>(
                value: _defaultEncoding,
                isExpanded: true,
                items: [
                  for (final encoding in TextFileEncodings.available)
                    DropdownMenuItem(value: encoding, child: Text(encoding)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _defaultEncoding = value);
                  widget.onDefaultEncodingChanged(value);
                },
              ),
            ),
          ]),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => modals.dismiss(dialogId),
              child: Text('common.done'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}


