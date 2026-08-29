// Terminal View UI state.
//
// The View is deliberately simple: the heavy rendering (xterm character
// grid) is owned by the [Terminal] controller from package:xterm2, which
// the View constructs and hands to the ViewModel via sink wrappers.  The
// state here therefore only carries chrome-level presentation: connection
// status, session id, errors, and exit codes.
//
// Localization of the status label is intentionally performed in the View
// layer (View owns lookup of theme/l10n keys per ARCHITECTURE.md § 8).

import 'package:flutter/foundation.dart';

import '../domain/terminal_repository.dart';

@immutable
class TerminalUiState {
  const TerminalUiState({
    required this.connectionState,
    required this.sessionId,
    required this.errorMessage,
    required this.exitCode,
    required this.title,
  });

  factory TerminalUiState.initial() => const TerminalUiState(
        connectionState: TerminalConnectionState.connecting,
        sessionId: null,
        errorMessage: null,
        exitCode: null,
        title: null,
      );

  final TerminalConnectionState connectionState;
  final String? sessionId;
  final String? errorMessage;
  final int? exitCode;

  /// Optional title propagated from the remote shell (xterm OSC 0 / OSC 2).
  /// Avalonia uses this as the chrome status text when non-empty.
  final String? title;

  bool get isConnected =>
      connectionState == TerminalConnectionState.connected;

  TerminalUiState copyWith({
    TerminalConnectionState? connectionState,
    String? sessionId,
    String? errorMessage,
    int? exitCode,
    String? title,
    bool clearError = false,
    bool clearExitCode = false,
    bool clearTitle = false,
  }) {
    return TerminalUiState(
      connectionState: connectionState ?? this.connectionState,
      sessionId: sessionId ?? this.sessionId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      exitCode: clearExitCode ? null : (exitCode ?? this.exitCode),
      title: clearTitle ? null : (title ?? this.title),
    );
  }
}
