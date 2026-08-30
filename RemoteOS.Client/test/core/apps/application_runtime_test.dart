import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/apps/app_registry.dart';
import 'package:remoteos_client/core/apps/application_manifest.dart';
import 'package:remoteos_client/core/apps/application_runtime.dart';
import 'package:remoteos_client/core/auth/auth_service.dart';
import 'package:remoteos_client/core/window_manager/window_manager.dart';

void main() {
  AppRegistryEntry entry({
    required String id,
    ApplicationManifest? manifest,
    bool Function(Uri)? canHandle,
    void Function(Uri)? onActivation,
  }) =>
      AppRegistryEntry(
        id: id,
        nameKey: 'app.test',
        icon: Icons.extension_outlined,
        windowBuilder: (_) => const SizedBox.shrink(),
        manifest: manifest,
        canHandleActivation: canHandle,
        handleActivation: onActivation,
      );

  ApplicationRuntime runtime(
          AppRegistry registry, WindowManagerNotifier windows) =>
      ApplicationRuntime(
          registry: registry, windows: windows, auth: AuthNotifier());

  test('rejects unsafe or malformed activation URIs', () {
    final registry = AppRegistry();
    final result = runtime(registry, WindowManagerNotifier()).activate(
      AppActivationRequest(
          uri: Uri.parse('remoteos://user@help/guide/docker/install')),
      buildWindow: (_) => const SizedBox.shrink(),
    );

    expect(result.status, AppActivationStatus.invalidUri);
  });

  test('reuses the primary window for a built-in help activation', () {
    final registry = AppRegistry();
    final handled = <Uri>[];
    final manifest = ApplicationManifest(
      id: 'remoteos.help-test',
      version: '1.0.0',
      instancePolicy: ApplicationInstancePolicy.singleWindow,
    );
    registry.register(entry(
      id: manifest.id,
      manifest: manifest,
      canHandle: (uri) =>
          uri.scheme == 'remoteos' &&
          uri.host == 'help' &&
          uri.path == '/guide/docker/install',
      onActivation: handled.add,
    ));
    final windows = WindowManagerNotifier();
    final appRuntime = runtime(registry, windows);
    final request = AppActivationRequest(
        uri: Uri.parse('remoteos://help/guide/docker/install?lang=en'));

    expect(
      appRuntime
          .activate(request, buildWindow: (_) => const SizedBox.shrink())
          .succeeded,
      isTrue,
    );
    expect(
      appRuntime
          .activate(request, buildWindow: (_) => const SizedBox.shrink())
          .succeeded,
      isTrue,
    );
    expect(windows.state, hasLength(1));
    expect(handled, hasLength(2));
  });

  test('does not start a server-dependent app without a server descriptor', () {
    final registry = AppRegistry();
    final manifest = ApplicationManifest(
      id: 'remoteos.firewall-test',
      version: '1.0.0',
      server: const ApplicationServerRequirements(
        platforms: [ApplicationPlatform.linux],
        capabilities: ['server.firewall'],
      ),
    );
    registry.register(entry(id: manifest.id, manifest: manifest));
    final appRuntime = runtime(registry, WindowManagerNotifier());

    expect(
      appRuntime
          .launch(manifest.id, buildWindow: (_) => const SizedBox.shrink())
          .status,
      AppActivationStatus.unavailable,
    );
    expect(
      appRuntime.evaluate(registry.get(manifest.id)!).status,
      ApplicationCompatibilityStatus.serverUnavailable,
    );
  });

  test('routes a reserved URI only through a first-party manifest handler', () {
    final registry = AppRegistry();
    final handled = <Uri>[];
    final manifest = ApplicationManifest(
      id: 'remoteos.settings-test',
      version: '1.0.0',
      instancePolicy: ApplicationInstancePolicy.singleWindow,
    );
    registry.register(entry(
      id: manifest.id,
      manifest: manifest,
      canHandle: (uri) =>
          uri.scheme == 'remoteos' &&
          uri.host == 'settings' &&
          uri.path == '/apps',
      onActivation: handled.add,
    ));

    final result = runtime(registry, WindowManagerNotifier()).activate(
      AppActivationRequest(uri: Uri.parse('remoteos://settings/apps')),
      buildWindow: (_) => const SizedBox.shrink(),
    );

    expect(result.status, AppActivationStatus.activated);
    expect(handled.single.toString(), 'remoteos://settings/apps');
  });
}
