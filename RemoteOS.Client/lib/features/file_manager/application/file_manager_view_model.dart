// File Manager ViewModel.
//
// Responsibilities (matches Avalonia's merged ExplorerViewModel):
//   * loads navigation root (special locations + drives) →
//     `loadRootCommand`;
//   * navigates directories with a forward/backward/up history stack;
//   * exposes typed commands for new/rename/delete/copy/paste/up/download/
//     upload/openWith/terminal/properties/confirmPicker;
//   * keeps file-picker state machine separate from the desktop Explorer so
//     pickers can share the same implementation (mirrors
//     `ExplorerViewModel.IsPickerMode`).
//
// Dialogs + pickers + file-selection native helpers are requested through
// explicit callback hooks set by the View — never `BuildContext`.

import 'dart:async';
import 'dart:io';

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';

import '../../../app/dependency_injection.dart' as app_di;
import '../../../core/commands/base_view_model.dart';
import '../../../core/errors/remote_os_failure.dart';
import '../../files/data/remote_file_api.dart';
import '../data/file_manager_repository.dart';
import '../domain/file_manager_models.dart';
import '../domain/file_manager_ui_state.dart';
import '../../../../apps/explorer/explorer_picker.dart';

// ---- Callback hook signatures ----

typedef FmRequestTextAsync = Future<String?> Function(
  String title,
  String initialValue,
  String confirmLabel,
);
typedef FmRequestConfirmAsync = Future<bool> Function(
    String title, String message, String confirmLabel);
typedef FmRequestLocalFilesAsync = Future<List<File>> Function();
typedef FmRequestLocalFolderAsync = Future<String?> Function();
typedef FmRequestClipboardFilesAsync = Future<List<String>> Function();
typedef FmRequestLocalSaveFileAsync = Future<String?> Function(
    String suggestedName);
typedef FmShowMessageAsync = Future<void> Function(String message);
typedef FmShowErrorAsync = void Function(Object error);
typedef FmOpenFileAppAsync = Future<void> Function(
    FileItem entry, OpenWithChoice? choice);
typedef FmOpenWithChooseAsync = Future<OpenWithChoice?> Function(
    FileItem entry, List<OpenWithCandidate> candidates);
typedef FmOpenTerminalAsync = void Function(String workingDirectory);
typedef FmShowPropertiesAsync = Future<void> Function(
    RemoteFileProperties properties);
typedef FmConfirmPickerAsync = void Function(List<String> paths);
typedef FmCancelPickerAsync = void Function();

// ---- Factory ----

FileManagerViewModel createFileManagerViewModel({
  ExplorerPickerOptions? picker,
}) {
  return FileManagerViewModel(
    repository: app_di.getService<FileManagerRepository>(),
    picker: picker,
  );
}

class FileManagerViewModel extends ViewModel {
  FileManagerViewModel({
    required FileManagerRepository repository,
    ExplorerPickerOptions? picker,
  }) : _repository = repository {
    state = ValueNotifier<FileManagerUiState>(
        FileManagerUiState.initial(picker: picker));
    trackDisposable(state);
    trackDisposable(loadRootCommand);
    trackDisposable(navigateBackCommand);
    trackDisposable(navigateForwardCommand);
    trackDisposable(goUpCommand);
    trackDisposable(newFolderCommand);
    trackDisposable(renameCommand);
    trackDisposable(deleteCommand);
    trackDisposable(copyCommand);
    trackDisposable(cutCommand);
    trackDisposable(pasteCommand);
    trackDisposable(uploadFilesCommand);
    trackDisposable(uploadFolderCommand);
    trackDisposable(pasteHostFilesCommand);
    trackDisposable(downloadCommand);
    trackDisposable(propertiesCommand);
    trackDisposable(refreshCommand);
    trackDisposable(confirmPickerCommand);
  }

  final FileManagerRepository _repository;

  late final ValueNotifier<FileManagerUiState> state;
  FileManagerUiState get _s => state.value;

  // ---- Hooks (View injects) ----

  FmRequestTextAsync? requestTextAsync;
  FmRequestConfirmAsync? requestConfirmAsync;
  FmRequestLocalFilesAsync? requestLocalFilesAsync;
  FmRequestLocalFolderAsync? requestLocalFolderAsync;
  FmRequestClipboardFilesAsync? requestClipboardFilesAsync;
  FmRequestLocalSaveFileAsync? requestLocalSaveFileAsync;
  FmShowMessageAsync? showMessageAsync;
  FmShowErrorAsync? showError;
  FmOpenFileAppAsync? openFileAppAsync;
  FmOpenWithChooseAsync? openWithChooseAsync;
  FmOpenTerminalAsync? openTerminal;
  FmShowPropertiesAsync? showPropertiesAsync;
  FmConfirmPickerAsync? confirmPicker;
  FmCancelPickerAsync? onCancelPicker;

  // ---- Commands ----

  late final loadRootCommand = Command.createAsyncNoParamNoResult(loadRoot);
  late final navigateBackCommand =
      Command.createSyncNoParamNoResult(navigateBack);
  late final navigateForwardCommand =
      Command.createSyncNoParamNoResult(navigateForward);
  late final goUpCommand = Command.createSyncNoParamNoResult(goUp);
  late final newFolderCommand = Command.createAsyncNoParamNoResult(newFolder);
  late final renameCommand = Command.createAsyncNoParamNoResult(renameSelected);
  late final deleteCommand = Command.createAsyncNoParamNoResult(deleteSelected);
  late final copyCommand = Command.createSyncNoParamNoResult(copySelection);
  late final cutCommand = Command.createSyncNoParamNoResult(cutSelection);
  late final pasteCommand = Command.createAsyncNoParamNoResult(paste);
  late final uploadFilesCommand =
      Command.createAsyncNoParamNoResult(uploadFiles);
  late final uploadFolderCommand =
      Command.createAsyncNoParamNoResult(uploadFolder);
  late final pasteHostFilesCommand =
      Command.createAsyncNoParamNoResult(pasteHostFiles);
  late final downloadCommand =
      Command.createAsyncNoParamNoResult(downloadSelected);
  late final propertiesCommand =
      Command.createAsyncNoParamNoResult(showSelectedProperties);
  late final refreshCommand = Command.createAsyncNoParamNoResult(refresh);
  late final confirmPickerCommand =
      Command.createSyncNoParamNoResult(commitPicker);

  // ---- View-controller sync methods ----

  void setSelectedNodePath(String? path) {
    state.value = _s.copyWith(
      selectedNodePath: path,
      clearSelectedNodePath: path == null,
    );
  }

  void updateSearch(String value) {
    state.value = _s.copyWith(searchText: value);
  }

  void toggleDetailsView() =>
      state.value = _s.copyWith(detailsView: !_s.detailsView);

  void selectEntry(FileItem entry, {bool toggle = false}) {
    final next = Set<String>.from(_s.selectedPaths);
    if (toggle) {
      if (!next.add(entry.path)) next.remove(entry.path);
    } else {
      next
        ..clear()
        ..add(entry.path);
    }
    final s2 = _s.copyWith(selectedPaths: next);
    if (s2.isPickerMode) state.value = _refreshPickerName(s2);
  }

  void clearSelection() {
    final s2 = _s.copyWith(selectedPaths: const <String>{});
    if (s2.isPickerMode) state.value = _refreshPickerName(s2);
  }

  void setPickerEntryName(String value, {bool fromUserTyping = true}) {
    state.value = _s.copyWith(pickerEntryName: value);
  }

  void setPickerSelectedFilter(ExplorerFileFilter filter) {
    state.value = _s.copyWith(pickerSelectedFilter: filter);
  }

  FileManagerUiState _refreshPickerName(FileManagerUiState s) {
    if (!s.isPickerMode) return s;
    final selection = s.selectedEntries();
    final filter = s.pickerSelectedFilter;
    String name = '';
    if (s.isFolderPickerMode) {
      final folder = selection.where((e) => e.isFolder).firstOrNull;
      name = folder?.name ?? '';
    } else if (s.isSaveFilePickerMode) {
      final files = selection.where((e) {
        if (e.isFolder) return false;
        return filter.matches(e.name) || filter.patterns.contains('*');
      }).toList(growable: false);
      if (files.isNotEmpty) name = files.first.name;
    } else if (s.allowMultipleFiles) {
      final files = selection.where((e) {
        if (e.isFolder) return false;
        return filter.matches(e.name) || filter.patterns.contains('*');
      }).toList(growable: false);
      name = files.isEmpty ? '' : files.map((e) => '"${e.name}"').join(' ');
    } else {
      final files = selection.where((e) {
        if (e.isFolder) return false;
        return filter.matches(e.name) || filter.patterns.contains('*');
      }).toList(growable: false);
      name = files.isEmpty ? '' : files.first.name;
    }
    return s.copyWith(pickerEntryName: name);
  }

  bool get canConfirmPicker {
    final s = _s;
    if (!s.isPickerMode) return false;
    if (s.isFolderPickerMode) {
      return s.selectedEntries().any((e) => e.isFolder) ||
          s.currentPath.isNotEmpty;
    }
    if (s.isSaveFilePickerMode) {
      return s.pickerEntryName.trim().isNotEmpty && s.currentPath.isNotEmpty;
    }
    if (s.pickerEntryName.trim().isNotEmpty && !s.allowMultipleFiles) {
      return true;
    }
    if (s.allowMultipleFiles) {
      final f = s.pickerSelectedFilter;
      return s.selectedEntries().any((e) =>
          !e.isFolder && (f.matches(e.name) || f.patterns.contains('*')));
    }
    final f = s.pickerSelectedFilter;
    return s.selectedEntries().any(
        (e) => !e.isFolder && (f.matches(e.name) || f.patterns.contains('*')));
  }

  bool isSelectableForPicker(FileItem entry) {
    final s = _s;
    if (!s.isFilePickerMode &&
        !s.isMultiFilePickerMode &&
        !s.isSaveFilePickerMode) {
      return false;
    }
    if (entry.isFolder) return false;
    final f = s.pickerSelectedFilter;
    return f.matches(entry.name) || f.patterns.contains('*');
  }

  // ---- Navigation ----

  void navigateBack() {
    final s = _s;
    final idx = s.historyIndex - 1;
    if (idx < 0) return;
    _navigateHistory(idx);
  }

  void navigateForward() {
    final s = _s;
    final idx = s.historyIndex + 1;
    if (idx >= s.history.length) return;
    _navigateHistory(idx);
  }

  void goUp() {
    final s = _s;
    if (s.currentPath.isEmpty) return;
    final normalized = s.currentPath.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    if (slash < 0) return;
    final parent = slash == 0 ? '/' : s.currentPath.substring(0, slash);
    navigate(_fileName(parent), parent);
  }

  void _navigateHistory(int index) {
    final s = _s;
    if (index < 0 || index >= s.history.length) return;
    final path = s.history[index];
    final location = _fileName(path);
    state.value = s.copyWith(
      historyIndex: index,
      currentPath: path,
      locationName: location,
      selectedPaths: const <String>{},
    );
    unawaited(_load(path));
  }

  void navigate(String location, String path) {
    final s = _s;
    if (path == s.currentPath && s.historyIndex >= 0) return;
    final history = List<String>.from(s.history);
    if (s.historyIndex < history.length - 1) {
      history.removeRange(s.historyIndex + 1, history.length);
    }
    history.add(path);
    final idx = history.length - 1;
    state.value = s.copyWith(
      locationName: location,
      currentPath: path,
      selectedPaths: const <String>{},
      history: history,
      historyIndex: idx,
    );
    final post = _refreshPickerName(state.value);
    if (!identical(post, state.value)) state.value = post;
    unawaited(_load(path));
  }

  // ---- Loaders ----

  Future<void> loadRoot() async {
    state.value = _s.copyWith(
      isLoading: true,
      statusKey: 'explorer.status.loading_navigation',
      statusArgs: const {},
    );
    try {
      final results = await Future.wait([
        _repository.specialLocations(),
        _repository.drives(),
      ]);
      final specials = results[0] as List<RemoteSpecialLocation>;
      final drives = results[1] as List<RemoteDrive>;

      final home = specials.where((s) {
            final name = s.name.toLowerCase();
            return name == 'home';
          }).firstOrNull ??
          (specials.isNotEmpty ? specials.first : null);

      final nodes = <TreeNodeItem>[];

      // (1) Home group + quick access
      final homeChildren = specials.where((s) => !identical(s, home)).map((s) {
        final name = s.name.toLowerCase();
        final kind = _kindForSpecialName(name);
        return TreeNodeItem(
          name: s.name,
          path: s.path,
          kind: kind,
        );
      }).toList(growable: false);
      nodes.add(TreeNodeItem(
        name: 'explorer.home',
        path: home?.path,
        kind: TreeNodeKind.home,
        children: homeChildren,
        isExpanded: true,
      ));

      // (2) This PC (drives + lazy-load dummy children)
      final driveChildren = drives.map((d) {
        return TreeNodeItem(
          name: d.name,
          path: d.path,
          kind: TreeNodeKind.drive,
          hasDummyChild: true,
        );
      }).toList(growable: false);
      nodes.add(TreeNodeItem(
        name: 'explorer.computer',
        path: null,
        kind: TreeNodeKind.computer,
        children: driveChildren,
        isExpanded: true,
      ));

      // (3) Network placeholder
      nodes.add(const TreeNodeItem(
        name: 'explorer.network',
        path: null,
        kind: TreeNodeKind.network,
      ));

      final initialPath = home?.path ??
          (specials.isNotEmpty ? specials.first.path : null) ??
          (drives.isNotEmpty ? drives.first.path : '');
      final initialLocation = home?.name ??
          (specials.isNotEmpty
              ? specials.first.name
              : (drives.isNotEmpty ? drives.first.name : ''));

      final s2 = _s.copyWith(
        navigationNodes: nodes,
        isLoading: false,
        loadError: null,
        statusKey: 'explorer.status.root_ready',
        statusArgs: const {},
        currentPath: _initialCurrentPath(_s, initialPath),
        locationName: _initialCurrentPath(_s, initialLocation),
        history: _initialHistory(_s, initialPath),
        historyIndex: _initialHistoryIndex(_s, initialPath),
      );
      state.value = s2;
    } catch (error) {
      state.value = _s.copyWith(
        isLoading: false,
        statusKey: 'explorer.status.load_failed',
        statusArgs: {'error': _err(error)},
      );
    }
    if (_s.currentPath.isNotEmpty) {
      await _load(_s.currentPath);
    }
  }

  // These helpers exist purely to avoid read-after-write issues inside the
  // copyWith closure: Dart evaluates named parameters eagerly.
  static String _initialCurrentPath(FileManagerUiState s, String fallback) {
    final current = s.currentPath;
    return current.isEmpty ? fallback : current;
  }

  static List<String> _initialHistory(
      FileManagerUiState s, String initialPath) {
    if (s.history.isNotEmpty) return s.history;
    if (initialPath.isEmpty) return const [];
    return <String>[initialPath];
  }

  static int _initialHistoryIndex(FileManagerUiState s, String initialPath) {
    if (s.historyIndex >= 0) return s.historyIndex;
    return initialPath.isEmpty ? -1 : 0;
  }

  Future<void> _load(String path) async {
    state.value = _s.copyWith(isLoading: true, loadError: null);
    try {
      final entries = await _repository.listDirectory(path);
      if (path != state.value.currentPath) return;
      final nowSelected = Set<String>.from(state.value.selectedPaths)
        ..removeWhere((p) => !entries.any((e) => e.path == p));
      state.value = state.value.copyWith(
        entries: entries,
        selectedPaths: nowSelected,
        isLoading: false,
      );
    } catch (error) {
      if (path != state.value.currentPath) return;
      state.value = state.value.copyWith(
        isLoading: false,
        loadError: error.toString(),
        statusKey: 'explorer.status.path_load_failed',
        statusArgs: {'path': path, 'error': _err(error)},
      );
    }
  }

  Future<void> refresh() => _load(state.value.currentPath);

  // ---- Operations (copy/paste/new/rename/delete/...) ----

  void copySelection() {
    final s = _s;
    if (s.selectedPaths.isEmpty) return;
    state.value = s.copyWith(
      clipboardPaths: s.selectedPaths.toList(growable: false),
      clipboardIsCut: false,
    );
  }

  void cutSelection() {
    final s = _s;
    if (s.selectedPaths.isEmpty) return;
    state.value = s.copyWith(
      clipboardPaths: s.selectedPaths.toList(growable: false),
      clipboardIsCut: true,
    );
  }

  Future<void> paste() async {
    final s = _s;
    final paths = s.clipboardPaths;
    if (paths == null || paths.isEmpty || s.currentPath.isEmpty) return;
    await _runOperation(() async {
      for (final src in paths) {
        final dest = joinPath(s.currentPath, _fileName(src));
        if (s.clipboardIsCut) {
          await _repository.move(src, dest);
        } else {
          await _repository.copy(src, dest);
        }
      }
      if (s.clipboardIsCut) {
        state.value = state.value.copyWith(
          clearClipboardPaths: true,
          clipboardIsCut: false,
        );
      }
    });
  }

  Future<void> uploadFiles() async {
    if (_s.currentPath.isEmpty) return;
    final files = await requestLocalFilesAsync?.call();
    if (files == null || files.isEmpty) return;
    await _runOperation(() async {
      for (final file in files) {
        if (file.path.isEmpty) continue;
        await _repository.upload(_s.currentPath, file);
      }
    });
  }

  Future<void> uploadFolder() async {
    if (_s.currentPath.isEmpty) return;
    final rootPath = await requestLocalFolderAsync?.call();
    if (rootPath == null || rootPath.isEmpty) return;
    await _runOperation(() => _uploadDirectoryTree(rootPath));
  }

  Future<void> pasteHostFiles() async {
    if (_s.currentPath.isEmpty) return;
    final paths = await requestClipboardFilesAsync?.call();
    if (paths == null || paths.isEmpty) return;
    await _runOperation(() async {
      for (final p in paths) {
        if (FileSystemEntity.isFileSync(p)) {
          await _repository.upload(_s.currentPath, File(p));
        } else if (FileSystemEntity.isDirectorySync(p)) {
          await _uploadDirectoryTree(p);
        }
      }
    });
  }

  Future<void> _uploadDirectoryTree(String rootPath) async {
    final root = Directory(rootPath);
    final directories = <Directory>[root];
    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is Directory) directories.add(entity);
      if (entity is File) files.add(entity);
    }
    directories.sort((a, b) => a.path.length.compareTo(b.path.length));
    for (final directory in directories) {
      await _repository
          .createDirectory(_remoteUploadPath(root.path, directory.path));
    }
    for (final file in files) {
      await _repository.upload(
          _remoteUploadPath(root.path, file.parent.path), file);
    }
  }

  String _remoteUploadPath(String root, String localPath) {
    final normalizedRoot =
        root.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = localPath.replaceAll('\\', '/');
    final relative = normalizedPath.startsWith(normalizedRoot)
        ? normalizedPath
            .substring(normalizedRoot.length)
            .replaceFirst(RegExp(r'^/+'), '')
        : _fileName(localPath);
    final segments = <String>[_fileName(root), ...relative.split('/')]
        .where((segment) => segment.isNotEmpty);
    return segments.fold(state.value.currentPath, joinPath);
  }

  Future<void> downloadSelected() async {
    final s = _s;
    final entries = s.selectedEntries().where((e) => !e.isFolder);
    if (entries.length != 1) return;
    final entry = entries.single;
    final destination = await requestLocalSaveFileAsync?.call(entry.name);
    if (destination == null || destination.isEmpty) return;
    await _runOperation(() async {
      await _repository.downloadToFile(entry.path, File(destination));
    });
  }

  Future<void> newFolder() async {
    if (_s.currentPath.isEmpty) return;
    final name = await requestTextAsync?.call(
      'New folder',
      'New folder',
      'Create',
    );
    if (name == null || name.trim().isEmpty) return;
    await _runOperation(
        () => _repository.createDirectory(joinPath(_s.currentPath, name)));
  }

  Future<void> renameSelected() async {
    final s = _s;
    final selection = s.selectedEntries();
    if (selection.length != 1) return;
    final entry = selection.single;
    final name = await requestTextAsync?.call(
      'Rename',
      entry.name,
      'Rename',
    );
    if (name == null || name.trim().isEmpty) return;
    await _runOperation(() => _repository.rename(entry.path, name));
  }

  Future<void> deleteSelected() async {
    final s = _s;
    final selection = s.selectedEntries();
    if (selection.isEmpty) return;
    final message = selection.length == 1
        ? 'This permanently deletes ${selection.single.name}.'
        : 'This permanently deletes ${selection.length} items.';
    final ok = await requestConfirmAsync?.call(
      selection.length == 1
          ? 'Delete ${selection.single.name}?'
          : 'Delete ${selection.length} items?',
      message,
      'Delete',
    );
    if (ok != true) return;
    await _runOperation(() async {
      for (final entry in selection) {
        await _repository.delete(entry.path);
      }
    });
  }

  Future<void> showSelectedProperties() async {
    final s = _s;
    final selection = s.selectedEntries();
    if (selection.length != 1) return;
    try {
      final properties = await _repository.properties(selection.single.path);
      if (properties != null) {
        await showPropertiesAsync?.call(properties);
      }
    } catch (error) {
      showError?.call(error);
    }
  }

  void moveEntry(FileItem source, FileItem target) {
    if (!canMoveEntry(source, target)) return;
    _runOperation(
      () => _repository.move(source.path, joinPath(target.path, source.name)),
    );
  }

  bool canMoveEntry(FileItem source, FileItem target) {
    if (!target.isFolder || source.path == target.path) return false;
    final sp =
        source.path.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
    final tp =
        target.path.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
    if (!source.isFolder) return true;
    return !(tp == sp || tp.startsWith('$sp/'));
  }

  // ---- Open-with dispatch ----

  List<OpenWithCandidate> candidatesFor(FileItem entry) {
    final candidates = <OpenWithCandidate>[];
    if (_isImage(entry)) {
      candidates.add(const OpenWithCandidate('image_viewer', 'Image Viewer'));
    }
    if (_isTextByName(entry)) {
      candidates.add(const OpenWithCandidate('code_editor', 'Code Editor'));
    }
    return candidates;
  }

  Future<bool> isTextContent(FileItem entry) async {
    if (entry.mimeType?.toLowerCase().startsWith('text/') == true) return true;
    try {
      final bytes = await _repository.readBytes(entry.path);
      if (bytes.contains(0)) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openEntry(FileItem entry, {OpenWithChoice? choice}) async {
    if (entry.isFolder) {
      navigate(entry.name, entry.path);
      return;
    }
    final s = _s;
    if (s.isPickerMode) {
      _handlePickerOpen(entry);
      return;
    }
    var candidates = candidatesFor(entry);
    if (candidates.isEmpty && await isTextContent(entry)) {
      candidates = const [
        OpenWithCandidate('code_editor', 'Code Editor'),
      ];
    }
    if (candidates.isEmpty) {
      showError?.call(const UnsupportedOperationFailure());
      return;
    }
    await openFileAppAsync?.call(
      entry,
      choice ?? OpenWithChoice(candidates.first, false),
    );
  }

  Future<void> chooseOpenWith(FileItem entry) async {
    final candidates = candidatesFor(entry);
    if (candidates.isEmpty) return openEntry(entry);
    final choice = await openWithChooseAsync?.call(entry, candidates);
    if (choice == null) return;
    await openFileAppAsync?.call(entry, choice);
  }

  void _handlePickerOpen(FileItem entry) {
    final s = _s;
    if (s.isSaveFilePickerMode && isSelectableForPicker(entry)) {
      selectEntry(entry);
      return;
    }
    if ((s.isFilePickerMode || s.isMultiFilePickerMode) &&
        isSelectableForPicker(entry)) {
      if (s.allowMultipleFiles) {
        selectEntry(entry);
        return;
      }
      selectEntry(entry);
      commitPicker();
    }
  }

  // ---- Picker commit ----

  void commitPicker() {
    final s = _s;
    if (!s.isPickerMode) return;
    final List<String> selected;
    if (s.isFolderPickerMode) {
      final folders = s
          .selectedEntries()
          .where((e) => e.isFolder)
          .map((e) => e.path)
          .toList(growable: false);
      selected = folders.isNotEmpty
          ? folders
          : (s.currentPath.isEmpty
              ? const <String>[]
              : <String>[s.currentPath]);
    } else if (s.isSaveFilePickerMode) {
      final typed = s.pickerEntryName.trim();
      if (typed.isEmpty || s.currentPath.isEmpty) return;
      final resolved = typed.startsWith('/') || typed.startsWith('\\')
          ? typed
          : joinPath(s.currentPath, typed);
      selected = <String>[resolved];
    } else if (s.allowMultipleFiles) {
      final filter = s.pickerSelectedFilter;
      final files = s
          .selectedEntries()
          .where((e) =>
              !e.isFolder &&
              (filter.matches(e.name) || filter.patterns.contains('*')))
          .map((e) => e.path)
          .toList(growable: false);
      if (files.isEmpty && s.pickerEntryName.trim().isNotEmpty) {
        selected = <String>[
          _resolveTypedName(s.currentPath, s.pickerEntryName.trim()),
        ];
      } else {
        selected = files;
      }
    } else {
      final filter = s.pickerSelectedFilter;
      final files = s
          .selectedEntries()
          .where((e) =>
              !e.isFolder &&
              (filter.matches(e.name) || filter.patterns.contains('*')))
          .map((e) => e.path)
          .toList(growable: false);
      if (files.isEmpty && s.pickerEntryName.trim().isNotEmpty) {
        selected = <String>[
          _resolveTypedName(s.currentPath, s.pickerEntryName.trim()),
        ];
      } else {
        selected = files.length > 1 ? <String>[files.first] : files;
      }
    }
    if (selected.isEmpty) return;
    confirmPicker?.call(selected);
  }

  void cancelPicker() => onCancelPicker?.call();

  // ---- Helpers ----

  Future<void> _runOperation(Future<void> Function() operation) async {
    try {
      await operation();
      await _load(state.value.currentPath);
    } catch (error) {
      showError?.call(error);
    }
  }

  static String joinPath(String parent, String name) {
    if (parent.isEmpty) return name;
    final separator = parent.contains('\\') ? '\\' : '/';
    return parent.endsWith(separator)
        ? '$parent$name'
        : '$parent$separator$name';
  }

  static String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((p) => p.isNotEmpty);
    return parts.isEmpty ? normalized : parts.last;
  }

  static String _resolveTypedName(String currentPath, String typed) {
    if (typed.startsWith('/') || typed.startsWith('\\')) return typed;
    return currentPath.isEmpty ? typed : joinPath(currentPath, typed);
  }

  static TreeNodeKind _kindForSpecialName(String lower) {
    switch (lower) {
      case 'desktop':
        return TreeNodeKind.desktop;
      case 'documents':
        return TreeNodeKind.documents;
      case 'downloads':
        return TreeNodeKind.downloads;
      case 'pictures':
        return TreeNodeKind.pictures;
      case 'music':
        return TreeNodeKind.music;
      case 'videos':
        return TreeNodeKind.videos;
      default:
        return TreeNodeKind.folder;
    }
  }

  static bool _isImage(FileItem entry) {
    final name = entry.name.toLowerCase();
    return const ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp']
        .any(name.endsWith);
  }

  static bool _isTextByName(FileItem entry) {
    if (entry.mimeType?.toLowerCase().startsWith('text/') == true) return true;
    final name = entry.name.toLowerCase();
    return const [
      '.txt',
      '.md',
      '.json',
      '.yaml',
      '.yml',
      '.xml',
      '.html',
      '.css',
      '.js',
      '.ts',
      '.dart',
      '.cs',
      '.py',
      '.sh',
      '.toml',
      '.ini',
      '.log',
    ].any(name.endsWith);
  }

  static String _err(Object error) {
    final msg = error.toString();
    return msg.length > 240 ? '${msg.substring(0, 240)}…' : msg;
  }
}

extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
