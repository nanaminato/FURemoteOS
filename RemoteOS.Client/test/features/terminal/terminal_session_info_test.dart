// Unit tests for the [TerminalSessionInfo] domain model.
//
// The repository's `listSessions` cannot be unit-tested without mocking the
// SignalR transport, but the JSON → domain mapping it depends on is non-trivial
// (DateTimeOffset parsing, missing-field tolerance, equality by sessionId) and
// worth pinning down so a future server-side serialization change does not
// silently break desktop terminal restoration.

import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/features/terminal/domain/terminal_session_info.dart';

void main() {
  group('TerminalSessionInfo.fromJson', () {
    test('parses a well-formed server payload', () {
      final info = TerminalSessionInfo.fromJson(const {
        'sessionId': 'abc-123',
        'createdAt': '2026-08-28T12:34:56.789+00:00',
        'hasExited': false,
      });
      expect(info.sessionId, 'abc-123');
      expect(info.hasExited, isFalse);
      expect(info.createdAt.toIso8601String(), '2026-08-28T12:34:56.789Z');
    });

    test('tolerates a missing hasExited field (defaults to false)', () {
      final info = TerminalSessionInfo.fromJson(const {
        'sessionId': 'abc-123',
        'createdAt': '2026-08-28T12:34:56.789+00:00',
      });
      expect(info.hasExited, isFalse);
    });

    test('tolerates a missing sessionId (becomes empty string)', () {
      final info = TerminalSessionInfo.fromJson(const {
        'createdAt': '2026-08-28T12:34:56.789+00:00',
        'hasExited': true,
      });
      expect(info.sessionId, '');
      expect(info.hasExited, isTrue);
    });

    test('falls back to epoch when createdAt cannot be parsed', () {
      final info = TerminalSessionInfo.fromJson(const {
        'sessionId': 'abc-123',
        'createdAt': 'not-a-date',
        'hasExited': false,
      });
      expect(
          info.createdAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: false));
    });

    test('equality is by sessionId only', () {
      final a = TerminalSessionInfo(
        sessionId: 'same',
        createdAt: DateTime.utc(2026, 8, 28),
        hasExited: false,
      );
      final b = TerminalSessionInfo(
        sessionId: 'same',
        createdAt: DateTime.utc(2026, 8, 29),
        hasExited: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
