// File Manager dialogs: text input, confirmation, properties, open-with,
// entry context menu.  All dialogs complete through `RemoteModalScope` +
// `ModalManager` (AGENTS.md § 18).

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/theme_service.dart';
import '../../../../../core/window_manager/context_menu_host.dart';
import '../../../../../core/window_manager/modal_manager.dart';
import '../../../../../core/window_manager/window_manager.dart';
import '../../../../features/files/data/remote_file_api.dart';
import '../../application/file_manager_view_model.dart';
import '../../domain/file_manager_models.dart';

// ---- Text input dialog (new-folder / rename) ----

class FmTextPromptDialog extends ConsumerStatefulWidget {
  const FmTextPromptDialog({
    super.key,
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
  });
  final String title;
  final String initialValue;
  final String confirmLabel;

  @override
  ConsumerState<FmTextPromptDialog> createState() => _FmTextPromptDialogState();
}

class _FmTextPromptDialogState extends ConsumerState<FmTextPromptDialog> {
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
        Text(widget.title,
            style: TextStyle(color: palette.textPrimary, fontSize: 14)),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          onSubmitted: (value) => modals.complete(
              dialogId, value.trim().isEmpty ? null : value.trim()),
          style: TextStyle(color: palette.textPrimary),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
              onPressed: () => modals.dismiss(dialogId),
              child: Text('common.cancel'.tr())),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => modals.complete(
                dialogId,
                _controller.text.trim().isEmpty
                    ? null
                    : _controller.text.trim()),
            child: Text(widget.confirmLabel),
          ),
        ]),
      ]),
    );
  }
}

// ---- Confirmation dialog ----

class FmConfirmDialog extends ConsumerWidget {
  const FmConfirmDialog({
    super.key,
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(color: palette.textPrimary)),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
              onPressed: () => modals.dismiss(dialogId),
              child: Text('common.cancel'.tr())),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: () => modals.complete(dialogId, true),
              child: Text(confirmLabel)),
        ]),
      ]),
    );
  }
}

// ---- Properties dialog ----

class FmPropertiesDialog extends ConsumerWidget {
  const FmPropertiesDialog({super.key, required this.properties});

  final RemoteFileProperties properties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final rows = <(String, String)>[
      ('common.name'.tr(), properties.name),
      ('common.kind'.tr(), properties.type),
      ('common.location'.tr(), properties.path),
      (
        'common.size'.tr(),
        properties.size == null ? '—' : _formatBytes(properties.size!)
      ),
      (
        'common.created'.tr(),
        properties.created?.toLocal().toString().split('.').first ?? '—'
      ),
      (
        'common.modified'.tr(),
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
        Text('explorer.properties'.tr(),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final (label, value) = rows[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 100,
                          child: Text(label,
                              style: TextStyle(color: palette.textSecondary))),
                      Expanded(
                          child: Text(value,
                              style: TextStyle(color: palette.textPrimary))),
                    ]),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => ref.read(modalManagerProvider).dismiss(dialogId),
            child: Text('common.close'.tr()),
          ),
        ),
      ]),
    );
  }

  static String _formatBytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ---- Open-with dialog ----

class FmOpenWithDialog extends ConsumerStatefulWidget {
  const FmOpenWithDialog({
    super.key,
    required this.entry,
    required this.candidates,
  });
  final FileItem entry;
  final List<OpenWithCandidate> candidates;

  @override
  ConsumerState<FmOpenWithDialog> createState() => _FmOpenWithDialogState();
}

class _FmOpenWithDialogState extends ConsumerState<FmOpenWithDialog> {
  int _selected = 0;
  bool _always = false;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('explorer.open_with'.tr(),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary)),
        const SizedBox(height: 4),
        Text(widget.entry.name,
            style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: widget.candidates.length,
            itemBuilder: (context, i) {
              final c = widget.candidates[i];
              final sel = i == _selected;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selected = i),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          sel ? palette.accent.withValues(alpha: 0.12) : null,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: sel
                              ? palette.accent.withValues(alpha: 0.35)
                              : palette.borderDefault),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      Icon(c.icon, color: palette.textSecondary),
                      const SizedBox(width: 10),
                      Text(c.label,
                          style: TextStyle(color: palette.textPrimary)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Checkbox(
              value: _always,
              onChanged: (v) => setState(() => _always = v == true)),
          Expanded(
              child: Text('explorer.open_with_always'.tr(),
                  style: TextStyle(color: palette.textSecondary))),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
              onPressed: () => modals.dismiss(dialogId),
              child: Text('common.cancel'.tr())),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: () => modals.complete(
                    dialogId,
                    OpenWithChoice(widget.candidates[_selected], _always),
                  ),
              child: Text('common.ok'.tr())),
        ]),
      ]),
    );
  }
}

// ---- Context menu builder ----

/// Builds the right-click entry menu using RemoteOS typed [ContextMenuEntry]
/// items ([ContextMenuAction] + [ContextMenuDivider]) consumed by
/// [RemoteContextMenuController.show].  Avalonia previously rendered
/// MenuItemButton widgets directly; AGENTS.md § 19 keeps menu actions as
/// ViewModel-owned *intent* descriptors so the View owns positioning.
List<ContextMenuEntry> buildFileManagerContextMenu({
  required FileManagerViewModel vm,
  required FileItem? entry,
  required bool isPickerMode,
}) {
  final s = vm.state.value;
  final entries = <ContextMenuEntry>[];
  if (entry != null && !isPickerMode) {
    entries
      ..add(ContextMenuAction(
        icon: Icons.open_in_new_outlined,
        label: 'common.open'.tr(),
        onSelected: () => vm.openEntry(entry),
      ))
      ..add(ContextMenuAction(
        icon: Icons.apps_outlined,
        label: 'explorer.open_with'.tr(),
        onSelected: () => vm.chooseOpenWith(entry),
      ))
      ..add(const ContextMenuDivider())
      ..add(ContextMenuAction(
        icon: Icons.content_cut_outlined,
        label: 'common.cut'.tr(),
        enabled: s.hasSelection,
        onSelected: () {
          if (s.hasSelection) vm.cutCommand.run();
        },
      ))
      ..add(ContextMenuAction(
        icon: Icons.content_copy_outlined,
        label: 'common.copy'.tr(),
        enabled: s.hasSelection,
        onSelected: () {
          if (s.hasSelection) vm.copyCommand.run();
        },
      ))
      ..add(ContextMenuAction(
        icon: Icons.edit_outlined,
        label: 'common.rename'.tr(),
        enabled: s.hasSelection,
        onSelected: () {
          if (s.hasSelection) vm.renameCommand.runAsync();
        },
      ))
      ..add(ContextMenuAction(
        icon: Icons.delete_outline_rounded,
        label: 'common.delete'.tr(),
        enabled: s.hasSelection,
        onSelected: () {
          if (s.hasSelection) vm.deleteCommand.runAsync();
        },
      ))
      ..add(const ContextMenuDivider())
      ..add(ContextMenuAction(
        icon: Icons.download_outlined,
        label: 'explorer.download'.tr(),
        enabled: s.hasSelection && !entry.isFolder,
        onSelected: () {
          if (s.hasSelection && !entry.isFolder) vm.downloadCommand.runAsync();
        },
      ))
      ..add(ContextMenuAction(
        icon: Icons.info_outline_rounded,
        label: 'explorer.properties'.tr(),
        enabled: s.hasSelection,
        onSelected: () {
          if (s.hasSelection) vm.propertiesCommand.runAsync();
        },
      ));
  }
  if (!isPickerMode) {
    if (entries.isNotEmpty) entries.add(const ContextMenuDivider());
    entries
      ..add(ContextMenuAction(
        icon: Icons.create_new_folder_outlined,
        label: 'explorer.new_folder'.tr(),
        enabled: s.currentPath.isNotEmpty,
        onSelected: () {
          if (s.currentPath.isNotEmpty) vm.newFolderCommand.runAsync();
        },
      ))
      ..add(ContextMenuAction(
        icon: Icons.content_paste_outlined,
        label: 'common.paste'.tr(),
        enabled: s.hasClipboard,
        onSelected: () {
          if (s.hasClipboard) vm.pasteCommand.runAsync();
        },
      ))
      ..add(const ContextMenuDivider())
      ..add(ContextMenuAction(
        icon: Icons.terminal_outlined,
        label: 'explorer.terminal'.tr(),
        enabled: s.currentPath.isNotEmpty && vm.openTerminal != null,
        onSelected: () {
          if (s.currentPath.isNotEmpty) vm.openTerminal?.call(s.currentPath);
        },
      ))
      ..add(ContextMenuAction(
        icon: Icons.refresh_rounded,
        label: 'common.refresh'.tr(),
        onSelected: () => vm.refreshCommand.runAsync(),
      ));
  }
  return entries;
}
