// Notepad ViewModel.
//
// Presentation owner for one Notepad window. Mirrors Client.Apps.Notepad.
// NotepadViewModel on a best-effort basis: Text, CurrentPath, EncodingName,
// DefaultEncodingName, FontSize, IsDirty, StatusText plus the derived
// CharCount / LineCount / DocumentName / HasOpenFile helpers, and the six
// commands New / Open / Save / SaveAs / ChooseEncoding / OpenSettings
// (plus CloseSettings consumed by the settings modal).
//
// Localization (AGENTS.md §23.1): this file only stores raw data values
// (file / encoding / error strings) inside a `statusNamedArgs` map.
// The View is the single place that calls `.tr(namedArgs: ...)`.

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';

import '../../../app/dependency_injection.dart' as app_di;
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
typedef RequestDiscardChangesAsync = Future<bool> Function();

/// Signature for "open the Notepad settings modal".
typedef RequestSettingsAsync = Future<void> Function();

/// Signature for "ask whether to reopen or save with the new encoding".
typedef RequestEncodingActionAsync = Future<EncodingDialogAction?> Function();

/// Signature for "let the user pick one supported encoding, with the
/// currently active one optionally supplied as default selection".
typedef RequestEncodingAsync = Future<String?> Function([String? currentEncoding]);

/// Signature for "persist the new default-encoding preference".
typedef SaveDefaultEncodingAsync = Future<void> Function(String encoding);

NotepadViewModel createNotepadViewModel() => NotepadViewModel(
      repository: app_di.getService<TextFileRepository>(),
      workspaceSync: app_di.getService<WorkspaceSyncCoordinator>(),
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

    final preferences = _workspaceSync.debugPreferencesSnapshot();
    final stored = preferences?.notepadDefaultEncoding;
    final defaultEncoding = TextFileEncodings.isSupported(stored)
        ? stored!
        : TextFileEncodings.defaultEncoding;
    state.value = NotepadUiState.initial(defaultEncodingName: defaultEncoding);
  }

  final TextFileRepository _repository;
  final WorkspaceSyncCoordinator _workspaceSync;
  bool _isLoading = false;

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

  // ---- Derived properties shared with the settings dialog ----

  List<String> get availableEncodings => TextFileEncodings.available;

  List<double> get fontSizes => const [12, 13, 14, 16, 18, 20];

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

  // ---- CloseSettingsCommand (mirrors Avalonia RelayCommand) ----

  VoidCallback? closeSettingsAction;
  void closeSettings() => closeSettingsAction?.call();

  // ---- View -> VM text edits ----

  void onTextChanged(String text) {
    if (_isLoading) return;
    state.value = _s.copyWith(text: text);
    if (!_s.isDirty) {
      state.value = _s.copyWith(isDirty: true);
    }
  }

  // ---- Settings / encoding setters used from the UI ----

  void setFontSize(double size) {
    state.value = _s.copyWith(fontSize: size);
  }

  void setDefaultEncoding(String encoding) {
    if (!TextFileEncodings.isSupported(encoding)) return;
    state.value = _s.copyWith(defaultEncodingName: encoding);
    saveDefaultEncodingAsync?.call(encoding);
    _persistDefaultEncoding(encoding);
  }

  /// Switch the *current* working encoding without reopening or saving.
  ///
  /// Used from the StatusBar encoding picker when there is no open file:
  /// the picked encoding becomes the one that subsequent "save first time"
  /// or "save as" flows use, mirroring a user-specified override before any
  /// file is touched on disk.
  void setWorkingEncoding(String encoding) {
    final candidate = encoding.trim();
    if (!TextFileEncodings.isSupported(candidate)) return;
    state.value = _s.copyWith(encodingName: candidate);
  }

  Future<void> _persistDefaultEncoding(String encoding) async {
    final current = _workspaceSync.debugPreferencesSnapshot();
    if (current == null) return;
    _workspaceSync
        .queuePreferences(current.copyWith(notepadDefaultEncoding: encoding));
  }

  // ---- Document commands (mirror Avalonia 1:1) ----

  Future<void> newDocument() async {
    _isLoading = true;
    state.value = NotepadUiState.initial(
      defaultEncodingName: _s.defaultEncodingName,
      encodingName: _s.defaultEncodingName,
    ).copyWith(
      fontSize: _s.fontSize,
      statusKey: 'notepad.status.new_document',
    );
    _isLoading = false;
  }

  Future<void> openDocument() async {
    final path = await requestFileAsync?.call();
    if (path == null || path.trim().isEmpty) return;
    await openPath(path);
  }

  Future<void> openPath(String path, [String? requestedEncoding]) async {
    if (_repository.isNotConnected) {
      state.value = _s.copyWith(
        statusKey: 'notepad.status.connect_before_open',
      );
      return;
    }
    final encoding = requestedEncoding ?? _s.defaultEncodingName;
    try {
      final decoded = await _repository.readText(path, encoding);
      if (decoded == null) {
        state.value = _s.copyWith(
          statusKey: 'notepad.status.file_missing',
        );
        return;
      }
      _isLoading = true;
      state.value = _s.copyWith(
        text: decoded,
        encodingName: encoding,
        currentPath: path,
        isDirty: false,
        statusKey: 'notepad.status.opened',
        statusNamedArgs: <String, String>{
          'file': _baseName(path),
          'encoding': encoding,
        },
      );
    } catch (error) {
      state.value = _s.copyWith(
        statusKey: 'notepad.status.open_failed',
        statusNamedArgs: <String, String>{'error': _errorMsg(error)},
      );
    } finally {
      _isLoading = false;
    }
  }

  Future<void> save() async {
    var path = _s.currentPath;
    if (path == null || path.trim().isEmpty) {
      path = await requestSavePathAsync?.call('untitled.txt');
    }
    if (path == null || path.trim().isEmpty) return;
    await saveToPath(path);
  }

  Future<void> saveAs() async {
    final suggestedName = (_s.currentPath == null || _s.currentPath!.trim().isEmpty)
        ? 'untitled.txt'
        : _baseName(_s.currentPath!);
    final path = await requestSavePathAsync?.call(suggestedName);
    if (path == null || path.trim().isEmpty) return;
    await saveToPath(path);
  }

  Future<void> saveToPath(String path) async {
    if (_repository.isNotConnected) {
      state.value = _s.copyWith(
        statusKey: 'notepad.status.connect_before_save',
      );
      return;
    }
    try {
      await _repository.writeText(path, _s.text, _s.encodingName);
      state.value = _s.copyWith(
        currentPath: path,
        isDirty: false,
        statusKey: 'notepad.status.saved',
        statusNamedArgs: <String, String>{
          'file': _baseName(path),
          'encoding': _s.encodingName,
        },
      );
    } catch (error) {
      state.value = _s.copyWith(
        statusKey: 'notepad.status.save_failed',
        statusNamedArgs: <String, String>{'error': _errorMsg(error)},
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
    if (_s.isDirty && !((await requestDiscardChangesAsync?.call()) ?? false)) {
      return;
    }
    state.value = _s.copyWith(encodingName: encodingName);
    await openPath(_s.currentPath!, encodingName);
  }

  Future<void> saveWithEncoding(String encodingName) async {
    if (!_s.hasOpenFile || !TextFileEncodings.isSupported(encodingName)) return;
    state.value = _s.copyWith(encodingName: encodingName);
    await saveToPath(_s.currentPath!);
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
    if (msg.length > 240) return '…';
    return msg;
  }
}