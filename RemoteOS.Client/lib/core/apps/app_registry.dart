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
import '../../apps/server_admin/server_admin_apps.dart';

/// Registry of available RemoteOS applications.
class AppRegistryEntry {
  final String id;
  final String nameKey; // Translation key for display name
  final IconData icon;
  final String? description;
  final WidgetBuilder windowBuilder;
  final Size defaultSize;
  final Size minimumSize;
  final bool allowMultipleInstances;

  const AppRegistryEntry({
    required this.id,
    required this.nameKey,
    required this.icon,
    this.description,
    required this.windowBuilder,
    this.defaultSize = const Size(800, 600),
    this.minimumSize = const Size(320, 240),
    this.allowMultipleInstances = false,
  });
}

/// Global registry of all registered apps.
class AppRegistry {
  final Map<String, AppRegistryEntry> _entries = {};

  void register(AppRegistryEntry entry) {
    _entries[entry.id] = entry;
  }

  void registerAll(Iterable<AppRegistryEntry> entries) {
    for (final e in entries) register(e);
  }

  AppRegistryEntry? get(String id) => _entries[id];

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
      id: 'welcome',
      nameKey: key('welcome'),
      icon: Icons.waving_hand_outlined,
      defaultSize: const Size(620, 520),
      minimumSize: const Size(480, 400),
      windowBuilder: (_) => const WelcomeApp(),
    ),
    AppRegistryEntry(
      id: 'notepad',
      nameKey: key('notepad'),
      icon: Icons.edit_note_outlined,
      defaultSize: const Size(720, 520),
      minimumSize: const Size(360, 280),
      allowMultipleInstances: true,
      windowBuilder: (_) => const NotepadApp(),
    ),
    AppRegistryEntry(
      id: 'code_editor',
      nameKey: key('code_editor'),
      icon: Icons.code_outlined,
      defaultSize: const Size(1000, 680),
      minimumSize: const Size(480, 360),
      allowMultipleInstances: true,
      windowBuilder: (_) => const CodeEditorApp(),
    ),
    AppRegistryEntry(
      id: 'image_viewer',
      nameKey: key('image_viewer'),
      icon: Icons.image_outlined,
      defaultSize: const Size(800, 600),
      minimumSize: const Size(400, 300),
      allowMultipleInstances: true,
      windowBuilder: (_) => const ImageViewerApp(),
    ),
    AppRegistryEntry(
      id: 'settings',
      nameKey: key('settings'),
      icon: Icons.settings_outlined,
      defaultSize: const Size(920, 620),
      minimumSize: const Size(640, 480),
      windowBuilder: (_) => const SettingsApp(),
    ),
    AppRegistryEntry(
      id: 'terminal',
      nameKey: key('terminal'),
      icon: Icons.terminal_outlined,
      defaultSize: const Size(820, 520),
      minimumSize: const Size(400, 280),
      allowMultipleInstances: true,
      windowBuilder: (_) => const TerminalApp(),
    ),
    AppRegistryEntry(
      id: 'explorer',
      nameKey: key('explorer'),
      icon: Icons.folder_outlined,
      defaultSize: const Size(920, 620),
      minimumSize: const Size(480, 360),
      allowMultipleInstances: true,
      windowBuilder: (_) => const ExplorerApp(),
    ),
    AppRegistryEntry(
      id: 'browser',
      nameKey: key('browser'),
      icon: Icons.public_outlined,
      defaultSize: const Size(1080, 720),
      minimumSize: const Size(480, 360),
      allowMultipleInstances: true,
      windowBuilder: (_) => const BrowserApp(),
    ),
    AppRegistryEntry(
      id: 'task_manager',
      nameKey: key('task_manager'),
      icon: Icons.monitor_heart_outlined,
      defaultSize: const Size(820, 580),
      minimumSize: const Size(480, 360),
      windowBuilder: (_) => const TaskManagerApp(),
    ),
    AppRegistryEntry(
      id: 'docker_manager',
      nameKey: key('docker_manager'),
      icon: Icons.integration_instructions_outlined,
      defaultSize: const Size(1020, 680),
      minimumSize: const Size(600, 440),
      windowBuilder: (_) => const DockerManagerApp(),
    ),
    AppRegistryEntry(
      id: 'firewall',
      nameKey: key('firewall'),
      icon: Icons.shield_outlined,
      defaultSize: const Size(820, 580),
      minimumSize: const Size(520, 400),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.firewall),
    ),
    AppRegistryEntry(
      id: 'certificates',
      nameKey: key('certificates'),
      icon: Icons.verified_user_outlined,
      defaultSize: const Size(880, 580),
      minimumSize: const Size(560, 420),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.certificates),
    ),
    AppRegistryEntry(
      id: 'web_servers',
      nameKey: key('web_servers'),
      icon: Icons.http_outlined,
      defaultSize: const Size(980, 640),
      minimumSize: const Size(560, 420),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.webServers),
    ),
    AppRegistryEntry(
      id: 'tunnels',
      nameKey: key('tunnels'),
      icon: Icons.route_outlined,
      defaultSize: const Size(920, 620),
      minimumSize: const Size(560, 400),
      windowBuilder: (_) => const ServerAdminApp(kind: ServerAdminKind.tunnels),
    ),
    AppRegistryEntry(
      id: 'git_client',
      nameKey: key('git_client'),
      icon: Icons.source_outlined,
      defaultSize: const Size(980, 640),
      minimumSize: const Size(560, 400),
      windowBuilder: (_) => const ServerAdminApp(kind: ServerAdminKind.git),
    ),
    AppRegistryEntry(
      id: 'port_forwarding',
      nameKey: key('port_forwarding'),
      icon: Icons.alt_route_outlined,
      defaultSize: const Size(800, 560),
      minimumSize: const Size(480, 360),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.portForwarding),
    ),
    AppRegistryEntry(
      id: 'process_guardian',
      nameKey: key('process_guardian'),
      icon: Icons.health_and_safety_outlined,
      defaultSize: const Size(860, 580),
      minimumSize: const Size(560, 400),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.guardian),
    ),
    AppRegistryEntry(
      id: 'app_installer',
      nameKey: key('app_installer'),
      icon: Icons.get_app_outlined,
      defaultSize: const Size(820, 580),
      minimumSize: const Size(520, 400),
      windowBuilder: (_) =>
          const ServerAdminApp(kind: ServerAdminKind.installer),
    ),
  ];
}
