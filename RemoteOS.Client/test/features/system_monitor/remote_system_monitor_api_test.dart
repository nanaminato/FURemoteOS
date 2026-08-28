import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:remoteos_client/core/auth/auth_service.dart';
import 'package:remoteos_client/core/network/remoteos_api.dart';
import 'package:remoteos_client/features/system_monitor/data/remote_system_monitor_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses Task Manager snapshot, history, process-query and kill contracts',
      () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login')
        return http.Response(jsonEncode(_login), 200);
      expect(request.headers['authorization'], 'Bearer access');
      switch ('${request.method} ${request.url.path}') {
        case 'GET /api/v1/system/performance/snapshot':
        case 'GET /api/v1/system/performance/history':
          if (request.url.path.endsWith('history'))
            expect(request.url.queryParameters['seconds'], '60');
          return http.Response(jsonEncode([_snapshot]), 200);
        case 'GET /api/v1/system/performance/info':
          return http.Response(jsonEncode(_info), 200);
        case 'GET /api/v1/system/processes/query':
          expect(request.url.queryParameters['filter'], 'server');
          expect(request.url.queryParameters['sort'], 'memory');
          return http.Response(
              jsonEncode({
                'items': [_process],
                'totalCount': 1
              }),
              200);
        case 'DELETE /api/v1/system/processes/42':
          expect(request.url.queryParameters['force'], 'false');
          return http.Response(
              jsonEncode({
                'success': false,
                'requiresElevation': true,
                'error': 'denied'
              }),
              200);
      }
      throw StateError('Unexpected $request');
    });
    final auth = AuthNotifier(httpClient: client);
    addTearDown(auth.dispose);
    await auth.login(
        serverUrl: 'https://remoteos.test', username: 'a', password: 'p');
    final api = RemoteSystemMonitorApi(RemoteOsApi(auth));
    final history = await api.history();
    final info = await api.info();
    final processes = await api.processes(filter: 'server');
    final killed = await api.kill(42);
    expect(history.single.cpuPercent, 25);
    expect(history.single.filesystemUsedBytes, 30);
    expect(history.single.diskReadBytesPerSecond, 4);
    expect(history.single.networkSendBytesPerSecond, 9);
    expect(info.filesystems, ['root']);
    expect(info.logicalProcessors, 8);
    expect(processes.items.single.name, 'server');
    expect(killed.requiresElevation, isTrue);
  });
}

const _snapshot = {
  'sequence': 1,
  'timestamp': '2026-08-28T00:00:00Z',
  'cpu': {'totalPercent': 25},
  'memory': {'usedBytes': 20, 'totalBytes': 100},
  'filesystems': [
    {'usedBytes': 10, 'totalBytes': 40},
    {'usedBytes': 20, 'totalBytes': 60}
  ],
  'disks': [
    {'readBytesPerSecond': 4, 'writeBytesPerSecond': 5}
  ],
  'networks': [
    {'receiveBytesPerSecond': 8, 'sendBytesPerSecond': 9}
  ]
};
const _process = {
  'id': 42,
  'name': 'server',
  'cpuPercent': 3,
  'memoryBytes': 1024,
  'userName': 'remoteos'
};
const _info = {
  'cpu': {'model': 'CPU', 'logicalProcessorCount': 8},
  'memory': {'totalBytes': 100},
  'filesystems': [
    {'name': 'root'}
  ],
  'disks': [
    {'name': 'disk'}
  ],
  'networks': [
    {'name': 'eth0'}
  ]
};
const _login = {
  'user': {'username': 'a'},
  'workspace': {'id': 'w', 'name': 'W'},
  'tokens': {
    'accessToken': 'access',
    'refreshToken': 'refresh',
    'accessTokenExpiresAt': '2026-08-28T16:00:00Z',
    'refreshTokenExpiresAt': '2026-09-28T16:00:00Z'
  }
};
