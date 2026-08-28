import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_hub/signalr_client.dart';
import 'package:xterm2/flutter.dart';
import 'package:xterm2/xterm.dart';

import '../../core/auth/auth_service.dart';

/// Remote PTY terminal backed by the server's `/hubs/terminals` SignalR hub.
/// The server transports raw PTY bytes; [Terminal] performs VT/xterm parsing.
class TerminalApp extends ConsumerStatefulWidget {
  const TerminalApp({super.key, this.workingDirectory, this.sessionId});

  final String? workingDirectory;
  final String? sessionId;

  @override
  ConsumerState<TerminalApp> createState() => _TerminalAppState();
}

class _TerminalAppState extends ConsumerState<TerminalApp> {
  late final Terminal _terminal;
  HubConnection? _connection;
  String? _sessionId;
  String? _error;
  _TerminalConnectionState _state = _TerminalConnectionState.connecting;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000)
      ..onOutput = _sendInput
      ..onResize = _resize;
    unawaited(_connect());
  }

  @override
  void dispose() {
    // Detach only: the hub retains the PTY for a later restore.
    final connection = _connection;
    if (connection != null) unawaited(connection.stop());
    super.dispose();
  }

  Future<void> _connect() async {
    final auth = ref.read(authProvider);
    final serverUrl = auth.serverUrl;
    if (serverUrl == null || auth.accessToken == null) {
      _setFailure('Not signed in.');
      return;
    }
    final connection = HubConnectionBuilder()
        .withUrl(
          Uri.parse(serverUrl).resolve('/hubs/terminals').toString(),
          options: HttpConnectionOptions(
            accessTokenFactory: () async =>
                ref.read(authProvider).accessToken ?? '',
          ),
        )
        .build();
    _connection = connection;
    connection.on('OnOutput', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final bytes = _bytesFromHub(arguments.first);
        if (bytes.isNotEmpty) {
          _terminal.write(utf8.decode(bytes, allowMalformed: true));
        }
      }
      return null;
    });
    connection.on('OnProcessExited', (arguments) {
      final code = arguments?.first;
      _terminal.write(
          '\r\n\x1b[90mProcess exited${code == null ? '' : ' ($code)'}.\x1b[0m\r\n');
      if (mounted) setState(() => _state = _TerminalConnectionState.exited);
      return null;
    });
    connection.onclose(({error}) {
      if (!mounted || _closing) return;
      setState(() {
        _state = _TerminalConnectionState.disconnected;
        _error = error?.toString();
      });
    });

    try {
      await connection.start();
      final response = await connection.invoke('Start', args: [
        {
          'columns': _terminal.viewWidth,
          'rows': _terminal.viewHeight,
          'widthPixels': 0,
          'heightPixels': 0,
          'shell': null,
          'workingDirectory': widget.workingDirectory,
        },
        widget.sessionId,
      ]);
      _sessionId = (response as Map?)?['sessionId']?.toString();
      if (mounted) setState(() => _state = _TerminalConnectionState.connected);
    } catch (error) {
      _setFailure(error.toString());
      unawaited(connection.stop());
    }
  }

  void _sendInput(String value) {
    final connection = _connection;
    if (connection == null || _state != _TerminalConnectionState.connected)
      return;
    // System.Text.Json represents C# byte[] as a Base64 JSON string.
    unawaited(
        connection.send('Input', args: [base64Encode(utf8.encode(value))]));
  }

  void _resize(int columns, int rows, int widthPixels, int heightPixels) {
    final connection = _connection;
    if (connection == null || _state != _TerminalConnectionState.connected)
      return;
    unawaited(connection
        .send('Resize', args: [columns, rows, widthPixels, heightPixels]));
  }

  Future<void> _killSession() async {
    final connection = _connection;
    if (connection == null) return;
    setState(() => _closing = true);
    try {
      await connection.invoke('Close');
      await connection.stop();
    } catch (_) {
      // A dropped connection means there is no local attachment left to close.
    }
    if (mounted) setState(() => _state = _TerminalConnectionState.disconnected);
  }

  void _setFailure(String error) {
    if (!mounted) return;
    setState(() {
      _state = _TerminalConnectionState.disconnected;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (_state) {
      _TerminalConnectionState.connecting => 'Connecting…',
      _TerminalConnectionState.connected => 'Connected',
      _TerminalConnectionState.exited => 'Process exited',
      _TerminalConnectionState.disconnected => 'Disconnected',
    };
    final connected = _state == _TerminalConnectionState.connected;
    return ColoredBox(
      color: const Color(0xFF1A1B26),
      child: Column(children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: const Color(0xFF24283B),
          child: Row(children: [
            Icon(
                connected
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                size: 16,
                color: connected
                    ? const Color(0xFF9ECE6A)
                    : const Color(0xFFF7768E)),
            const SizedBox(width: 6),
            Text(status,
                style: const TextStyle(color: Color(0xFFC0CAF5), fontSize: 12)),
            if (_sessionId != null) ...[
              const SizedBox(width: 10),
              Text(
                  'Session ${_sessionId!.substring(0, _sessionId!.length.clamp(0, 8))}',
                  style:
                      const TextStyle(color: Color(0xFF7AA2F7), fontSize: 12)),
            ],
            const Spacer(),
            IconButton(
              tooltip: 'Terminate remote session',
              onPressed: connected ? _killSession : null,
              icon: const Icon(Icons.power_settings_new_outlined, size: 18),
              color: const Color(0xFFF7768E),
            ),
          ]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(_error!,
                style: const TextStyle(color: Color(0xFFF7768E), fontSize: 12)),
          ),
        Expanded(
          child: TerminalView(
            _terminal,
            theme: const TerminalTheme(
              cursor: Color(0xFF7AA2F7),
              selection: Color(0xFF33467C),
              foreground: Color(0xFFC0CAF5),
              background: Color(0xFF1A1B26),
              black: Color(0xFF15161E),
              red: Color(0xFFF7768E),
              green: Color(0xFF9ECE6A),
              yellow: Color(0xFFE0AF68),
              blue: Color(0xFF7AA2F7),
              magenta: Color(0xFFBB9AF7),
              cyan: Color(0xFF7DCFFF),
              white: Color(0xFFC0CAF5),
              brightBlack: Color(0xFF565F89),
              brightRed: Color(0xFFFF9E64),
              brightGreen: Color(0xFF73DACA),
              brightYellow: Color(0xFFFFC777),
              brightBlue: Color(0xFF7AA2F7),
              brightMagenta: Color(0xFFBB9AF7),
              brightCyan: Color(0xFF7DCFFF),
              brightWhite: Color(0xFFC0CAF5),
              searchHitBackground: Color(0xFF33467C),
              searchHitBackgroundCurrent: Color(0xFF7AA2F7),
              searchHitForeground: Color(0xFF1A1B26),
            ),
          ),
        ),
      ]),
    );
  }
}

List<int> _bytesFromHub(Object? value) {
  if (value is String) {
    try {
      return base64Decode(value);
    } on FormatException {
      return utf8.encode(value);
    }
  }
  if (value is List)
    return value.whereType<num>().map((it) => it.toInt()).toList();
  return const [];
}

enum _TerminalConnectionState { connecting, connected, exited, disconnected }
