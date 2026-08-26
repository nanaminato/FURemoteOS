import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/theme_service.dart';
import '../../core/auth/auth_service.dart';

/// A simple, aesthetic terminal emulator with:
/// - Command input history
/// - Built-in commands (help, clear, echo, date, theme, whoami, open)
/// - Visual output buffers with colored text
/// This is a local mock terminal; real SignalR-backed transport is
/// available via [TerminalTransport] (WIP port from Avalonia).
class TerminalApp extends ConsumerStatefulWidget {
  const TerminalApp({super.key});

  @override
  ConsumerState<TerminalApp> createState() => _TerminalAppState();
}

class _TerminalAppState extends ConsumerState<TerminalApp> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();

  final List<_TerminalLine> _buffer = [];
  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _writeBanner();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inputFocus.requestFocus());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _writeBanner() {
    _writeln('RemoteOS Terminal v1.0.0 (Flutter)', color: const Color(0xFF4CC2FF), bold: true);
    _writeln('Type "help" for available commands.', color: const Color(0xFFA8A8A8));
    _writeln('');
  }

  void _writeln(String text, {Color? color, bool bold = false}) {
    _buffer.add(_TerminalLine(text: text, color: color, bold: bold));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _submit() {
    final raw = _inputController.text;
    final cmd = raw.trim();
    _writeln('user@remoteos:~\$ $raw', color: const Color(0xFF4CC2FF));
    _inputController.clear();
    if (cmd.isEmpty) return;
    _history.add(cmd);
    _historyIndex = _history.length;
    _runCommand(cmd);
  }

  void _runCommand(String line) {
    final parts = line.split(' ');
    final cmd = parts.first.toLowerCase();
    final args = parts.skip(1).toList();

    switch (cmd) {
      case 'help':
        _help();
        break;
      case 'clear':
        setState(_buffer.clear);
        break;
      case 'echo':
        _writeln(args.join(' '));
        break;
      case 'date':
        _writeln(DateTime.now().toString());
        break;
      case 'whoami':
        final auth = ref.read(authProvider);
        _writeln(auth.username ?? 'guest');
        break;
      case 'pwd':
        _writeln('/home/user');
        break;
      case 'ls':
        _writeln('Documents  Downloads  Pictures  Projects  Desktop  .bashrc', color: const Color(0xFF88C0D0));
        break;
      case 'theme':
        if (args.isEmpty) {
          final state = ref.read(themeProvider);
          _writeln('Theme mode: ${state.kind.name}');
          _writeln('Palette ID: ${state.preferences.paletteId}');
        } else {
          final notifier = ref.read(themeProvider.notifier);
          switch (args[0]) {
            case 'light':
              notifier.setThemeKind(ThemeKind.light);
              _writeln('Switched to light mode.', color: const Color(0xFF6CCB5F));
              break;
            case 'dark':
              notifier.setThemeKind(ThemeKind.dark);
              _writeln('Switched to dark mode.', color: const Color(0xFF6CCB5F));
              break;
            case 'system':
              notifier.setThemeKind(ThemeKind.system);
              _writeln('Switched to system default.', color: const Color(0xFF6CCB5F));
              break;
            default:
              _writeln('Usage: theme [light|dark|system]', color: const Color(0xFFFF7262));
          }
        }
        break;
      case 'exit':
        Navigator.of(context, rootNavigator: true).maybePop();
        break;
      default:
        _writeln('Command not found: $cmd. Try "help".', color: const Color(0xFFFF7262));
    }
    _writeln('');
  }

  void _help() {
    final entries = <(String, String)>[
      ('help', 'Show this help message'),
      ('clear', 'Clear the screen'),
      ('echo <text>', 'Print text to stdout'),
      ('date', 'Show current date and time'),
      ('whoami', 'Print the current user'),
      ('pwd', 'Print the working directory'),
      ('ls', 'List directory contents (mock)'),
      ('theme [light|dark|system]', 'Change UI theme'),
      ('exit', 'Close the terminal window'),
    ];
    for (final (cmd, desc) in entries) {
      _writeln('  ${cmd.padRight(28)} $desc', color: const Color(0xFFCDD6F4));
    }
  }

  void _onKey(RawKeyEvent e) {
    if (e is RawKeyDownEvent) {
      if (e.logicalKey.keyLabel == 'Arrow Up') {
        if (_history.isNotEmpty && _historyIndex > 0) {
          _historyIndex--;
          _inputController.text = _history[_historyIndex];
          _inputController.selection = TextSelection.fromPosition(
            TextPosition(offset: _inputController.text.length),
          );
        }
      } else if (e.logicalKey.keyLabel == 'Arrow Down') {
        if (_historyIndex < _history.length - 1) {
          _historyIndex++;
          _inputController.text = _history[_historyIndex];
        } else {
          _historyIndex = _history.length;
          _inputController.clear();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    const bg = Color(0xFF1A1B26);
    const fg = Color(0xFFCDD6F4);

    return Container(
      color: bg,
      padding: const EdgeInsets.all(12),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: _onKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: SelectionArea(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontFamilyFallback: ['Consolas', 'Courier New', 'monospace'],
                        fontSize: 13,
                        height: 1.45,
                        color: fg,
                      ),
                      children: [
                        for (int i = 0; i < _buffer.length; i++) ...[
                          TextSpan(
                            text: _buffer[i].text,
                            style: TextStyle(
                              color: _buffer[i].color ?? fg,
                              fontWeight: _buffer[i].bold ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                          if (i < _buffer.length - 1) const TextSpan(text: '\n'),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('user@remoteos:~\$',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      color: Color(0xFF4CC2FF),
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      color: fg,
                      height: 1.2,
                    ),
                    cursorColor: const Color(0xFF4CC2FF),
                    cursorWidth: 2,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalLine {
  final String text;
  final Color? color;
  final bool bold;
  _TerminalLine({required this.text, this.color, this.bold = false});
}
