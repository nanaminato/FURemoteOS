import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/network/remoteos_api.dart';
import '../../../core/theme/theme_models.dart';
import '../data/remote_workspace_api.dart';
import '../domain/workspace_models.dart';

class WorkspaceSyncState {
  const WorkspaceSyncState({
    this.preferences,
    this.layouts = const WorkspaceWindowLayouts(),
    this.loading = false,
    this.error,
  });

  final WorkspacePreferences? preferences;
  final WorkspaceWindowLayouts layouts;
  final bool loading;
  final Object? error;
}

/// Loads workspace-owned desktop data once a session is authenticated and
/// coalesces preference writes so UI sliders/chips do not issue a PUT per tap.
class WorkspaceSyncCoordinator extends StateNotifier<WorkspaceSyncState> {
  WorkspaceSyncCoordinator({
    required RemoteWorkspaceApi api,
    required AuthNotifier auth,
    this.writeDelay = const Duration(milliseconds: 350),
  })  : _api = api,
        _auth = auth,
        super(const WorkspaceSyncState());

  final RemoteWorkspaceApi _api;
  final AuthNotifier _auth;
  final Duration writeDelay;
  Timer? _pendingPreferenceWrite;
  Timer? _pendingLayoutWrite;

  Future<void> load() async {
    final workspaceId = _auth.current.workspaceId;
    if (!_auth.current.isAuthenticated || workspaceId == null) return;
    state = WorkspaceSyncState(layouts: state.layouts, loading: true);
    try {
      final result = await Future.wait([
        _api.preferences(workspaceId),
        _api.windowLayouts(workspaceId),
      ]);
      state = WorkspaceSyncState(
        preferences: result[0] as WorkspacePreferences,
        layouts: result[1] as WorkspaceWindowLayouts,
      );
    } catch (error) {
      state = WorkspaceSyncState(
        preferences: state.preferences,
        layouts: state.layouts,
        error: error,
      );
    }
  }

  void queuePreferences(WorkspacePreferences preferences) {
    state =
        WorkspaceSyncState(preferences: preferences, layouts: state.layouts);
    _pendingPreferenceWrite?.cancel();
    _pendingPreferenceWrite =
        Timer(writeDelay, () => _writePreferences(preferences));
  }

  Future<void> _writePreferences(WorkspacePreferences preferences) async {
    final workspaceId = _auth.current.workspaceId;
    if (workspaceId == null) return;
    try {
      final saved = await _api.updatePreferences(workspaceId, preferences);
      if (mounted)
        state = WorkspaceSyncState(preferences: saved, layouts: state.layouts);
    } catch (error) {
      if (mounted) {
        state = WorkspaceSyncState(
          preferences: state.preferences,
          layouts: state.layouts,
          error: error,
        );
      }
    }
  }

  void queueTheme(ThemeKind kind, ThemePreferencesDto themePreferences) {
    final current = state.preferences;
    if (current == null) return;
    queuePreferences(
        current.copyWith(theme: kind, themePreferences: themePreferences));
  }

  void queueLayouts(WorkspaceWindowLayouts layouts) {
    if (state.preferences == null) return;
    state =
        WorkspaceSyncState(preferences: state.preferences, layouts: layouts);
    _pendingLayoutWrite?.cancel();
    _pendingLayoutWrite = Timer(writeDelay, () => _writeLayouts(layouts));
  }

  Future<void> _writeLayouts(WorkspaceWindowLayouts layouts) async {
    final workspaceId = _auth.current.workspaceId;
    if (workspaceId == null) return;
    try {
      final saved = await _api.updateWindowLayouts(workspaceId, layouts);
      if (mounted) {
        state =
            WorkspaceSyncState(preferences: state.preferences, layouts: saved);
      }
    } catch (error) {
      if (mounted) {
        state = WorkspaceSyncState(
          preferences: state.preferences,
          layouts: state.layouts,
          error: error,
        );
      }
    }
  }

  @override
  void dispose() {
    _pendingPreferenceWrite?.cancel();
    _pendingLayoutWrite?.cancel();
    super.dispose();
  }
}

final workspaceSyncProvider =
    StateNotifierProvider<WorkspaceSyncCoordinator, WorkspaceSyncState>(
  (ref) => WorkspaceSyncCoordinator(
    api: RemoteWorkspaceApi(ref.read(remoteOsApiProvider)),
    auth: ref.read(authProvider.notifier),
  ),
);
