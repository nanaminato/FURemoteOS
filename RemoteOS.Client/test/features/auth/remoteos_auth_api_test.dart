import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remoteos_client/features/auth/data/remoteos_auth_api.dart';
import 'package:remoteos_client/core/auth/auth_service.dart';
import 'package:remoteos_client/core/network/remoteos_api.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  test('refreshes once after an unauthorized REST request and retries it',
      () async {
    var protectedRequestCount = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(_loginResponse(), 200);
      }
      if (request.url.path == '/api/v1/auth/refresh') {
        expect(jsonDecode(request.body), {'refreshToken': 'refresh-token'});
        return http.Response(_refreshResponse(), 200);
      }
      if (request.url.path == '/api/v1/files') {
        protectedRequestCount++;
        if (protectedRequestCount == 1) {
          expect(request.headers['authorization'], 'Bearer access-token');
          return http.Response('{"title":"Expired"}', 401);
        }
        expect(request.headers['authorization'], 'Bearer renewed-access-token');
        return http.Response('{"items":[]}', 200);
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final auth = AuthNotifier(
      httpClient: client,
      credentialStore: _MemoryCredentialStore(),
    );
    addTearDown(auth.dispose);

    expect(
      await auth.login(
        serverUrl: 'http://localhost:5090',
        username: 'alice',
        password: 'password',
      ),
      isTrue,
    );

    final result = await RemoteOsApi(auth).getJson('api/v1/files');
    expect(result, {'items': []});
    expect(protectedRequestCount, 2);
    expect(auth.current.accessToken, 'renewed-access-token');
  });

  test('stores remembered passwords outside SharedPreferences', () async {
    final store = _MemoryCredentialStore();
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(_loginResponse(), 200);
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final auth = AuthNotifier(httpClient: client, credentialStore: store);
    addTearDown(auth.dispose);

    await auth.login(
      serverUrl: 'https://example.test',
      username: 'alice',
      password: 'do-not-store-this-in-preferences',
      rememberPassword: true,
    );

    final prefs = await SharedPreferences.getInstance();
    final serializedProfile = prefs.getStringList('auth.remembered.profiles')!;
    expect(serializedProfile.single, isNot(contains('do-not-store-this')));
    expect(serializedProfile.single, contains('hasSavedPassword'));
    expect(
      await auth.loadSavedPassword(
        serverUrl: 'https://example.test',
        username: 'alice',
      ),
      'do-not-store-this-in-preferences',
    );
  });
}

String _loginResponse() => jsonEncode({
      'user': {'username': 'alice'},
      'workspace': {'name': 'Alice Workspace'},
      'tokens': {
        'accessToken': 'access-token',
        'refreshToken': 'refresh-token',
        'accessTokenExpiresAt': '2026-08-26T16:00:00Z',
        'refreshTokenExpiresAt': '2026-09-26T16:00:00Z',
      },
    });

String _refreshResponse() => jsonEncode({
      'tokens': {
        'accessToken': 'renewed-access-token',
        'refreshToken': 'renewed-refresh-token',
        'accessTokenExpiresAt': '2026-08-27T16:00:00Z',
        'refreshTokenExpiresAt': '2026-09-27T16:00:00Z',
      },
    });

class _MemoryCredentialStore implements CredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
