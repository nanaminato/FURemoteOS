// Dependency injection bootstrap.
//
// Application-scope and window-scope singletons are registered into the
// global get_it instance here.  Existing riverpod providers are preserved for
// modules that have not yet been migrated; the new MVVM stack reads the same
// notifiers/state objects via get_it singletons pre-registered in
// [registerCoreSingletons].
//
// Scopes (ARCHITECTURE.md § 14):
//   * ApplicationScope: settings/theme/localization/window manager/apps/etc.
//   * WindowScope: shell view-model, workspace controller, modal coordinator.
//   * ServerSessionScope: created in [registerServerSession] after login and
//     released in [unregisterServerSession].
//   * FeatureScope: transient factories (`di.registerFactory`).

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../core/apps/app_registry.dart';
import '../core/auth/auth_service.dart';
import '../core/localization/language_catalog.dart';
import '../core/network/remoteos_api.dart';
import '../core/runtime/desktop_runtime.dart';
import '../core/theme/theme_service.dart';
import '../core/window_manager/modal_manager.dart';
import '../core/window_manager/window_manager.dart';
import '../apps/explorer/explorer_picker.dart';
import '../features/docker/application/docker_repository.dart';
import '../features/docker/application/docker_view_model.dart';
import '../features/docker/data/remote_docker_api.dart';
import '../features/file_manager/application/file_manager_view_model.dart';
import '../features/file_manager/data/file_manager_repository.dart';
import '../features/files/data/remote_file_api.dart';
import '../features/firewall/application/firewall_view_model.dart';
import '../features/firewall/data/remote_firewall_api.dart';
import '../features/firewall/data/repositories/remote_firewall_repository.dart';
import '../features/firewall/domain/firewall_repository.dart';
import '../features/notepad/application/notepad_view_model.dart';
import '../features/notepad/data/text_file_repository.dart';
import '../features/settings/application/settings_view_model.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/system_monitor/data/remote_system_monitor_api.dart';
import '../features/task_manager/application/task_manager_view_model.dart';
import '../features/task_manager/data/repositories/remote_task_repository.dart';
import '../features/task_manager/domain/task_repository.dart';
import '../features/workspace/application/workspace_sync_coordinator.dart';
import '../features/workspace/data/remote_workspace_api.dart';

/// Short alias for the global get_it instance.
GetIt get di => GetIt.instance;

/// Shorthand helper.
T getService<T extends Object>({String? instanceName}) =>
    di<T>(instanceName: instanceName);

/// Register application-scope singletons.
///
/// Called from `main()` after window/runtime/localization are initialized.
void registerCoreSingletons({
  required LanguageCatalog catalog,
  RuntimeLog? runtimeLog,
}) {
  // Localization
  di.registerSingleton<LanguageCatalog>(catalog);

  // Diagnostic runtime log (optional).  When supplied, core desktop paths
  // write structured INFO entries that help diagnose "white screen" or
  // "lost connection to device" failures between sign-in and desktop mount.
  if (runtimeLog != null) {
    di.registerSingleton<RuntimeLog>(runtimeLog);
  }

  // App registry
  di.registerSingleton<AppRegistry>(
    AppRegistry()..registerAll(BuiltinApps.all),
  );

  // Core notifiers.  These are the canonical instances; riverpod providers
  // are overridden in bootstrap.dart to return them.
  final authNotifier = AuthNotifier();
  di.registerSingleton<AuthNotifier>(authNotifier);

  final themeNotifier = ThemeNotifier();
  di.registerSingleton<ThemeNotifier>(themeNotifier);

  final windowManagerNotifier = WindowManagerNotifier();
  di.registerSingleton<WindowManagerNotifier>(windowManagerNotifier);

  final modalManager = ModalManager(windowManagerNotifier);
  di.registerSingleton<ModalManager>(modalManager);

  // Authenticated REST transport.
  final remoteOsApi = RemoteOsApi(authNotifier);
  di.registerSingleton<RemoteOsApi>(remoteOsApi);

  // Feature-level REST clients (service layer).  They all wrap [RemoteOsApi]
  // so the active auth token / server address flows through automatically.
  di
    ..registerLazySingleton<http.Client>(http.Client.new)
    ..registerLazySingleton<RemoteWorkspaceApi>(
      () => RemoteWorkspaceApi(remoteOsApi),
    )
    ..registerLazySingleton<RemoteFileApi>(
      () => RemoteFileApi(remoteOsApi),
    )
    ..registerLazySingleton<RemoteDockerApi>(
      () => RemoteDockerApi(remoteOsApi),
    )
    ..registerLazySingleton<RemoteSystemMonitorApi>(
      () => RemoteSystemMonitorApi(remoteOsApi),
    )
    ..registerLazySingleton<RemoteFirewallApi>(
      () => RemoteFirewallApi(remoteOsApi),
    );

  // Workspace sync (uses window manager + workspace REST client).
  final workspaceSync = WorkspaceSyncCoordinator(
    api: di<RemoteWorkspaceApi>(),
    auth: authNotifier,
  );
  di.registerSingleton<WorkspaceSyncCoordinator>(workspaceSync);

  // Settings feature (ARCHITECTURE.md § 11: repository is the canonical
  // state accessor for the ViewModel; VM is transient because each open
  // settings window has its own page state / clock / status messages).
  di.registerLazySingleton<SettingsRepository>(WorkspaceSettingsRepository.new);
  di.registerFactory<SettingsViewModel>(createSettingsViewModel);

  // Docker feature (ARCHITECTURE.md § 11 — repository is the canonical
  // state accessor for the ViewModel; VM is transient because each open
  // Docker manager window owns its own operation log, selection and
  // per-read panels).
  di.registerLazySingleton<DockerRepository>(
    () => RemoteDockerRepository(di<RemoteDockerApi>()),
  );
  di.registerFactory<DockerViewModel>(createDockerViewModel);

  // Notepad feature (ARCHITECTURE.md § 11 — repository wraps RemoteFileApi +
  // encoding conversion; VM is transient because each open Notepad window
  // owns its own undo/redo history, find/replace state and status text).
  di.registerLazySingleton<TextFileRepository>(
    () => RemoteTextFileRepository(di<RemoteFileApi>()),
  );
  di.registerFactory<NotepadViewModel>(createNotepadViewModel);

  // File Manager / Explorer feature (ARCHITECTURE.md § 11).
  // Repository wraps RemoteFileApi + DTO→domain mapping; the ViewModel is
  // transient because each open Explorer window (including picker dialogs)
  // owns its own history, selection and picker-mode state machine.
  di.registerLazySingleton<FileManagerRepository>(
    () => RemoteFileManagerRepository(di<RemoteFileApi>()),
  );
  di.registerFactoryParam<FileManagerViewModel, ExplorerPickerOptions?, void>(
    (picker, _) => createFileManagerViewModel(picker: picker),
  );

  // Firewall feature (ARCHITECTURE.md § 11).
  // Repository wraps RemoteFirewallApi + error mapping; VM is transient
  // because each open firewall window owns its own dialog hook state and
  // pending confirmation password.
  di.registerLazySingleton<FirewallRepository>(
    () => RemoteFirewallRepository(di<RemoteFirewallApi>()),
  );
  di.registerFactory<FirewallViewModel>(createFirewallViewModel);

  // Task Manager feature (ARCHITECTURE.md § 11).
  // The repository wraps RemoteSystemMonitorApi; the realtime PerformanceHub
  // is injected from the owning ConsumerState (because it is riverpod-owned)
  // so no DI singleton is registered here.  Use createTaskManagerViewModel
  // directly with the hub instance.
}

/// Register server-session-scoped objects after a successful login.
void registerServerSession() {
  // TODO(remoteos-migration): Per-session repository interfaces + impls are
  // added as each feature is migrated (settings, docker, file_manager, …).
}

/// Release any server-session-scoped objects on logout.
void unregisterServerSession() {
  // Feature repositories dispose their underlying subscriptions/clients here.
}
