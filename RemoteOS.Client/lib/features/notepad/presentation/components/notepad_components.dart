// Notepad shared UI components: menu bar, find/replace toolbar and status
// bar.  They read state from [NotepadViewModel] via a provided `ValueListenable`
// and route user gestures to ViewModel methods / Commands.  Widgets here
// intentionally keep their build bodies short (<300 lines target) so the
// top-level NotepadView stays readable.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/theme_service.dart';
import '../../application/notepad_view_model.dart';
import '../../domain/notepad_ui_state.dart';

// ---------- Menu bar ----------

class NotepadMenuBar extends StatelessWidget {
  const NotepadMenuBar({
    super.key,
    required this.state,
    required this.vm,
    required this.findController,
    required this.replaceController,
    required this.editorFocus,
    required this.editorController,
  });

  final NotepadUiState state;
  final NotepadViewModel vm;
  final TextEditingController findController;
  final TextEditingController replaceController;
  final FocusNode editorFocus;
  final TextEditingController editorController;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 32,
      color: palette.windowTitleBarBackground,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          _menuButton(palette, Icons.description_outlined, 'common.file'.tr(), [
            MenuItemButton(
              onPressed: () => vm.newDocumentCommand.runAsync(),
              leadingIcon: const Icon(Icons.note_add_outlined, size: 16),
              child: Text('${'common.new'.tr()}    Ctrl+N',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: () => vm.openDocumentCommand.runAsync(),
              leadingIcon: const Icon(Icons.folder_open_outlined, size: 16),
              child: Text('${'common.open_ellipsis'.tr()}    Ctrl+O',
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: () => vm.saveCommand.runAsync(),
              leadingIcon: const Icon(Icons.save_outlined, size: 16),
              child: Text('${'common.save'.tr()}    Ctrl+S',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: () => vm.saveAsCommand.runAsync(),
              leadingIcon: const Icon(Icons.save_as_outlined, size: 16),
              child: Text('${'common.save_as_ellipsis'.tr()}    Ctrl+Shift+S',
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: () => vm.chooseEncodingCommand.runAsync(),
              leadingIcon: const Icon(Icons.translate_rounded, size: 16),
              child: Text('common.file_encoding'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
          ]),
          _menuButton(palette, Icons.edit_note_outlined, 'common.edit'.tr(), [
            MenuItemButton(
              onPressed: _undo,
              leadingIcon: const Icon(Icons.undo_outlined, size: 16),
              child: Text('${'common.undo'.tr()}    Ctrl+Z',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _redo,
              leadingIcon: const Icon(Icons.redo_outlined, size: 16),
              child: Text('${'common.redo'.tr()}    Ctrl+Y',
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: _cut,
              leadingIcon: const Icon(Icons.content_cut_outlined, size: 16),
              child: Text('${'common.cut'.tr()}    Ctrl+X',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _copy,
              leadingIcon: const Icon(Icons.content_copy_outlined, size: 16),
              child: Text('${'common.copy'.tr()}    Ctrl+C',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _paste,
              leadingIcon: const Icon(Icons.content_paste_outlined, size: 16),
              child: Text('${'common.paste'.tr()}    Ctrl+V',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _selectAll,
              leadingIcon: const Icon(Icons.select_all_outlined, size: 16),
              child: Text('${'common.select_all'.tr()}    Ctrl+A',
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: () => vm.openFind(),
              leadingIcon: const Icon(Icons.search_outlined, size: 16),
              child: Text('${'common.find'.tr()}    Ctrl+F',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: () => vm.openFind(replaceMode: true),
              leadingIcon: const Icon(Icons.find_replace_outlined, size: 16),
              child: Text('${'common.replace'.tr()}    Ctrl+H',
                  style: const TextStyle(fontSize: 13)),
            ),
          ]),
          _menuButton(palette, Icons.visibility_outlined, 'common.view'.tr(), [
            MenuItemButton(
              onPressed: () => vm.toggleWordWrap(),
              trailingIcon: Icon(
                state.wordWrap
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 16,
                color: palette.accent,
              ),
              child: Text('common.word_wrap'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: () => vm.toggleShowLineNumbers(),
              trailingIcon: Icon(
                state.showLineNumbers
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 16,
                color: palette.accent,
              ),
              child: Text('common.line_numbers'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: () => vm.openSettingsCommand.runAsync(),
              leadingIcon: const Icon(Icons.settings_outlined, size: 16),
              child: Text('common.preferences_ellipsis'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _displayedDocumentName(state),
              style: TextStyle(
                fontSize: 12,
                color: palette.windowTitleForeground.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- Edit clipboard helpers (keep inline; small) ---
  void _undo() {
    final snap = vm.undo();
    if (snap == null) return;
    editorController.value = TextEditingValue(
      text: snap.text,
      selection: snap.selection,
    );
  }

  void _redo() {
    final snap = vm.redo();
    if (snap == null) return;
    editorController.value = TextEditingValue(
      text: snap.text,
      selection: snap.selection,
    );
  }

  void _cut() {
    final sel = editorController.selection;
    if (sel.isCollapsed) return;
    final textInside = sel.textInside(editorController.text) ?? '';
    Clipboard.setData(ClipboardData(text: textInside));
    final newText = editorController.text.replaceRange(sel.start, sel.end, '');
    editorController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start),
    );
  }

  Future<void> _copy() async {
    final sel = editorController.selection;
    if (sel.isCollapsed) return;
    final textInside = sel.textInside(editorController.text) ?? '';
    await Clipboard.setData(ClipboardData(text: textInside));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return;
    final sel = editorController.selection;
    final newText =
        editorController.text.replaceRange(sel.start, sel.end, text);
    final newOffset = sel.start + text.length;
    editorController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void _selectAll() {
    editorController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: editorController.text.length,
    );
  }

  static String _displayedDocumentName(NotepadUiState s) {
    if (!s.hasOpenFile) return 'notepad.document.untitled'.tr();
    return s.documentName;
  }
}

// ---------- Find/replace toolbar ----------

class NotepadFindReplaceToolbar extends StatelessWidget {
  const NotepadFindReplaceToolbar({
    super.key,
    required this.state,
    required this.vm,
    required this.findController,
    required this.findFocusNode,
    required this.replaceController,
    required this.editorController,
    required this.onSelectionApplied,
  });

  final NotepadUiState state;
  final NotepadViewModel vm;
  final TextEditingController findController;
  final FocusNode findFocusNode;
  final TextEditingController replaceController;
  final TextEditingController editorController;
  final ValueChanged<TextSelection> onSelectionApplied;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: findController,
              focusNode: findFocusNode,
              style: TextStyle(color: palette.textPrimary, fontSize: 13),
              onSubmitted: (_) => _findNext(),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'notepad.find.find'.tr(),
                labelStyle:
                    TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'common.previous'.tr(),
            onPressed: _findPrev,
            icon: Icon(Icons.arrow_upward_rounded,
                size: 18, color: palette.textSecondary),
          ),
          IconButton(
            tooltip: 'common.next'.tr(),
            onPressed: _findNext,
            icon: Icon(Icons.arrow_downward_rounded,
                size: 18, color: palette.textSecondary),
          ),
          if (state.isReplaceMode) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 220,
              child: TextField(
                controller: replaceController,
                style: TextStyle(color: palette.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'notepad.find.replace_with'.tr(),
                  labelStyle:
                      TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _replaceNext,
              child: Text('notepad.find.replace'.tr(),
                  style: const TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: _replaceAll,
              child: Text('notepad.find.replace_all'.tr(),
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
          const SizedBox(width: 10),
          FilterChip(
            label: Text('Aa',
                style: TextStyle(
                    fontSize: 11,
                    color: state.findOptions.caseSensitive
                        ? palette.textOnAccent
                        : palette.textSecondary)),
            backgroundColor: palette.surfaceRaised,
            selectedColor: palette.accent,
            selected: state.findOptions.caseSensitive,
            onSelected: vm.setFindCaseSensitive,
            side: BorderSide(
                color: state.findOptions.caseSensitive
                    ? palette.accent
                    : palette.borderDefault),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: Text('.*',
                style: TextStyle(
                    fontSize: 11,
                    color: state.findOptions.useRegex
                        ? palette.textOnAccent
                        : palette.textSecondary)),
            backgroundColor: palette.surfaceRaised,
            selectedColor: palette.accent,
            selected: state.findOptions.useRegex,
            onSelected: vm.setFindRegex,
            side: BorderSide(
                color: state.findOptions.useRegex
                    ? palette.accent
                    : palette.borderDefault),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _formatFindStatus(state.findStatus),
              style: TextStyle(color: palette.textTertiary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'common.close'.tr(),
            onPressed: () => vm.closeFindReplace(),
            icon: Icon(Icons.close_rounded,
                size: 18, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }

  void _findNext() {
    final match = vm.findNext(
      findController.text,
      editorController.text,
      editorController.selection.baseOffset
          .clamp(0, editorController.text.length),
    );
    if (match != null) onSelectionApplied(match);
  }

  void _findPrev() {
    final match = vm.findPrev(
      findController.text,
      editorController.text,
      editorController.selection.baseOffset
          .clamp(0, editorController.text.length),
    );
    if (match != null) onSelectionApplied(match);
  }

  void _replaceNext() {
    final result = vm.replaceNext(
      findController.text,
      replaceController.text,
      editorController.text,
      editorController.selection.baseOffset
          .clamp(0, editorController.text.length),
    );
    if (result == null) return;
    editorController.value = TextEditingValue(
      text: result.$1,
      selection: result.$2,
    );
  }

  void _replaceAll() {
    final result = vm.replaceAll(
      findController.text,
      replaceController.text,
      editorController.text,
    );
    if (result == null) return;
    editorController.value = TextEditingValue(
      text: result.$1,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  static String _formatFindStatus(String raw) {
    // `raw` is either a bare localization key or `key|arg1|arg2`.
    if (raw.isEmpty) return '';
    final parts = raw.split('|');
    final key = parts.first;
    final args = parts.skip(1).toList();
    // Fall back without `.tr()` if a raw legacy string was stored.
    try {
      return key.tr(args: args.isEmpty ? null : args);
    } catch (_) {
      return raw;
    }
  }
}

// ---------- Status bar ----------

class NotepadStatusBar extends StatelessWidget {
  const NotepadStatusBar({
    super.key,
    required this.state,
    required this.onEncodingPressed,
  });

  final NotepadUiState state;
  final VoidCallback? onEncodingPressed;

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
              _formatStatus(state.statusText),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textTertiary, fontSize: 11),
            ),
          ),
          Text(
            'notepad.status.ln_col'
                .tr(args: ['${state.cursor.line}', '${state.cursor.column}']),
            style: TextStyle(color: palette.textTertiary, fontSize: 11),
          ),
          const SizedBox(width: 14),
          Text(
            'notepad.status.offset'.tr(args: ['${state.cursor.offset}']),
            style: TextStyle(color: palette.textTertiary, fontSize: 11),
          ),
          const SizedBox(width: 14),
          if (state.hasOpenFile) ...[
            TextButton(
              onPressed: onEncodingPressed,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: palette.textTertiary,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: Text(state.encodingName),
            ),
            const SizedBox(width: 14),
          ],
          Text(
            'common.line_count_format'.tr(args: ['${state.lineCount}']),
            style: TextStyle(color: palette.textTertiary, fontSize: 11),
          ),
          const SizedBox(width: 14),
          Text(
            'common.character_count_format'.tr(args: ['${state.charCount}']),
            style: TextStyle(color: palette.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static String _formatStatus(String raw) {
    if (raw.isEmpty) return 'notepad.status.ready'.tr();
    final parts = raw.split('|');
    final key = parts.first;
    final args = parts.skip(1).toList();
    try {
      return key.tr(args: args.isEmpty ? null : args);
    } catch (_) {
      return raw;
    }
  }
}

// ---------- Menu button helper ----------

Widget _menuButton(
    ThemePalette palette, IconData icon, String label, List<Widget> children) {
  return MenuAnchor(
    builder: (context, controller, _) => InkWell(
      onTap: () => controller.isOpen ? controller.close() : controller.open(),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(icon, size: 14, color: palette.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: palette.windowTitleForeground)),
          ],
        ),
      ),
    ),
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(palette.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: palette.borderSubtle)),
      ),
    ),
    menuChildren: children,
  );
}
