import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:remoteos_client/core/auth/auth_service.dart';
import 'package:remoteos_client/core/network/remoteos_api.dart';
import 'package:remoteos_client/features/docker/data/remote_docker_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('uses typed Docker resource and confirmed operation contracts',
      () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login')
        return http.Response(jsonEncode(_login), 200);
      expect(request.headers['authorization'], 'Bearer access');
      switch ('${request.method} ${request.url.path}') {
        case 'GET /api/v1/docker/status':
          return http.Response(
              jsonEncode({
                'isAvailable': true,
                'problemCode': '',
                'serverVersion': '27'
              }),
              200);
        case 'GET /api/v1/docker/containers':
          return http.Response(
              jsonEncode([
                {
                  'id': 'abc',
                  'names': 'web',
                  'image': 'nginx',
                  'state': 'running',
                  'status': 'Up'
                }
              ]),
              200);
        case 'POST /api/v1/docker/containers/abc/stop':
          expect(jsonDecode(request.body), {'force': false, 'confirmed': true});
          return http.Response(
              jsonEncode({'success': true, 'problemCode': ''}), 200);
        case 'POST /api/v1/docker/containers':
          expect(jsonDecode(request.body), {
            'name': 'web',
            'image': 'nginx:latest',
            'arguments': ['-g', 'daemon off;'],
            'ports': ['8080:80'],
            'environment': [],
            'mounts': []
          });
          return http.Response(
              jsonEncode({'success': true, 'problemCode': ''}), 200);
        case 'DELETE /api/v1/docker/images/img':
          expect(jsonDecode(request.body),
              {'imageReference': 'img', 'confirmed': true});
          return http.Response(
              jsonEncode({'success': true, 'problemCode': ''}), 200);
        case 'DELETE /api/v1/docker/networks/net':
          expect(request.url.queryParameters['confirmed'], 'true');
          return http.Response(
              jsonEncode({'success': true, 'problemCode': ''}), 200);
        case 'POST /api/v1/docker/networks':
          expect(jsonDecode(request.body),
              {'name': 'isolated', 'driver': 'bridge', 'confirmed': false});
          return http.Response(
              jsonEncode({'success': true, 'problemCode': ''}), 200);
        case 'POST /api/v1/docker/stacks/validate':
          expect(jsonDecode(request.body),
              {'name': 'web', 'composeYaml': 'services: {}'});
          return http.Response(
              jsonEncode({
                'success': true,
                'problemCode': '',
                'messages': ['service web uses image nginx']
              }),
              200);
      }
      throw StateError('Unexpected $request');
    });
    final auth = AuthNotifier(httpClient: client);
    addTearDown(auth.dispose);
    await auth.login(
        serverUrl: 'https://remoteos.test', username: 'a', password: 'p');
    final api = RemoteDockerApi(RemoteOsApi(auth));
    expect((await api.status()).version, '27');
    expect((await api.containers()).single.name, 'web');
    expect((await api.containerAction('abc', 'stop', confirmed: true)).success,
        isTrue);
    expect(
        (await api.createContainer(const DockerContainerCreate(
                name: 'web',
                image: 'nginx:latest',
                arguments: ['-g', 'daemon off;'],
                ports: ['8080:80'])))
            .success,
        isTrue);
    expect((await api.deleteImage('img')).success, isTrue);
    expect((await api.deleteNetwork('net')).success, isTrue);
    expect((await api.createNetwork('isolated')).success, isTrue);
    final stackResult = await api.validateStack(const DockerStackDefinition(
        name: 'web', composeYaml: 'services: {}'));
    expect(stackResult.success, isTrue);
    expect(stackResult.messages, ['service web uses image nginx']);
  });
}

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
