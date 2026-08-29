// File Manager presentation components (split per AGENTS.md § 7, target
// <300 lines each).  This file contains the tool bar, address bar and side
// rail navigation widgets.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/file_manager_view_model.dart';
import '../../domain/file_manager_models.dart';
import '../../domain/file_manager_ui_state.dart';
import '../../../../apps/explorer/explorer_picker.dart';

// ---------- Toolbar (edit actions) ----------

class FileManagerToolbar extends StatelessWidget {
  const FileManagerToolbar({
    super.key,
    required this.state,
    required this.vm,
    required this.pickerMode,
  });

  final FileManagerUiState state;
  final FileManagerViewModel vm;
  final bool pickerMode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 48,
      color: palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        _toolButton(palette, Icons.arrow_back_rounded, 'common.back'.tr(),
            onPressed: state.canGoBack
                ? () => vm.navigateBackCommand.run()
                : null),
        _toolButton(palette, Icons.arrow_forward_rounded, 'common.forward'.tr(),
            onPressed: state.canGoForward
                ? () => vm.navigateForwardCommand.run()
                : null),
        _toolButton(palette, Icons.arrow_upward_rounded, 'common.up'.tr(),
            onPressed:
                state.canGoUp ? () => vm.goUpCommand.run() : null),
        const SizedBox(width: 4),
        if (!pickerMode) ...[
          const _Divider(),
          _toolButton(palette, Icons.create_new_folder_outlined,
              'explorer.new_folder'.tr(),
              onPressed: () => vm.newFolderCommand.runAsync()),
          _toolButton(palette, Icons.drive_file_rename_outline,
              'common.rename'.tr(),
              onPressed: state.hasSelection
                  ? () => vm.renameCommand.runAsync()
                  : null),
          _toolButton(palette, Icons.delete_outline_rounded,
              'common.delete'.tr(),
              onPressed: state.hasSelection
                  ? () => vm.deleteCommand.runAsync()
                  : null),
          const _Divider(),
          _toolButton(palette, Icons.content_copy_outlined, 'common.copy'.tr(),
              onPressed: state.hasSelection
                  ? () => vm.copyCommand.run()
                  : null),
          _toolButton(palette, Icons.content_cut_outlined, 'common.cut'.tr(),
              onPressed: state.hasSelection
                  ? () => vm.cutCommand.run()
                  : null),
          _toolButton(palette, Icons.content_paste_outlined,
              'common.paste'.tr(),
              onPressed: state.hasClipboard
                  ? () => vm.pasteCommand.runAsync()
                  : null),
          const _Divider(),
          _toolButton(palette, Icons.upload_file_outlined,
              'explorer.upload_files'.tr(),
              onPressed: () => vm.uploadFilesCommand.runAsync()),
          _toolButton(palette, Icons.folder_open_outlined,
              'explorer.upload_folder'.tr(),
              onPressed: () => vm.uploadFolderCommand.runAsync()),
          _toolButton(palette, Icons.download_outlined,
              'explorer.download'.tr(),
              onPressed: state.hasSelection
                  ? () => vm.downloadCommand.runAsync()
                  : null),
          const _Divider(),
          _toolButton(palette, Icons.terminal_outlined, 'explorer.terminal'.tr(),
              onPressed: state.currentPath.isNotEmpty
                  ? () => vm.openTerminal?.call(state.currentPath)
                  : null),
          _toolButton(palette, Icons.info_outline_rounded,
              'explorer.properties'.tr(),
              onPressed: state.hasSelection
                  ? () => vm.propertiesCommand.runAsync()
                  : null),
          const _Divider(),
          _toolButton(palette, Icons.refresh_rounded, 'common.refresh'.tr(),
              onPressed: () => vm.refreshCommand.runAsync()),
          _toolButton(
              palette,
              state.detailsView
                  ? Icons.grid_view_outlined
                  : Icons.view_list_outlined,
              state.detailsView ? 'explorer.tiles' : 'explorer.details',
              onPressed: () => vm.toggleDetailsView()),
        ],
        const Spacer(),
        if (pickerMode)
          _toolButton(palette, Icons.refresh_rounded, 'common.refresh'.tr(),
              onPressed: () => vm.refreshCommand.runAsync()),
      ]),
    );
  }

  Widget _toolButton(
      ThemePalette palette, IconData icon, String tooltip, {VoidCallback? onPressed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: palette.textSecondary),
          visualDensity: VisualDensity.compact,
          splashRadius: 18,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: VerticalDivider(
          width: 1, thickness: 1, color: palette.borderSubtle),
    );
  }
}

// ---------- Address bar (editable breadcrumb + search) ----------

class FileManagerAddressBar extends StatelessWidget {
  const FileManagerAddressBar({
    super.key,
    required this.state,
    required this.vm,
    required this.addressController,
    required this.searchController,
    this.addressFocusNode,
  });

  final FileManagerUiState state;
  final FileManagerViewModel vm;
  final TextEditingController addressController;
  final TextEditingController searchController;
  final FocusNode? addressFocusNode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: addressController,
            focusNode: addressFocusNode,
            style: TextStyle(color: palette.textPrimary, fontSize: 13),
            onSubmitted: (value) {
              if (value.trim().isEmpty) return;
              vm.navigate(_lastSegment(value), value.trim());
            },
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.location_on_outlined,
                  size: 16, color: palette.textSecondary),
              hintText: 'explorer.address_hint'.tr(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              constraints: const BoxConstraints(maxHeight: 36),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 240,
          child: TextField(
            controller: searchController,
            style: TextStyle(color: palette.textPrimary, fontSize: 13),
            onChanged: vm.updateSearch,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search_outlined,
                  size: 16, color: palette.textSecondary),
              hintText: 'common.search'.tr(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              constraints: const BoxConstraints(maxHeight: 36),
            ),
          ),
        ),
      ]),
    );
  }

  static String _lastSegment(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((p) => p.isNotEmpty);
    return parts.isEmpty ? normalized : parts.last;
  }
}

// ---------- Side rail (navigation tree) ----------

class FileManagerSideRail extends StatelessWidget {
  const FileManagerSideRail({
    super.key,
    required this.state,
    required this.vm,
    required this.onNodeTap,
  });

  final FileManagerUiState state;
  final FileManagerViewModel vm;
  final ValueChanged<TreeNodeItem> onNodeTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 260,
      color: palette.surfaceSunken,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: state.navigationNodes.length,
        itemBuilder: (context, i) {
          final node = state.navigationNodes[i];
          return _buildGroup(palette, node, depth: 0);
        },
      ),
    );
  }

  Widget _buildGroup(ThemePalette palette, TreeNodeItem node, {required int depth}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tile(palette, node, depth: depth),
        if (node.isExpanded)
          Padding(
            padding: EdgeInsets.only(left: depth == 0 ? 14 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final child in node.children)
                  _tile(palette, child, depth: depth + 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tile(ThemePalette palette, TreeNodeItem node, {required int depth}) {
    final selected = node.path != null && node.path == state.selectedNodePath;
    final childrenAreEntries = node.children.isNotEmpty && !node.isComputer;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onNodeTap(node),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? palette.accent.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            Icon(_iconFor(node.kind),
                size: 16,
                color: selected ? palette.accent : palette.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _label(node.name),
                style: TextStyle(
                    color: selected ? palette.textPrimary : palette.textSecondary,
                    fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (childrenAreEntries && depth == 0)
              Icon(node.isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: palette.textTertiary),
          ]),
        ),
      ),
    );
  }

  IconData _iconFor(TreeNodeKind kind) {
    switch (kind) {
      case TreeNodeKind.home:
        return Icons.home_outlined;
      case TreeNodeKind.desktop:
        return Icons.desktop_windows_outlined;
      case TreeNodeKind.documents:
        return Icons.description_outlined;
      case TreeNodeKind.downloads:
        return Icons.download_outlined;
      case TreeNodeKind.pictures:
        return Icons.photo_outlined;
      case TreeNodeKind.music:
        return Icons.music_note_outlined;
      case TreeNodeKind.videos:
        return Icons.movie_outlined;
      case TreeNodeKind.folder:
        return Icons.folder_outlined;
      case TreeNodeKind.drive:
        return Icons.storage_outlined;
      case TreeNodeKind.computer:
        return Icons.computer_outlined;
      case TreeNodeKind.network:
        return Icons.lan_outlined;
    }
  }

  String _label(String key) {
    // Navigation labels are semantic keys like `explorer.home`.  Attempt
    // localization first; fall back to the raw name if no key exists.
    try {
      return key.tr();
    } catch (_) {
      return key;
    }
  }
}

// ---------- Status bar ----------

class FileManagerStatusBar extends StatelessWidget {
  const FileManagerStatusBar({super.key, required this.state});

  final FileManagerUiState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatStatus(state),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textTertiary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatStatus(FileManagerUiState s) {
    final ready = 'explorer.status.ready'.tr();
    final itemsText = 'explorer.status.items_count'
        .tr(args: ['${s.entries.length}']);
    if (s.isTransferActive) {
      final label = s.transferText.isEmpty ? ready : s.transferText;
      return '$label  ${s.transferProgressPercent.toStringAsFixed(1)}%';
    }
    if (s.statusText.isNotEmpty) {
      final parts = s.statusText.split('|');
      final key = parts.first;
      final args = parts.skip(1).toList();
      try {
        return '${key.tr(args: args.isEmpty ? null : args)}  ·  $itemsText';
      } catch (_) {
        return '${s.statusText}  ·  $itemsText';
      }
    }
    final loading = s.isLoading ? ' · ${'common.loading'.tr()}…' : '';
    return '$ready  ·  $itemsText$loading';
  }
}

// ---------- Picker confirmation footer ----------

class FileManagerPickerFooter extends StatelessWidget {
  const FileManagerPickerFooter({
    super.key,
    required this.state,
    required this.vm,
    required this.nameController,
    this.nameFocusNode,
  });

  final FileManagerUiState state;
  final FileManagerViewModel vm;
  final TextEditingController nameController;
  final FocusNode? nameFocusNode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final folderMode = state.isFolderPickerMode;
    final label = folderMode
        ? 'explorer.picker.folder_label'.tr()
        : 'explorer.picker.file_name_label'.tr();
    final confirmLabel = folderMode
        ? 'explorer.picker.select_folder'.tr()
        : 'common.open'.tr();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(children: [
        SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: palette.textSecondary))),
        Expanded(
          child: TextField(
            controller: nameController,
            focusNode: nameFocusNode,
            style: TextStyle(color: palette.textPrimary),
            onChanged: (value) => vm.setPickerEntryName(value),
            decoration: const InputDecoration(isDense: true),
            enabled: !folderMode || state.selectedEntries().isEmpty,
          ),
        ),
        const SizedBox(width: 10),
        if (!folderMode)
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<ExplorerFileFilter>(
              initialValue: state.pickerSelectedFilter,
              items: [
                for (final f in state.pickerFilters)
                  DropdownMenuItem(value: f, child: Text(f.label)),
              ],
              onChanged: (v) {
                if (v != null) vm.setPickerSelectedFilter(v);
              },
              decoration: const InputDecoration(isDense: true),
            ),
          ),
        const SizedBox(width: 10),
        TextButton(
            onPressed: () => vm.cancelPicker(),
            child: Text('common.cancel'.tr())),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: vm.canConfirmPicker
              ? () => vm.confirmPickerCommand.run()
              : null,
          child: Text(confirmLabel),
        ),
      ]),
    );
  }
}
