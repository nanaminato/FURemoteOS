import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:remoteos_client/core/auth/auth_service.dart';
import 'package:remoteos_client/core/network/remoteos_api.dart';
import 'package:remoteos_client/features/files/data/remote_file_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses Explorer file routes and protocol request field names', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(jsonEncode(_loginResponse), 200);
      }
      expect(request.headers['authorization'], 'Bearer access');
      switch ('${request.method} ${request.url.path}') {
        case 'GET /api/v1/files/list':
          expect(request.url.queryParameters['path'], '/remote');
          return http.Response(
              jsonEncode({
                'directories': [
                  {'name': 'folder', 'path': '/remote/folder'},
                ],
                'files': [
                  {
                    'name': 'note.txt',
                    'path': '/remote/note.txt',
                    'mimeType': 'text/plain',
                  },
                ],
              }),
              200);
        case 'GET /api/v1/files/properties':
          return http.Response(
              jsonEncode({
                'path': '/remote/note.txt',
                'name': 'note.txt',
                'type': 'file',
                'size': 4,
              }),
              200);
        case 'POST /api/v1/files/rename':
          expect(jsonDecode(request.body),
              {'sourcePath': '/remote/note.txt', 'newName': 'renamed.txt'});
          return http.Response('{}', 200);
        case 'POST /api/v1/files/copy':
        case 'POST /api/v1/files/move':
          expect(jsonDecode(request.body), {
            'sourcePath': '/remote/note.txt',
            'destinationPath': '/remote/folder/note.txt',
          });
          return http.Response('{}', 200);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    final auth = AuthNotifier(httpClient: client);
    addTearDown(auth.dispose);
    await auth.login(
      serverUrl: 'https://remoteos.test',
      username: 'alice',
      password: 'password',
    );
    final api = RemoteFileApi(RemoteOsApi(auth));

    final entries = await api.list('/remote');
    final properties = await api.properties('/remote/note.txt');
    await api.rename('/remote/note.txt', 'renamed.txt');
    await api.copy('/remote/note.txt', '/remote/folder/note.txt');
    await api.move('/remote/note.txt', '/remote/folder/note.txt');

    expect(entries.map((entry) => entry.isDirectory), [true, false]);
    expect(entries.last.mimeType, 'text/plain');
    expect(properties?.size, 4);
  });
}

const _loginResponse = {
  'user': {'username': 'alice'},
  'workspace': {'id': 'ws-1', 'name': 'Workspace'},
  'tokens': {
    'accessToken': 'access',
    'refreshToken': 'refresh',
    'accessTokenExpiresAt': '2026-08-28T16:00:00Z',
    'refreshTokenExpiresAt': '2026-09-28T16:00:00Z',
  },
};
