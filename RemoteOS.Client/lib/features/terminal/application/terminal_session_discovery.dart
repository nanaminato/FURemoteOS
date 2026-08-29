// Terminal session discovery coordinator.
//
// Bridges the desktop shell (which knows about the authenticated session but
// must not import the SignalR transport per ARCHITECTURE.md § 8 / § 11) and
// the terminal repository. Exposed as a riverpod provider so the shell calls
// `ref.read(terminalSessionDiscoveryProvider).discover(auth)` instead of
// touching [SignalRTerminalRepository] directly.
//
// The discovery call is read-only: it lists the user's existing terminal
// sessions so the desktop can restore them on sign-in, matching Avalonia's
// "PTY is decoupled from hub connections" lifecycle.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../data/repositories/signalr_terminal_repository.dart';
import '../domain/terminal_repository.dart';
import '../domain/terminal_session_info.dart';

class TerminalSessionDiscovery {
  TerminalSessionDiscovery({required TerminalRepository repository})
      : _repository = repository;

  final TerminalRepository _repository;

  /// Returns the user's existing (non-exited) terminal sessions, or an empty
  /// list when the session is unavailable or the lookup fails. Failures are
  /// swallowed on purpose: terminal restoration is best-effort and must not
  /// block the desktop from finishing its restore sequence.
  Future<List<TerminalSessionInfo>> discover(AuthSessionState auth) async {
    if (!auth.isAuthenticated ||
        auth.serverUrl == null ||
        auth.accessToken == null) {
      return const [];
    }
    try {
      return await _repository.listSessions(
        serverUrl: auth.serverUrl!,
        accessToken: auth.accessToken!,
      );
    } catch (_) {
      return const [];
    }
  }
}

/// Stable coordinator backed by a transient [SignalRTerminalRepository].
/// Reusing the same repository instance is safe here because [listSessions]
/// opens its own short-lived hub connection and never touches the
/// connection-scoped state owned by an open terminal window.
final terminalSessionDiscoveryProvider = Provider<TerminalSessionDiscovery>(
  (ref) => TerminalSessionDiscovery(repository: SignalRTerminalRepository()),
);
