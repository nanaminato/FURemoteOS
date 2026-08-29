// Top-level File Manager view.
//
// Responsibilities:
//   * owns Flutter UI controllers (search/address/picker name) and focus;
//   * owns the context menu controller and menu positioning;
//   * wires up ViewModel → dialog/modal + native file picker hooks;
//   * composes the chrome (toolbar + address bar + side rail + list + status
//     bar / picker footer) and reacts to tree/list/user gestures.

import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../../app/dependency_injection.dart' as app_di;
import '../../../../apps/code_editor/code_editor_app.dart';
import '../../../../apps/image_viewer/image_viewer_app.dart';
import '../../../../apps/terminal/terminal_app.dart';
import '../../../../core/apps/app_registry.dart';
import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/context_menu_host.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../../../core/window_manager/window_manager.dart';
import '../../../../features/auth/domain/auth_models.dart';
import '../../../../features/files/data/remote_file_api.dart';
import '../../../../features/workspace/application/workspace_sync_coordinator.dart';
import '../../../../features/workspace/domain/workspace_models.dart';
import '../application/file_manager_view_model.dart';
import '../domain/file_manager_models.dart';
import '../domain/file_manager_ui_state.dart';
import '../../../../apps/explorer/explorer_picker.dart';
import 'components/file_manager_chrome.dart';
import 'components/file_manager_file_list.dart';
import 'dialogs/file_manager_dialogs.dart';

class FileManagerView extends ConsumerStatefulWidget {
  const FileManagerView({
    super.key,
    this.vm,
    this.initialPath,
    this.picker,
  });

  final FileManagerViewModel? vm;
  final String? initialPath;
  final ExplorerPickerOptions? picker;

  @override
  ConsumerState<FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends ConsumerState<FileManagerView> {
  late final FileManagerViewModel _vm;
  final _search = TextEditingController();
  final _address = TextEditingController();
  final _pickerName = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _pickerNameFocusNode = FocusNode();
  final _menu = RemoteContextMenuController();
  bool _hooksInstalled = false;

  @override
  void initState() {
    super.initState();
    _vm = widget.vm ??
        app_di.di<FileManagerViewModel>(param1: widget.picker);
    _search.addListener(() => setState(() {}));
    unawaited(_vm.loadRootCommand.runAsync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hooksInstalled) return;
    _hooksInstalled = true;
    _installHooks();
    _installStateBridge();
    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _vm.navigate(_lastSegment(widget.initialPath!), widget.initialPath!);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _address.dispose();
    _pickerName.dispose();
    _addressFocusNode.dispose();
    _pickerNameFocusNode.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _installStateBridge() {
    _vm.state.addListener(() {
      final s = _vm.state.value;
      // Address bar / picker-name text fields: stay in sync with ViewModel
      // state *unless* the user is actively editing that specific field.
      // ARCHITECTURE.md § 8 keeps focus handling in the View.  We gate on
      // individual field focus rather than legacy Focus.isFirstFocus /
      // focusedChild to remain compatible with Flutter 3.33+ APIs.
      if (!_addressFocusNode.hasFocus && _address.text != s.currentPath) {
        _address.text = s.currentPath;
      }
      if (!_pickerNameFocusNode.hasFocus &&
          _pickerName.text != s.pickerEntryName) {
        _pickerName.text = s.pickerEntryName;
      }
    });
  }

  void _installHooks() {
    _vm.requestTextAsync = _requestText;
    _vm.requestConfirmAsync = _requestConfirm;
    _vm.requestLocalFilesAsync = _requestLocalFiles;
    _vm.requestLocalFolderAsync =
        () => getDirectoryPath(confirmButtonText: 'Select folder');
    _vm.requestClipboardFilesAsync = Pasteboard.files;
    _vm.requestLocalSaveFileAsync = (suggested) async {
      final location =
          await getSaveLocation(suggestedName: suggested);
      return location?.path;
    };
    _vm.showError = _showError;
    _vm.openFileAppAsync = _openFileApp;
    _vm.openWithChooseAsync = _chooseOpenWith;
    _vm.openTerminal = _openTerminalHere;
    _vm.showPropertiesAsync = _showProperties;
    final picker = _vm.state.value.pickerOptions;
    if (picker != null) {
      _vm.confirmPicker = picker.onConfirm;
      _vm.onCancelPicker = picker.onCancel;
    }
  }

  // ---- Dialog / modal wrappers ----

  ModalManager get _modals => ref.read(modalManagerProvider);
  String get _ownerId => RemoteWindowScope.of(context).window.id;

  Future<String?> _requestText(
    String title,
    String initialValue,
    String confirmLabel,
  ) async {
    return _modals.open<String>(
      ownerId: _ownerId,
      spec: ModalSpec(
        title: title,
        icon: Icons.folder_outlined,
        preferredSize: const Size(430, 230),
        child: FmTextPromptDialog(
          title: title,
          initialValue: initialValue,
          confirmLabel: confirmLabel,
        ),
      ),
    );
  }

  Future<bool> _requestConfirm(
      String title, String message, String confirmLabel) async {
    final v = await _modals.open<bool>(
      ownerId: _ownerId,
      spec: ModalSpec(
        title: title,
        icon: Icons.delete_outline_rounded,
        preferredSize: const Size(430, 230),
        child: FmConfirmDialog(
            title: title, message: message, confirmLabel: confirmLabel),
      ),
    );
    return v == true;
  }

  Future<List<File>> _requestLocalFiles() async {
    final files = await openFiles();
    return files
        .where((f) => f.path.isNotEmpty)
        .map((f) => File(f.path))
        .toList(growable: false);
  }

  Future<OpenWithChoice?> _chooseOpenWith(
      FileItem entry, List<OpenWithCandidate> candidates) async {
    return _modals.open<OpenWithChoice>(
      ownerId: _ownerId,
      spec: ModalSpec(
        title: 'explorer.open_with'.tr(),
        icon: Icons.apps_outlined,
        preferredSize: const Size(440, 360),
        child: FmOpenWithDialog(entry: entry, candidates: candidates),
      ),
    );
  }

  Future<void> _showProperties(RemoteFileProperties properties) {
    return _modals.open<void>(
      ownerId: _ownerId,
      spec: ModalSpec(
        title: 'explorer.properties'.tr(),
        icon: Icons.info_outline_rounded,
        preferredSize: const Size(460, 360),
        child: FmPropertiesDialog(properties: properties),
      ),
    );
  }

  void _showError(Object error) {
    final msg = error is RemoteOsApiException
        ? error.message
        : 'File operation failed: $error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ---- Open-with dispatch + app opening ----

  Future<void> _openFileApp(FileItem entry, OpenWithCandidate? candidate) async {
    final defaultAppId = _resolveDefaultApp(entry, candidate);
    if (defaultAppId == null) return;
    final registry = ref.read(appRegistryProvider);
    final app = registry.get(defaultAppId);
    if (app == null) return;
    Widget child;
    String title;
    if (defaultAppId == 'image_viewer') {
      child = ImageViewerApp(remotePath: entry.path, fileName: entry.name);
      title = entry.name;
    } else {
      child = CodeEditorApp(remotePath: entry.path, fileName: entry.name);
      title = entry.name;
    }
    ref.read(windowManagerProvider.notifier).openApp(
          entry: app,
          title: title,
          child: child,
        );
  }

  String? _resolveDefaultApp(FileItem entry, OpenWithCandidate? candidate) {
    final candidates = _vm.candidatesFor(entry);
    if (candidates.isEmpty) return null;
    final selected = candidate ?? candidates.first;
    final ext = _extension(entry.name);
    if (ext != null &&
        candidate != null &&
        candidate is OpenWithChoice &&
        (candidate as OpenWithChoice).always) {
      final current = ref.read(workspaceSyncProvider).preferences;
      if (current != null) {
        final mappings = current.defaultApps
            .where((m) => m.scheme.toLowerCase() != ext)
            .toList()
          ..add(WorkspaceDefaultAppMapping(
              scheme: ext, appId: _mapCandidateId(selected)));
        ref
            .read(workspaceSyncProvider.notifier)
            .queuePreferences(current.copyWith(defaultApps: mappings));
      }
    }
    return _mapCandidateId(selected);
  }

  static String _mapCandidateId(OpenWithCandidate c) => c.appId;

  static String? _extension(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? null : name.substring(dot).toLowerCase();
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

  // ---- Context menu ----

  void _onContextMenuRequested(FileItem entry, Offset position) {
    _menu.show(
      position,
      buildFileManagerContextMenu(
        vm: _vm,
        entry: entry,
        isPickerMode: _vm.state.value.isPickerMode,
      ),
    );
  }

  void _onBlankContextMenu(TapUpDetails details) {
    _menu.show(
      details.globalPosition,
      buildFileManagerContextMenu(
        vm: _vm,
        entry: null,
        isPickerMode: _vm.state.value.isPickerMode,
      ),
    );
  }

  static String _lastSegment(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((p) => p.isNotEmpty);
    return parts.isEmpty ? normalized : parts.last;
  }

  void _onNodeTap(TreeNodeItem node) {
    if (node.path == null) return;
    _vm.setSelectedNodePath(node.path);
    _vm.navigate(node.name, node.path!);
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return ValueListenableBuilder(
      valueListenable: _vm.state,
      builder: (context, FileManagerUiState s, _) {
        return ContextMenuHost(
          controller: _menu,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final picker = s.isPickerMode;
              return Column(
                children: [
                  picker
                      ? FileManagerToolbar(
                          state: s, vm: _vm, pickerMode: true)
                      : FileManagerToolbar(
                          state: s, vm: _vm, pickerMode: false),
                  FileManagerAddressBar(
                    state: s,
                    vm: _vm,
                    addressController: _address,
                    searchController: _search,
                    addressFocusNode: _addressFocusNode,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onSecondaryTapUp: _onBlankContextMenu,
                      behavior: HitTestBehavior.deferToChild,
                      child: compact
                          ? _buildList(palette, s)
                          : Row(children: [
                              FileManagerSideRail(
                                  state: s, vm: _vm, onNodeTap: _onNodeTap),
                              VerticalDivider(
                                  width: 1,
                                  thickness: 1,
                                  color: palette.borderSubtle),
                              Expanded(child: _buildList(palette, s)),
                            ]),
                    ),
                  ),
                  if (picker)
                    FileManagerPickerFooter(
                      state: s,
                      vm: _vm,
                      nameController: _pickerName,
                      nameFocusNode: _pickerNameFocusNode,
                    )
                  else
                    FileManagerStatusBar(state: s),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildList(ThemePalette palette, FileManagerUiState s) {
    return Container(
      color: palette.surface,
      child: FileManagerFileList(
        state: s,
        vm: _vm,
        pickerMode: s.isPickerMode,
        onContextMenuRequested: _onContextMenuRequested,
        onOpenEntry: (entry) => _vm.openEntry(entry),
        onOpenWith: (entry) => _vm.chooseOpenWith(entry),
      ),
    );
  }
}
