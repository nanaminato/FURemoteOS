// Terminal View (xterm chrome + rendering host).
//
// Owns the xterm2 [Terminal] text buffer controller (because it is a
// rendering concern per ARCHITECTURE.md § 8 — VT/xterm parsing).  Pipes the
// inbound byte stream into it via a [TerminalOutputSink] installed on the
// ViewModel; user keystrokes / resizes / terminate-button taps are routed
// back through the VM's typed methods and gating helpers.

import 'package:flutter/material.dart';
import 'package:xterm2/flutter.dart' as xterm;
import 'package:xterm2/xterm.dart';

import '../application/terminal_view_model.dart';
import '../domain/terminal_ui_state.dart';

class TerminalView extends StatefulWidget {
  const TerminalView({
    super.key,
    required this.vm,
    required this.serverUrl,
    required this.accessToken,
    this.workingDirectory,
    this.resumeSessionId,
  });

  final TerminalViewModel vm;
  final String serverUrl;
  final String accessToken;
  final String? workingDirectory;
  final String? resumeSessionId;

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  late final Terminal _terminal;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    // Install output sink so the VM can feed inbound data to the xterm buffer.
    widget.vm.outputSink = _writeChunk;
    _terminal
      ..onOutput = _handleKeystroke
      ..onResize = _handleResize;
    // Kick off the PTY handshake once the xterm controller knows its size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.vm.prepareStartArgs((
        serverUrl: widget.serverUrl,
        accessToken: widget.accessToken,
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
        workingDirectory: widget.workingDirectory,
        resumeSessionId: widget.resumeSessionId,
      ));
      if (widget.vm.startCommand.canRun.value) {
        widget.vm.startCommand();
      }
    });
  }

  @override
  void dispose() {
    widget.vm.outputSink = null;
    super.dispose();
  }

  void _writeChunk(String chunk) {
    // Output may arrive on the microtask queue within a build pass; guard so
    // we don't write into the xterm2 controller while it is mid-render.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _terminal.write(chunk);
    });
  }

  void _handleKeystroke(String value) {
    if (widget.vm.canSendInput()) {
      // ignore: discarded_futures
      widget.vm.sendInput(value);
    }
  }

  void _handleResize(int cols, int rows, int wpx, int hpx) {
    if (widget.vm.canResize()) {
      // ignore: discarded_futures
      widget.vm.resize(cols, rows, widthPx: wpx, heightPx: hpx);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1A1B26);
    const accentOk = Color(0xFF9ECE6A);
    const accentBad = Color(0xFFF7768E);
    const infoFg = Color(0xFFC0CAF5);
    const sessionFg = Color(0xFF7AA2F7);
    return ColoredBox(
      color: bg,
      child: Column(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF24283B),
            child: ListenableBuilder(
              listenable: widget.vm.state,
              builder: (context, _) {
                final s = widget.vm.state.value;
                return _buildToolbar(s, accentOk, accentBad, infoFg, sessionFg);
              },
            ),
          ),
          ListenableBuilder(
            listenable: widget.vm.state,
            builder: (context, _) {
              final err = widget.vm.state.value.errorMessage;
              if (err == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(
                  err,
                  style: const TextStyle(color: accentBad, fontSize: 12),
                ),
              );
            },
          ),
          Expanded(
            child: xterm.TerminalView(
              _terminal,
              theme: TerminalTheme(
                cursor: const Color(0xFF7AA2F7),
                selection: const Color(0xFF33467C),
                foreground: const Color(0xFFC0CAF5),
                background: bg,
                black: const Color(0xFF15161E),
                red: const Color(0xFFF7768E),
                green: const Color(0xFF9ECE6A),
                yellow: const Color(0xFFE0AF68),
                blue: const Color(0xFF7AA2F7),
                magenta: const Color(0xFFBB9AF7),
                cyan: const Color(0xFF7DCFFF),
                white: const Color(0xFFC0CAF5),
                brightBlack: const Color(0xFF565F89),
                brightRed: const Color(0xFFFF9E64),
                brightGreen: const Color(0xFF73DACA),
                brightYellow: const Color(0xFFFFC777),
                brightBlue: const Color(0xFF7AA2F7),
                brightMagenta: const Color(0xFFBB9AF7),
                brightCyan: const Color(0xFF7DCFFF),
                brightWhite: const Color(0xFFC0CAF5),
                searchHitBackground: const Color(0xFF33467C),
                searchHitBackgroundCurrent: const Color(0xFF7AA2F7),
                searchHitForeground: bg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    TerminalUiState s,
    Color ok,
    Color bad,
    Color infoFg,
    Color sessionFg,
  ) {
    final connected = s.isConnected;
    final sessionId = s.sessionId;
    return Row(
      children: [
        Icon(
          connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          size: 16,
          color: connected ? ok : bad,
        ),
        const SizedBox(width: 6),
        Text(
          s.statusLabel,
          style: TextStyle(color: infoFg, fontSize: 12),
        ),
        if (sessionId != null) ...[
          const SizedBox(width: 10),
          Text(
            'Session ${sessionId.substring(0, sessionId.length.clamp(0, 8))}',
            style: TextStyle(color: sessionFg, fontSize: 12),
          ),
        ],
        const Spacer(),
        ListenableBuilder(
          listenable: widget.vm.state,
          builder: (context, _) {
            final enabled = widget.vm.canTerminate();
            return IconButton(
              tooltip: 'Terminate remote session',
              onPressed: enabled
                  ? () {
                      // ignore: discarded_futures
                      widget.vm.terminateSession();
                    }
                  : null,
              icon: const Icon(Icons.power_settings_new_outlined, size: 18),
              color: bad,
            );
          },
        ),
      ],
    );
  }
}
