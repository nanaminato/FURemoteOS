import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/features/auth/data/remoteos_auth_api.dart';

void main() {
  test('uses the v1 login endpoint and parses nested protocol tokens',
      () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'user': {'username': 'alice'},
          'workspace': {'name': 'Alice Workspace'},
          'tokens': {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'accessTokenExpiresAt': '2026-08-26T16:00:00Z',
            'refreshTokenExpiresAt': '2026-09-26T16:00:00Z',
          },
          'assignedRole': 'controller',
          'server': {'platform': 'windows', 'capabilities': []},
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    final api = RemoteOsAuthApi(client);

    final result = await api.login(
      serverUrl: Uri.parse('http://localhost:5090'),
      username: 'alice',
      password: 'password',
      deviceName: 'test-device',
      clientVersion: 'test',
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/api/v1/auth/login');
    expect(jsonDecode(capturedRequest.body), {
      'username': 'alice',
      'password': 'password',
      'clientPlatform': Platform.isWindows ? 'windows' : 'linux',
      'deviceName': 'test-device',
      'clientVersion': 'test',
    });
    expect(result.tokens.accessToken, 'access-token');
    expect(result.tokens.refreshToken, 'refresh-token');
    expect(result.username, 'alice');
    expect(result.workspaceName, 'Alice Workspace');
  });
}
