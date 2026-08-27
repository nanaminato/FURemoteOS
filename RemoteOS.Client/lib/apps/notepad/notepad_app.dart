import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/theme_service.dart';

/// A simple Notepad application with toolbar, word wrap, and font size controls.
/// Mirrors the original Avalonia Notepad UX (minimal, like classic Windows Notepad).
class NotepadApp extends ConsumerStatefulWidget {
  const NotepadApp({super.key});

  @override
  ConsumerState<NotepadApp> createState() => _NotepadAppState();
}

class _NotepadAppState extends ConsumerState<NotepadApp> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _wordWrap = true;
  bool _showStatusBar = true;
  double _fontSize = 14;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _lineCount => '\n'.allMatches(_controller.text).length + 1;

  int get _charCount => _controller.text.length;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return Column(
      children: [
        _buildMenuBar(palette),
        Expanded(
          child: Container(
            color: palette.surface,
            child: TextField(
              controller: _controller,
              scrollController: _scrollController,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontFamilyFallback: const ['Courier New', 'monospace'],
                fontSize: _fontSize,
                height: 1.35,
                color: palette.textPrimary,
              ),
              cursorColor: palette.accent,
              cursorWidth: 2,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                border: InputBorder.none,
                filled: true,
                fillColor: palette.surface,
                contentPadding: const EdgeInsets.all(14),
                hintText: 'Start typing...',
                hintStyle:
                    TextStyle(color: palette.textTertiary, fontSize: _fontSize),
                isCollapsed: true,
                isDense: false,
              ),
              // Note: Flutter TextField always wraps at layout width.
              // Setting [maxLines: null] enables soft wrapping (default).
              // For no-wrap, we'd need a horizontal SingleChildScrollView.
            ),
          ),
        ),
        if (_showStatusBar) _buildStatusBar(palette),
      ],
    );
  }

  Widget _buildMenuBar(ThemePalette palette) {
    return Container(
      height: 32,
      color: palette.windowTitleBarBackground,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          _menuButton(palette, Icons.description_outlined, 'File', [
            MenuItemButton(
              onPressed: _newDoc,
              leadingIcon: const Icon(Icons.note_add_outlined, size: 16),
              child: Text('${'common.new'.tr()}    Ctrl+N',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: () {},
              leadingIcon: const Icon(Icons.folder_open_outlined, size: 16),
              child: Text('${'common.open_ellipsis'.tr()}    Ctrl+O',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: () {},
              leadingIcon: const Icon(Icons.save_outlined, size: 16),
              child: Text('${'common.save'.tr()}    Ctrl+S',
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: () {},
              leadingIcon: const Icon(Icons.save_as_outlined, size: 16),
              child: Text('${'common.save_as_ellipsis'.tr()}',
                  style: const TextStyle(fontSize: 13)),
            ),
          ]),
          _menuButton(palette, Icons.edit_outlined, 'Edit', [
            MenuItemButton(
              onPressed: () => _controller.text = '',
              leadingIcon: const Icon(Icons.delete_outline, size: 16),
              child: const Text('Clear all', style: TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: () {
                final sel = _controller.selection;
                if (sel.isValid) {
                  // ignore: deprecated_member_use
                  _controller.clearComposing();
                }
              },
              leadingIcon: const Icon(Icons.content_copy, size: 16),
              child:
                  const Text('Copy    Ctrl+C', style: TextStyle(fontSize: 13)),
            ),
          ]),
          _menuButton(palette, Icons.view_quilt_outlined, 'View', [
            MenuItemButton(
              leadingIcon: Icon(
                  _wordWrap ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 16),
              onPressed: () => setState(() => _wordWrap = !_wordWrap),
              child: const Text('Word wrap', style: TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              leadingIcon: Icon(
                  _showStatusBar
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 16),
              onPressed: () => setState(() => _showStatusBar = !_showStatusBar),
              child: const Text('Status bar', style: TextStyle(fontSize: 13)),
            ),
            SubmenuButton(
              menuChildren: [
                for (final sz in [
                  10.0,
                  11.0,
                  12.0,
                  14.0,
                  16.0,
                  18.0,
                  20.0,
                  24.0
                ])
                  MenuItemButton(
                    onPressed: () => setState(() => _fontSize = sz),
                    child: Text('${sz.toInt()} pt',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                sz == _fontSize ? FontWeight.w700 : null)),
                  ),
              ],
              leadingIcon: const Icon(Icons.text_fields, size: 16),
              child: const Text('Font size', style: TextStyle(fontSize: 13)),
            ),
            SubmenuButton(
              menuChildren: [
                MenuItemButton(
                  onPressed: () => setState(
                      () => _fontSize = (_fontSize - 1).clamp(8.0, 36.0)),
                  child: const Text('Zoom out   Ctrl+-',
                      style: TextStyle(fontSize: 13)),
                ),
                MenuItemButton(
                  onPressed: () => setState(
                      () => _fontSize = (_fontSize + 1).clamp(8.0, 36.0)),
                  child: const Text('Zoom in   Ctrl++',
                      style: TextStyle(fontSize: 13)),
                ),
                MenuItemButton(
                  onPressed: () => setState(() => _fontSize = 14),
                  child: const Text('Restore default zoom',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
              leadingIcon: const Icon(Icons.zoom_out_map_outlined, size: 16),
              child: const Text('Zoom', style: TextStyle(fontSize: 13)),
            ),
          ]),
          const Spacer(),
          _toolIcon(palette, Icons.text_decrease,
              onTap: () =>
                  setState(() => _fontSize = (_fontSize - 1).clamp(8.0, 36.0))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${_fontSize.toInt()}pt',
              style: TextStyle(color: palette.textSecondary, fontSize: 11),
            ),
          ),
          _toolIcon(palette, Icons.text_increase,
              onTap: () =>
                  setState(() => _fontSize = (_fontSize + 1).clamp(8.0, 36.0))),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _menuButton(ThemePalette palette, IconData icon, String label,
      List<Widget> children) {
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

  Widget _toolIcon(ThemePalette palette, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: palette.textSecondary),
      ),
    );
  }

  Widget _buildStatusBar(ThemePalette palette) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(
        children: [
          Text('common.line_count_format'.tr(args: ['$_lineCount']),
              style: TextStyle(color: palette.textTertiary, fontSize: 11)),
          const SizedBox(width: 16),
          Text('common.character_count_format'.tr(args: ['$_charCount']),
              style: TextStyle(color: palette.textTertiary, fontSize: 11)),
          const Spacer(),
          Text('UTF-8',
              style: TextStyle(color: palette.textTertiary, fontSize: 11)),
          const SizedBox(width: 16),
          Text('LF',
              style: TextStyle(color: palette.textTertiary, fontSize: 11)),
          const SizedBox(width: 16),
          Text('${(_wordWrap ? 'Wrap' : 'No wrap')}',
              style: TextStyle(color: palette.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }

  void _newDoc() {
    if (_controller.text.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Create new document'),
          content: const Text('Unsaved changes will be lost. Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.cancel'.tr())),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _controller.clear();
              },
              child: Text('common.ok'.tr()),
            ),
          ],
        ),
      );
    } else {
      _controller.clear();
    }
  }
}
