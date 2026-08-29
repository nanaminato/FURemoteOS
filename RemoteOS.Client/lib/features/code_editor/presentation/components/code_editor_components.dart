import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../../../core/window_manager/window_manager.dart';
import '../../application/code_editor_view_model.dart';
import '../../domain/code_editor_models.dart';
import '../../domain/code_editor_ui_state.dart';

class CodeEditorMenuBar extends StatelessWidget {
  const CodeEditorMenuBar({super.key, required this.vm});
  final CodeEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
        _menuButton(context, 'common.settings', const []),
        const Spacer(),
        IconButton(
          tooltip: 'code_editor.sidebar.explorer'.tr(),
          onPressed: vm.toggleSidebar,
          icon: const Icon(Icons.view_sidebar_outlined),
        ),
        IconButton(
          tooltip: 'common.save'.tr(),
          onPressed: vm.canSave ? () => vm.saveCommand.runAsync() : null,
          icon: const Icon(Icons.save_outlined),
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

  Widget _activityButton(IconData icon, CodeEditorSidebar sidebar) =>
      IconButton(
        onPressed: () => vm.setSidebar(sidebar),
        icon: Icon(icon, color: state.sidebar == sidebar ? null : null),
      );
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
                onOpenFile: vm.openPath,
                onToggleFolder: vm.toggleFolder,
              ),
          ]),
        ),
      ]);
}

class _FolderTree extends StatelessWidget {
  const _FolderTree({
    required this.node,
    required this.onOpenFile,
    required this.onToggleFolder,
    this.depth = 0,
  });
  final CodeEditorFolderNode node;
  final ValueChanged<String> onOpenFile;
  final ValueChanged<String> onToggleFolder;
  final int depth;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.only(left: 8 + depth * 14.0, right: 4),
          leading: Icon(
              node.isDirectory
                  ? Icons.folder_outlined
                  : Icons.description_outlined,
              size: 16),
          title: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: node.isDirectory
              ? () => onToggleFolder(node.path)
              : () => onOpenFile(node.path),
        ),
        if (node.isDirectory && node.isExpanded)
          for (final child in node.children)
            _FolderTree(
              node: child,
              onOpenFile: onOpenFile,
              onToggleFolder: onToggleFolder,
              depth: depth + 1,
            ),
      ]);
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
                  '${document.displayName}${document.isDirty ? ' •' : ''}'),
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
              : _CodeTextEditor(vm: vm, state: state),
        ),
      ]);
}

class _DocumentTabs extends StatelessWidget {
  const _DocumentTabs({required this.vm, required this.state});
  final CodeEditorViewModel vm;
  final CodeEditorUiState state;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final document in state.documents)
            InkWell(
              onTap: () => vm.activateDocument(document.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: Text(
                    '${document.displayName}${document.isDirty ? ' •' : ''}'),
              ),
            ),
        ]),
      );
}

class _CodeTextEditor extends StatefulWidget {
  const _CodeTextEditor({required this.vm, required this.state});
  final CodeEditorViewModel vm;
  final CodeEditorUiState state;

  @override
  State<_CodeTextEditor> createState() => _CodeTextEditorState();
}

class _CodeTextEditorState extends State<_CodeTextEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.state.activeDocument?.text);
  }

  @override
  void didUpdateWidget(covariant _CodeTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.state.activeDocument?.text ?? '';
    if (_controller.text != text) {
      _controller.value = TextEditingValue(text: text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlign: TextAlign.start,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style:
            TextStyle(fontFamily: 'monospace', fontSize: widget.state.fontSize),
        decoration: const InputDecoration(
            border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
        onChanged: widget.vm.updateActiveDocument,
      );
}

class CodeEditorStatusBar extends StatelessWidget {
  const CodeEditorStatusBar({super.key, required this.state});
  final CodeEditorUiState state;

  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(
              child: Text(state.statusKey.tr(args: state.statusArguments),
                  overflow: TextOverflow.ellipsis)),
          if (state.hasOpenFile) Text(state.activeDocument!.encodingName),
          const SizedBox(width: 14),
          Text('common.line_count_format'.tr(args: ['${state.lineCount}'])),
          const SizedBox(width: 14),
          Text('common.character_count_format'
              .tr(args: ['${state.characterCount}'])),
        ]),
      );
}

class CodeEditorDiscardDialog extends ConsumerWidget {
  const CodeEditorDiscardDialog({super.key, required this.document});
  final CodeEditorDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            'code_editor.close_dirty_message'.tr(args: [document.displayName])),
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
