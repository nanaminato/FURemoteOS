import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';

import '../../../core/commands/base_view_model.dart';
import '../../files/text_file_encodings.dart';
import '../domain/code_editor_models.dart';
import '../domain/code_editor_repository.dart';
import '../domain/code_editor_ui_state.dart';

typedef RequestCodeEditorPath = Future<String?> Function();
typedef RequestCodeEditorSavePath = Future<String?> Function(
    String defaultName);
typedef RequestDiscardDocument = Future<bool> Function(
    CodeEditorDocument document);

/// Presentation logic for one Code Editor window.
///
/// Remote I/O is isolated behind [CodeEditorRepository]. The callbacks
/// describe owner-window picker and modal workflows; their Flutter
/// implementation is installed by the View and is never referenced here.
class CodeEditorViewModel extends ViewModel {
  CodeEditorViewModel({
    required CodeEditorRepository repository,
    String? initialPath,
    bool pathCaseSensitive = true,
    String defaultEncodingName = 'UTF-8',
  })  : _repository = repository,
        _initialPath = initialPath,
        _pathCaseSensitive = pathCaseSensitive {
    state = ValueNotifier(CodeEditorUiState.initial(
      defaultEncodingName: TextFileEncodings.isSupported(defaultEncodingName)
          ? defaultEncodingName
          : 'UTF-8',
    ));
    trackDisposable(state);
    trackDisposable(newDocumentCommand);
    trackDisposable(openDocumentCommand);
    trackDisposable(saveCommand);
    trackDisposable(saveAsCommand);
    trackDisposable(addFolderCommand);
    trackDisposable(refreshFolderCommand);
    trackDisposable(removeFolderCommand);
    trackDisposable(closeDocumentCommand);
  }

  final CodeEditorRepository _repository;
  final String? _initialPath;
  final bool _pathCaseSensitive;
  int _untitledSequence = 0;

  late final ValueNotifier<CodeEditorUiState> state;

  RequestCodeEditorPath? requestFilePath;
  RequestCodeEditorPath? requestFolderPath;
  RequestCodeEditorSavePath? requestSavePath;
  RequestDiscardDocument? requestDiscardDocument;

  CodeEditorUiState get _s => state.value;
  void _set(CodeEditorUiState next) => state.value = next;
  bool get canSave => !_s.isLoading && _s.activeDocument != null;

  late final newDocumentCommand =
      Command.createSyncNoParamNoResult(newDocument);
  late final openDocumentCommand =
      Command.createAsyncNoParamNoResult(requestOpenDocument);
  late final saveCommand = Command.createAsyncNoParamNoResult(save);
  late final saveAsCommand = Command.createAsyncNoParamNoResult(saveAs);
  late final addFolderCommand = Command.createAsyncNoParamNoResult(addFolder);
  late final refreshFolderCommand =
      Command.createAsyncNoParamNoResult(refreshSelectedFolder);
  late final removeFolderCommand =
      Command.createSyncNoParamNoResult(removeSelectedFolder);
  late final closeDocumentCommand =
      Command.createAsyncNoParamNoResult(closeActiveDocument);

  Future<void> loadInitialDocument() async {
    final path = _initialPath;
    if (path != null && path.isNotEmpty) await openPath(path);
  }

  void newDocument() {
    final document = CodeEditorDocument(
      id: 'untitled-${++_untitledSequence}',
      path: null,
      text: '',
      encodingName: _s.defaultEncodingName,
      untitledName: 'Untitled $_untitledSequence',
    );
    _set(_s.copyWith(
      documents: [..._s.documents, document],
      activeDocumentId: document.id,
      statusKey: 'code_editor.status.new_document',
      statusArguments: const [],
    ));
  }

  Future<void> requestOpenDocument() async {
    final path = await requestFilePath?.call();
    if (path != null && path.isNotEmpty) await openPath(path);
  }

  Future<void> openPath(String path, {bool forceReload = false}) async {
    final existing = _documentAtPath(path);
    if (existing != null && !forceReload) {
      activateDocument(existing.id);
      return;
    }
    if (existing?.isDirty == true) {
      _set(_s.copyWith(
        statusKey: 'code_editor.status.save_or_discard',
        statusArguments: const [],
      ));
      return;
    }
    _set(_s.copyWith(isLoading: true));
    try {
      final encoding = existing?.encodingName ?? _s.defaultEncodingName;
      final text = await _repository.readText(path, encoding);
      if (text == null) {
        _set(_s.copyWith(
          isLoading: false,
          statusKey: 'code_editor.status.file_missing',
          statusArguments: const [],
        ));
        return;
      }
      final document = existing ??
          CodeEditorDocument(
            id: path,
            path: path,
            text: text,
            encodingName: encoding,
            untitledName: 'Untitled ${++_untitledSequence}',
          );
      final documents = [
        for (final item in _s.documents)
          if (item.id == document.id)
            document.copyWith(text: text, isDirty: false)
          else
            item,
        if (existing == null) document,
      ];
      _set(_s.copyWith(
        documents: documents,
        activeDocumentId: document.id,
        isLoading: false,
        statusKey: 'code_editor.status.opened',
        statusArguments: [document.displayName, encoding],
      ));
    } catch (_) {
      _set(_s.copyWith(
        isLoading: false,
        statusKey: 'code_editor.status.open_failed',
        statusArguments: const [],
      ));
    }
  }

  Future<void> save() async {
    var document = _s.activeDocument;
    if (document == null) {
      newDocument();
      document = _s.activeDocument;
    }
    if (document == null) return;
    final path = document.path;
    if (path == null || path.isEmpty) return saveAs();
    await _saveToPath(document, path);
  }

  Future<void> saveAs() async {
    var document = _s.activeDocument;
    if (document == null) {
      newDocument();
      document = _s.activeDocument;
    }
    if (document == null) return;
    final path = await requestSavePath?.call(document.displayName);
    if (path != null && path.isNotEmpty) await _saveToPath(document, path);
  }

  Future<void> _saveToPath(CodeEditorDocument document, String path) async {
    _set(_s.copyWith(isLoading: true));
    try {
      await _repository.writeText(path, document.text, document.encodingName);
      final saved = document.copyWith(path: path, isDirty: false);
      _set(_s.copyWith(
        documents: [
          for (final item in _s.documents)
            if (item.id == document.id) saved else item,
        ],
        isLoading: false,
        statusKey: 'code_editor.status.saved',
        statusArguments: [saved.displayName, saved.encodingName],
      ));
    } catch (_) {
      _set(_s.copyWith(
        isLoading: false,
        statusKey: 'code_editor.status.save_failed',
        statusArguments: const [],
      ));
    }
  }

  void updateActiveDocument(String text) {
    final active = _s.activeDocument;
    if (active == null || active.text == text) return;
    _set(_s.copyWith(documents: [
      for (final item in _s.documents)
        if (item.id == active.id)
          item.copyWith(text: text, isDirty: true)
        else
          item,
    ]));
  }

  void activateDocument(String id) {
    if (_s.documents.every((document) => document.id != id)) return;
    _set(_s.copyWith(activeDocumentId: id));
  }

  Future<void> closeActiveDocument() async {
    final document = _s.activeDocument;
    if (document == null) return;
    if (document.isDirty &&
        !(await requestDiscardDocument?.call(document) ?? false)) {
      return;
    }
    final index = _s.documents.indexWhere((item) => item.id == document.id);
    final remaining = [..._s.documents]..removeAt(index);
    final next = remaining.isEmpty
        ? null
        : remaining[index.clamp(0, remaining.length - 1)];
    _set(_s.copyWith(
      documents: remaining,
      activeDocumentId: next?.id,
      clearActiveDocument: next == null,
    ));
  }

  void setSidebar(CodeEditorSidebar sidebar) =>
      _set(_s.copyWith(sidebar: sidebar, isSidebarVisible: true));
  void toggleSidebar() =>
      _set(_s.copyWith(isSidebarVisible: !_s.isSidebarVisible));
  void toggleWordWrap() => _set(_s.copyWith(wordWrap: !_s.wordWrap));
  void setFontSize(double size) =>
      _set(_s.copyWith(fontSize: size.clamp(12, 20).toDouble()));
  void setDefaultEncoding(String name) {
    if (TextFileEncodings.isSupported(name)) {
      _set(_s.copyWith(defaultEncodingName: name));
    }
  }

  Future<void> addFolder() async {
    final path = await requestFolderPath?.call();
    if (path == null || path.isEmpty || _rootAtPath(path) != null) return;
    final root = CodeEditorFolderNode(
      name: _fileName(path),
      path: path,
      isDirectory: true,
      isExpanded: true,
    );
    _set(_s.copyWith(workspaceRoots: [..._s.workspaceRoots, root]));
    await refreshFolder(path);
  }

  Future<void> refreshSelectedFolder() async {
    final root = _s.workspaceRoots.firstWhere(
      (node) => node.isExpanded,
      orElse: () =>
          const CodeEditorFolderNode(name: '', path: '', isDirectory: false),
    );
    if (root.path.isNotEmpty) await refreshFolder(root.path);
  }

  Future<void> refreshFolder(String path) async {
    final node = _nodeAtPath(path);
    if (node == null || !node.isDirectory) return;
    _replaceNode(node.copyWith(isLoading: true));
    try {
      final children = await _repository.listFolder(path);
      _replaceNode(
          node.copyWith(children: children, isLoading: false, isLoaded: true));
    } catch (_) {
      _replaceNode(node.copyWith(isLoading: false));
    }
  }

  Future<void> toggleFolder(String path) async {
    final node = _nodeAtPath(path);
    if (node == null || !node.isDirectory) return;
    final expanded = !node.isExpanded;
    _replaceNode(node.copyWith(isExpanded: expanded));
    if (expanded && !node.isLoaded) await refreshFolder(path);
  }

  void removeSelectedFolder() {
    final root = _s.workspaceRoots.firstWhere(
      (node) => node.isExpanded,
      orElse: () =>
          const CodeEditorFolderNode(name: '', path: '', isDirectory: false),
    );
    if (root.path.isEmpty) return;
    _set(_s.copyWith(
      workspaceRoots:
          _s.workspaceRoots.where((item) => item.path != root.path).toList(),
      statusKey: 'code_editor.status.folder_removed',
      statusArguments: [root.name],
    ));
  }

  void _replaceNode(CodeEditorFolderNode next) => _set(_s.copyWith(
        workspaceRoots: [
          for (final root in _s.workspaceRoots) _replaceNodeInTree(root, next),
        ],
      ));

  CodeEditorFolderNode _replaceNodeInTree(
      CodeEditorFolderNode current, CodeEditorFolderNode next) {
    if (_pathsEqual(current.path, next.path)) return next;
    if (!current.isDirectory || current.children.isEmpty) return current;
    return current.copyWith(
      children: [
        for (final child in current.children) _replaceNodeInTree(child, next),
      ],
    );
  }

  CodeEditorDocument? _documentAtPath(String path) {
    for (final document in _s.documents) {
      if (document.path != null && _pathsEqual(document.path!, path)) {
        return document;
      }
    }
    return null;
  }

  CodeEditorFolderNode? _rootAtPath(String path) {
    for (final root in _s.workspaceRoots) {
      if (_pathsEqual(root.path, path)) return root;
    }
    return null;
  }

  CodeEditorFolderNode? _nodeAtPath(String path) {
    for (final root in _s.workspaceRoots) {
      final found = _findNode(root, path);
      if (found != null) return found;
    }
    return null;
  }

  CodeEditorFolderNode? _findNode(CodeEditorFolderNode node, String path) {
    if (_pathsEqual(node.path, path)) return node;
    for (final child in node.children) {
      final found = _findNode(child, path);
      if (found != null) return found;
    }
    return null;
  }

  bool _pathsEqual(String left, String right) => _pathCaseSensitive
      ? left == right
      : left.toLowerCase() == right.toLowerCase();

  static String _fileName(String path) {
    final values =
        path.replaceAll('\\', '/').split('/').where((item) => item.isNotEmpty);
    return values.isEmpty ? path : values.last;
  }
}
