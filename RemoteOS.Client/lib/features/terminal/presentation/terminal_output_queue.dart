// Bounded output queue for the terminal rendering host.
//
// SignalR can replay the server's 1 MB terminal history in one message.  The
// xterm parser runs on Flutter's UI isolate, so feeding that entire message to
// [Terminal.write] in a single frame makes Windows visibly stall.  This queue
// preserves byte-decoded text order while allowing the View to consume a
// small, predictable amount on each frame.

import 'dart:collection';

/// FIFO text queue that removes at most a requested number of UTF-16 code
/// units, without splitting a surrogate pair across terminal writes.
class TerminalOutputQueue {
  final ListQueue<String> _chunks = ListQueue<String>();
  var _pendingCodeUnits = 0;

  bool get isEmpty => _chunks.isEmpty;
  bool get isNotEmpty => _chunks.isNotEmpty;
  int get pendingCodeUnits => _pendingCodeUnits;

  void add(String chunk) {
    if (chunk.isEmpty) return;
    _chunks.addLast(chunk);
    _pendingCodeUnits += chunk.length;
  }

  /// Removes text up to [maximumCodeUnits]. A single surrogate pair may make
  /// the result one code unit larger than the requested limit so Unicode text
  /// is never corrupted at a frame boundary.
  String takeUpTo(int maximumCodeUnits) {
    if (maximumCodeUnits <= 0) {
      throw ArgumentError.value(
        maximumCodeUnits,
        'maximumCodeUnits',
        'Must be greater than zero.',
      );
    }

    if (_chunks.isEmpty) return '';

    final output = StringBuffer();
    var wroteOutput = false;
    var remaining = maximumCodeUnits;
    while (remaining > 0 && _chunks.isNotEmpty) {
      final chunk = _chunks.first;
      if (chunk.length <= remaining) {
        _chunks.removeFirst();
        output.write(chunk);
        wroteOutput = true;
        remaining -= chunk.length;
        _pendingCodeUnits -= chunk.length;
        continue;
      }

      var count = _safePrefixLength(chunk, remaining);
      if (count == 0) {
        if (wroteOutput) break;
        // A one-code-unit frame budget must still be able to make progress
        // when the next scalar value is represented by a surrogate pair.
        count = 2;
      }
      output.write(chunk.substring(0, count));
      wroteOutput = true;
      _chunks
        ..removeFirst()
        ..addFirst(chunk.substring(count));
      remaining -= count;
      _pendingCodeUnits -= count;
    }
    return output.toString();
  }

  void clear() {
    _chunks.clear();
    _pendingCodeUnits = 0;
  }

  static int _safePrefixLength(String chunk, int requested) {
    var count = requested;
    if (count < chunk.length &&
        _isHighSurrogate(chunk.codeUnitAt(count - 1)) &&
        _isLowSurrogate(chunk.codeUnitAt(count))) {
      count--;
    }

    return count;
  }

  static bool _isHighSurrogate(int value) => value >= 0xD800 && value <= 0xDBFF;

  static bool _isLowSurrogate(int value) => value >= 0xDC00 && value <= 0xDFFF;
}
