// Shared Notepad UI components (Avalonia parity).
//
// Layout mirrors NotepadView.axaml:
//   Row 0  MenuBar (File / Settings menus + document name on the right)
//   Row 1  Expanded TextBox
//   Row 2  StatusBar: StatusText | Encoding | LineCountText | CharacterCountText
//
// Localization (AGENTS.md §23.1): every `.tr()` that carries runtime
// values uses **named** placeholders (`{file}`, `{encoding}`, `{error}`,
// `{line}`, `{count}`). ViewModel / State only ship data and the semantic
// key; this file is the single caller of `.tr(namedArgs: ...)`.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/theme_service.dart';
import '../../application/notepad_view_model.dart';
import '../../domain/notepad_ui_state.dart';

// ---------- Menu bar ----------

class NotepadMenuBar extends StatelessWidget {
  const NotepadMenuBar({super.key, required this.state, required this.vm});
  final NotepadUiState state;
  final NotepadViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.borderDefault)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _menu(
            palette,
            'common.file'.tr(),
            [
              MenuItemButton(
                onPressed: () => vm.newDocumentCommand.runAsync(),
                child: Text(
                  '${'common.new'.tr()}    Ctrl+N',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              MenuItemButton(
                onPressed: () => vm.openDocumentCommand.runAsync(),
                child: Text(
                  '${'common.open_ellipsis'.tr()}    Ctrl+O',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const MenuItemButton(child: Divider(height: 1, thickness: 1)),
              MenuItemButton(
                onPressed: () => vm.saveCommand.runAsync(),
                child: Text(
                  '${'common.save'.tr()}    Ctrl+S',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              MenuItemButton(
                onPressed: () => vm.saveAsCommand.runAsync(),
                child: Text(
                  '${'common.save_as_ellipsis'.tr()}    Ctrl+Shift+S',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          _menu(
            palette,
            'common.settings'.tr(),
            [
              MenuItemButton(
                onPressed: () => vm.openSettingsCommand.runAsync(),
                child: Text(
                  'common.preferences_ellipsis'.tr(),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                _displayedDocumentName(state),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textPrimary.withValues(alpha: 0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _displayedDocumentName(NotepadUiState s) {
    if (!s.hasOpenFile) return 'notepad.document.untitled'.tr();
    return s.documentName;
  }

  static Widget _menu(ThemePalette palette, String label, List<Widget> children) {
    return MenuAnchor(
      builder: (context, controller, _) => InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.textPrimary),
          ),
        ),
      ),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(palette.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: palette.borderDefault),
          ),
        ),
      ),
      menuChildren: children,
    );
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
    return Material(
      color: palette.surface,
      child: Ink(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(
            top: BorderSide(color: palette.borderDefault, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                state.statusKey.tr(namedArgs: state.statusNamedArgs),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textPrimary.withValues(alpha: 0.7),
                ),
              ),
            ),
            _encodingButton(palette),
            const SizedBox(width: 14),
            Text(
              'common.line_count_format'.tr(namedArgs: {
                'line': '${state.lineCount}',
              }),
              style: TextStyle(
                fontSize: 12,
                color: palette.textPrimary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'common.character_count_format'.tr(namedArgs: {
                'count': '${state.charCount}',
              }),
              style: TextStyle(
                fontSize: 12,
                color: palette.textPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encodingButton(ThemePalette palette) {
    return Tooltip(
      message: 'common.file_encoding'.tr(),
      waitDuration: const Duration(milliseconds: 300),
      child: TextButton(
        onPressed: onEncodingPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: palette.textPrimary.withValues(alpha: 0.7),
          textStyle: const TextStyle(fontSize: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        child: Text(state.encodingName),
      ),
    );
  }
}