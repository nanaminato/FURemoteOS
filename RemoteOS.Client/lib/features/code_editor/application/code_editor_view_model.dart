// Code Editor ViewModel.
//
// Relies on the existing TextFileRepository (shared with Notepad) for
// remote text I/O with encoding-awareness and file-path validation.
// Document content changes propagate in two directions:
//   * View → VM: view calls [updateDocument] whenever the TextField changes.
//   * VM → View: state.documentText (used by the View to reset the
//     controller's value when a remote file finishes loading).
//
// Parameterised I/O (load) and 1-param void commands (save) follow the same
// plain-async-method pattern used by Docker and Image Viewer ViewModels,
// because command_it v9.x does not expose a 1-param factory.

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/commands/base_view_model.dart';
import '../../files/text_file_encodings.dart';
import '../../notepad/data/text_file_repository.dart';
import '../domain/code_editor_ui_state.dart';

/// Factory used by the code-editor app shell.
CodeEditorViewModel createCodeEditorViewModel({
  required TextFileRepository repository,
  String? remotePath,
  String? fileName,
}) =>
    CodeEditorViewModel(
      repository: repository,
      initialPath: remotePath,
      initialFileName: fileName,
    );

const defaultWelcomeSource = '''import 'package:flutter/material.dart';

void main() {
  runApp(const RemoteOSApp());
}

class RemoteOSApp extends StatelessWidget {
  const RemoteOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Welcome to RemoteOS')),
      ),
    );
  }
}
''';

class CodeEditorViewModel extends ViewModel {
  CodeEditorViewModel({
    required TextFileRepository repository,
    String? initialPath,
    String? initialFileName,
  }) : _repository = repository {
    state = ValueNotifier<CodeEditorUiState>(
      CodeEditorUiState.initial(
        remotePath: initialPath,
        fileName: initialFileName,
        initialDocument: defaultWelcomeSource,
      ),
    );
    trackDisposable(state);
    trackDisposable(saveCommand);
    trackDisposable(toggleWordWrapCommand);
    trackDisposable(toggleExplorerCommand);
    trackDisposable(increaseFontSizeCommand);
    trackDisposable(decreaseFontSizeCommand);
  }

  final TextFileRepository _repository;

  late final ValueNotifier<CodeEditorUiState> state;

  CodeEditorUiState get _s => state.value;
  void _mutate(CodeEditorUiState Function(CodeEditorUiState s) fn) =>
      state.value = fn(state.value);

  // ---- Gate helpers for the View layer ----

  bool canSave() => !_s.isLoading && _s.isDirty && _s.remotePath != null;
  bool get isLoading => _s.isLoading;

  // ---- Pure UI toggle commands (NoParam sync) ----

  late final toggleWordWrapCommand = Command.createSyncNoParamNoResult(
    () => _mutate((s) => s.copyWith(wordWrap: !s.wordWrap)),
  );

  late final toggleExplorerCommand = Command.createSyncNoParamNoResult(
    () => _mutate((s) => s.copyWith(showExplorer: !s.showExplorer)),
  );

  late final increaseFontSizeCommand = Command.createSyncNoParamNoResult(
    () => _mutate(
        (s) => s.copyWith(fontSize: (s.fontSize + 1).clamp(10.0, 28.0))),
  );

  late final decreaseFontSizeCommand = Command.createSyncNoParamNoResult(
    () => _mutate(
        (s) => s.copyWith(fontSize: (s.fontSize - 1).clamp(10.0, 28.0))),
  );

  // ---- Data I/O: save is NoParam async command; load is parameterised → method ----

  /// Persists the document to the current remotePath (no-op if unsaved or no path).
  late final saveCommand = Command.createAsyncNoParamNoResult(() async {
    final path = _s.remotePath;
    if (path == null || !_s.isDirty) return;
    _mutate((s) => s.copyWith(isLoading: true, clearError: true));
    try {
      await _repository.writeText(
          path, _s.documentText, TextFileEncodings.defaultEncoding);
      _mutate((s) => s.copyWith(isDirty: false, isLoading: false));
    } catch (error) {
      _mutate((s) => s.copyWith(
            errorMessage: '$error',
            isLoading: false,
          ));
    }
  });

  /// Loads remotePath's text content into the document.
  Future<void> load(String path) async {
    if (isLoading) return;
    _mutate((s) => s.copyWith(isLoading: true, clearError: true));
    try {
      final content =
          await _repository.readText(path, TextFileEncodings.defaultEncoding) ??
              '';
      _mutate((s) => s.copyWith(
            documentText: content,
            isDirty: false,
            isLoading: false,
          ));
    } catch (_) {
      _mutate((s) => s.copyWith(
            documentText: 'Unable to open remote text file.',
            isLoading: false,
          ));
    }
  }

  // ---- View-to-VM setters (not commands: pure local state updates) ----

  void updateDocument(String text) {
    if (text == _s.documentText) return;
    _mutate((s) => s.copyWith(documentText: text, isDirty: true));
  }

  void setSearch(String value) => _mutate((s) => s.copyWith(searchText: value));

  /// Trigger remote load from the shell-supplied path once build is ready.
  void scheduleInitialLoad() {
    final path = _s.remotePath;
    if (path == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      load(path);
    });
  }
}
