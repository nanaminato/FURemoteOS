import 'dart:io';

import '../../../core/network/remoteos_api.dart';
import '../domain/workspace_models.dart';

/// REST client for workspace-scoped preferences and managed window layouts.
/// Paths mirror `Shared/RemoteOS.Protocol/Workspace/WorkspaceApiRoutes`.
class RemoteWorkspaceApi {
  const RemoteWorkspaceApi(this._api);

  final RemoteOsApi _api;

  Future<WorkspacePreferences> preferences(String workspaceId) async {
    final json = await _api.getJson(_route(workspaceId, 'preferences'));
    return WorkspacePreferences.fromJson(_map(json));
  }

  Future<WorkspacePreferences> updatePreferences(
    String workspaceId,
    WorkspacePreferences preferences,
  ) async {
    final json = await _api.sendJson(
      'PUT',
      _route(workspaceId, 'preferences'),
      body: preferences.toJson(),
    );
    return WorkspacePreferences.fromJson(_map(json));
  }

  /// Uploads a local image and atomically makes it the workspace wallpaper.
  /// The server returns the updated preferences only after the blob is stored.
  Future<WorkspacePreferences> uploadWallpaper(
    String workspaceId,
    File file,
  ) async {
    final json =
        await _api.sendFile(_route(workspaceId, 'wallpaper'), file: file);
    return WorkspacePreferences.fromJson(_map(json));
  }

  Future<WorkspaceWindowLayouts> windowLayouts(String workspaceId) async {
    final json = await _api.getJson(_route(workspaceId, 'window-layouts'));
    return WorkspaceWindowLayouts.fromJson(_map(json));
  }

  Future<WorkspaceWindowLayouts> updateWindowLayouts(
    String workspaceId,
    WorkspaceWindowLayouts layouts,
  ) async {
    final json = await _api.sendJson(
      'PUT',
      _route(workspaceId, 'window-layouts'),
      body: layouts.toJson(),
    );
    return WorkspaceWindowLayouts.fromJson(_map(json));
  }

  static String _route(String workspaceId, String suffix) =>
      'api/v1/workspaces/$workspaceId/$suffix';

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException(
        'The server returned an invalid workspace response.');
  }
}
