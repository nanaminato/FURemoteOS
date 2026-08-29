import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:remoteos_client/core/auth/auth_service.dart';
import 'package:remoteos_client/core/network/remoteos_api.dart';
import 'package:remoteos_client/core/theme/theme_models.dart';
import 'package:remoteos_client/features/workspace/data/remote_workspace_api.dart';
import 'package:remoteos_client/features/workspace/domain/workspace_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses workspace preference and layout routes with protocol JSON',
      () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(jsonEncode(_loginResponse), 200);
      }
      expect(request.headers['authorization'], 'Bearer access');
      if (request.url.path == '/api/v1/workspaces/ws-1/preferences') {
        expect(request.method, 'PUT');
        expect(jsonDecode(request.body)['language'], 'zh-CN');
        expect(jsonDecode(request.body)['defaultApps'], [
          {'scheme': '.png', 'appId': 'remoteos.imageviewer'},
        ]);
        return http.Response(jsonEncode(_preferences), 200);
      }
      if (request.url.path == '/api/v1/workspaces/ws-1/window-layouts') {
        expect(request.method, 'PUT');
        expect(jsonDecode(request.body)['windows'], hasLength(1));
        return http.Response(
            jsonEncode({
              'windows': [
                {'key': 'notepad', 'width': 720, 'height': 520},
              ],
            }),
            200);
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final auth = AuthNotifier(httpClient: client);
    addTearDown(auth.dispose);
    await auth.login(
      serverUrl: 'https://remoteos.test',
      username: 'alice',
      password: 'password',
    );
    final api = RemoteWorkspaceApi(RemoteOsApi(auth));

    final preferences = await api.updatePreferences(
      'ws-1',
      const WorkspacePreferences(
        wallpaperKey: 'builtin:bloom',
        theme: ThemeKind.dark,
        timeFormat: '24h',
        dateFormat: 'yyyy/M/d',
        language: 'zh-CN',
        region: 'zh-CN',
        themePreferences: ThemePreferencesDto(),
        defaultApps: const [
          WorkspaceDefaultAppMapping(
              scheme: '.png', appId: 'remoteos.imageviewer'),
        ],
      ),
    );
    final layouts = await api.updateWindowLayouts(
      'ws-1',
      const WorkspaceWindowLayouts(
        windows: [WorkspaceWindowSize(key: 'notepad', width: 720, height: 520)],
      ),
    );

    expect(preferences.theme, ThemeKind.dark);
    expect(preferences.defaultApps.single.scheme, '.png');
    expect(preferences.themePreferences.paletteId, PaletteIds.nord);
    expect(layouts.windows.single.key, 'notepad');
  });

  test('uploads wallpaper multipart data and reads returned preferences',
      () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(jsonEncode(_loginResponse), 200);
      }
      expect(request.headers['authorization'], 'Bearer access');
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/workspaces/ws-1/wallpaper');
      expect(
          request.headers['content-type'], startsWith('multipart/form-data'));
      return http.Response(
          jsonEncode({
            ..._preferences,
            'wallpaperKey': 'custom:9b0464f46c7b44b0904c47cfafb70812',
          }),
          200);
    });
    final auth = AuthNotifier(httpClient: client);
    addTearDown(auth.dispose);
    await auth.login(
      serverUrl: 'https://remoteos.test',
      username: 'alice',
      password: 'password',
    );
    final file =
        File('${Directory.systemTemp.path}/remoteos-wallpaper-test.png');
    await file.writeAsBytes(const [137, 80, 78, 71]);
    addTearDown(() => file.delete());

    final preferences = await RemoteWorkspaceApi(RemoteOsApi(auth))
        .uploadWallpaper('ws-1', file);

    expect(preferences.wallpaperKey, 'custom:9b0464f46c7b44b0904c47cfafb70812');
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

const _preferences = {
  'wallpaperKey': 'builtin:bloom',
  'theme': 'dark',
  'timeFormat': '24h',
  'dateFormat': 'yyyy/M/d',
  'language': 'zh-CN',
  'region': 'zh-CN',
  'themePreferences': {
    'styleId': 'remoteos',
    'paletteId': 'builtin:nord',
    'customPalettes': [],
  },
  'defaultApps': [
    {'scheme': '.png', 'appId': 'remoteos.imageviewer'},
  ],
};
