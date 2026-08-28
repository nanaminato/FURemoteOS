import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_hub/signalr_client.dart';

void main() {
  const url = String.fromEnvironment('REMOTEOS_E2E_URL');
  const token = String.fromEnvironment('REMOTEOS_E2E_TOKEN');

  test('Task Manager ends a controlled remote process', () async {
    final connection = HubConnectionBuilder()
        .withUrl(Uri.parse(url).resolve('/hubs/terminals').toString(), options: HttpConnectionOptions(accessTokenFactory: () async => token))
        .build();
    final pid = Completer<int>();
    var buffer = '';
    connection.on('OnOutput', (args) {
      if (args != null && args.isNotEmpty && args.first is String) {
        buffer += utf8.decode(base64Decode(args.first as String), allowMalformed: true);
        final match = RegExp(r'REMOTEOS_KILL_PID:(\d+)').firstMatch(buffer);
        if (match != null && !pid.isCompleted) pid.complete(int.parse(match.group(1)!));
      }
      return null;
    });
    var processId = 0;
    try {
      await connection.start();
      await connection.invoke('Start', args: [
        {'columns': 80, 'rows': 24, 'widthPixels': 0, 'heightPixels': 0, 'shell': null, 'workingDirectory': '/tmp'},
        null,
      ]);
      await connection.send('Input', args: [base64Encode(utf8.encode('sleep 120 & echo REMOTEOS_KILL_PID:\$!\n'))]);
      processId = await pid.future.timeout(const Duration(seconds: 15));
      final response = await http.delete(
        Uri.parse(url).resolve('/api/v1/system/processes/$processId?force=false'),
        headers: {'Authorization': 'Bearer $token'},
      );
      expect(response.statusCode, 200);
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      expect(result['success'], true);
    } finally {
      if (processId != 0) {
        try { await connection.send('Input', args: [base64Encode(utf8.encode('kill $processId 2>/dev/null || true\n'))]); } catch (_) {}
      }
      try { await connection.invoke('Close'); } catch (_) {}
      try { await connection.stop(); } catch (_) {}
    }
  }, skip: url.isEmpty || token.isEmpty ? 'Set REMOTEOS_E2E_URL and REMOTEOS_E2E_TOKEN to run.' : false);
}
