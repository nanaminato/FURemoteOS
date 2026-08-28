import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_hub/signalr_client.dart';

void main() {
  const url = String.fromEnvironment('REMOTEOS_E2E_URL');
  const token = String.fromEnvironment('REMOTEOS_E2E_TOKEN');

  test('Performance Hub subscribes and receives a server sample', () async {
    final connection = HubConnectionBuilder()
        .withUrl(
          Uri.parse(url).resolve('/hubs/performance').toString(),
          options: HttpConnectionOptions(accessTokenFactory: () async => token),
        )
        .build();
    final sample = Completer<Map>();
    connection.on('OnPerformanceSnapshot', (args) {
      if (args != null && args.isNotEmpty && args.first is Map && !sample.isCompleted) {
        sample.complete(args.first as Map);
      }
      return null;
    });
    try {
      await connection.start();
      await connection.invoke('Subscribe');
      final value = await sample.future.timeout(const Duration(seconds: 15));
      expect(value['sequence'], isA<num>());
      expect(value['cpu'], isA<Map>());
      expect(value['memory'], isA<Map>());
    } finally {
      try { await connection.invoke('Unsubscribe'); } catch (_) {}
      try { await connection.stop(); } catch (_) {}
    }
  }, skip: url.isEmpty || token.isEmpty ? 'Set REMOTEOS_E2E_URL and REMOTEOS_E2E_TOKEN to run.' : false);
}
