// Aggregated terminal latency diagnostics.
//
// Terminal input and output can be sensitive, so this records only sizes and
// timings — never the text, escape sequences, credentials, or session ID.
// The View supplies render timings while the ViewModel supplies transport
// timings, keeping the diagnostic boundary independent of Flutter widgets.

import 'dart:async';

typedef TerminalPerformanceLog = Future<void> Function(String message);

/// Low-frequency metrics used to distinguish SignalR send backpressure from
/// xterm/UI-isolate rendering pressure without making every keystroke a log
/// write. Instances are window-scoped along with [TerminalViewModel].
class TerminalPerformanceDiagnostics {
  TerminalPerformanceDiagnostics({
    TerminalPerformanceLog? log,
    Duration summaryInterval = const Duration(seconds: 5),
  })  : _log = log,
        _summaryInterval = summaryInterval;

  static const _slowSend = Duration(milliseconds: 100);
  static const _slowFrame = Duration(milliseconds: 50);
  static const _slowTerminalWrite = Duration(milliseconds: 8);
  static const _slowPostFrameWait = Duration(milliseconds: 50);
  static const _largeOutputQueue = 64 * 1024;

  final TerminalPerformanceLog? _log;
  final Duration _summaryInterval;
  final Stopwatch _clock = Stopwatch()..start();

  Timer? _summaryTimer;
  String? _sessionTail;
  _RenderSurface? _surface;

  var _inputEvents = 0;
  var _inputCodeUnits = 0;
  var _inputFailures = 0;
  var _inputDispatchTotal = Duration.zero;
  var _inputDispatchMax = Duration.zero;

  var _inboundChunks = 0;
  var _inboundCodeUnits = 0;

  var _renderFlushes = 0;
  var _renderedCodeUnits = 0;
  var _renderQueueMax = 0;
  var _postFrameWaitMax = Duration.zero;
  var _terminalWriteMax = Duration.zero;

  var _frames = 0;
  var _slowFrames = 0;
  var _frameBuildMax = Duration.zero;
  var _frameRasterMax = Duration.zero;
  var _frameTotalMax = Duration.zero;

  void start() {
    if (_log == null || _summaryTimer != null) return;
    _summaryTimer = Timer.periodic(_summaryInterval, (_) {
      // Logging is intentionally ordered by RuntimeLog and must not block the
      // UI isolate timer that gathers the next interval.
      unawaited(flush(reason: 'interval'));
    });
  }

  void updateSession(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return;
    _sessionTail = sessionId.length <= 8
        ? sessionId
        : sessionId.substring(sessionId.length - 8);
  }

  void updateRenderSurface({
    required int columns,
    required int rows,
    required int widthPixels,
    required int heightPixels,
    required String windowState,
  }) {
    _surface = _RenderSurface(
      columns: columns,
      rows: rows,
      widthPixels: widthPixels,
      heightPixels: heightPixels,
      windowState: windowState,
    );
  }

  /// Records only the local duration until SignalR accepts the outbound send.
  /// It is a transport/backpressure signal, not an end-to-end shell RTT.
  void recordInputDispatch({
    required int codeUnits,
    required Duration elapsed,
    required bool failed,
  }) {
    _inputEvents += 1;
    _inputCodeUnits += codeUnits;
    if (failed) _inputFailures += 1;
    _inputDispatchTotal += elapsed;
    _inputDispatchMax = _max(_inputDispatchMax, elapsed);
  }

  void recordInboundOutput(int codeUnits) {
    if (codeUnits <= 0) return;
    _inboundChunks += 1;
    _inboundCodeUnits += codeUnits;
  }

  void recordRenderFlush({
    required int renderedCodeUnits,
    required int queuedCodeUnits,
    required Duration postFrameWait,
    required Duration terminalWrite,
  }) {
    _renderFlushes += 1;
    _renderedCodeUnits += renderedCodeUnits;
    _renderQueueMax =
        _renderQueueMax > queuedCodeUnits ? _renderQueueMax : queuedCodeUnits;
    _postFrameWaitMax = _max(_postFrameWaitMax, postFrameWait);
    _terminalWriteMax = _max(_terminalWriteMax, terminalWrite);
  }

  void recordFrame({
    required Duration build,
    required Duration raster,
    required Duration total,
  }) {
    _frames += 1;
    if (total >= _slowFrame) _slowFrames += 1;
    _frameBuildMax = _max(_frameBuildMax, build);
    _frameRasterMax = _max(_frameRasterMax, raster);
    _frameTotalMax = _max(_frameTotalMax, total);
  }

  Future<void> flush({required String reason}) async {
    if (_log == null || !_hasActivity) return;

    final inputAverage = _inputEvents == 0
        ? Duration.zero
        : Duration(
            microseconds: _inputDispatchTotal.inMicroseconds ~/ _inputEvents,
          );
    final classification = _classify();
    final surface = _surface;
    final message = StringBuffer('[terminal-performance] reason=$reason')
      ..write(' elapsedMs=${_clock.elapsedMilliseconds}')
      ..write(' session=${_sessionTail ?? '<pending>'}')
      ..write(' surface=${surface ?? '<unknown>'}')
      ..write(' input={events=$_inputEvents codeUnits=$_inputCodeUnits '
          'failed=$_inputFailures sendAvgMs=${_milliseconds(inputAverage)} '
          'sendMaxMs=${_milliseconds(_inputDispatchMax)}}')
      ..write(' inbound={chunks=$_inboundChunks codeUnits=$_inboundCodeUnits}')
      ..write(' render={flushes=$_renderFlushes codeUnits=$_renderedCodeUnits '
          'queueMax=$_renderQueueMax postFrameMaxMs=${_milliseconds(_postFrameWaitMax)} '
          'writeMaxMs=${_milliseconds(_terminalWriteMax)}}')
      ..write(' frame={count=$_frames slow=$_slowFrames '
          'buildMaxMs=${_milliseconds(_frameBuildMax)} '
          'rasterMaxMs=${_milliseconds(_frameRasterMax)} '
          'totalMaxMs=${_milliseconds(_frameTotalMax)}}')
      ..write(' diagnosis=$classification');

    _resetInterval();
    await _log(message.toString());
  }

  void dispose() {
    _summaryTimer?.cancel();
    _summaryTimer = null;
    // Keep the final partial interval: a user can reproduce the lag and close
    // the terminal before the five-second periodic summary is emitted.
    unawaited(flush(reason: 'dispose'));
  }

  bool get _hasActivity =>
      _inputEvents > 0 ||
      _inboundChunks > 0 ||
      _renderFlushes > 0 ||
      _frames > 0;

  String _classify() {
    final outboundPressure =
        _inputDispatchMax >= _slowSend || _inputFailures > 0;
    final renderPressure = _terminalWriteMax >= _slowTerminalWrite ||
        _postFrameWaitMax >= _slowPostFrameWait ||
        _renderQueueMax >= _largeOutputQueue ||
        _slowFrames > 0;
    if (outboundPressure && renderPressure) return 'mixed';
    if (renderPressure) return 'client-render-pressure';
    if (outboundPressure) return 'signalr-outbound-backpressure-candidate';
    return 'no-client-bottleneck-observed';
  }

  void _resetInterval() {
    _inputEvents = 0;
    _inputCodeUnits = 0;
    _inputFailures = 0;
    _inputDispatchTotal = Duration.zero;
    _inputDispatchMax = Duration.zero;
    _inboundChunks = 0;
    _inboundCodeUnits = 0;
    _renderFlushes = 0;
    _renderedCodeUnits = 0;
    _renderQueueMax = 0;
    _postFrameWaitMax = Duration.zero;
    _terminalWriteMax = Duration.zero;
    _frames = 0;
    _slowFrames = 0;
    _frameBuildMax = Duration.zero;
    _frameRasterMax = Duration.zero;
    _frameTotalMax = Duration.zero;
  }

  static Duration _max(Duration current, Duration next) =>
      current >= next ? current : next;

  static String _milliseconds(Duration duration) =>
      (duration.inMicroseconds / Duration.microsecondsPerMillisecond)
          .toStringAsFixed(1);
}

class _RenderSurface {
  const _RenderSurface({
    required this.columns,
    required this.rows,
    required this.widthPixels,
    required this.heightPixels,
    required this.windowState,
  });

  final int columns;
  final int rows;
  final int widthPixels;
  final int heightPixels;
  final String windowState;

  @override
  String toString() =>
      '{state=$windowState grid=${columns}x$rows pixels=${widthPixels}x$heightPixels}';
}
