// Code Editor chrome components.
//
// Splitting responsibilities:
//   * [CodeEditorMenuBar] — top chrome: File/Edit/View menu labels, Save
//     button, explorer-toggle, word-wrap toggle, font-size controls.
//   * [CodeEditorTabBar] — single-tab strip (multi-tab pending shell wiring).
//   * [CodeEditorExplorer] — left-hand "EXPLORER" tree placeholder panel.
//   * [CodeEditorTextField] — central text area with line number gutter.
//   * [CodeEditorStatusBar] — bottom chrome with line/col + dirty marker.

import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/code_editor_view_model.dart';
import '../../domain/code_editor_ui_state.dart';

// ----------------------------- Menu Bar -----------------------------

class CodeEditorMenuBar extends StatelessWidget {
  const CodeEditorMenuBar({super.key, required this.vm});
  final CodeEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 40,
      color: palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListenableBuilder(
        listenable: vm.state,
        builder: (context, _) {
          final s = vm.state.value;
          return Row(
            children: [
              ...['File', 'Edit', 'Selection', 'View', 'Go', 'Run'].map(
                (label) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      minimumSize: const Size(60, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: palette.textPrimary,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: Text(label),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 22,
                color: palette.borderSubtle,
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              ListenableBuilder(
                listenable: vm.saveCommand,
                builder: (_, __) => IconButton(
                  onPressed: vm.canSave() && vm.saveCommand.canRun.value
                      ? () => vm.saveCommand()
                      : null,
                  tooltip: 'Save (Ctrl+S)',
                  icon: Icon(
                    Icons.save_rounded,
                    color: s.isDirty ? palette.accent : palette.textSecondary,
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: vm.toggleExplorerCommand,
                builder: (_, __) => IconButton(
                  onPressed: vm.toggleExplorerCommand.canRun.value
                      ? () => vm.toggleExplorerCommand()
                      : null,
                  tooltip: 'Toggle Explorer',
                  icon: Icon(
                    Icons.folder_copy_outlined,
                    color:
                        s.showExplorer ? palette.accent : palette.textSecondary,
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: vm.toggleWordWrapCommand,
                builder: (_, __) => IconButton(
                  onPressed: vm.toggleWordWrapCommand.canRun.value
                      ? () => vm.toggleWordWrapCommand()
                      : null,
                  tooltip: 'Toggle Word Wrap',
                  icon: Icon(
                    Icons.wrap_text_rounded,
                    color: s.wordWrap ? palette.accent : palette.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: vm.decreaseFontSizeCommand,
                builder: (_, __) => IconButton(
                  onPressed: vm.decreaseFontSizeCommand.canRun.value
                      ? () => vm.decreaseFontSizeCommand()
                      : null,
                  tooltip: 'Decrease font size',
                  icon: const Icon(Icons.text_decrease_rounded),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${s.fontSize.toStringAsFixed(0)}px',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
              ),
              ListenableBuilder(
                listenable: vm.increaseFontSizeCommand,
                builder: (_, __) => IconButton(
                  onPressed: vm.increaseFontSizeCommand.canRun.value
                      ? () => vm.increaseFontSizeCommand()
                      : null,
                  tooltip: 'Increase font size',
                  icon: const Icon(Icons.text_increase_rounded),
                ),
              ),
              if (s.isLoading)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------ Tab Bar ------------------------------

class CodeEditorTabBar extends StatelessWidget {
  const CodeEditorTabBar({super.key, required this.state});
  final CodeEditorUiState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 36,
      color: palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Container(
            height: 36,
            constraints: const BoxConstraints(minWidth: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: palette.surfaceSunken,
              border: Border(
                bottom: BorderSide(color: palette.accent, width: 2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code_outlined,
                  size: 14,
                  color: palette.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  state.fileName,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.textPrimary,
                  ),
                ),
                if (state.isDirty) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------ Explorer -----------------------------

class CodeEditorExplorer extends StatelessWidget {
  const CodeEditorExplorer({super.key, required this.vm});
  final CodeEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 260,
      color: palette.surface,
      child: Column(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            child: Text(
              'EXPLORER',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
                color: palette.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                _treeRow(context, Icons.folder_outlined, 'remoteos',
                    expanded: true, indent: 0),
                _treeRow(context, Icons.folder_open_outlined, 'lib',
                    expanded: true, indent: 1),
                _treeRow(context, Icons.description_outlined,
                    vm.state.value.fileName,
                    indent: 2, active: true),
                _treeRow(context, Icons.description_outlined, 'main.dart',
                    indent: 2),
                _treeRow(context, Icons.folder_outlined, 'src', indent: 1),
                _treeRow(context, Icons.folder_outlined, 'assets', indent: 1),
                _treeRow(context, Icons.description_outlined, 'pubspec.yaml',
                    indent: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeRow(
    BuildContext context,
    IconData icon,
    String label, {
    int indent = 0,
    bool expanded = false,
    bool active = false,
  }) {
    final palette = context.palette;
    return Container(
      height: 26,
      color: active ? palette.borderSubtle.withValues(alpha: .35) : null,
      padding: EdgeInsets.only(left: 6.0 + indent * 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(
            expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
            size: 14,
            color: palette.textTertiary,
          ),
          const SizedBox(width: 2),
          Icon(icon, size: 15, color: palette.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------- Editor text area -------------------------

class CodeEditorTextField extends StatefulWidget {
  const CodeEditorTextField({super.key, required this.vm});
  final CodeEditorViewModel vm;

  @override
  State<CodeEditorTextField> createState() => _CodeEditorTextFieldState();
}

class _CodeEditorTextFieldState extends State<CodeEditorTextField> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Seed controller from current state (welcome doc or pre-loaded doc).
    _controller.text = widget.vm.state.value.documentText;
    // Listen for programmatic document replacement (after remote load).
    widget.vm.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.vm.state.removeListener(_onStateChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final doc = widget.vm.state.value.documentText;
    if (_controller.text != doc) {
      final caret = _controller.selection.baseOffset;
      _controller.value = TextEditingValue(
        text: doc,
        selection: TextSelection.collapsed(
          offset: caret.clamp(0, doc.length),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E2030) : const Color(0xFFFFFFFF);
    final gutterFg = palette.textTertiary;
    return ListenableBuilder(
      listenable: widget.vm.state,
      builder: (context, _) {
        final s = widget.vm.state.value;
        return LayoutBuilder(
          builder: (context, c) => Row(
            children: [
              Container(
                width: 42,
                color: bg,
                padding: const EdgeInsets.only(top: 10),
                alignment: Alignment.topRight,
                child: _buildLineNumbers(s, gutterFg),
              ),
              Container(width: 1, color: palette.borderSubtle),
              Expanded(
                child: Container(
                  color: bg,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        maxLines: s.wordWrap ? null : 1,
                        keyboardType: TextInputType.multiline,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: s.fontSize,
                          height: 1.45,
                          color: palette.textPrimary,
                        ),
                        decoration: const InputDecoration.collapsed(
                          hintText: '',
                        ),
                        onChanged: widget.vm.updateDocument,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineNumbers(CodeEditorUiState s, Color fg) {
    final count = s.documentText.split('\n').length;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        List.generate(count, (i) => '${i + 1}').join('\n'),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: s.fontSize,
          height: 1.45,
          color: fg,
        ),
      ),
    );
  }
}

// ----------------------------- Status Bar ----------------------------

class CodeEditorStatusBar extends StatelessWidget {
  const CodeEditorStatusBar({super.key, required this.vm});
  final CodeEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: vm.state,
      builder: (context, _) {
        final s = vm.state.value;
        return Container(
          height: 24,
          color: palette.accent,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                s.remotePath != null ? 'Connected to server' : 'Local preview',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.check_circle_outline_rounded,
                  size: 13, color: Colors.white.withValues(alpha: .9)),
              const SizedBox(width: 6),
              const Text(
                'No errors',
                style: TextStyle(fontSize: 11.5, color: Colors.white),
              ),
              const Spacer(),
              Text(
                s.isDirty ? 'Unsaved' : 'Saved',
                style: const TextStyle(fontSize: 11.5, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Text(
                'UTF-8',
                style: TextStyle(
                    fontSize: 11.5, color: Colors.white.withValues(alpha: .9)),
              ),
              const SizedBox(width: 16),
              Text(
                'Ln ${_lineCount(s.documentText)} · Dart',
                style: TextStyle(
                    fontSize: 11.5, color: Colors.white.withValues(alpha: .9)),
              ),
            ],
          ),
        );
      },
    );
  }

  int _lineCount(String text) {
    if (text.isEmpty) return 1;
    return text.split('\n').length;
  }
}
