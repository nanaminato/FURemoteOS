import 'dart:async';
import 'dart:io';

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
    this.writeDelay = const Duration(seconds: 2),
  })  : _api = api,
        _auth = auth,
        super(const WorkspaceSyncState());

  final RemoteWorkspaceApi _api;
  final AuthNotifier _auth;
  final Duration writeDelay;
  Timer? _pendingPreferenceWrite;
  Timer? _pendingLayoutWrite;
  bool _preferencesDirty = false;
  bool _layoutsDirty = false;
  int _preferencesVersion = 0;
  int _layoutsVersion = 0;

  Future<void> load() async {
    final workspaceId = _auth.current.workspaceId;
    if (!_auth.current.isAuthenticated || workspaceId == null) return;
    state = WorkspaceSyncState(layouts: state.layouts, loading: true);
    // Keep window-layout restoration independent from optional preferences:
    // this is how Avalonia's WindowLayoutStore remains usable when another
    // workspace request temporarily fails.
    WorkspacePreferences? preferences = state.preferences;
    WorkspaceWindowLayouts layouts = state.layouts;
    Object? error;
    try {
      preferences = await _api.preferences(workspaceId);
    } catch (caught) {
      error = caught;
    }
    try {
      layouts = await _api.windowLayouts(workspaceId);
    } catch (caught) {
      error ??= caught;
    }
    if (!mounted) return;
    state = WorkspaceSyncState(
      preferences: preferences,
      layouts: layouts,
      error: error,
    );
  }

  void queuePreferences(WorkspacePreferences preferences) {
    state =
        WorkspaceSyncState(preferences: preferences, layouts: state.layouts);
    _preferencesDirty = true;
    final version = ++_preferencesVersion;
    _pendingPreferenceWrite?.cancel();
    _pendingPreferenceWrite =
        Timer(writeDelay, () => _writePreferences(preferences, version));
  }

  Future<void> _writePreferences(
      WorkspacePreferences preferences, int version) async {
    final workspaceId = _auth.current.workspaceId;
    if (workspaceId == null) return;
    try {
      final saved = await _api.updatePreferences(workspaceId, preferences);
      if (mounted && version == _preferencesVersion) {
        state = WorkspaceSyncState(preferences: saved, layouts: state.layouts);
        _preferencesDirty = false;
      }
    } catch (error) {
      if (mounted && version == _preferencesVersion) {
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

  /// Upload a custom desktop image. Unlike ordinary preference changes this
  /// request is immediate: the server stores the blob and updates WallpaperKey
  /// atomically, so no client can observe a reference to an absent image.
  Future<void> uploadWallpaper(File file) async {
    final workspaceId = _auth.current.workspaceId;
    if (!_auth.current.isAuthenticated || workspaceId == null) {
      throw StateError('Not signed in to a workspace.');
    }

    _pendingPreferenceWrite?.cancel();
    _pendingPreferenceWrite = null;
    final version = ++_preferencesVersion;
    _preferencesDirty = false;
    final saved = await _api.uploadWallpaper(workspaceId, file);
    if (mounted && version == _preferencesVersion) {
      state = WorkspaceSyncState(preferences: saved, layouts: state.layouts);
    }
  }

  void queueLayouts(WorkspaceWindowLayouts layouts) {
    state =
        WorkspaceSyncState(preferences: state.preferences, layouts: layouts);
    _layoutsDirty = true;
    final version = ++_layoutsVersion;
    _pendingLayoutWrite?.cancel();
    _pendingLayoutWrite =
        Timer(writeDelay, () => _writeLayouts(layouts, version));
  }

  Future<void> _writeLayouts(
      WorkspaceWindowLayouts layouts, int version) async {
    final workspaceId = _auth.current.workspaceId;
    if (workspaceId == null) return;
    try {
      final saved = await _api.updateWindowLayouts(workspaceId, layouts);
      if (mounted && version == _layoutsVersion) {
        state =
            WorkspaceSyncState(preferences: state.preferences, layouts: saved);
        _layoutsDirty = false;
      }
    } catch (error) {
      if (mounted && version == _layoutsVersion) {
        state = WorkspaceSyncState(
          preferences: state.preferences,
          layouts: state.layouts,
          error: error,
        );
      }
    }
  }

  /// Sends pending best-effort changes before a user-initiated disconnect or
  /// close, matching Avalonia's WindowLayoutStore.FlushAsync behaviour.
  Future<void> flush() async {
    _pendingPreferenceWrite?.cancel();
    _pendingPreferenceWrite = null;
    _pendingLayoutWrite?.cancel();
    _pendingLayoutWrite = null;

    final preferences = state.preferences;
    if (_preferencesDirty && preferences != null) {
      await _writePreferences(preferences, _preferencesVersion);
    }
    if (_layoutsDirty) await _writeLayouts(state.layouts, _layoutsVersion);
  }

  @override
  void dispose() {
    _pendingPreferenceWrite?.cancel();
    _pendingLayoutWrite?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public read-only snapshots intended for non-riverpod consumers (e.g. the
  // new MVVM ViewModel stack which cannot call the protected `state` getter
  // from outside this library).  These intentionally do not publish setters —
  // mutations still go through the existing queue* methods so debouncing and
  // server writes stay centralised.
  // ---------------------------------------------------------------------------

  WorkspaceWindowLayouts debugLayoutsSnapshot() => state.layouts;
  WorkspacePreferences? debugPreferencesSnapshot() => state.preferences;
  WorkspaceSyncState debugStateSnapshot() => state;
}

final workspaceSyncProvider =
    StateNotifierProvider<WorkspaceSyncCoordinator, WorkspaceSyncState>(
  (ref) => WorkspaceSyncCoordinator(
    api: RemoteWorkspaceApi(ref.read(remoteOsApiProvider)),
    auth: ref.read(authProvider.notifier),
  ),
);
