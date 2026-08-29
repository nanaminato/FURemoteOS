import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/features/terminal/application/terminal_performance_diagnostics.dart';

void main() {
  test('summarizes render pressure without recording terminal text', () async {
    final entries = <String>[];
    final diagnostics = TerminalPerformanceDiagnostics(
      log: (message) async => entries.add(message),
    );

    diagnostics
      ..recordInputDispatch(
        codeUnits: 1,
        elapsed: const Duration(milliseconds: 2),
        failed: false,
      )
      ..recordInboundOutput(32768)
      ..recordRenderFlush(
        renderedCodeUnits: 32768,
        queuedCodeUnits: 65536,
        postFrameWait: const Duration(milliseconds: 60),
        terminalWrite: const Duration(milliseconds: 9),
      )
      ..recordFrame(
        build: const Duration(milliseconds: 8),
        raster: const Duration(milliseconds: 45),
        total: const Duration(milliseconds: 55),
      );

    await diagnostics.flush(reason: 'test');

    expect(entries, hasLength(1));
    expect(entries.single, contains('diagnosis=client-render-pressure'));
    expect(entries.single, contains('queueMax=65536'));
    expect(entries.single, isNot(contains('terminal text')));
  });

  test('labels slow local SignalR sends as an outbound candidate', () async {
    final entries = <String>[];
    final diagnostics = TerminalPerformanceDiagnostics(
      log: (message) async => entries.add(message),
    );

    diagnostics.recordInputDispatch(
      codeUnits: 1,
      elapsed: const Duration(milliseconds: 120),
      failed: false,
    );
    await diagnostics.flush(reason: 'test');

    expect(
      entries.single,
      contains('diagnosis=signalr-outbound-backpressure-candidate'),
    );
  });
}
