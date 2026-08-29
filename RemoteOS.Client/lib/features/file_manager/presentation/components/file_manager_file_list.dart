// File Manager file list and entry context menu.
//
// Two layout modes are supported (details & tiles), mirroring the original
// Avalonia explorer.  Selection state is pushed back to the ViewModel; the
// context menu asks the ViewModel for action availability (AGENTS.md § 19).

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/file_manager_view_model.dart';
import '../../domain/file_manager_models.dart';
import '../../domain/file_manager_ui_state.dart';

class FileManagerFileList extends StatelessWidget {
  const FileManagerFileList({
    super.key,
    required this.state,
    required this.vm,
    required this.onContextMenuRequested,
    required this.onOpenEntry,
    required this.onOpenWith,
    this.pickerMode = false,
  });

  final FileManagerUiState state;
  final FileManagerViewModel vm;
  final void Function(FileItem entry, Offset position) onContextMenuRequested;
  final ValueChanged<FileItem> onOpenEntry;
  final ValueChanged<FileItem> onOpenWith;
  final bool pickerMode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entries = _applySearch(state.entries, state.searchText);
    if (state.isLoading && entries.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 18,
          height: 18,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: palette.accent),
        ),
      ));
    }
    if (state.loadError != null && entries.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
            'explorer.status.path_load_failed'
                .tr(args: [state.currentPath, state.loadError!]),
            style: TextStyle(color: palette.textSecondary)),
      ));
    }
    if (entries.isEmpty) {
      return Center(
        child: Text(
            'explorer.status.directory_ready'.tr(args: const ['0', '0']),
            style: TextStyle(color: palette.textTertiary)),
      );
    }
    if (state.detailsView) {
      return _DetailsTable(
        entries: entries,
        state: state,
        vm: vm,
        onContextMenuRequested: onContextMenuRequested,
        onOpenEntry: onOpenEntry,
        onOpenWith: onOpenWith,
      );
    }
    return _TilesGrid(
      entries: entries,
      state: state,
      vm: vm,
      onContextMenuRequested: onContextMenuRequested,
      onOpenEntry: onOpenEntry,
      onOpenWith: onOpenWith,
    );
  }

  static List<FileItem> _applySearch(List<FileItem> items, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((e) => e.name.toLowerCase().contains(q))
        .toList(growable: false);
  }
}

// ---- Details table ----

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({
    required this.entries,
    required this.state,
    required this.vm,
    required this.onContextMenuRequested,
    required this.onOpenEntry,
    required this.onOpenWith,
  });

  final List<FileItem> entries;
  final FileManagerUiState state;
  final FileManagerViewModel vm;
  final void Function(FileItem entry, Offset position) onContextMenuRequested;
  final ValueChanged<FileItem> onOpenEntry;
  final ValueChanged<FileItem> onOpenWith;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(builder: (context, constraints) {
      // Avalonia's details ListBox leaves an unused trailing viewport area.
      // Keep it intentionally: users right-click there to get directory
      // actions without accidentally targeting the final row.
      final rightClickGutter = constraints.maxWidth >= 680 ? 160.0 : 64.0;
      return Padding(
        padding: EdgeInsets.only(right: rightClickGutter),
        child: Column(
          children: [
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: palette.surfaceRaised,
                border: Border(bottom: BorderSide(color: palette.borderSubtle)),
              ),
              child: const Row(
                children: [
                  _HeaderCell(flex: 4, text: 'common.name'),
                  _HeaderCell(flex: 2, text: 'explorer.modified'),
                  _HeaderCell(flex: 1, text: 'explorer.size'),
                  _HeaderCell(flex: 1, text: 'common.type'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  final selected = state.selectedPaths.contains(entry.path);
                  return _EntryRow(
                    palette: palette,
                    entry: entry,
                    selected: selected,
                    state: state,
                    vm: vm,
                    onContextMenuRequested: onContextMenuRequested,
                    onOpenEntry: onOpenEntry,
                    onOpenWith: onOpenWith,
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.flex, required this.text});
  final int flex;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text.tr(),
              style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.palette,
    required this.entry,
    required this.selected,
    required this.state,
    required this.vm,
    required this.onContextMenuRequested,
    required this.onOpenEntry,
    required this.onOpenWith,
  });

  final ThemePalette palette;
  final FileItem entry;
  final bool selected;
  final FileManagerUiState state;
  final FileManagerViewModel vm;
  final void Function(FileItem entry, Offset position) onContextMenuRequested;
  final ValueChanged<FileItem> onOpenEntry;
  final ValueChanged<FileItem> onOpenWith;

  @override
  Widget build(BuildContext context) {
    final selectable = !state.isPickerMode ||
        entry.isFolder ||
        vm.isSelectableForPicker(entry);
    final bg =
        selected ? palette.accent.withValues(alpha: 0.16) : Colors.transparent;
    return InkWell(
      onTap: selectable
          ? () {
              final toggle = HardwareKeyboard.instance.isControlPressed ||
                  (state.allowMultipleFiles && state.hasSelection);
              vm.selectEntry(entry, toggle: toggle);
            }
          : null,
      onDoubleTap: () => onOpenEntry(entry),
      onSecondaryTapUp: (details) =>
          onContextMenuRequested(entry, details.globalPosition),
      child: Container(
        color: bg,
        height: 30,
        child: Row(
          children: [
            _Cell(
                flex: 4,
                child: Row(children: [
                  const SizedBox(width: 6),
                  Icon(_entryIcon(entry),
                      size: 16, color: palette.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: palette.textPrimary, fontSize: 13))),
                ])),
            _Cell(
                flex: 2,
                child: Text(entry.modifiedText,
                    style:
                        TextStyle(color: palette.textSecondary, fontSize: 12))),
            _Cell(
                flex: 1,
                child: Text(entry.sizeText,
                    style:
                        TextStyle(color: palette.textSecondary, fontSize: 12))),
            _Cell(
                flex: 1,
                child: Text(entry.isFolder ? 'Folder' : 'File',
                    style:
                        TextStyle(color: palette.textSecondary, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.flex, required this.child});
  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }
}

// ---- Tiles grid ----

class _TilesGrid extends StatelessWidget {
  const _TilesGrid({
    required this.entries,
    required this.state,
    required this.vm,
    required this.onContextMenuRequested,
    required this.onOpenEntry,
    required this.onOpenWith,
  });

  final List<FileItem> entries;
  final FileManagerUiState state;
  final FileManagerViewModel vm;
  final void Function(FileItem entry, Offset position) onContextMenuRequested;
  final ValueChanged<FileItem> onOpenEntry;
  final ValueChanged<FileItem> onOpenWith;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 108,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          final selected = state.selectedPaths.contains(entry.path);
          final selectable = !state.isPickerMode ||
              entry.isFolder ||
              vm.isSelectableForPicker(entry);
          return InkWell(
            onTap: selectable
                ? () {
                    final toggle = HardwareKeyboard.instance.isControlPressed ||
                        state.allowMultipleFiles;
                    vm.selectEntry(entry, toggle: toggle);
                  }
                : null,
            onDoubleTap: () => onOpenEntry(entry),
            onSecondaryTapUp: (d) =>
                onContextMenuRequested(entry, d.globalPosition),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? palette.accent.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: selected
                    ? Border.all(color: palette.accent.withValues(alpha: 0.35))
                    : null,
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_entryIcon(entry),
                      size: 40,
                      color: entry.isFolder
                          ? palette.accent
                          : palette.textSecondary),
                  const SizedBox(height: 4),
                  Text(entry.name,
                      maxLines: 3,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: palette.textPrimary, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

IconData _entryIcon(FileItem entry) =>
    entry.isFolder ? Icons.folder_rounded : Icons.description_outlined;
