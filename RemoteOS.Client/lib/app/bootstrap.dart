// Bootstrap the RemoteOS Flutter client before MaterialApp mounts.
//
// Registers get_it singletons via [registerCoreSingletons] and returns a
// riverpod `Override` list so legacy Consumer code reads the exact same
// notifier instances as the new MVVM stack (`di<...>()`).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dependency_injection.dart';
import '../core/apps/app_registry.dart';
import '../core/auth/auth_service.dart';
import '../core/localization/language_catalog.dart';
import '../core/network/remoteos_api.dart';
import '../core/theme/theme_service.dart';
import '../core/window_manager/modal_manager.dart';
import '../core/window_manager/window_manager.dart';
import '../features/workspace/application/workspace_sync_coordinator.dart';

/// Performs all one-time DI registration and returns the riverpod overrides
/// required so legacy providers resolve to the shared get_it instances.
List<Override> bootstrapRemoteOs({
  required LanguageCatalog catalog,
}) {
  registerCoreSingletons(catalog: catalog);

  final auth = di<AuthNotifier>();
  final theme = di<ThemeNotifier>();
  final windows = di<WindowManagerNotifier>();
  final workspace = di<WorkspaceSyncCoordinator>();

  return [
    languageCatalogProvider.overrideWithValue(catalog),
    appRegistryProvider.overrideWithValue(di<AppRegistry>()),
    authProvider.overrideWith((_) => auth),
    themeProvider.overrideWith((_) => theme),
    windowManagerProvider.overrideWith((_) => windows),
    modalManagerProvider.overrideWithValue(di<ModalManager>()),
    remoteOsApiProvider.overrideWithValue(di<RemoteOsApi>()),
    workspaceSyncProvider.overrideWith((_) => workspace),
  ];
}
