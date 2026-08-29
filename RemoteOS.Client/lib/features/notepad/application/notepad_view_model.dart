// Notepad ViewModel (ARCHITECTURE.md § 9).
//
// This is the presentation owner for one Notepad window:
//   * owns `ValueNotifier<NotepadUiState>` for the entire projection;
//   * exposes user intents as Commands (AGENTS.md § 10);
//   * delegates file I/O to [TextFileRepository];
//   * delegates preferences to [WorkspaceSyncCoordinator];
//   * owns undo/redo history stacks and find/replace helpers.
//
// Dialogs and file pickers are requested via explicit callback hooks set by
// the View — this keeps BuildContext / Navigator / Widgets out of the VM.

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/commands/base_view_model.dart';
import '../../files/text_file_encodings.dart';
import '../../workspace/application/workspace_sync_coordinator.dart';
import '../data/text_file_repository.dart';
import '../domain/notepad_models.dart';
import '../domain/notepad_ui_state.dart';

/// Signature for "open a file picker and return a remote path".
typedef RequestFileAsync = Future<String?> Function();

/// Signature for "request a save-as remote path for [suggestedName]".
typedef RequestSavePathAsync = Future<String?> Function(String suggestedName);

/// Signature for "ask the user whether to discard dirty changes".
typedef RequestDiscardChangesAsync = Future<bool> Function(
  String title,
  String message,
);

/// Signature for "open the Notepad settings modal".
typedef RequestSettingsAsync = Future<void> Function();

/// Signature for "ask whether to reopen or save with the new encoding".
typedef RequestEncodingActionAsync = Future<EncodingDialogAction?> Function();

/// Signature for "let the user pick one supported encoding".
typedef RequestEncodingAsync = Future<String?> Function(String currentEncoding);

/// Signature for "persist the new default-encoding preference".
typedef SaveDefaultEncodingAsync = Future<void> Function(String encoding);

/// ViewModel factory so get_it can inject dependencies.
NotepadViewModel createNotepadViewModel() => NotepadViewModel(
      repository: getService<TextFileRepository>(),
      workspaceSync: getService<WorkspaceSyncCoordinator>(),
    );

class NotepadViewModel extends ViewModel {
  NotepadViewModel({
    required TextFileRepository repository,
    required WorkspaceSyncCoordinator workspaceSync,
  })  : _repository = repository,
        _workspaceSync = workspaceSync {
    trackDisposable(state);
    trackDisposable(newDocumentCommand);
    trackDisposable(openDocumentCommand);
    trackDisposable(saveCommand);
    trackDisposable(saveAsCommand);
    trackDisposable(chooseEncodingCommand);
    trackDisposable(openSettingsCommand);

    // Seed the initial state from the workspace preferences (Avalonia reads
    // them once at construction time in the NotepadViewModel ctor).
    final preferences = _workspaceSync.preferences;
    final stored = preferences?.notepadDefaultEncoding;
    final defaultEncoding = TextFileEncodings.isSupported(stored)
        ? stored!
        : TextFileEncodings.defaultEncoding;
    state.value = NotepadUiState.initial(defaultEncodingName: defaultEncoding);
  }

  final TextFileRepository _repository;
  final WorkspaceSyncCoordinator _workspaceSync;

  // ---- Hooks injected by the View ----

  RequestFileAsync? requestFileAsync;
  RequestSavePathAsync? requestSavePathAsync;
  RequestDiscardChangesAsync? requestDiscardChangesAsync;
  RequestSettingsAsync? requestSettingsAsync;
  RequestEncodingActionAsync? requestEncodingActionAsync;
  RequestEncodingAsync? requestEncodingAsync;
  SaveDefaultEncodingAsync? saveDefaultEncodingAsync;

  // ---- State ----

  final ValueNotifier<NotepadUiState> state =
      ValueNotifier<NotepadUiState>(NotepadUiState.initial());

  NotepadUiState get _s => state.value;

  // ---- Undo / redo history ----

  final List<DocSnapshot> _undoStack = <DocSnapshot>[];
  final List<DocSnapshot> _redoStack = <DocSnapshot>[];
  bool _isApplyingHistory = false;
  bool _isBulkTextUpdate = false;
  static const int _maxHistory = 500;

  // ---- Commands ----

  late final newDocumentCommand =
      Command.createAsyncNoParamNoResult(newDocument);
  late final openDocumentCommand =
      Command.createAsyncNoParamNoResult(openDocument);
  late final saveCommand = Command.createAsyncNoParamNoResult(save);
  late final saveAsCommand = Command.createAsyncNoParamNoResult(saveAs);
  late final chooseEncodingCommand =
      Command.createAsyncNoParamNoResult(chooseEncoding);
  late final openSettingsCommand =
      Command.createAsyncNoParamNoResult(openSettings);

  // ---- View-controller boundary helpers ----
  // The View calls these directly because they represent pure in-memory
  // edits, clipboard or selection projections that don't warrant a Command.

  /// Called by the View whenever the text content changes (via the
  /// TextField's onChanged listener).  Mirrors the ViewModel's
  /// `OnTextChanged` partial.
  void onTextChanged(String text) {
    if (_isBulkTextUpdate || _isApplyingHistory) return;
    state.value = _s.copyWith(text: text);
    _pushUndoSnapshot(text);
    if (!_s.isDirty) {
      state.value = _s.copyWith(isDirty: true);
    }
  }

  /// Called by the View whenever the cursor selection changes so the
  /// status bar can stay in sync.  The `offset` is clamped to [textLength].
  void onSelectionChanged({
    required int baseOffset,
    required String text,
  }) {
    final clamped = baseOffset.clamp(0, text.length);
    final textBefore = text.substring(0, clamped);
    final line = '\n'.allMatches(textBefore).length + 1;
    final lastLf = textBefore.lastIndexOf('\n');
    final column = clamped - (lastLf < 0 ? 0 : lastLf + 1) + 1;
    final previous = _s.cursor;
    if (previous.line == line &&
        previous.column == column &&
        previous.offset == clamped) {
      return;
    }
    state.value = _s.copyWith(
      cursor: CursorPosition(line: line, column: column, offset: clamped),
    );
  }

  // ---- Undo / redo ----

  bool canUndo() => _undoStack.length >= 2;
  bool canRedo() => _redoStack.isNotEmpty;

  DocSnapshot? undo() {
    if (!canUndo()) return null;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    final prev = _undoStack.last;
    _applySnapshot(prev);
    state.value = _s.copyWith(isDirty: true);
    return prev;
  }

  DocSnapshot? redo() {
    if (!canRedo()) return null;
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    _applySnapshot(next);
    return next;
  }

  void _pushUndoSnapshot(String text, {TextSelection? selection}) {
    final current = DocSnapshot(
      text: text,
      selection: selection ?? const TextSelection.collapsed(offset: 0),
    );
    if (_undoStack.isNotEmpty && _undoStack.last.text == current.text) {
      if (selection != null) _undoStack[_undoStack.length - 1] = current;
      return;
    }
    _undoStack.add(current);
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void seedInitialSnapshot(String text, TextSelection selection) {
    if (_undoStack.isNotEmpty) return;
    _undoStack.add(DocSnapshot(text: text, selection: selection));
  }

  DocSnapshot _applySnapshot(DocSnapshot snapshot) {
    _isApplyingHistory = true;
    state.value = _s.copyWith(text: snapshot.text);
    _isApplyingHistory = false;
    return snapshot;
  }

  // ---- View toggles ----

  void toggleWordWrap() =>
      state.value = _s.copyWith(wordWrap: !_s.wordWrap);

  void toggleShowLineNumbers() =>
      state.value = _s.copyWith(showLineNumbers: !_s.showLineNumbers);

  void setFontSize(double size) => state.value = _s.copyWith(fontSize: size);

  void setDefaultEncoding(String encoding) {
    if (!TextFileEncodings.isSupported(encoding)) return;
    state.value = _s.copyWith(defaultEncodingName: encoding);
    saveDefaultEncodingAsync?.call(encoding);
    _persistDefaultEncoding(encoding);
  }

  Future<void> _persistDefaultEncoding(String encoding) async {
    final current = _workspaceSync.preferences;
    if (current == null) return;
    _workspaceSync
        .queuePreferences(current.copyWith(notepadDefaultEncoding: encoding));
  }

  // ---- Find / replace toggles ----

  void openFind({bool replaceMode = false}) {
    state.value = _s.copyWith(
      showFindReplace: true,
      isReplaceMode: replaceMode,
      findStatus: '',
    );
  }

  void closeFindReplace() {
    state.value = _s.copyWith(
      showFindReplace: false,
      findStatus: '',
    );
  }

  void setFindCaseSensitive(bool value) {
    state.value =
        _s.copyWith(findOptions: _s.findOptions.copyWith(caseSensitive: value));
  }

  void setFindRegex(bool value) {
    state.value =
        _s.copyWith(findOptions: _s.findOptions.copyWith(useRegex: value));
  }

  // ---- Find / replace core ----

  List<TextSelection> findAllMatches(String query, String text) {
    if (query.isEmpty) return const <TextSelection>[];
    final matches = <TextSelection>[];
    try {
      final pattern = _s.findOptions.useRegex
          ? RegExp(query, caseSensitive: _s.findOptions.caseSensitive)
          : RegExp(RegExp.escape(query),
              caseSensitive: _s.findOptions.caseSensitive);
      for (final match in pattern.allMatches(text)) {
        matches.add(
          TextSelection(baseOffset: match.start, extentOffset: match.end),
        );
      }
    } catch (_) {
      // Invalid regex — ignore silently; UI shows "not found" status.
    }
    return matches;
  }

  int findNextIndex(List<TextSelection> matches, int caret) {
    if (matches.isEmpty) return -1;
    for (var i = 0; i < matches.length; i++) {
      if (matches[i].start >= caret && !matches[i].isCollapsed) return i;
    }
    return 0;
  }

  TextSelection? findNext(String query, String text, int caret) {
    final matches = findAllMatches(query, text);
    if (matches.isEmpty) {
      state.value = _s.copyWith(findStatus: 'notepad.find.not_found');
      return null;
    }
    final idx = findNextIndex(matches, caret);
    state.value = _s.copyWith(
        findStatus: 'notepad.found_n_of_m|${idx + 1}|${matches.length}');
    return matches[idx];
  }

  TextSelection? findPrev(String query, String text, int caret) {
    final matches = findAllMatches(query, text);
    if (matches.isEmpty) {
      state.value = _s.copyWith(findStatus: 'notepad.find.not_found');
      return null;
    }
    var idx = matches.length - 1;
    for (var i = matches.length - 1; i >= 0; i--) {
      if (matches[i].end <= caret && !matches[i].isCollapsed) {
        idx = i;
        break;
      }
    }
    state.value = _s.copyWith(
        findStatus: 'notepad.found_n_of_m|${idx + 1}|${matches.length}');
    return matches[idx];
  }

  // Returns (newText, newSelection) so the View can apply the result.
  (String newText, TextSelection newSelection)? replaceNext(
    String query,
    String replacement,
    String text,
    int caret,
  ) {
    final matches = findAllMatches(query, text);
    if (matches.isEmpty) {
      state.value = _s.copyWith(findStatus: 'notepad.find.not_found');
      return null;
    }
    final idx = findNextIndex(matches, caret);
    final match = matches[idx];
    final newText = text.replaceRange(match.start, match.end, replacement);
    final newSelection =
        TextSelection.collapsed(offset: match.start + replacement.length);
    state.value =
        _s.copyWith(findStatus: 'notepad.replace.replaced_one|${idx + 1}');
    return (newText, newSelection);
  }

  (String newText, int replaced)? replaceAll(
    String query,
    String replacement,
    String text,
  ) {
    final matches = findAllMatches(query, text);
    if (matches.isEmpty) {
      state.value = _s.copyWith(findStatus: 'notepad.find.not_found');
      return null;
    }
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in matches) {
      buffer.write(text.substring(cursor, match.start));
      buffer.write(replacement);
      cursor = match.end;
    }
    buffer.write(text.substring(cursor));
    state.value = _s.copyWith(
        findStatus: 'notepad.replace.replaced_all|${matches.length}');
    return (buffer.toString(), matches.length);
  }

  // ---- Document commands ----

  Future<void> newDocument() async {
    if (_s.isDirty) {
      final keep = await requestDiscardChangesAsync?.call(
            'notepad.reopen_dirty_title',
            'notepad.reopen_dirty_message',
          ) ??
          false;
      if (!keep) return;
    }
    _isBulkTextUpdate = true;
    _undoStack.clear();
    _redoStack.clear();
    state.value = NotepadUiState.initial(
      defaultEncodingName: _s.defaultEncodingName,
    ).copyWith(
      fontSize: _s.fontSize,
      wordWrap: _s.wordWrap,
      showLineNumbers: _s.showLineNumbers,
      statusText: 'notepad.status.new_document',
    );
    _isBulkTextUpdate = false;
    seedInitialSnapshot('', const TextSelection.collapsed(offset: 0));
  }

  Future<void> openDocument() async {
    final path = await requestFileAsync?.call();
    if (path == null || path.isEmpty) return;
    await openPath(path, _s.defaultEncodingName);
  }

  Future<void> openPath(String path, String? requestedEncoding) async {
    final encoding = requestedEncoding ?? _s.defaultEncodingName;
    if (!TextFileEncodings.isSupported(encoding)) return;
    try {
      final decoded = await _repository.readText(path, encoding);
      if (decoded == null) {
        state.value = _s.copyWith(statusText: 'notepad.status.file_missing');
        return;
      }
      _isBulkTextUpdate = true;
      _undoStack.clear();
      _redoStack.clear();
      state.value = _s.copyWith(
        currentPath: path,
        encodingName: encoding,
        text: decoded,
        isDirty: false,
        isLoading: true,
      );
      seedInitialSnapshot(decoded, const TextSelection.collapsed(offset: 0));
      state.value = _s.copyWith(
        isLoading: false,
        statusText: 'notepad.status.opened|${_baseName(path)}|$encoding',
      );
    } catch (error) {
      state.value = _s.copyWith(
        statusText: 'notepad.status.open_failed|${_errorMsg(error)}',
        isLoading: false,
      );
    } finally {
      _isBulkTextUpdate = false;
    }
  }

  Future<void> save() async {
    var path = _s.currentPath;
    if (path == null || path.isEmpty) {
      path = await requestSavePathAsync?.call('untitled.txt');
      if (path == null || path.isEmpty) return;
    }
    await _saveToPath(path);
  }

  Future<void> saveAs() async {
    final suggested = (_s.currentPath == null || _s.currentPath!.isEmpty)
        ? 'untitled.txt'
        : _baseName(_s.currentPath!);
    final path = await requestSavePathAsync?.call(suggested);
    if (path == null || path.isEmpty) return;
    await _saveToPath(path);
  }

  Future<void> _saveToPath(String path) async {
    try {
      await _repository.writeText(path, _s.text, _s.encodingName);
      state.value = _s.copyWith(
        currentPath: path,
        isDirty: false,
        statusText:
            'notepad.status.saved|${_baseName(path)}|${_s.encodingName}',
      );
    } catch (error) {
      state.value = _s.copyWith(
        statusText: 'notepad.status.save_failed|${_errorMsg(error)}',
      );
    }
  }

  Future<void> chooseEncoding() async {
    if (!_s.hasOpenFile) return;
    final action = await requestEncodingActionAsync?.call();
    if (action == null) return;
    final encoding = await requestEncodingAsync?.call(_s.encodingName);
    if (encoding == null || encoding.trim().isEmpty) return;
    if (action == EncodingDialogAction.reopen) {
      await reopenWithEncoding(encoding);
    } else {
      await saveWithEncoding(encoding);
    }
  }

  Future<void> reopenWithEncoding(String encodingName) async {
    if (!_s.hasOpenFile || !TextFileEncodings.isSupported(encodingName)) return;
    if (_s.isDirty) {
      final keep = await requestDiscardChangesAsync?.call(
            'notepad.reopen_dirty_title',
            'notepad.reopen_dirty_message',
          ) ??
          false;
      if (!keep) return;
    }
    state.value = _s.copyWith(encodingName: encodingName);
    await openPath(_s.currentPath!, encodingName);
  }

  Future<void> saveWithEncoding(String encodingName) async {
    if (!_s.hasOpenFile || !TextFileEncodings.isSupported(encodingName)) return;
    state.value = _s.copyWith(encodingName: encodingName);
    await _saveToPath(_s.currentPath!);
  }

  Future<void> openSettings() async {
    await requestSettingsAsync?.call();
  }

  // ---- Helpers ----

  static String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? normalized : parts.last;
  }

  static String _errorMsg(Object error) {
    final msg = error.toString();
    // Strip any leading Instance of ... wrapping from toString() noise.
    if (msg.length > 240) return '${msg.substring(0, 240)}…';
    return msg;
  }
}
