import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_service.dart';
import '../../core/network/remoteos_api.dart';
import '../../features/files/data/remote_file_api.dart';

/// A lean, split-pane code editor modeled after the original CodeEditor view.
/// It keeps documents as independent tabs and is ready to receive Explorer's
/// remote file-open activation once the file API adapter is attached.
class CodeEditorApp extends ConsumerStatefulWidget {
  const CodeEditorApp({super.key, this.remotePath, this.fileName});
  final String? remotePath;
  final String? fileName;

  @override
  ConsumerState<CodeEditorApp> createState() => _CodeEditorAppState();
}

class _CodeEditorAppState extends ConsumerState<CodeEditorApp> {
  late final TextEditingController _controller;
  final _search = TextEditingController();
  bool _showExplorer = true;
  bool _wordWrap = true;
  double _fontSize = 14;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _welcomeSource);
    if (widget.remotePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemoteFile());
    }
  }

  Future<void> _loadRemoteFile() async {
    try {
      final bytes = await RemoteFileApi(ref.read(remoteOsApiProvider))
          .readBytes(widget.remotePath!);
      if (mounted) _controller.text = utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      if (mounted) _controller.text = 'Unable to open remote text file.';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return Column(children: [
      _menu(palette),
      _tabBar(palette),
      Expanded(
          child: Row(children: [
        if (_showExplorer) _explorer(palette),
        if (_showExplorer)
          VerticalDivider(width: 1, thickness: 1, color: palette.borderSubtle),
        Expanded(child: _editor(palette)),
      ])),
      _status(palette),
    ]);
  }

  Widget _menu(ThemePalette palette) => Container(
      height: 40,
      color: palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        _menuButton(palette, 'File', Icons.description_outlined, [
          const MenuItemButton(child: Text('New file')),
          const MenuItemButton(child: Text('Open folder')),
          const MenuItemButton(child: Text('Save'))
        ]),
        _menuButton(palette, 'Edit', Icons.edit_outlined, [
          const MenuItemButton(child: Text('Undo')),
          const MenuItemButton(child: Text('Redo')),
          const MenuItemButton(child: Text('Find'))
        ]),
        _menuButton(palette, 'View', Icons.visibility_outlined, [
          MenuItemButton(
              onPressed: () => setState(() => _wordWrap = !_wordWrap),
              child:
                  Text(_wordWrap ? 'Disable word wrap' : 'Enable word wrap')),
          MenuItemButton(
              onPressed: () => setState(() => _showExplorer = !_showExplorer),
              child: const Text('Toggle explorer'))
        ]),
        const Spacer(),
        IconButton(
            onPressed: () => setState(() => _showExplorer = !_showExplorer),
            tooltip: 'Toggle explorer',
            icon: Icon(Icons.folder_open_outlined,
                size: 19, color: palette.textSecondary)),
        IconButton(
            onPressed: () =>
                setState(() => _fontSize = (_fontSize - 1).clamp(10.0, 28.0)),
            icon: Icon(Icons.text_decrease,
                size: 19, color: palette.textSecondary)),
        Text('${_fontSize.toInt()} px',
            style: TextStyle(fontSize: 11, color: palette.textSecondary)),
        IconButton(
            onPressed: () =>
                setState(() => _fontSize = (_fontSize + 1).clamp(10.0, 28.0)),
            icon: Icon(Icons.text_increase,
                size: 19, color: palette.textSecondary)),
      ]));

  Widget _menuButton(ThemePalette palette, String label, IconData icon,
          List<Widget> children) =>
      MenuAnchor(
        builder: (context, controller, _) => InkWell(
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                child: Row(children: [
                  Icon(icon, size: 15, color: palette.textSecondary),
                  const SizedBox(width: 5),
                  Text(label,
                      style:
                          TextStyle(fontSize: 12, color: palette.textPrimary))
                ]))),
        menuChildren: children,
      );

  Widget _tabBar(ThemePalette palette) => Container(
      height: 37,
      color: palette.surfaceSunken,
      padding: const EdgeInsets.only(left: 8),
      child: Row(children: [
        Container(
            height: 37,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: palette.appBackground,
                border:
                    Border(top: BorderSide(color: palette.accent, width: 2))),
            child: Row(children: [
              Icon(Icons.code_rounded, size: 16, color: palette.accent),
              const SizedBox(width: 7),
              Text(widget.fileName ?? 'welcome.dart',
                  style: TextStyle(fontSize: 12, color: palette.textPrimary)),
              const SizedBox(width: 12),
              Icon(Icons.close_rounded, size: 15, color: palette.textTertiary)
            ])),
        IconButton(
            onPressed: () {}, icon: const Icon(Icons.add_rounded, size: 18)),
      ]));

  Widget _explorer(ThemePalette palette) => SizedBox(
      width: 220,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(children: [
              Text('EXPLORER',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .8,
                      color: palette.textSecondary)),
              const Spacer(),
              Icon(Icons.more_horiz_rounded,
                  size: 18, color: palette.textSecondary)
            ])),
        _tree(palette, 'REMOTE WORKSPACE', Icons.folder_open_rounded, true),
        _tree(palette, 'lib', Icons.folder_rounded, true),
        _file(palette, 'main.dart', Icons.code_rounded),
        _file(palette, 'welcome.dart', Icons.code_rounded, selected: true),
        _tree(palette, 'assets', Icons.folder_rounded, false),
        _file(palette, 'pubspec.yaml', Icons.settings_outlined),
        const Spacer(),
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.borderSubtle))),
            child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded, size: 17),
                    hintText: 'Find files',
                    border: OutlineInputBorder()))),
      ]));

  Widget _tree(
          ThemePalette palette, String name, IconData icon, bool expanded) =>
      Padding(
          padding: const EdgeInsets.only(left: 10),
          child: SizedBox(
              height: 28,
              child: Row(children: [
                Icon(
                    expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 16,
                    color: palette.textTertiary),
                Icon(icon, size: 16, color: const Color(0xFFE9A23B)),
                const SizedBox(width: 6),
                Text(name,
                    style: TextStyle(fontSize: 12, color: palette.textPrimary))
              ])));
  Widget _file(ThemePalette palette, String name, IconData icon,
          {bool selected = false}) =>
      Material(
          color: Colors.transparent,
          child: InkWell(
              onTap: () {},
              child: Container(
                  height: 29,
                  padding: const EdgeInsets.only(left: 42, right: 8),
                  color: selected ? palette.accentMuted : null,
                  child: Row(children: [
                    Icon(icon,
                        size: 15,
                        color:
                            selected ? palette.accent : palette.textSecondary),
                    const SizedBox(width: 7),
                    Expanded(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: palette.textPrimary)))
                  ]))));

  Widget _editor(ThemePalette palette) => Container(
      color: const Color(0xFF1E1E1E),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            width: 48,
            color: const Color(0xFF181818),
            padding: const EdgeInsets.only(top: 14),
            child: Text(List.generate(32, (i) => '${i + 1}').join('\n'),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF858585)))),
        Expanded(
            child: TextField(
          controller: _controller,
          expands: true,
          maxLines: null,
          minLines: null,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: _fontSize,
              height: 1.45,
              color: const Color(0xFFD4D4D4)),
          decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(14, 12, 20, 20)),
        )),
      ]));

  Widget _status(ThemePalette palette) => Container(
      height: 25,
      color: palette.accent,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        const Icon(Icons.sync_rounded, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        const Text('main', style: TextStyle(fontSize: 11, color: Colors.white)),
        const Spacer(),
        const Text('UTF-8   LF   Dart',
            style: TextStyle(fontSize: 11, color: Colors.white))
      ]));
}

const _welcomeSource = '''import 'package:flutter/material.dart';

void main() {
  runApp(const RemoteOSApp());
}

class RemoteOSApp extends StatelessWidget {
  const RemoteOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Welcome to RemoteOS')),
      ),
    );
  }
}
''';
