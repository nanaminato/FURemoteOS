import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apps/settings/settings_app.dart';
import '../../apps/welcome/welcome_app.dart';
import '../../apps/terminal/terminal_app.dart';
import '../../apps/notepad/notepad_app.dart';
import '../../apps/browser/browser_app.dart';
import '../../apps/code_editor/code_editor_app.dart';
import '../../apps/explorer/explorer_app.dart';
import '../../apps/image_viewer/image_viewer_app.dart';
import '../../apps/task_manager/task_manager_app.dart';
import '../../apps/docker/docker_manager_app.dart';
import '../../apps/firewall/firewall_app.dart';
import '../../apps/server_admin/server_admin_apps.dart';
import '../../external_apps/help_center/help_center_app.dart';
import '../../external_apps/help_center/help_center_package.dart';
import 'app_ids.dart';
import 'builtin_app_activations.dart';
import 'application_manifest.dart';

/// Registry of available RemoteOS applications.
class AppRegistryEntry {
  final ApplicationManifest manifest;
  String get id => manifest.id;
  final String nameKey; // Translation key for display name
  final IconData icon;
  final String? description;
  final WidgetBuilder windowBuilder;
  final Size defaultSize;
  final Size minimumSize;
  bool get allowMultipleInstances =>
      manifest.instancePolicy == ApplicationInstancePolicy.multiWindow;
  final bool Function(Uri uri)? canHandleActivation;
  final void Function(Uri uri)? handleActivation;

  AppRegistryEntry({
    required String id,
    required this.nameKey,
    required this.icon,
    this.description,
    required this.windowBuilder,
    this.defaultSize = const Size(800, 600),
    this.minimumSize = const Size(320, 240),
    bool allowMultipleInstances = false,
    ApplicationManifest? manifest,
    this.canHandleActivation,
    this.handleActivation,
  })  : assert(manifest == null || manifest.id == id),
        manifest = manifest ??
            ApplicationManifest(
              id: id,
              version: '1.0.0',
              instancePolicy: allowMultipleInstances
                  ? ApplicationInstancePolicy.multiWindow
                  : ApplicationInstancePolicy.singleWindow,
            );
}

/// Global registry of all registered apps.
class AppRegistry {
  final Map<String, AppRegistryEntry> _entries = {};
  static const _legacyAliases = <String, String>{
    'welcome': AppIds.welcome,
    'notepad': AppIds.notepad,
    'code_editor': AppIds.codeEditor,
    'image_viewer': AppIds.imageViewer,
    'settings': AppIds.settings,
    'terminal': AppIds.terminal,
    'explorer': AppIds.explorer,
    'browser': AppIds.browser,
    'task_manager': AppIds.taskManager,
    'docker_manager': AppIds.docker,
    'firewall': AppIds.firewall,
    'certificates': AppIds.certificates,
    'web_servers': AppIds.webServers,
    'tunnels': AppIds.tunnels,
    'git_client': AppIds.git,
    'port_forwarding': AppIds.portForwarding,
    'process_guardian': AppIds.processGuardian,
    'app_installer': AppIds.appInstaller,
  };

  void register(AppRegistryEntry entry) {
    _entries[entry.id] = entry;
  }

  void registerAll(Iterable<AppRegistryEntry> entries) {
    for (final e in entries) register(e);
  }

  /// Resolves earlier Flutter UI aliases at the registry boundary. Newly
  /// persisted values and activation requests use the manifest package id.
  AppRegistryEntry? get(String id) => _entries[_legacyAliases[id] ?? id];

  List<AppRegistryEntry> get all => _entries.values.toList(growable: false);
}

final appRegistryProvider = Provider<AppRegistry>((ref) {
  final registry = AppRegistry();
  // Register built-in apps dynamically from [_BuiltinApps].
  registry.registerAll(BuiltinApps.all);
  return registry;
});

/// Catalog of built-in apps.  Complex server applications use the same
/// split-pane, multi-page pattern as the original Avalonia workspaces.
class BuiltinApps {
  static String key(String name) => 'app.$name';

  static final List<AppRegistryEntry> all = [
    AppRegistryEntry(
      id: AppIds.welcome,
      nameKey: key('welcome'),
      icon: Icons.waving_hand_outlined,
      defaultSize: const Size(620, 520),
      minimumSize: const Size(480, 400),
      windowBuilder: (_) => const WelcomeApp(),
    ),
    AppRegistryEntry(
      id: AppIds.notepad,
      nameKey: key('notepad'),
      icon: Icons.edit_note_outlined,
      defaultSize: const Size(720, 520),
      minimumSize: const Size(360, 280),
      allowMultipleInstances: true,
      windowBuilder: (_) => const NotepadApp(),
    ),
    AppRegistryEntry(
      id: AppIds.codeEditor,
      nameKey: key('code_editor'),
      icon: Icons.code_outlined,
      defaultSize: const Size(1000, 680),
      minimumSize: const Size(480, 360),
      allowMultipleInstances: true,
      windowBuilder: (_) => const CodeEditorApp(),
    ),
    AppRegistryEntry(
      id: AppIds.imageViewer,
      nameKey: key('image_viewer'),
      icon: Icons.image_outlined,
      defaultSize: const Size(800, 600),
      minimumSize: const Size(400, 300),
      allowMultipleInstances: true,
      windowBuilder: (_) => const ImageViewerApp(),
    ),
    AppRegistryEntry(
      id: AppIds.settings,
      nameKey: key('settings'),
      icon: Icons.settings_outlined,
      defaultSize: const Size(920, 620),
      minimumSize: const Size(640, 480),
      canHandleActivation: BuiltinAppActivations.canHandleSettings,
      handleActivation: BuiltinAppActivations.settings.handle,
      windowBuilder: (_) =>
          SettingsApp(activation: BuiltinAppActivations.settings),
    ),
    AppRegistryEntry(
      id: AppIds.terminal,
      nameKey: key('terminal'),
      icon: Icons.terminal_outlined,
      defaultSize: const Size(820, 520),
      minimumSize: const Size(400, 280),
      allowMultipleInstances: true,
      windowBuilder: (_) => const TerminalApp(),
    ),
    AppRegistryEntry(
      id: AppIds.explorer,
      nameKey: key('explorer'),
      icon: Icons.folder_outlined,
      defaultSize: const Size(920, 620),
      minimumSize: const Size(480, 360),
      allowMultipleInstances: true,
      windowBuilder: (_) => const ExplorerApp(),
    ),
    AppRegistryEntry(
      id: AppIds.browser,
      nameKey: key('browser'),
      icon: Icons.public_outlined,
      defaultSize: const Size(1080, 720),
      minimumSize: const Size(480, 360),
      allowMultipleInstances: true,
      windowBuilder: (_) => const BrowserApp(),
    ),
    AppRegistryEntry(
      id: AppIds.taskManager,
      nameKey: key('task_manager'),
      icon: Icons.monitor_heart_outlined,
      defaultSize: const Size(820, 580),
      minimumSize: const Size(480, 360),
      windowBuilder: (_) => const TaskManagerApp(),
    ),
    AppRegistryEntry(
      id: AppIds.docker,
      nameKey: key('docker_manager'),
      icon: Icons.integration_instructions_outlined,
      defaultSize: const Size(1020, 680),
      minimumSize: const Size(600, 440),
      windowBuilder: (_) => const DockerManagerApp(),
    ),
    AppRegistryEntry(
      id: AppIds.firewall,
      nameKey: key('firewall'),
      icon: Icons.shield_outlined,
      defaultSize: const Size(1160, 760),
      minimumSize: const Size(800, 520),
      windowBuilder: (_) => const FirewallApp(),
      manifest: ApplicationManifest(
        id: AppIds.firewall,
        version: '1.0.0',
        server: const ApplicationServerRequirements(
          platforms: [ApplicationPlatform.linux],
          capabilities: ['server.firewall'],
        ),
        instancePolicy: ApplicationInstancePolicy.singleWindow,
      ),
    ),
    AppRegistryEntry(
      id: AppIds.certificates,
      nameKey: key('certificates'),
      icon: Icons.verified_user_outlined,
      defaultSize: const Size(880, 580),
      minimumSize: const Size(560, 420),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.certificates),
    ),
    AppRegistryEntry(
      id: AppIds.webServers,
      nameKey: key('web_servers'),
      icon: Icons.http_outlined,
      defaultSize: const Size(980, 640),
      minimumSize: const Size(560, 420),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.webServers),
    ),
    AppRegistryEntry(
      id: AppIds.tunnels,
      nameKey: key('tunnels'),
      icon: Icons.route_outlined,
      defaultSize: const Size(920, 620),
      minimumSize: const Size(560, 400),
      windowBuilder: (_) => const ServerAdminApp(kind: ServerAdminKind.tunnels),
    ),
    AppRegistryEntry(
      id: AppIds.git,
      nameKey: key('git_client'),
      icon: Icons.source_outlined,
      defaultSize: const Size(980, 640),
      minimumSize: const Size(560, 400),
      windowBuilder: (_) => const ServerAdminApp(kind: ServerAdminKind.git),
    ),
    AppRegistryEntry(
      id: AppIds.portForwarding,
      nameKey: key('port_forwarding'),
      icon: Icons.alt_route_outlined,
      defaultSize: const Size(800, 560),
      minimumSize: const Size(480, 360),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.portForwarding),
    ),
    AppRegistryEntry(
      id: AppIds.processGuardian,
      nameKey: key('process_guardian'),
      icon: Icons.health_and_safety_outlined,
      defaultSize: const Size(860, 580),
      minimumSize: const Size(560, 400),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.guardian),
    ),
    AppRegistryEntry(
      id: AppIds.appInstaller,
      nameKey: key('app_installer'),
      icon: Icons.get_app_outlined,
      defaultSize: const Size(820, 580),
      minimumSize: const Size(520, 400),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.installer),
    ),
    AppRegistryEntry(
      id: AppIds.helpCenter,
      nameKey: 'app.help_center',
      icon: Icons.help_outline_rounded,
      defaultSize: const Size(900, 620),
      minimumSize: const Size(600, 420),
      manifest: HelpCenterPackage.manifest,
      canHandleActivation: HelpCenterPackages.instance.canHandle,
      handleActivation: HelpCenterPackages.instance.handle,
      windowBuilder: (_) => HelpCenterApp(package: HelpCenterPackages.instance),
    ),
  ];
}
