// Domain model for a remote terminal session summary.
//
// Mirrors `RemoteOS.Protocol.Hubs.TerminalSessionInfo` (sessionId / createdAt
// / hasExited). Kept in the domain layer so neither the repository nor the
// discovery coordinator leak raw JSON into the desktop shell.
//
// `hasExited == true` means the PTY has already terminated; clients must not
// try to attach such sessions (the server will turn an attach into a new
// session instead of replaying the dead buffer).

import 'package:flutter/foundation.dart';

@immutable
class TerminalSessionInfo {
  const TerminalSessionInfo({
    required this.sessionId,
    required this.createdAt,
    required this.hasExited,
  });

  final String sessionId;

  /// Server-side creation timestamp. The server serializes this as an
  /// ISO-8601 DateTimeOffset (e.g. `2026-08-28T12:34:56.789+00:00`).
  final DateTime createdAt;

  /// Whether the underlying PTY has already exited.
  final bool hasExited;

  factory TerminalSessionInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['createdAt'];
    return TerminalSessionInfo(
      sessionId: (json['sessionId'] ?? '').toString(),
      createdAt: _parseDateTime(raw) ?? DateTime.fromMillisecondsSinceEpoch(0),
      hasExited: (json['hasExited'] as bool?) ?? false,
    );
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'createdAt': createdAt.toIso8601String(),
        'hasExited': hasExited,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TerminalSessionInfo && other.sessionId == sessionId);

  @override
  int get hashCode => sessionId.hashCode;
}
