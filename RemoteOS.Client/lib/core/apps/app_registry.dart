import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';
import '../../apps/settings/settings_app.dart';
import '../../apps/welcome/welcome_app.dart';
import '../../apps/terminal/terminal_app.dart';
import '../../apps/notepad/notepad_app.dart';

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

/// Catalog of built-in apps (placeholder implementations).
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
      windowBuilder: (_) => const _PlaceholderApp(id: 'code_editor'),
    ),
    AppRegistryEntry(
      id: 'image_viewer',
      nameKey: key('image_viewer'),
      icon: Icons.image_outlined,
      defaultSize: const Size(800, 600),
      minimumSize: const Size(400, 300),
      allowMultipleInstances: true,
      windowBuilder: (_) => const _PlaceholderApp(id: 'image_viewer'),
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
      windowBuilder: (_) => const _PlaceholderApp(id: 'explorer'),
    ),
    AppRegistryEntry(
      id: 'browser',
      nameKey: key('browser'),
      icon: Icons.public_outlined,
      defaultSize: const Size(1080, 720),
      minimumSize: const Size(480, 360),
      allowMultipleInstances: true,
      windowBuilder: (_) => const _PlaceholderApp(id: 'browser'),
    ),
    AppRegistryEntry(
      id: 'task_manager',
      nameKey: key('task_manager'),
      icon: Icons.monitor_heart_outlined,
      defaultSize: const Size(820, 580),
      minimumSize: const Size(480, 360),
      windowBuilder: (_) => const _PlaceholderApp(id: 'task_manager'),
    ),
    AppRegistryEntry(
      id: 'docker_manager',
      nameKey: key('docker_manager'),
      icon: Icons.integration_instructions_outlined,
      defaultSize: const Size(1020, 680),
      minimumSize: const Size(600, 440),
      windowBuilder: (_) => const _PlaceholderApp(id: 'docker_manager'),
    ),
    AppRegistryEntry(
      id: 'firewall',
      nameKey: key('firewall'),
      icon: Icons.shield_outlined,
      defaultSize: const Size(820, 580),
      minimumSize: const Size(520, 400),
      windowBuilder: (_) => const _PlaceholderApp(id: 'firewall'),
    ),
    AppRegistryEntry(
      id: 'certificates',
      nameKey: key('certificates'),
      icon: Icons.verified_user_outlined,
      defaultSize: const Size(880, 580),
      minimumSize: const Size(560, 420),
      windowBuilder: (_) => const _PlaceholderApp(id: 'certificates'),
    ),
    AppRegistryEntry(
      id: 'web_servers',
      nameKey: key('web_servers'),
      icon: Icons.http_outlined,
      defaultSize: const Size(980, 640),
      minimumSize: const Size(560, 420),
      windowBuilder: (_) => const _PlaceholderApp(id: 'web_servers'),
    ),
    AppRegistryEntry(
      id: 'tunnels',
      nameKey: key('tunnels'),
      icon: Icons.tunnel_outlined,
      defaultSize: const Size(920, 620),
      minimumSize: const Size(560, 400),
      windowBuilder: (_) => const _PlaceholderApp(id: 'tunnels'),
    ),
    AppRegistryEntry(
      id: 'git_client',
      nameKey: key('git_client'),
      icon: Icons.source_outlined,
      defaultSize: const Size(980, 640),
      minimumSize: const Size(560, 400),
      windowBuilder: (_) => const _PlaceholderApp(id: 'git_client'),
    ),
    AppRegistryEntry(
      id: 'port_forwarding',
      nameKey: key('port_forwarding'),
      icon: Icons.alt_route_outlined,
      defaultSize: const Size(800, 560),
      minimumSize: const Size(480, 360),
      windowBuilder: (_) => const _PlaceholderApp(id: 'port_forwarding'),
    ),
    AppRegistryEntry(
      id: 'process_guardian',
      nameKey: key('process_guardian'),
      icon: Icons.health_and_safety_outlined,
      defaultSize: const Size(860, 580),
      minimumSize: const Size(560, 400),
      windowBuilder: (_) => const _PlaceholderApp(id: 'process_guardian'),
    ),
    AppRegistryEntry(
      id: 'app_installer',
      nameKey: key('app_installer'),
      icon: Icons.get_app_outlined,
      defaultSize: const Size(820, 580),
      minimumSize: const Size(520, 400),
      windowBuilder: (_) => const _PlaceholderApp(id: 'app_installer'),
    ),
  ];
}

/// A generic placeholder window body for apps not yet fully ported.
class _PlaceholderApp extends StatelessWidget {
  final String id;
  const _PlaceholderApp({required this.id});

  @override
  Widget build(BuildContext context) {
    final palette = ThemePaletteX(this).palette;
    final registry = ProviderScope.containerOf(this, listen: false).read(appRegistryProvider);
    final entry = registry.get(id);
    return Container(
      color: palette.appBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(entry?.icon ?? Icons.widgets_outlined, size: 72, color: palette.textTertiary),
            const SizedBox(height: 16),
            Text(
              (entry?.nameKey ?? 'app.$id').tr(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: palette.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Application UI is a work-in-progress port from Avalonia.',
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'App ID: $id',
              style: TextStyle(color: palette.textTertiary, fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
