// Terminal ViewModel.
//
// Presentation state lives in the single [ValueNotifier<TerminalUiState>].
// The terminal text buffer is a rendering concern owned by the View layer
// (package:xterm2's Terminal controller) — the ViewModel simply pipes the
// repository's onOutput stream back into a UI-installed sink callback.
//
// Outbound (keystrokes) are modelled as async methods. Open-settings uses
// the same callback-wireup pattern as Avalonia: the host (terminal_app.dart)
// installs [requestSettingsAsync] so the chrome menu item can trigger a
// workspace dialog without the VM importing Flutter dialog types.

import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';

import '../../../app/dependency_injection.dart' as app_di;
import '../../../core/commands/base_view_model.dart';
import '../../../core/runtime/desktop_runtime.dart';
import '../data/repositories/signalr_terminal_repository.dart';
import '../domain/terminal_repository.dart';
import '../domain/terminal_ui_state.dart';
import 'terminal_performance_diagnostics.dart';

/// Sink installed by the View so the repository's inbound bytes can reach
/// the xterm Terminal controller without the VM importing xterm2 types.
typedef TerminalOutputSink = void Function(String text);

/// Transient factory — called from terminal_app.dart so each window owns
/// its own repository and streams.
TerminalViewModel createTerminalViewModel() => TerminalViewModel(
      repository: SignalRTerminalRepository(),
      diagnostics: TerminalPerformanceDiagnostics(
        log: _optionalRuntimeLog()?.info,
      ),
    );

RuntimeLog? _optionalRuntimeLog() {
  try {
    return app_di.di.isRegistered<RuntimeLog>()
        ? app_di.di<RuntimeLog>()
        : null;
  } catch (_) {
    return null;
  }
}

class TerminalViewModel extends ViewModel {
  TerminalViewModel({
    required TerminalRepository repository,
    TerminalPerformanceDiagnostics? diagnostics,
  })  : _repository = repository,
        _diagnostics = diagnostics ?? TerminalPerformanceDiagnostics() {
    trackDisposable(state);
    trackDisposable(startCommand);
    _diagnostics.start();
  }

  final TerminalRepository _repository;
  final TerminalPerformanceDiagnostics _diagnostics;

  StreamSubscription<String>? _outputSubscription;
  StreamSubscription<int?>? _exitSubscription;
  StreamSubscription<Object?>? _closeSubscription;

  // ---- Callbacks installed by the View / App ----

  /// Writes incoming bytes into the xterm render buffer.  Owned by View.
  TerminalOutputSink? outputSink;

  /// Invoked by the "Terminal → Settings" menu item.  The shell/host installs
  /// this callback to show a settings dialog (matches Avalonia
  /// `RequestSettingsAsync` pattern).
  Future<void> Function()? requestSettingsAsync;

  /// Opened by the chrome menu bar via command_it command.
  late final openSettingsCommand = Command.createAsyncNoParamNoResult(
    () async => requestSettingsAsync?.call(),
  );

  // ---- Presentation state ----

  final ValueNotifier<TerminalUiState> state =
      ValueNotifier<TerminalUiState>(TerminalUiState.initial());

  TerminalUiState get _s => state.value;
  void _mutate(TerminalUiState Function(TerminalUiState s) fn) =>
      state.value = fn(state.value);

  // ---- Gate helpers for the View layer ----

  bool canSendInput() => _s.isConnected;
  bool canResize() => _s.isConnected;

  // ---- Command (parameterless, matches command_it v9.x NoParam factories) ----

  /// Start the SignalR connection + PTY handshake.
  /// Callers should first call [prepareStartArgs] so the required handshake
  /// parameters are staged before executing the command.
  TerminalStartArgs? _pendingStart;

  void prepareStartArgs(TerminalStartArgs args) {
    _pendingStart = args;
  }

  late final startCommand = Command.createAsyncNoParamNoResult(() async {
    final args = _pendingStart;
    if (args == null) return;
    String? failure;
    try {
      // Attach listeners first so any bytes emitted immediately after Start
      // are routed to the View's terminal controller.
      _outputSubscription?.cancel();
      _outputSubscription = _repository.onOutput.listen((chunk) {
        _diagnostics.recordInboundOutput(chunk.length);
        outputSink?.call(chunk);
      });
      _exitSubscription?.cancel();
      _exitSubscription = _repository.onProcessExited.listen((code) {
        outputSink?.call(
          '\r\n\x1b[90mProcess exited${code == null ? '' : ' ($code)'}.\x1b[0m\r\n',
        );
        _mutate((s) => s.copyWith(
              connectionState: TerminalConnectionState.exited,
              exitCode: code,
            ));
      });
      _closeSubscription?.cancel();
      _closeSubscription = _repository.onClose.listen((error) {
        _mutate((s) => s.copyWith(
              connectionState: _repository.state,
              errorMessage: error?.toString(),
            ));
      });
      await _repository.connect(
        serverUrl: args.serverUrl,
        accessToken: args.accessToken,
        columns: args.columns,
        rows: args.rows,
        workingDirectory: args.workingDirectory,
        resumeSessionId: args.resumeSessionId,
      );
      failure = null;
    } catch (error) {
      failure = error.toString();
    }
    _mutate((s) => s.copyWith(
          connectionState: _repository.state,
          sessionId: _repository.sessionId,
          errorMessage: failure,
        ));
    _diagnostics.updateSession(_repository.sessionId);
  });

  // ---- Parameterised operations (plain async methods per command_it v9.x) ----

  Future<void> sendInput(String value) async {
    if (!canSendInput()) return;
    final stopwatch = Stopwatch()..start();
    try {
      await _repository.sendInput(value);
      stopwatch.stop();
      _diagnostics.recordInputDispatch(
        codeUnits: value.length,
        elapsed: stopwatch.elapsed,
        failed: false,
      );
    } catch (_) {
      stopwatch.stop();
      _diagnostics.recordInputDispatch(
        codeUnits: value.length,
        elapsed: stopwatch.elapsed,
        failed: true,
      );
      rethrow;
    }
  }

  /// Reports UI-isolate timings from the View. The View owns xterm and frame
  /// callbacks; this ViewModel-owned diagnostic object owns log aggregation.
  void reportRenderFlush({
    required int renderedCodeUnits,
    required int queuedCodeUnits,
    required Duration postFrameWait,
    required Duration terminalWrite,
  }) =>
      _diagnostics.recordRenderFlush(
        renderedCodeUnits: renderedCodeUnits,
        queuedCodeUnits: queuedCodeUnits,
        postFrameWait: postFrameWait,
        terminalWrite: terminalWrite,
      );

  void reportFrameTiming({
    required Duration build,
    required Duration raster,
    required Duration total,
  }) =>
      _diagnostics.recordFrame(build: build, raster: raster, total: total);

  void reportRenderSurface({
    required int columns,
    required int rows,
    required int widthPixels,
    required int heightPixels,
    required String windowState,
  }) =>
      _diagnostics.updateRenderSurface(
        columns: columns,
        rows: rows,
        widthPixels: widthPixels,
        heightPixels: heightPixels,
        windowState: windowState,
      );

  Future<void> resize(int columns, int rows,
      {int widthPx = 0, int heightPx = 0}) async {
    if (!canResize()) return;
    await _repository.resize(columns, rows,
        widthPx: widthPx, heightPx: heightPx);
  }

  /// Called by the View when the remote shell announces an OSC 0/2 title
  /// change.  Avalonia surfaces this as the chrome status line.
  ///
  /// De-duplicates against the current title: some prompt themes (zsh
  /// powerlevel10k, oh-my-bash) re-emit the same OSC 2 sequence on every
  /// prompt, which used to cause [TerminalUiState] to re-assign the same
  /// string, trigger the chrome's [ListenableBuilder]s, and rebuild the
  /// menu bar + status row + session tail for no visible change.
  void setTitle(String? value) {
    if (value == null || value.isEmpty) return;
    if (_s.title == value) return;
    _mutate((s) => s.copyWith(title: value));
  }

  /// Closes the remote PTY and the transport.  Used as part of the
  /// deliberate-window-close teardown sequence (see [dispose]).  For
  /// logout / workspace teardown the session is already unauthenticated so
  /// the View simply detaches and the transport stop is sufficient — the
  /// server preserves the PTY for the next sign-in (matches Avalonia's
  /// `ReleaseActiveSession(kill: false)` branch).
  Future<void> _terminateAndDetach() async {
    final current = _repository.state;
    if (current == TerminalConnectionState.connected ||
        current == TerminalConnectionState.connecting) {
      try {
        await _repository.terminateSession();
      } catch (_) {
        // A dropping transport is equivalent to a closed attachment.
      }
      _mutate((s) => s.copyWith(connectionState: _repository.state));
    }
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _exitSubscription?.cancel();
    _closeSubscription?.cancel();
    // Intentional: best-effort kill of the corresponding server PTY as
    // part of a deliberate window close.  We do not await the future
    // because `dispose()` is synchronous in the ViewModel supertype; any
    // transport-level error here is swallowed and the subsequent
    // `_repository.dispose()` still closes the local streams + hub.
    unawaited(_terminateAndDetach().whenComplete(_repository.dispose));
    _diagnostics.dispose();
    super.dispose();
  }
}

// ---- Start args record ----

/// Argument bundle staged by the View before invoking [startCommand].
/// Mirrors the shape of [SignalRTerminalRepository.connect].
typedef TerminalStartArgs = ({
  String serverUrl,
  String accessToken,
  int columns,
  int rows,
  String? workingDirectory,
  String? resumeSessionId,
});
