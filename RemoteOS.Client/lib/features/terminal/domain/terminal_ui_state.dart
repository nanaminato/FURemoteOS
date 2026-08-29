// Terminal View UI state.
//
// The View is deliberately simple: the heavy rendering (xterm character
// grid) is owned by the [Terminal] controller from package:xterm2, which
// the View constructs and hands to the ViewModel via sink wrappers.  The
// state here therefore only carries chrome-level presentation: connection
// status, session id, errors.

import 'package:flutter/foundation.dart';

import '../domain/terminal_repository.dart';

@immutable
class TerminalUiState {
  const TerminalUiState({
    required this.connectionState,
    required this.sessionId,
    required this.errorMessage,
  });

  factory TerminalUiState.initial() => const TerminalUiState(
        connectionState: TerminalConnectionState.connecting,
        sessionId: null,
        errorMessage: null,
      );

  final TerminalConnectionState connectionState;
  final String? sessionId;
  final String? errorMessage;

  String get statusLabel => switch (connectionState) {
        TerminalConnectionState.connecting => 'Connecting…',
        TerminalConnectionState.connected => 'Connected',
        TerminalConnectionState.exited => 'Process exited',
        TerminalConnectionState.disconnected => 'Disconnected',
      };

  bool get isConnected => connectionState == TerminalConnectionState.connected;

  TerminalUiState copyWith({
    TerminalConnectionState? connectionState,
    String? sessionId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TerminalUiState(
      connectionState: connectionState ?? this.connectionState,
      sessionId: sessionId ?? this.sessionId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
