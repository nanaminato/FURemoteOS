// SignalR-backed Terminal repository implementation.
//
// Wires the hubs/terminals SignalR hub contract: Start, Input, Resize,
// Close client → server, and OnOutput / OnProcessExited server → client.
// System.Text.Json serializes C# byte[] as Base64 strings.

import 'dart:async';
import 'dart:convert';

import 'package:signalr_hub/signalr_client.dart';

import '../../domain/terminal_repository.dart';
import '../../domain/terminal_session_info.dart';

class SignalRTerminalRepository implements TerminalRepository {
  SignalRTerminalRepository();

  HubConnection? _connection;
  TerminalConnectionState _state = TerminalConnectionState.connecting;
  String? _sessionId;

  final StreamController<String> _onOutput =
      StreamController<String>.broadcast();
  final StreamController<int?> _onExited = StreamController<int?>.broadcast();
  final StreamController<Object?> _onClose =
      StreamController<Object?>.broadcast();

  @override
  Stream<String> get onOutput => _onOutput.stream;
  @override
  Stream<int?> get onProcessExited => _onExited.stream;
  @override
  Stream<Object?> get onClose => _onClose.stream;

  @override
  TerminalConnectionState get state => _state;
  @override
  String? get sessionId => _sessionId;

  @override
  Future<void> connect({
    required String serverUrl,
    required String accessToken,
    required int columns,
    required int rows,
    String? workingDirectory,
    String? resumeSessionId,
  }) async {
    final connection = HubConnectionBuilder()
        .withUrl(
          Uri.parse(serverUrl).resolve('/hubs/terminals').toString(),
          options: HttpConnectionOptions(
            accessTokenFactory: () async => accessToken,
          ),
        )
        .build();
    _connection = connection;
    connection.on('OnOutput', (arguments) {
      if (arguments == null || arguments.isEmpty) return null;
      final bytes = _bytesFromHub(arguments.first);
      if (bytes.isNotEmpty) {
        _onOutput.add(utf8.decode(bytes, allowMalformed: true));
      }
      return null;
    });
    connection.on('OnProcessExited', (arguments) {
      _state = TerminalConnectionState.exited;
      _onExited.add(arguments?.first as int?);
      return null;
    });
    connection.onclose(({error}) {
      if (_state == TerminalConnectionState.connected) {
        _state = TerminalConnectionState.disconnected;
      }
      _onClose.add(error);
    });
    await connection.start();
    final response = await connection.invoke('Start', args: [
      {
        'columns': columns,
        'rows': rows,
        'widthPixels': 0,
        'heightPixels': 0,
        'shell': null,
        'workingDirectory': workingDirectory,
      },
      resumeSessionId,
    ]);
    _sessionId = (response as Map?)?['sessionId']?.toString();
    _state = TerminalConnectionState.connected;
  }

  @override
  Future<void> sendInput(String value) async {
    final conn = _connection;
    if (conn == null || _state != TerminalConnectionState.connected) return;
    await conn.send('Input', args: [base64Encode(utf8.encode(value))]);
  }

  @override
  Future<void> resize(int columns, int rows,
      {int widthPx = 0, int heightPx = 0}) async {
    final conn = _connection;
    if (conn == null || _state != TerminalConnectionState.connected) return;
    await conn.send('Resize', args: [columns, rows, widthPx, heightPx]);
  }

  @override
  Future<void> terminateSession() async {
    final conn = _connection;
    if (conn == null) return;
    try {
      await conn.invoke('Close');
      await conn.stop();
    } catch (_) {
      // A dropping transport is equivalent to a closed attachment.
    }
    _state = TerminalConnectionState.disconnected;
  }

  @override
  Future<List<TerminalSessionInfo>> listSessions({
    required String serverUrl,
    required String accessToken,
  }) async {
    // Short-lived connection used only for the ListSessions invocation: we do
    // not want to attach to a PTY here, nor share the long-lived
    // [_connection] owned by the open-terminal handshake. Failure to stop the
    // discovery connection would otherwise leave an extra attachment record
    // on the server for the same user.
    final discovery = HubConnectionBuilder()
        .withUrl(
          Uri.parse(serverUrl).resolve('/hubs/terminals').toString(),
          options: HttpConnectionOptions(
            accessTokenFactory: () async => accessToken,
          ),
        )
        .build();
    try {
      await discovery.start();
      final result = await discovery.invoke('ListSessions');
      final raw = result is List ? result : const [];
      return raw
          .whereType<Map>()
          .map((item) =>
              TerminalSessionInfo.fromJson(Map<String, dynamic>.from(item)))
          .where((info) =>
              info.sessionId.isNotEmpty &&
              // The server turns an attach to a HasExited session into a new
              // PTY, so skipping them keeps "restore" semantics honest.
              !info.hasExited)
          .toList();
    } finally {
      try {
        await discovery.stop();
      } catch (_) {
        // Stopping the discovery transport is best-effort: the server's
        // OnDisconnectedAsync only detaches, so a leaked connection does not
        // kill any PTY.
      }
    }
  }

  @override
  Future<void> dispose() async {
    final conn = _connection;
    _connection = null;
    try {
      if (conn != null) await conn.stop();
    } catch (_) {}
    await _onOutput.close();
    await _onExited.close();
    await _onClose.close();
  }

  static List<int> _bytesFromHub(Object? value) {
    if (value is String) {
      try {
        return base64Decode(value);
      } on FormatException {
        return utf8.encode(value);
      }
    }
    if (value is List) {
      return value.whereType<num>().map((it) => it.toInt()).toList();
    }
    return const [];
  }
}
