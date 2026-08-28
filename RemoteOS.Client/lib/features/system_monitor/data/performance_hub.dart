import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_hub/signalr_client.dart';

import '../../../core/auth/auth_service.dart';
import 'remote_system_monitor_api.dart';

/// One Task Manager window's performance subscription.  After SignalR
/// reconnects it subscribes again and notifies the UI to refill REST history.
class PerformanceHub {
  PerformanceHub(this._ref);

  final Ref _ref;
  HubConnection? _connection;
  final _snapshots = StreamController<PerformanceSnapshot>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  Stream<PerformanceSnapshot> get snapshots => _snapshots.stream;
  Stream<void> get reconnected => _reconnected.stream;

  Future<void> connect() async {
    if (_connection != null) return;
    final auth = _ref.read(authProvider);
    if (auth.serverUrl == null || auth.accessToken == null) {
      throw StateError('Not signed in.');
    }
    final connection = HubConnectionBuilder()
        .withUrl(
          Uri.parse(auth.serverUrl!).resolve('/hubs/performance').toString(),
          options: HttpConnectionOptions(
              accessTokenFactory: () async =>
                  _ref.read(authProvider).accessToken ?? ''),
        )
        .withAutomaticReconnect()
        .build();
    connection.on('OnPerformanceSnapshot', (arguments) {
      if (arguments != null && arguments.isNotEmpty && arguments.first is Map) {
        final snapshot = arguments.first as Map;
        _snapshots.add(PerformanceSnapshot.fromJson(
            snapshot.map((key, value) => MapEntry(key.toString(), value))));
      }
      return null;
    });
    connection.onreconnected(({connectionId}) async {
      try {
        await connection.invoke('Subscribe');
        _reconnected.add(null);
      } catch (_) {
        // The built-in retry policy will surface a final close if this cannot
        // be restored; do not report a false successful subscription.
      }
    });
    _connection = connection;
    try {
      await connection.start();
      await connection.invoke('Subscribe');
    } catch (_) {
      _connection = null;
      await connection.stop();
      rethrow;
    }
  }

  void dispose() {
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      unawaited(_unsubscribeAndStop(connection));
    }
    unawaited(_snapshots.close());
    unawaited(_reconnected.close());
  }

  static Future<void> _unsubscribeAndStop(HubConnection connection) async {
    try {
      await connection.invoke('Unsubscribe');
    } catch (_) {
      // Window disposal must not depend on a live network connection.
    }
    try {
      await connection.stop();
    } catch (_) {}
  }
}

final performanceHubProvider = Provider.autoDispose<PerformanceHub>((ref) {
  final hub = PerformanceHub(ref);
  ref.onDispose(hub.dispose);
  return hub;
});
