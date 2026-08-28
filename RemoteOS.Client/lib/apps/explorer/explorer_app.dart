import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../core/theme/theme_service.dart';
import '../../core/network/remoteos_api.dart';
import '../../core/apps/app_registry.dart';
import '../../core/window_manager/context_menu_host.dart';
import '../../core/window_manager/modal_manager.dart';
import '../../core/window_manager/window_manager.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/files/data/remote_file_api.dart';
import '../../features/workspace/application/workspace_sync_coordinator.dart';
import '../../features/workspace/domain/workspace_models.dart';
import '../image_viewer/image_viewer_app.dart';
import '../code_editor/code_editor_app.dart';
import '../terminal/terminal_app.dart';
import 'explorer_picker.dart';

/// File Explorer migration.  Its panes mirror the Avalonia explorer: location
/// tree, command bar, editable breadcrumb and detail list.  The view is kept
/// independent from transport so server file DTOs can be bound here directly.
///
/// When [picker] is supplied, the explorer reuses the navigation surface but
/// hides the command bar's editing actions and adds a confirmation footer,
/// mirroring `ExplorerViewModel.IsPickerMode` on the Avalonia side.
class ExplorerApp extends ConsumerStatefulWidget {
  const ExplorerApp({super.key, this.initialPath, this.picker});

  /// Optional server path opened directly at activation, mirroring the
  /// original client's `RemoteOsActivationUris.ExplorerPath` activation.
  final String? initialPath;

  /// Optional picker configuration. When set, the explorer behaves like an
  /// OpenFile / SelectFolder dialog and reports the chosen paths back to the
  /// host instead of opening them in their own windows.
  final ExplorerPickerOptions? picker;

  @override
  ConsumerState<ExplorerApp> createState() => _ExplorerAppState();
}

class _ExplorerAppState extends ConsumerState<ExplorerApp> {
  String _location = 'Home';
  String _path = '';
  final _search = TextEditingController();
  final _address = TextEditingController();
  bool _detailsView = true;
  final _menu = RemoteContextMenuController();
  final Set<String> _selectedPaths = <String>{};
  List<String>? _clipboardPaths;
  bool _clipboardIsCut = false;
  List<_FileEntry> _entries = const [];
  List<RemoteSpecialLocation> _specialLocations = const [];
  List<RemoteDrive> _drives = const [];
  bool _loading = false;
  String? _loadError;
  final List<String> _history = <String>[];
  int _historyIndex = -1;

  // Picker-mode state. Kept on the same widget so the explorer can be
  // embedded as a modal without spawning a separate state object.
  final _pickerName = TextEditingController();
  List<ExplorerFileFilter> _pickerFilters = const [ExplorerFileFilter.allFiles];
  ExplorerFileFilter _pickerSelectedFilter = ExplorerFileFilter.allFiles;
  bool _pickerNameIsUpdating = false;

  bool get _isPickerMode => widget.picker != null;
  bool get _isFolderPickerMode =>
      _isPickerMode &&
      widget.picker!.mode == ExplorerPickerMode.selectFolder;
  bool get _isFilePickerMode =>
      _isPickerMode && !_isFolderPickerMode && !_isSaveFilePickerMode;
  bool get _isSaveFilePickerMode =>
      _isPickerMode &&
      widget.picker!.mode == ExplorerPickerMode.saveFile;
  bool get _isMultiFilePickerMode =>
      _isPickerMode &&
      widget.picker!.mode == ExplorerPickerMode.openFiles;
  bool get _allowMultipleFiles =>
      _isMultiFilePickerMode ||
      (_isFilePickerMode && widget.picker!.allowMultiple);

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    if (widget.picker != null) {
      _pickerFilters = widget.picker!.filters.isEmpty
          ? const [ExplorerFileFilter.allFiles]
          : widget.picker!.filters;
      _pickerSelectedFilter = _pickerFilters.first;
      final suggested = widget.picker!.suggestedFileName;
      if (suggested != null && suggested.isNotEmpty) {
        _pickerName.text = suggested;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _search.dispose();
    _address.dispose();
    _pickerName.dispose();
    super.dispose();
  }

  void _navigate(String location, String path) {
    if (path == _path && _historyIndex >= 0) return;
    setState(() {
      _location = location;
      _path = path;
      _address.text = path;
      _selectedPaths.clear();
      if (_historyIndex < _history.length - 1) {
        _history.removeRange(_historyIndex + 1, _history.length);
      }
      _history.add(path);
      _historyIndex = _history.length - 1;
      if (_isPickerMode) _refreshPickerName();
    });
    _load(path);
  }

  void _navigateHistory(int index) {
    if (index < 0 || index >= _history.length) return;
    final path = _history[index];
    setState(() {
      _historyIndex = index;
      _path = path;
      _location = _fileName(path);
      _address.text = path;
      _selectedPaths.clear();
    });
    _load(path);
  }

  void _goUp() {
    if (_path.isEmpty) return;
    final normalized = _path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    if (slash < 0) return;
    final parent = slash == 0 ? '/' : _path.substring(0, slash);
    _navigate(_fileName(parent), parent);
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result =
          await RemoteFileApi(ref.read(remoteOsApiProvider)).list(path);
      if (!mounted || path != _path) return;
      setState(() {
        _entries = result.map(_FileEntry.fromRemote).toList();
        _selectedPaths.removeWhere(
            (path) => !_entries.any((entry) => entry.path == path));
        _loading = false;
      });
    } catch (error) {
      if (!mounted || path != _path) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _loadInitial() async {
    try {
      final api = RemoteFileApi(ref.read(remoteOsApiProvider));
      final results = await Future.wait([api.specialLocations(), api.drives()]);
      final locations = results[0] as List<RemoteSpecialLocation>;
      final drives = results[1] as List<RemoteDrive>;
      final home = locations
          .where((location) => location.name.toLowerCase() == 'home')
          .firstOrNull;
      final initial = home ?? (locations.isNotEmpty ? locations.first : null);
      if (mounted) {
        setState(() {
          _specialLocations = locations;
          _drives = drives;
          if (initial != null) {
            _location = initial.name;
            _path = initial.path;
          } else if (drives.isNotEmpty) {
            _location = drives.first.name;
            _path = drives.first.path;
          }
          final activatedPath = widget.initialPath;
          if (activatedPath != null && activatedPath.isNotEmpty) {
            _location = _fileName(activatedPath);
            _path = activatedPath;
          }
          _address.text = _path;
          if (_historyIndex < 0) {
            _history.add(_path);
            _historyIndex = 0;
          }
        });
      }
    } catch (_) {
      // Older servers may not expose SpecialLocations; list still preserves
      // compatibility with their file endpoint.
    }
    if (mounted) _load(_path);
  }

  RemoteFileApi get _api => RemoteFileApi(ref.read(remoteOsApiProvider));

  bool get _hasSelection => _selectedPaths.isNotEmpty;

  List<_FileEntry> get _selectedEntries => _entries
      .where((entry) => _selectedPaths.contains(entry.path))
      .toList(growable: false);

  String _joinPath(String parent, String name) {
    if (parent.isEmpty) return name;
    final separator = parent.contains('\\') ? '\\' : '/';
    return parent.endsWith(separator)
        ? '$parent$name'
        : '$parent$separator$name';
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? normalized : parts.last;
  }

  void _select(_FileEntry entry, {bool toggle = false}) {
    setState(() {
      if (toggle) {
        if (!_selectedPaths.add(entry.path)) _selectedPaths.remove(entry.path);
      } else if (_allowMultipleFiles) {
        _selectedPaths
          ..clear()
          ..add(entry.path);
      } else {
        _selectedPaths
          ..clear()
          ..add(entry.path);
      }
      if (_isPickerMode) _refreshPickerName();
    });
  }

  void _refreshPickerName() {
    if (!_isPickerMode) return;
    if (_pickerNameIsUpdating) return;
    _pickerNameIsUpdating = true;
    if (_isFolderPickerMode) {
      final folder = _selectedEntries
          .where((entry) => entry.type == 'Folder')
          .firstOrNull;
      _pickerName.text = folder?.name ?? '';
    } else if (_isSaveFilePickerMode) {
      final files = _selectedEntries
          .where((entry) =>
              entry.type == 'File' &&
              (_pickerSelectedFilter.matches(entry.name) ||
                  _pickerSelectedFilter.patterns.contains('*')))
          .toList(growable: false);
      if (files.isNotEmpty) {
        _pickerName.text = files.first.name;
      }
    } else if (_allowMultipleFiles) {
      final files = _selectedEntries
          .where((entry) =>
              entry.type == 'File' &&
              (_pickerSelectedFilter.matches(entry.name) ||
                  _pickerSelectedFilter.patterns.contains('*')))
          .toList(growable: false);
      _pickerName.text = files.isEmpty
          ? ''
          : files.map((entry) => '"${entry.name}"').join(' ');
    } else {
      final files = _selectedEntries
          .where((entry) =>
              entry.type == 'File' &&
              (_pickerSelectedFilter.matches(entry.name) ||
                  _pickerSelectedFilter.patterns.contains('*')))
          .toList(growable: false);
      _pickerName.text = files.isEmpty ? '' : files.first.name;
    }
    _pickerNameIsUpdating = false;
  }

  bool get _canConfirmPicker {
    if (!_isPickerMode) return false;
    if (_isFolderPickerMode) {
      return _selectedEntries.any((entry) => entry.type == 'Folder') ||
          _path.isNotEmpty;
    }
    if (_isSaveFilePickerMode) {
      // Save-as: only needs a non-empty target name (current folder + name).
      return _pickerName.text.trim().isNotEmpty && _path.isNotEmpty;
    }
    if (_pickerName.text.trim().isNotEmpty && !_allowMultipleFiles) {
      return true;
    }
    if (_allowMultipleFiles) {
      return _selectedEntries.any((entry) =>
          entry.type == 'File' &&
          (_pickerSelectedFilter.matches(entry.name) ||
              _pickerSelectedFilter.patterns.contains('*')));
    }
    return _selectedEntries.any((entry) =>
        entry.type == 'File' &&
        (_pickerSelectedFilter.matches(entry.name) ||
            _pickerSelectedFilter.patterns.contains('*')));
  }

  bool _isSelectableForPicker(_FileEntry entry) {
    if (entry.type != 'File') return false;
    if (!(_isFilePickerMode ||
        _isMultiFilePickerMode ||
        _isSaveFilePickerMode)) {
      return false;
    }
    return _pickerSelectedFilter.matches(entry.name) ||
        _pickerSelectedFilter.patterns.contains('*');
  }

  void _confirmPicker() {
    if (!_isPickerMode) return;
    final picker = widget.picker!;
    List<String> selected;
    if (_isFolderPickerMode) {
      final folders = _selectedEntries
          .where((entry) => entry.type == 'Folder')
          .map((entry) => entry.path)
          .toList(growable: false);
      selected = folders.isNotEmpty ? folders : (_path.isEmpty ? const [] : [_path]);
    } else if (_isSaveFilePickerMode) {
      final typed = _pickerName.text.trim();
      if (typed.isEmpty || _path.isEmpty) return;
      final resolved = typed.startsWith('/') || typed.startsWith('\\')
          ? typed
          : _joinPath(_path, typed);
      selected = [resolved];
    } else if (_allowMultipleFiles) {
      final files = _selectedEntries
          .where((entry) =>
              entry.type == 'File' &&
              (_pickerSelectedFilter.matches(entry.name) ||
                  _pickerSelectedFilter.patterns.contains('*')))
          .map((entry) => entry.path)
          .toList(growable: false);
      if (files.isEmpty && _pickerName.text.trim().isNotEmpty) {
        final typed = _pickerName.text.trim();
        final resolved = typed.startsWith('/') || typed.startsWith('\\')
            ? typed
            : (_path.isEmpty ? typed : _joinPath(_path, typed));
        selected = [resolved];
      } else {
        selected = files;
      }
    } else {
      final files = _selectedEntries
          .where((entry) =>
              entry.type == 'File' &&
              (_pickerSelectedFilter.matches(entry.name) ||
                  _pickerSelectedFilter.patterns.contains('*')))
          .map((entry) => entry.path)
          .toList(growable: false);
      if (files.isEmpty && _pickerName.text.trim().isNotEmpty) {
        final typed = _pickerName.text.trim();
        final resolved = typed.startsWith('/') || typed.startsWith('\\')
            ? typed
            : (_path.isEmpty ? typed : _joinPath(_path, typed));
        selected = [resolved];
      } else {
        selected = files;
        if (selected.length > 1) selected = [selected.first];
      }
    }
    if (selected.isEmpty) return;
    picker.onConfirm(selected);
  }

  void _cancelPicker() {
    if (!_isPickerMode) return;
    widget.picker!.onCancel?.call();
  }

  void _copySelection({required bool cut}) {
    if (!_hasSelection) return;
    setState(() {
      _clipboardPaths = _selectedPaths.toList(growable: false);
      _clipboardIsCut = cut;
    });
  }

  bool _canMoveEntry(_FileEntry source, _FileEntry target) {
    if (target.type != 'Folder' || source.path == target.path) return false;
    final sourcePath =
        source.path.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
    final targetPath =
        target.path.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
    return source.type != 'Folder' ||
        !(targetPath == sourcePath || targetPath.startsWith('$sourcePath/'));
  }

  Future<void> _moveEntry(_FileEntry source, _FileEntry target) =>
      _runOperation(
          () => _api.move(source.path, _joinPath(target.path, source.name)));

  Widget _draggableEntry(ThemePalette palette, _FileEntry entry, Widget child) {
    final target = entry.type != 'Folder'
        ? child
        : DragTarget<_FileEntry>(
            onWillAcceptWithDetails: (details) =>
                _canMoveEntry(details.data, entry),
            onAcceptWithDetails: (details) => _moveEntry(details.data, entry),
            builder: (context, candidates, _) => DecoratedBox(
              decoration: BoxDecoration(
                border: candidates.isEmpty
                    ? null
                    : Border.all(color: palette.accent, width: 2),
              ),
              child: child,
            ),
          );
    return LongPressDraggable<_FileEntry>(
      data: entry,
      feedback: Material(
        color: palette.surface,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(entry.name),
        ),
      ),
      childWhenDragging: Opacity(opacity: .45, child: target),
      child: target,
    );
  }

  Future<void> _paste() async {
    final paths = _clipboardPaths;
    if (paths == null || paths.isEmpty) return;
    await _runOperation(() async {
      for (final source in paths) {
        final destination = _joinPath(_path, _fileName(source));
        if (_clipboardIsCut) {
          await _api.move(source, destination);
        } else {
          await _api.copy(source, destination);
        }
      }
      if (_clipboardIsCut) {
        setState(() {
          _clipboardPaths = null;
          _clipboardIsCut = false;
        });
      }
    });
  }

  Future<void> _upload() async {
    if (_path.isEmpty) return;
    try {
      final files = await openFiles();
      if (files.isEmpty) return;
      await _runOperation(() async {
        for (final file in files) {
          if (file.path.isEmpty) continue;
          await _api.upload(_path, File(file.path));
        }
      });
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _uploadFolder() async {
    if (_path.isEmpty) return;
    try {
      final rootPath =
          await getDirectoryPath(confirmButtonText: 'Select folder');
      if (rootPath == null || rootPath.isEmpty) return;
      await _runOperation(() => _uploadDirectoryTree(rootPath));
    } catch (error) {
      if (mounted) _showError(error);
    }
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
      await _api.createDirectory(_remoteUploadPath(root.path, directory.path));
    }
    for (final file in files) {
      await _api.upload(_remoteUploadPath(root.path, file.parent.path), file);
    }
  }

  Future<void> _pasteHostFiles() async {
    if (_path.isEmpty) return;
    try {
      final paths = await Pasteboard.files();
      if (paths.isEmpty) return;
      await _runOperation(() async {
        for (final path in paths) {
          if (FileSystemEntity.isFileSync(path)) {
            await _api.upload(_path, File(path));
          } else if (FileSystemEntity.isDirectorySync(path)) {
            await _uploadDirectoryTree(path);
          }
        }
      });
    } catch (error) {
      if (mounted) _showError(error);
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
    return segments.fold(_path, _joinPath);
  }

  Future<void> _download() async {
    final entries = _selectedEntries.where((entry) => entry.type == 'File');
    if (entries.length != 1) return;
    final entry = entries.single;
    try {
      final destination = await getSaveLocation(suggestedName: entry.name);
      if (destination == null || destination.path.isEmpty) return;
      await _api.downloadToFile(entry.path, File(destination.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${entry.name}')),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  bool _isImage(_FileEntry entry) {
    final name = entry.name.toLowerCase();
    return const ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp']
        .any(name.endsWith);
  }

  bool _isText(_FileEntry entry) {
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
      '.log'
    ].any(name.endsWith);
  }

  String? _extension(_FileEntry entry) {
    final dot = entry.name.lastIndexOf('.');
    return dot <= 0 ? null : entry.name.substring(dot).toLowerCase();
  }

  List<_OpenWithCandidate> _candidatesFor(_FileEntry entry) => [
        if (_isImage(entry))
          const _OpenWithCandidate(
              'remoteos.imageviewer', 'Image Viewer', Icons.image_outlined),
        if (_isText(entry))
          const _OpenWithCandidate(
              'remoteos.codeeditor', 'Code Editor', Icons.code_outlined),
      ];

  Future<bool> _isTextContent(_FileEntry entry) async {
    try {
      final bytes = await _api.readBytes(entry.path);
      if (bytes.contains(0)) return false;
      utf8.decode(bytes, allowMalformed: false);
      return true;
    } on FormatException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openEntry(_FileEntry entry,
      {_OpenWithCandidate? candidate}) async {
    if (entry.type == 'Folder') {
      _navigate(entry.name, entry.path);
      return;
    }
    if (_isPickerMode) {
      // Picker mode: folders still navigate (handled above). In file modes
      // a single click fills the name box; a double-click or confirm button
      // commits it. Save-file simply fills the name with the existing
      // filename (so the user can overwrite it), mirroring Avalonia's
      // combined explorer + text input save flow.
      if (_isSaveFilePickerMode && _isSelectableForPicker(entry)) {
        _select(entry);
        return;
      }
      if ((_isFilePickerMode || _isMultiFilePickerMode) &&
          _isSelectableForPicker(entry)) {
        if (_allowMultipleFiles) {
          // In multi-select the primary click just adds to the selection.
          _select(entry);
          return;
        }
        // Single-select: fill the name and immediately confirm on open,
        // matching the Avalonia file-open behaviour.
        _select(entry);
        _confirmPicker();
      }
      return;
    }
    var candidates = _candidatesFor(entry);
    if (candidates.isEmpty && await _isTextContent(entry)) {
      candidates = const [
        _OpenWithCandidate(
            'remoteos.codeeditor', 'Code Editor', Icons.code_outlined),
      ];
    }
    if (candidates.isEmpty) {
      _showError(const RemoteOsApiException(
          statusCode: 409, message: 'No compatible application is available.'));
      return;
    }
    final extension = _extension(entry);
    final mapped = extension == null
        ? null
        : ref
            .read(workspaceSyncProvider)
            .preferences
            ?.defaultApps
            .where((item) => item.scheme.toLowerCase() == extension)
            .map((item) => item.appId)
            .firstOrNull;
    final selected = candidate ??
        candidates.where((item) => item.appId == mapped).firstOrNull ??
        candidates.first;
    final appId = selected.appId == 'remoteos.imageviewer'
        ? 'image_viewer'
        : 'code_editor';
    final app = ref.read(appRegistryProvider).get(appId);
    if (app == null) return;
    ref.read(windowManagerProvider.notifier).openApp(
          entry: app,
          title: entry.name,
          child: selected.appId == 'remoteos.imageviewer'
              ? ImageViewerApp(remotePath: entry.path, fileName: entry.name)
              : CodeEditorApp(remotePath: entry.path, fileName: entry.name),
        );
  }

  Future<void> _chooseOpenWith(_FileEntry entry) async {
    final candidates = _candidatesFor(entry);
    if (candidates.isEmpty) return _openEntry(entry);
    final choice = await ref.read(modalManagerProvider).open<_OpenWithChoice>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: 'Open with',
            icon: Icons.apps_outlined,
            preferredSize: const Size(440, 290),
            child: _OpenWithDialog(candidates: candidates),
          ),
        );
    if (choice == null) return;
    final extension = _extension(entry);
    if (choice.always && extension != null) {
      final current = ref.read(workspaceSyncProvider).preferences;
      if (current != null) {
        final mappings = current.defaultApps
            .where((mapping) => mapping.scheme.toLowerCase() != extension)
            .toList()
          ..add(WorkspaceDefaultAppMapping(
              scheme: extension, appId: choice.candidate.appId));
        ref
            .read(workspaceSyncProvider.notifier)
            .queuePreferences(current.copyWith(defaultApps: mappings));
      }
    }
    _openEntry(entry, candidate: choice.candidate);
  }

  void _openTerminalHere(String workingDirectory) {
    final app = ref.read(appRegistryProvider).get('terminal');
    if (app == null) return;
    ref.read(windowManagerProvider.notifier).openApp(
          entry: app,
          title: 'Terminal',
          child: TerminalApp(workingDirectory: workingDirectory),
        );
  }

  Future<void> _runOperation(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) await _load(_path);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error is RemoteOsApiException
          ? error.message
          : 'File operation failed: $error'),
    ));
  }

  Future<void> _promptNewFolder() => _prompt(
        title: 'New folder',
        initialValue: 'New folder',
        confirmLabel: 'Create',
        onConfirmed: (name) => _runOperation(
          () => _api.createDirectory(_joinPath(_path, name)),
        ),
      );

  Future<void> _promptRename() {
    final entries = _selectedEntries;
    if (entries.length != 1) return Future.value();
    final entry = entries.single;
    return _prompt(
      title: 'Rename',
      initialValue: entry.name,
      confirmLabel: 'Rename',
      onConfirmed: (name) => _runOperation(() => _api.rename(entry.path, name)),
    );
  }

  Future<void> _promptDelete() async {
    final entries = _selectedEntries;
    if (entries.isEmpty) return;
    final confirmed = await _confirm(
      'Delete ${entries.length == 1 ? entries.single.name : '${entries.length} items'}?',
      'This permanently deletes the selected item${entries.length == 1 ? '' : 's'}.',
    );
    if (confirmed == true) {
      await _runOperation(() async {
        for (final entry in entries) {
          await _api.delete(entry.path);
        }
      });
    }
  }

  Future<void> _showProperties() async {
    final entries = _selectedEntries;
    if (entries.length != 1) return;
    try {
      final properties = await _api.properties(entries.single.path);
      if (!mounted || properties == null) return;
      await ref.read(modalManagerProvider).open<void>(
            ownerId: RemoteWindowScope.of(context).window.id,
            spec: ModalSpec(
              title: 'Properties',
              icon: Icons.info_outline_rounded,
              preferredSize: const Size(460, 350),
              child: _PropertiesDialog(properties: properties),
            ),
          );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _prompt({
    required String title,
    required String initialValue,
    required String confirmLabel,
    required Future<void> Function(String value) onConfirmed,
  }) async {
    final value = await ref.read(modalManagerProvider).open<String>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: title,
            icon: Icons.folder_outlined,
            preferredSize: const Size(430, 230),
            child: _TextPromptDialog(
              initialValue: initialValue,
              confirmLabel: confirmLabel,
            ),
          ),
        );
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) await onConfirmed(trimmed);
  }

  Future<bool?> _confirm(String title, String message) =>
      ref.read(modalManagerProvider).open<bool>(
            ownerId: RemoteWindowScope.of(context).window.id,
            spec: ModalSpec(
              title: title,
              icon: Icons.delete_outline_rounded,
              preferredSize: const Size(430, 230),
              child: _ConfirmDialog(message: message),
            ),
          );

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    if (_isPickerMode) {
      // Picker reuses the navigation surface but drops the editing toolbar
      // and status bar, adding the picker confirmation footer instead.
      return ContextMenuHost(
        controller: _menu,
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          return Column(children: [
            _pickerCommandBar(palette),
            _addressBar(palette),
            Expanded(
              child: compact
                  ? _content(palette, showTree: false)
                  : Row(children: [
                      _tree(palette),
                      VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: palette.borderSubtle),
                      Expanded(child: _content(palette, showTree: false)),
                    ]),
            ),
            _pickerFooter(palette),
          ]);
        }),
      );
    }
    return ContextMenuHost(
      controller: _menu,
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        return Column(children: [
          _commandBar(palette),
          _addressBar(palette),
          Expanded(
            child: compact
                ? _content(palette, showTree: false)
                : Row(children: [
                    _tree(palette),
                    VerticalDivider(
                        width: 1, thickness: 1, color: palette.borderSubtle),
                    Expanded(child: _content(palette, showTree: false)),
                  ]),
          ),
          _statusBar(palette),
        ]);
      }),
    );
  }

  /// Slimmed-down toolbar shown in picker mode: navigation only, mirroring
  /// Avalonia's `IsVisible="{Binding !IsPickerMode}"` on the edit actions.
  Widget _pickerCommandBar(ThemePalette palette) => Container(
        height: 48,
        color: palette.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          _toolButton(palette, Icons.arrow_back_rounded, 'Back',
              onPressed: _historyIndex > 0
                  ? () => _navigateHistory(_historyIndex - 1)
                  : null),
          _toolButton(palette, Icons.arrow_forward_rounded, 'Forward',
              onPressed:
                  _historyIndex >= 0 && _historyIndex < _history.length - 1
                      ? () => _navigateHistory(_historyIndex + 1)
                      : null),
          _toolButton(palette, Icons.arrow_upward_rounded, 'Up',
              onPressed: _path.isEmpty ? null : _goUp),
          Container(
              width: 1,
              height: 22,
              color: palette.borderSubtle,
              margin: const EdgeInsets.symmetric(horizontal: 6)),
          _toolButton(palette, Icons.refresh_rounded, 'Refresh',
              onPressed: () => _load(_path)),
        ]),
      );

  Widget _pickerFooter(ThemePalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(
              _isFolderPickerMode
                  ? 'explorer.picker.folder_label'.tr()
                  : 'explorer.picker.file_name_label'.tr(),
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _pickerName,
                style: TextStyle(fontSize: 13, color: palette.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (_canConfirmPicker) _confirmPicker();
                },
              ),
            ),
            if (_isFilePickerMode) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 180,
                child: DropdownButton<ExplorerFileFilter>(
                  value: _pickerSelectedFilter,
                  isExpanded: true,
                  items: [
                    for (final filter in _pickerFilters)
                      DropdownMenuItem(
                          value: filter, child: Text(filter.label)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _pickerSelectedFilter = value;
                      _refreshPickerName();
                    });
                  },
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: _cancelPicker,
              child: Text('common.cancel'.tr()),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _canConfirmPicker ? _confirmPicker : null,
              child: Text(
                _isFolderPickerMode
                    ? 'explorer.picker.select_folder'.tr()
                    : 'common.open'.tr(),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _commandBar(ThemePalette palette) => Container(
        height: 48,
        color: palette.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          _toolButton(palette, Icons.arrow_back_rounded, 'Back',
              onPressed: _historyIndex > 0
                  ? () => _navigateHistory(_historyIndex - 1)
                  : null),
          _toolButton(palette, Icons.arrow_forward_rounded, 'Forward',
              onPressed:
                  _historyIndex >= 0 && _historyIndex < _history.length - 1
                      ? () => _navigateHistory(_historyIndex + 1)
                      : null),
          _toolButton(palette, Icons.arrow_upward_rounded, 'Up',
              onPressed: _path.isEmpty ? null : _goUp),
          Container(
              width: 1,
              height: 22,
              color: palette.borderSubtle,
              margin: const EdgeInsets.symmetric(horizontal: 6)),
          _toolButton(palette, Icons.refresh_rounded, 'Refresh',
              onPressed: () => _load(_path)),
          _toolButton(palette, Icons.create_new_folder_outlined, 'New folder',
              onPressed: _promptNewFolder),
          _toolButton(palette, Icons.upload_file_outlined, 'Upload',
              onPressed: _path.isEmpty ? null : _upload),
          _toolButton(
              palette, Icons.drive_folder_upload_outlined, 'Upload folder',
              onPressed: _path.isEmpty ? null : _uploadFolder),
          _toolButton(palette, Icons.download_outlined, 'Download',
              onPressed: _selectedEntries
                          .where((entry) => entry.type == 'File')
                          .length ==
                      1
                  ? _download
                  : null),
          _toolButton(palette, Icons.content_copy_outlined, 'Copy',
              onPressed:
                  _hasSelection ? () => _copySelection(cut: false) : null),
          _toolButton(palette, Icons.content_cut_outlined, 'Cut',
              onPressed:
                  _hasSelection ? () => _copySelection(cut: true) : null),
          _toolButton(palette, Icons.paste_outlined, 'Paste',
              onPressed: _clipboardPaths?.isNotEmpty == true ? _paste : null),
          _toolButton(
              palette, Icons.content_paste_go_outlined, 'Paste host files',
              onPressed: _path.isEmpty ? null : _pasteHostFiles),
          _toolButton(palette, Icons.terminal_outlined, 'Terminal',
              onPressed: _path.isEmpty ? null : () => _openTerminalHere(_path)),
          const Spacer(),
          IconButton(
            tooltip: _detailsView ? 'Icon view' : 'Details view',
            onPressed: () => setState(() => _detailsView = !_detailsView),
            icon: Icon(
                _detailsView
                    ? Icons.grid_view_rounded
                    : Icons.view_list_rounded,
                color: palette.textSecondary),
          ),
        ]),
      );

  Widget _toolButton(ThemePalette palette, IconData icon, String label,
          {VoidCallback? onPressed}) =>
      TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
            foregroundColor: palette.textSecondary,
            textStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8)),
      );

  Widget _addressBar(ThemePalette palette) => Container(
        height: 48,
        color: palette.surface,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(children: [
          Icon(Icons.folder_outlined, size: 18, color: palette.accent),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _address,
              onSubmitted: (value) =>
                  _navigate(value.split('/').lastOrNull ?? 'Location', value),
              style: TextStyle(fontSize: 13, color: palette.textPrimary),
              decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4))),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 188,
            child: TextField(
              controller: _search,
              style: TextStyle(fontSize: 12, color: palette.textPrimary),
              decoration: InputDecoration(
                  hintText: 'Search $_location',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4))),
            ),
          ),
        ]),
      );

  Widget _tree(ThemePalette palette) => SizedBox(
        width: 208,
        child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _treeHeading(palette, 'Quick access'),
              for (final location in _specialLocations)
                _treeItem(palette, location.name, _locationIcon(location.name),
                    location.path),
              const SizedBox(height: 8),
              _treeHeading(palette, 'This PC'),
              for (final drive in _drives)
                _treeItem(
                    palette, drive.name, Icons.storage_outlined, drive.path),
            ]),
      );

  Widget _treeHeading(ThemePalette palette, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 5),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
                color: palette.textTertiary)),
      );

  IconData _locationIcon(String name) => switch (name.toLowerCase()) {
        'home' => Icons.home_outlined,
        'desktop' => Icons.desktop_windows_outlined,
        'documents' => Icons.description_outlined,
        'downloads' => Icons.download_outlined,
        'pictures' => Icons.image_outlined,
        'music' => Icons.music_note_outlined,
        'videos' => Icons.video_library_outlined,
        _ => Icons.folder_outlined,
      };

  Widget _treeItem(
      ThemePalette palette, String label, IconData icon, String path) {
    final selected = label == _location;
    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigate(label, path),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: selected ? palette.accentMuted : Colors.transparent,
                border: selected
                    ? Border(left: BorderSide(color: palette.accent, width: 3))
                    : null),
            child: Row(children: [
              Icon(icon,
                  size: 18,
                  color: selected ? palette.accent : palette.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 13, color: palette.textPrimary)))
            ]),
          ),
        ));
  }

  Widget _content(ThemePalette palette, {required bool showTree}) {
    final filter = _search.text.trim().toLowerCase();
    var entries = filter.isEmpty
        ? _entries
        : _entries
            .where((entry) => entry.name.toLowerCase().contains(filter))
            .toList();
    // In file picker mode, hide files that the active filter rejects (folders
    // remain navigable), mirroring Avalonia's `IsSelectableFile`.
    if (_isFilePickerMode && !_pickerSelectedFilter.patterns.contains('*')) {
      entries = entries
          .where((entry) => entry.type == 'Folder' ||
              _pickerSelectedFilter.matches(entry.name))
          .toList();
    }
    return Container(
      color: palette.appBackground,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_location,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary)),
              const SizedBox(height: 3),
              Text(_path,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary)),
            ])),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                                'Unable to load this directory.\n$_loadError',
                                textAlign: TextAlign.center)))
                    : _detailsView
                        ? _details(palette, entries)
                        : _iconGrid(palette, entries)),
      ]),
    );
  }

  Widget _details(ThemePalette palette, List<_FileEntry> entries) =>
      ListView(children: [
        Container(
            height: 34,
            color: palette.surfaceSunken,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _column('Name', 3, palette),
              _column('Date modified', 2, palette),
              _column('Type', 2, palette),
              _column('Size', 1, palette),
            ])),
        for (final entry in entries) _entryRow(palette, entry),
      ]);

  Widget _column(String text, int flex, ThemePalette palette) => Expanded(
      flex: flex,
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.textSecondary)));

  Widget _entryRow(ThemePalette palette, _FileEntry entry) => ContextMenuRegion(
      controller: _menu,
      entries: _entryMenuEntries(entry),
      child: _draggableEntry(
          palette,
          entry,
          Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _select(entry,
                    toggle: HardwareKeyboard.instance.isControlPressed ||
                        HardwareKeyboard.instance.isShiftPressed),
                onDoubleTap: () => _openEntry(entry),
                child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: _selectedPaths.contains(entry.path)
                        ? palette.accentMuted
                        : Colors.transparent,
                    child: Row(children: [
                      Expanded(
                          flex: 3,
                          child: Row(children: [
                            Icon(entry.icon,
                                size: 19,
                                color: entry.type == 'Folder'
                                    ? const Color(0xFFE9A23B)
                                    : palette.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(entry.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: palette.textPrimary)))
                          ])),
                      _column(entry.modified, 2, palette),
                      _column(entry.type, 2, palette),
                      _column(entry.size, 1, palette),
                    ])),
              ))));

  Widget _iconGrid(ThemePalette palette, List<_FileEntry> entries) =>
      GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: entries.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            mainAxisExtent: 112,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10),
        itemBuilder: (_, index) {
          final entry = entries[index];
          return ContextMenuRegion(
              controller: _menu,
              entries: _entryMenuEntries(entry),
              child: _draggableEntry(
                  palette,
                  entry,
                  InkWell(
                      onTap: () => _select(entry,
                          toggle: HardwareKeyboard.instance.isControlPressed ||
                              HardwareKeyboard.instance.isShiftPressed),
                      onDoubleTap: () => _openEntry(entry),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                          decoration: BoxDecoration(
                            color: _selectedPaths.contains(entry.path)
                                ? palette.accentMuted
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(entry.icon,
                                    size: 42,
                                    color: entry.type == 'Folder'
                                        ? const Color(0xFFE9A23B)
                                        : palette.textSecondary),
                                const SizedBox(height: 7),
                                Text(entry.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: palette.textPrimary))
                              ])))));
        },
      );

  List<ContextMenuEntry> _entryMenuEntries(_FileEntry entry) => [
        ContextMenuAction(
          label: 'Open',
          icon: Icons.open_in_new_rounded,
          onSelected: () {
            _select(entry);
            _openEntry(entry);
          },
        ),
        if (entry.type == 'File')
          ContextMenuAction(
            label: 'Open with…',
            icon: Icons.apps_outlined,
            enabled: _candidatesFor(entry).isNotEmpty,
            onSelected: () {
              _select(entry);
              _chooseOpenWith(entry);
            },
          ),
        if (entry.type == 'Folder')
          ContextMenuAction(
            label: 'Open terminal here',
            icon: Icons.terminal_outlined,
            onSelected: () => _openTerminalHere(entry.path),
          ),
        const ContextMenuDivider(),
        ContextMenuAction(
          label: 'Download',
          icon: Icons.download_outlined,
          enabled: entry.type == 'File',
          onSelected: () {
            _select(entry);
            _download();
          },
        ),
        const ContextMenuDivider(),
        ContextMenuAction(
          label: 'Copy',
          icon: Icons.content_copy_outlined,
          onSelected: () {
            _select(entry);
            _copySelection(cut: false);
          },
        ),
        ContextMenuAction(
          label: 'Cut',
          icon: Icons.content_cut_outlined,
          onSelected: () {
            _select(entry);
            _copySelection(cut: true);
          },
        ),
        ContextMenuAction(
          label: 'Rename',
          icon: Icons.drive_file_rename_outline,
          onSelected: () {
            _select(entry);
            _promptRename();
          },
        ),
        ContextMenuAction(
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          onSelected: () {
            _select(entry);
            _promptDelete();
          },
        ),
        const ContextMenuDivider(),
        ContextMenuAction(
          label: 'Properties',
          icon: Icons.info_outline_rounded,
          onSelected: () {
            _select(entry);
            _showProperties();
          },
        ),
      ];

  Widget _statusBar(ThemePalette palette) => Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.borderSubtle))),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              '${_entries.length} items${_loading ? ' · Loading…' : ''}',
              style: TextStyle(fontSize: 11, color: palette.textTertiary))));
}

class _FileEntry {
  const _FileEntry(this.name, this.path, this.type, this.size, this.modified,
      this.icon, this.mimeType);
  final String name;
  final String path;
  final String type;
  final String size;
  final String modified;
  final IconData icon;
  final String? mimeType;

  factory _FileEntry.fromRemote(RemoteFileEntry entry) => _FileEntry(
        entry.name,
        entry.path,
        entry.isDirectory ? 'Folder' : 'File',
        entry.size == null ? '—' : _formatBytes(entry.size!),
        entry.lastWriteTime?.toLocal().toString().split('.').first ?? '—',
        entry.isDirectory ? Icons.folder_rounded : Icons.description_outlined,
        entry.mimeType,
      );

  static String _formatBytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

extension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _TextPromptDialog extends ConsumerStatefulWidget {
  const _TextPromptDialog(
      {required this.initialValue, required this.confirmLabel});
  final String initialValue;
  final String confirmLabel;

  @override
  ConsumerState<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends ConsumerState<_TextPromptDialog> {
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _controller,
          autofocus: true,
          onSubmitted: (value) => modals.complete(dialogId, value),
          style: TextStyle(color: palette.textPrimary),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
              onPressed: () => modals.dismiss(dialogId),
              child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => modals.complete(dialogId, _controller.text),
            child: Text(widget.confirmLabel),
          ),
        ]),
      ]),
    );
  }
}

class _ConfirmDialog extends ConsumerWidget {
  const _ConfirmDialog({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: TextStyle(color: palette.textPrimary)),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
              onPressed: () => modals.dismiss(dialogId),
              child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => modals.complete(dialogId, true),
            child: const Text('Delete'),
          ),
        ]),
      ]),
    );
  }
}

class _PropertiesDialog extends ConsumerWidget {
  const _PropertiesDialog({required this.properties});
  final RemoteFileProperties properties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final rows = <(String, String)>[
      ('Name', properties.name),
      ('Type', properties.type),
      ('Location', properties.path),
      (
        'Size',
        properties.size == null
            ? '—'
            : _FileEntry._formatBytes(properties.size!)
      ),
      (
        'Created',
        properties.created?.toLocal().toString().split('.').first ?? '—'
      ),
      (
        'Modified',
        properties.modified?.toLocal().toString().split('.').first ?? '—'
      ),
      if (properties.permissions?.isNotEmpty == true)
        ('Permissions', properties.permissions!),
      if (properties.attributes?.isNotEmpty == true)
        ('Attributes', properties.attributes!),
    ];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 90,
                  child: Text(row.$1,
                      style: TextStyle(color: palette.textSecondary))),
              Expanded(
                  child: Text(row.$2,
                      style: TextStyle(color: palette.textPrimary))),
            ]),
          ),
        const Spacer(),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => ref.read(modalManagerProvider).dismiss(dialogId),
            child: const Text('Close'),
          ),
        ),
      ]),
    );
  }
}

class _OpenWithCandidate {
  const _OpenWithCandidate(this.appId, this.label, this.icon);
  final String appId;
  final String label;
  final IconData icon;
}

class _OpenWithChoice {
  const _OpenWithChoice(this.candidate, this.always);
  final _OpenWithCandidate candidate;
  final bool always;
}

class _OpenWithDialog extends ConsumerStatefulWidget {
  const _OpenWithDialog({required this.candidates});
  final List<_OpenWithCandidate> candidates;

  @override
  ConsumerState<_OpenWithDialog> createState() => _OpenWithDialogState();
}

class _OpenWithDialogState extends ConsumerState<_OpenWithDialog> {
  _OpenWithCandidate? _selected;
  bool _always = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Choose an application'),
        const SizedBox(height: 10),
        for (final candidate in widget.candidates)
          RadioListTile<_OpenWithCandidate>(
            value: candidate,
            groupValue: _selected,
            title: Text(candidate.label),
            secondary: Icon(candidate.icon),
            onChanged: (value) => setState(() => _selected = value),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _always,
          title: const Text('Always use this application'),
          onChanged: (value) => setState(() => _always = value ?? false),
        ),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
              onPressed: () => modals.dismiss(dialogId),
              child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () => modals.complete(
                    dialogId, _OpenWithChoice(_selected!, _always)),
            child: const Text('Open'),
          ),
        ]),
      ]),
    );
  }
}
