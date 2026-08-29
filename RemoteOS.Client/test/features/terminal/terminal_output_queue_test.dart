import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/features/terminal/presentation/terminal_output_queue.dart';

void main() {
  group('TerminalOutputQueue', () {
    test('preserves order across chunk boundaries', () {
      final queue = TerminalOutputQueue()
        ..add('abc')
        ..add('def');

      expect(queue.takeUpTo(4), 'abcd');
      expect(queue.takeUpTo(4), 'ef');
      expect(queue.isEmpty, isTrue);
    });

    test('does not split a surrogate pair at a frame boundary', () {
      final queue = TerminalOutputQueue()..add('A😀B');

      expect(queue.takeUpTo(2), 'A');
      expect(queue.takeUpTo(2), '😀');
      expect(queue.takeUpTo(2), 'B');
      expect(queue.isEmpty, isTrue);
    });

    test('clears all queued output', () {
      final queue = TerminalOutputQueue()..add('pending output');

      queue.clear();

      expect(queue.pendingCodeUnits, 0);
      expect(queue.takeUpTo(8), isEmpty);
    });
  });
}
