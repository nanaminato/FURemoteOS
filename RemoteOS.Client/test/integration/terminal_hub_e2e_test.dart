import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_hub/signalr_client.dart';

void main() {
  const url = String.fromEnvironment('REMOTEOS_E2E_URL');
  const token = String.fromEnvironment('REMOTEOS_E2E_TOKEN');

  test('Terminal Hub starts a PTY, relays input/output, and closes it', () async {
    final connection = HubConnectionBuilder()
        .withUrl(Uri.parse(url).resolve('/hubs/terminals').toString(),
            options: HttpConnectionOptions(accessTokenFactory: () async => token))
        .build();
    final received = StringBuffer();
    final output = Completer<void>();
    connection.on('OnOutput', (args) {
      if (args != null && args.isNotEmpty && args.first is String) {
        received.write(utf8.decode(base64Decode(args.first as String), allowMalformed: true));
        if (received.toString().contains('/tmp') && !output.isCompleted) output.complete();
      }
      return null;
    });
    try {
      await connection.start();
      final started = await connection.invoke('Start', args: [
        {'columns': 80, 'rows': 24, 'widthPixels': 0, 'heightPixels': 0, 'shell': null, 'workingDirectory': '/tmp'},
        null,
      ]);
      expect((started as Map?)?['sessionId'], isNotEmpty);
      await connection.send('Input', args: [base64Encode(utf8.encode('pwd\n'))]);
      await output.future.timeout(const Duration(seconds: 15));
      expect(received.toString(), contains('/tmp'));
    } finally {
      try { await connection.invoke('Close'); } catch (_) {}
      try { await connection.stop(); } catch (_) {}
    }
  }, skip: url.isEmpty || token.isEmpty ? 'Set REMOTEOS_E2E_URL and REMOTEOS_E2E_TOKEN to run.' : false);
}
