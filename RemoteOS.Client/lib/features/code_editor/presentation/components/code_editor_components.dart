import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../../../core/window_manager/window_manager.dart';
import '../../application/code_editor_view_model.dart';
import '../../domain/code_editor_models.dart';
import '../../domain/code_editor_ui_state.dart';
import 'code_editor_text_field.dart';

/// Localized display name for a document. Untitled documents are rendered via
/// `code_editor.document.untitled_number` ({number}) so the name follows the
/// active locale (AGENTS.md §23.1 Rule B — View owns translation).
String codeEditorDocumentName(CodeEditorDocument document) {
  if (document.path != null && document.path!.isNotEmpty) {
    return document.displayName;
  }
  return 'code_editor.document.untitled_number'
      .tr(namedArgs: {'number': '${document.untitledSequence}'});
}

class CodeEditorMenuBar extends StatelessWidget {
  const CodeEditorMenuBar({super.key, required this.vm});
  final CodeEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = vm.state.value.activeDocument;
    return Container(
      height: 40,
      color: palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        _menuButton(context, 'common.file', [
          _menuAction('common.new', vm.newDocumentCommand),
          _menuAction('common.open_ellipsis', vm.openDocumentCommand),
          const PopupMenuDivider(),
          _menuAction('common.save', vm.saveCommand),
          _menuAction('common.save_as_ellipsis', vm.saveAsCommand),
        ]),
        _menuButton(context, 'common.settings', [
          _menuAction('code_editor.menu.preferences', vm.openSettingsCommand),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            active != null ? codeEditorDocumentName(active) : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  PopupMenuEntry<void> _menuAction(String key, dynamic command) =>
      PopupMenuItem<void>(
        onTap: () => command.runAsync(),
        child: Text(key.tr()),
      );

  Widget _menuButton(
      BuildContext context,
      String key,
      List<PopupMenuEntry<void>> entries,
      ) =>
      PopupMenuButton<void>(
        itemBuilder: (_) => entries,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text(key.tr()),
        ),
      );
}

class CodeEditorWorkspace extends StatelessWidget {
  const CodeEditorWorkspace({super.key, required this.vm, required this.state});
  final CodeEditorViewModel vm;
  final CodeEditorUiState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(children: [
      Container(
        width: 48,
        color: palette.surface,
        child: Column(children: [
          _activityButton(Icons.folder_outlined, CodeEditorSidebar.explorer),
          _activityButton(
              Icons.description_outlined, CodeEditorSidebar.openEditors),
        ]),
      ),
      if (state.isSidebarVisible) ...[
        Container(
          width: 250,
          color: palette.surface,
          child: state.sidebar == CodeEditorSidebar.explorer
              ? _ExplorerSidebar(vm: vm, state: state)
              : _OpenEditorsSidebar(vm: vm, state: state),
        ),
        VerticalDivider(width: 1, thickness: 1, color: palette.borderSubtle),
      ],
      Expanded(child: _DocumentWorkspace(vm: vm, state: state)),
    ]);
  }

  Widget _activityButton(IconData icon, CodeEditorSidebar sidebar) {
    final selected = state.sidebar == sidebar;
    return IconButton(
      onPressed: () => vm.setSidebar(sidebar),
      icon: Icon(icon,
          color: selected ? context.palette.accent : context.palette.textSecondary),
    );
  }
}

class _ExplorerSidebar extends StatelessWidget {
  const _ExplorerSidebar({required this.vm, required this.state});
  final CodeEditorViewModel vm;
  final CodeEditorUiState state;

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
      child: Row(children: [
        Expanded(
            child: Text('code_editor.sidebar.folders'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600))),
        IconButton(
            onPressed: () => vm.addFolderCommand.runAsync(),
            icon: const Icon(Icons.add, size: 18)),
        IconButton(
            onPressed: () => vm.refreshFolderCommand.runAsync(),
            icon: const Icon(Icons.refresh, size: 18)),
        IconButton(
            onPressed: vm.removeSelectedFolder,
            icon: const Icon(Icons.remove, size: 18)),
      ]),
    ),
    Expanded(
      child: ListView(children: [
        for (final root in state.workspaceRoots)
          _FolderTree(
            node: root,
            selectedFolderPath: state.selectedFolderPath,
            onOpenFile: vm.openPath,
            onSelectFolder: vm.selectFolder,
          ),
      ]),
    ),
  ]);
}

class _FolderTree extends StatelessWidget {
  const _FolderTree({
    required this.node,
    required this.selectedFolderPath,
    required this.onOpenFile,
    required this.onSelectFolder,
    this.depth = 0,
  });

  final CodeEditorFolderNode node;
  final String? selectedFolderPath;
  final ValueChanged<String> onOpenFile;
  final ValueChanged<String> onSelectFolder;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = selectedFolderPath == node.path;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: palette.borderSubtle,
        contentPadding: EdgeInsets.only(left: 8 + depth * 14.0, right: 4),
        leading: Icon(
            node.isDirectory
                ? (node.isExpanded
                ? Icons.folder_open_outlined
                : Icons.folder_outlined)
                : Icons.description_outlined,
            size: 16),
        title: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: node.isDirectory
            ? () => onSelectFolder(node.path)
            : () => onOpenFile(node.path),
      ),
      if (node.isDirectory && node.isExpanded)
        for (final child in node.children)
          _FolderTree(
            node: child,
            selectedFolderPath: selectedFolderPath,
            onOpenFile: onOpenFile,
            onSelectFolder: onSelectFolder,
            depth: depth + 1,
          ),
    ]);
  }
}

class _OpenEditorsSidebar extends StatelessWidget {
  const _OpenEditorsSidebar({required this.vm, required this.state});
  final CodeEditorViewModel vm;
  final CodeEditorUiState state;

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.all(10),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text('code_editor.sidebar.open_editors'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600))),
    ),
    Expanded(
        child: ListView(children: [
          for (final document in state.documents)
            ListTile(
              dense: true,
              selected: document.id == state.activeDocumentId,
              title: Text(
                  '${codeEditorDocumentName(document)}${document.isDirty ? ' •' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => unawaited(vm.closeDocument(document)),
                icon: const Icon(Icons.close),
              ),
              onTap: () => vm.activateDocument(document.id),
            ),
        ])),
  ]);
}

class _DocumentWorkspace extends StatelessWidget {
  const _DocumentWorkspace({required this.vm, required this.state});
  final CodeEditorViewModel vm;
  final CodeEditorUiState state;

  @override
  Widget build(BuildContext context) => Column(children: [
    _DocumentTabs(vm: vm, state: state),
    Expanded(
      child: state.activeDocument == null
          ? const SizedBox.shrink()
          : CodeEditorTextField(vm: vm, state: state),
    ),
  ]);
}

class _DocumentTabs extends StatelessWidget {
  const _DocumentTabs({required this.vm, required this.state});
  final CodeEditorViewModel vm;
  final CodeEditorUiState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 36,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final document in state.documents)
          Container(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: document.id == state.activeDocumentId
                          ? palette.accent
                          : Colors.transparent,
                      width: 2)),
            ),
            child: InkWell(
              onTap: () => vm.activateDocument(document.id),
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: Row(children: [
                  Text(
                      '${codeEditorDocumentName(document)}${document.isDirty ? ' •' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 14,
                    padding: const EdgeInsets.only(left: 4),
                    constraints: const BoxConstraints(),
                    onPressed: () => unawaited(vm.closeDocument(document)),
                    icon: const Icon(Icons.close),
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class CodeEditorStatusBar extends StatelessWidget {
  const CodeEditorStatusBar({
    super.key,
    required this.state,
    this.onEncodingPressed,
  });
  final CodeEditorUiState state;
  final VoidCallback? onEncodingPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Expanded(
            child: Text(
                state.statusKey.tr(namedArgs: state.statusNamedArgs),
                overflow: TextOverflow.ellipsis)),
        if (state.hasOpenFile)
          InkWell(
            onTap: onEncodingPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(state.activeDocument!.encodingName,
                  style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12,
                      decoration:
                      TextDecoration.underline)),
            ),
          )
        else if (onEncodingPressed != null)
          const SizedBox.shrink(),
        const SizedBox(width: 14),
        Text('common.line_count_format'
            .tr(namedArgs: {'line': '${state.lineCount}'})),
        const SizedBox(width: 14),
        Text('common.character_count_format'
            .tr(namedArgs: {'count': '${state.characterCount}'})),
      ]),
    );
  }
}

class CodeEditorDiscardDialog extends ConsumerWidget {
  const CodeEditorDiscardDialog({super.key, required this.document});
  final CodeEditorDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final id = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            'code_editor.close_dirty_message'
                .tr(namedArgs: {'name': codeEditorDocumentName(document)}),
            style: TextStyle(color: palette.textPrimary)),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
              onPressed: () => modals.dismiss(id),
              child: Text('common.cancel'.tr())),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: () => modals.complete(id, true),
              child: Text('code_editor.discard_changes'.tr())),
        ]),
      ]),
    );
  }
}