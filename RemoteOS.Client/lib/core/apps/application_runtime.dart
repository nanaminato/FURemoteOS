import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/window_manager/window_manager.dart';
import 'app_registry.dart';
import 'application_manifest.dart';

enum AppActivationStatus {
  activated,
  invalidUri,
  routeNotFound,
  noHandler,
  handlerSelectionRequired,
  unavailable,
}

class AppActivationRequest {
  const AppActivationRequest({
    required this.uri,
    this.sourceAppId,
    this.userInitiated = true,
  });

  final Uri uri;
  final String? sourceAppId;
  final bool userInitiated;
}

class AppActivationResult {
  const AppActivationResult(this.status, {this.targetAppId});

  final AppActivationStatus status;
  final String? targetAppId;

  bool get succeeded => status == AppActivationStatus.activated;
}

/// Builds a child at the presentation boundary. The runtime owns routing and
/// lifecycle decisions, while the Shell remains the only owner of context.
typedef AppWindowBuilder = Widget Function(AppRegistryEntry entry);

/// Shell-owned, typed application activation and instance-policy runtime.
class ApplicationRuntime {
  ApplicationRuntime({
    required AppRegistry registry,
    required WindowManagerNotifier windows,
    required AuthNotifier auth,
  })  : _registry = registry,
        _windows = windows,
        _auth = auth;

  final AppRegistry _registry;
  final WindowManagerNotifier _windows;
  final AuthNotifier _auth;

  ApplicationCompatibilityResult evaluate(AppRegistryEntry entry) {
    final client = _clientPlatform();
    final manifest = entry.manifest;
    if (manifest.clientPlatforms.isNotEmpty &&
        !manifest.clientPlatforms.contains(client)) {
      return ApplicationCompatibilityResult(
        ApplicationCompatibilityStatus.clientPlatformMismatch,
        expected: manifest.clientPlatforms.map((p) => p.wireName).join(', '),
        actual: client.wireName,
      );
    }
    if (manifest.server.isEmpty) {
      return const ApplicationCompatibilityResult.compatible();
    }
    final server = _auth.current.server;
    if (server == null) {
      return const ApplicationCompatibilityResult(
        ApplicationCompatibilityStatus.serverUnavailable,
      );
    }
    if (manifest.server.platforms.isNotEmpty &&
        !manifest.server.platforms.contains(server.platform)) {
      return ApplicationCompatibilityResult(
        ApplicationCompatibilityStatus.serverPlatformMismatch,
        expected: manifest.server.platforms.map((p) => p.wireName).join(', '),
        actual: server.platform.wireName,
      );
    }
    final missing = manifest.server.capabilities.firstWhere(
      (capability) => !server.capabilities.contains(capability),
      orElse: () => '',
    );
    return missing.isEmpty
        ? const ApplicationCompatibilityResult.compatible()
        : ApplicationCompatibilityResult(
            ApplicationCompatibilityStatus.missingServerCapability,
            expected: missing,
          );
  }

  AppActivationResult launch(
    String appId, {
    required AppWindowBuilder buildWindow,
    Size? screenSize,
    Size? initialSize,
    String? title,
  }) {
    final entry = _registry.get(appId);
    if (entry == null || !evaluate(entry).isCompatible) {
      return AppActivationResult(AppActivationStatus.unavailable,
          targetAppId: appId);
    }
    _open(entry, buildWindow,
        screenSize: screenSize, initialSize: initialSize, title: title);
    return AppActivationResult(AppActivationStatus.activated,
        targetAppId: appId);
  }

  AppActivationResult activate(
    AppActivationRequest request, {
    required AppWindowBuilder buildWindow,
    Size? screenSize,
    String? defaultHandlerForScheme,
  }) {
    final uri = request.uri;
    if (!uri.isAbsolute ||
        uri.scheme.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      return const AppActivationResult(AppActivationStatus.invalidUri);
    }
    if (uri.scheme.toLowerCase() == 'remoteos') {
      return _activateShellRoute(request,
          buildWindow: buildWindow, screenSize: screenSize);
    }
    if (uri.scheme.length > 32 || uri.host.isEmpty || uri.query.length > 4097) {
      return const AppActivationResult(AppActivationStatus.invalidUri);
    }
    final candidates = _registry.all.where((entry) {
      return entry.manifest.supportedUriSchemes
              .contains(uri.scheme.toLowerCase()) &&
          entry.canHandleActivation?.call(uri) == true;
    }).toList(growable: false);
    final preferred = defaultHandlerForScheme == null
        ? const <AppRegistryEntry>[]
        : candidates
            .where((entry) => entry.id == defaultHandlerForScheme)
            .toList();
    final defaultEntry = preferred.isEmpty ? null : preferred.first;
    if (defaultEntry != null) {
      return _activateEntry(defaultEntry, request, buildWindow, screenSize);
    }
    if (candidates.length == 1) {
      return _activateEntry(
          candidates.single, request, buildWindow, screenSize);
    }
    return AppActivationResult(
      candidates.isEmpty
          ? AppActivationStatus.noHandler
          : AppActivationStatus.handlerSelectionRequired,
    );
  }

  AppActivationResult _activateShellRoute(
    AppActivationRequest request, {
    required AppWindowBuilder buildWindow,
    Size? screenSize,
  }) {
    final uri = request.uri;
    if (uri.host.isEmpty)
      return const AppActivationResult(AppActivationStatus.invalidUri);
    final candidates = _registry.all
        .where((entry) =>
            !entry.manifest.isExternal &&
            entry.canHandleActivation?.call(uri) == true)
        .toList();
    if (candidates.length != 1) {
      return const AppActivationResult(AppActivationStatus.routeNotFound);
    }
    if (uri.host == 'file' &&
        request.sourceAppId != null &&
        request.sourceAppId != 'remoteos.explorer') {
      return const AppActivationResult(AppActivationStatus.unavailable);
    }
    return _activateEntry(candidates.single, request, buildWindow, screenSize);
  }

  AppActivationResult _activateEntry(
    AppRegistryEntry entry,
    AppActivationRequest request,
    AppWindowBuilder buildWindow,
    Size? screenSize,
  ) {
    if (!evaluate(entry).isCompatible) {
      return AppActivationResult(AppActivationStatus.unavailable,
          targetAppId: entry.id);
    }
    final existing = _primaryWindow(entry.id);
    if (existing != null &&
        entry.manifest.instancePolicy ==
            ApplicationInstancePolicy.singleWindow) {
      entry.handleActivation?.call(request.uri);
      if (existing.state == RemoteWindowState.minimized)
        _windows.restore(existing.id);
      _windows.focus(existing.id);
      return AppActivationResult(AppActivationStatus.activated,
          targetAppId: entry.id);
    }
    _open(entry, buildWindow, screenSize: screenSize);
    entry.handleActivation?.call(request.uri);
    return AppActivationResult(AppActivationStatus.activated,
        targetAppId: entry.id);
  }

  void _open(AppRegistryEntry entry, AppWindowBuilder buildWindow,
      {Size? screenSize, Size? initialSize, String? title}) {
    _windows.openApp(
      entry: entry,
      child: buildWindow(entry),
      title: title,
      screenSize: screenSize,
      initialSize: initialSize,
    );
  }

  RemoteWindow? _primaryWindow(String appId) {
    final windows = _windows.state
        .where((window) => !window.isModal && window.appId == appId);
    return windows.isEmpty ? null : windows.last;
  }

  static ApplicationPlatform _clientPlatform() {
    if (Platform.isWindows) return ApplicationPlatform.windows;
    if (Platform.isLinux) return ApplicationPlatform.linux;
    if (Platform.isMacOS) return ApplicationPlatform.macos;
    return ApplicationPlatform.unknown;
  }
}

class RemoteOsActivationUris {
  static final settingsPersonalization =
      Uri.parse('remoteos://settings/personalization');
  static final settingsApps = Uri.parse('remoteos://settings/apps');

  static Uri settingsAppPermissions(String appId) => Uri.parse(
      'remoteos://settings/apps/${Uri.encodeComponent(appId)}/permissions');

  static Uri explorerPath(String path) => Uri(
      scheme: 'remoteos',
      host: 'explorer',
      path: '/open',
      queryParameters: {'path': path});

  static Uri openFile(String appId, String path) => Uri(
        scheme: 'remoteos',
        host: 'file',
        path: '/open',
        queryParameters: {'appId': appId, 'path': path},
      );
}
