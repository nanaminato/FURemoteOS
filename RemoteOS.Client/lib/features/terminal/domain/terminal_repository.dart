// Terminal repository interface (ARCHITECTURE.md § 11).
//
// RemoteOS terminals are bidirectional PTY streams:
//   * client writes user keystrokes via [sendInput] / [resize]
//   * server pushes UTF-8 bytes (or exit events) back over the hub
//
// The repository exposes the inbound data as typed Dart streams so the
// ViewModel never wires a SignalR listener itself.

import 'dart:async';

/// Lifecycle state of the remote terminal attachment.
enum TerminalConnectionState { connecting, connected, exited, disconnected }

/// High-level repository contract for a single terminal attachment.
///
/// An individual instance is **not** safe to share across windows; create a
/// fresh repository per open Terminal app via the transient factory below.
abstract interface class TerminalRepository {
  /// Inbound bytes, decoded as a UTF-8 string (allowing malformed bytes).
  Stream<String> get onOutput;

  /// Fired once when the remote shell exits.  Carries the optional POSIX exit
  /// code as reported by the host.
  Stream<int?> get onProcessExited;

  /// Fired whenever the underlying transport dies without an explicit close.
  Stream<Object?> get onClose;

  TerminalConnectionState get state;

  /// The server-assigned session id, if a Start handshake has completed.
  String? get sessionId;

  // ---- Lifecycle ----
  Future<void> connect({
    required String serverUrl,
    required String accessToken,
    required int columns,
    required int rows,
    String? workingDirectory,
    String? resumeSessionId,
  });

  // ---- Client → server ----
  Future<void> sendInput(String value);
  Future<void> resize(int columns, int rows,
      {int widthPx = 0, int heightPx = 0});
  Future<void> terminateSession();
  Future<void> dispose();
}
