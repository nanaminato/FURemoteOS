import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart' as desktop_wm;

import '../../core/theme/theme_service.dart';
import '../../core/localization/language_catalog.dart';
import '../../core/auth/auth_service.dart';
import '../../core/apps/app_registry.dart';
import '../../core/window_manager/window_manager.dart';
import '../../core/window_manager/context_menu_host.dart';
import '../../apps/terminal/terminal_app.dart';
import '../../features/terminal/application/terminal_session_discovery.dart';
import '../../features/workspace/application/workspace_sync_coordinator.dart';
import '../../features/workspace/domain/workspace_models.dart';
import '../widgets/taskbar.dart';
import '../widgets/start_menu.dart';

class DesktopScreen extends ConsumerStatefulWidget {
  const DesktopScreen({super.key});

  @override
  ConsumerState<DesktopScreen> createState() => _DesktopScreenState();
}

class _DesktopScreenState extends ConsumerState<DesktopScreen> {
  bool _startMenuOpen = false;
  final _desktopMenu = RemoteContextMenuController();
  String? _lastQueuedLayoutFingerprint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreDesktop();
    });
  }

  void _autoOpenWelcome() {
    final wm = ref.read(windowManagerProvider.notifier);
    final registry = ref.read(appRegistryProvider);
    final welcome = registry.get('welcome');
    if (welcome != null) {
      final screen = MediaQuery.of(context).size;
      _openManagedApp(welcome, welcome.windowBuilder(context), screen);
    }
  }

  /// Runs once after the managed window host is ready. Loading layouts before
  /// opening the first application prevents its default size from replacing a
  /// restored workspace size.
  Future<void> _restoreDesktop() async {
    await ref.read(workspaceSyncProvider.notifier).load();
    if (!mounted) return;
    final preferences = ref.read(workspaceSyncProvider).preferences;
    if (preferences != null) {
      ref.read(themeProvider.notifier)
        ..setThemeKind(preferences.theme)
        ..setPreferences(preferences.themePreferences);
      final language = ref
          .read(languageCatalogProvider)
          .languages
          .where((option) => option.localeTag == preferences.language);
      if (language.isNotEmpty) await context.setLocale(language.first.locale);
    }
    if (!mounted) return;
    // Restore terminal sessions before opening the Welcome window so the user
    // lands on a desktop whose previously-running terminals are already
    // reattached (PTY lifecycle is server-side; we just reattach).
    await _restoreTerminalSessions();
    if (!mounted) return;
    _autoOpenWelcome();
  }

  /// Discovers the user's still-running terminal sessions on the server and
  /// reopens one managed [TerminalApp] window per session, each wired to its
  /// original `sessionId` so the SignalR `Start` handshake resumes the PTY
  /// buffer instead of spawning a new shell. Matches the Avalonia lifecycle
  /// where closing a terminal window only detaches from the PTY.
  Future<void> _restoreTerminalSessions() async {
    final auth = ref.read(authProvider);
    final sessions =
        await ref.read(terminalSessionDiscoveryProvider).discover(auth);
    if (!mounted || sessions.isEmpty) return;
    final entry = ref.read(appRegistryProvider).get('terminal');
    if (entry == null) return;
    final screen = MediaQuery.of(context).size;
    // Cascade opened windows so they don't all stack on the desktop centre.
    const step = 32.0;
    var index = 0;
    for (final session in sessions) {
      final offset = step * index;
      ref.read(windowManagerProvider.notifier).openApp(
            entry: entry,
            child: TerminalApp(sessionId: session.sessionId),
            initialBounds: Rect.fromLTWH(
              ((screen.width - entry.defaultSize.width) / 2 + offset)
                  .clamp(0.0, screen.width - entry.defaultSize.width),
              ((screen.height - entry.defaultSize.height) / 2 - 20 + offset)
                  .clamp(0.0, screen.height - entry.defaultSize.height),
              entry.defaultSize.width,
              entry.defaultSize.height,
            ),
            screenSize: screen,
          );
      index++;
    }
  }

  void _toggleStartMenu() => setState(() => _startMenuOpen = !_startMenuOpen);
  void _closeStartMenu() => setState(() => _startMenuOpen = false);

  Future<void> _logout() async {
    await ref.read(workspaceSyncProvider.notifier).flush();
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  Future<void> _shutdown() async {
    await _logout();
    await desktop_wm.windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<RemoteWindow>>(windowManagerProvider, (_, windows) {
      _saveWindowLayouts(windows);
    });
    final authState = ref.watch(authProvider);
    if (!authState.isAuthenticated) {
      // Kick unauthenticated users back to login.
      Future.microtask(() => context.go('/login'));
    }

    final palette = watchPalette(ref, context);
    final themeState = ref.watch(themeProvider);
    final brightness = themeState.resolveBrightness(context);
    final themeData = buildThemeData(palette, brightness);

    return Theme(
      data: themeData,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final taskbarHeight = 48.0;
            final workArea = Rect.fromLTWH(
              0,
              0,
              constraints.maxWidth,
              constraints.maxHeight - taskbarHeight,
            );
            return Container(
              color: palette.appBackground,
              child: ContextMenuHost(
                controller: _desktopMenu,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ContextMenuRegion(
                        controller: _desktopMenu,
                        entries: _desktopMenuEntries(
                          context,
                          Size(constraints.maxWidth, workArea.height),
                        ),
                        child: _buildDesktopBackground(palette, constraints),
                      ),
                    ),
                    _buildDesktopIcons(context, workArea),
                    _buildWindowLayer(workArea),
                    if (_startMenuOpen) _buildStartMenuScrim(),
                    if (_startMenuOpen)
                      Positioned(
                        left: 8,
                        bottom: taskbarHeight + 8,
                        child: StartMenu(
                          onAppSelected: (entry) {
                            _openManagedApp(
                              entry,
                              entry.windowBuilder(context),
                              Size(constraints.maxWidth, workArea.height),
                            );
                            _closeStartMenu();
                          },
                          onClose: _closeStartMenu,
                          onLogout: _logout,
                          onShutdown: _shutdown,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: taskbarHeight,
                      child: Taskbar(
                        onStartPressed: _toggleStartMenu,
                        isStartOpen: _startMenuOpen,
                        onLogout: _logout,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<ContextMenuEntry> _desktopMenuEntries(
    BuildContext context,
    Size screenSize,
  ) =>
      [
        ContextMenuAction(
          label: 'Refresh',
          icon: Icons.refresh_rounded,
          onSelected: () => setState(() {}),
        ),
        const ContextMenuDivider(),
        ContextMenuAction(
          label: 'Task Manager',
          icon: Icons.monitor_heart_outlined,
          onSelected: () =>
              _openDesktopApp(context, 'task_manager', screenSize),
        ),
        ContextMenuAction(
          label: 'Settings',
          icon: Icons.settings_outlined,
          onSelected: () => _openDesktopApp(context, 'settings', screenSize),
        ),
      ];

  void _openDesktopApp(BuildContext context, String appId, Size screenSize) {
    final entry = ref.read(appRegistryProvider).get(appId);
    if (entry == null) return;
    _openManagedApp(entry, entry.windowBuilder(context), screenSize);
  }

  void _openManagedApp(AppRegistryEntry entry, Widget child, Size screenSize) {
    final layout = ref
        .read(workspaceSyncProvider)
        .layouts
        .windows
        .where((item) => item.key == entry.id);
    final size =
        layout.isEmpty ? null : Size(layout.first.width, layout.first.height);
    ref.read(windowManagerProvider.notifier).openApp(
          entry: entry,
          child: child,
          initialSize: size,
          screenSize: screenSize,
        );
  }

  void _saveWindowLayouts(List<RemoteWindow> windows) {
    final sizes = <String, WorkspaceWindowSize>{};
    for (final window in windows.where((item) => !item.isModal)) {
      final bounds = window.restoreBounds ?? window.bounds;
      sizes[window.appId] = WorkspaceWindowSize(
        key: window.appId,
        width: bounds.width.clamp(240, 3840).toDouble(),
        height: bounds.height.clamp(160, 2160).toDouble(),
      );
    }
    if (sizes.isNotEmpty) {
      final layouts = WorkspaceWindowLayouts(windows: sizes.values.toList());
      final fingerprint = layouts.windows
          .map((item) => '${item.key}:${item.width}:${item.height}')
          .join('|');
      if (fingerprint == _lastQueuedLayoutFingerprint) return;
      _lastQueuedLayoutFingerprint = fingerprint;
      ref.read(workspaceSyncProvider.notifier).queueLayouts(layouts);
    }
  }

  Widget _buildDesktopBackground(
      ThemePalette palette, BoxConstraints constraints) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.appBackground,
            palette.shellBackground,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _DesktopPatternPainter(palette),
      ),
    );
  }

  Widget _buildDesktopIcons(BuildContext context, Rect workArea) {
    final palette = context.palette;
    final apps = [
      ('explorer', 'This PC'),
      ('browser', 'Browser'),
      ('settings', 'Settings'),
      ('terminal', 'Terminal'),
    ];
    return Positioned(
      left: 12,
      top: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: apps.map((pair) {
          final registry = ProviderScope.containerOf(context, listen: false)
              .read(appRegistryProvider);
          final entry = registry.get(pair.$1);
          if (entry == null) return const SizedBox.shrink();
          return _DesktopIcon(
            entry: entry,
            palette: palette,
            onOpen: () {
              _openManagedApp(
                entry,
                entry.windowBuilder(context),
                Size(workArea.width, workArea.height),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWindowLayer(Rect workArea) {
    final windows = ref.watch(windowManagerProvider);
    final sorted = List<RemoteWindow>.from(windows)
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    return Positioned.fromRect(
      rect: workArea,
      child: ClipRect(
        child: Stack(children: [
          for (final window in sorted) ...[
            if (window.isModal)
              _ModalBlocker(
                  dialogId: window.id,
                  owner: sorted
                          .where((item) => item.id == window.modalOwnerId)
                          .isEmpty
                      ? null
                      : sorted.firstWhere(
                          (item) => item.id == window.modalOwnerId)),
            RemoteWindowChrome(
              key: ValueKey('remote-window-${window.id}'),
              window: window,
              workArea: workArea,
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildStartMenuScrim() => Positioned.fill(
        child: GestureDetector(
          onTap: _closeStartMenu,
          behavior: HitTestBehavior.translucent,
          child: const SizedBox.expand(),
        ),
      );
}

/// Input shield for a modal owner. It is placed immediately below its dialog,
/// leaving other top-level windows usable just like the original desktop.
class _ModalBlocker extends ConsumerWidget {
  const _ModalBlocker({required this.owner, required this.dialogId});
  final RemoteWindow? owner;
  final String dialogId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (owner == null) return const SizedBox.shrink();
    return Positioned.fromRect(
      rect: owner!.bounds,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(windowManagerProvider.notifier).focus(dialogId),
        child: ColoredBox(color: Colors.black.withOpacity(0.16)),
      ),
    );
  }
}

class _DesktopPatternPainter extends CustomPainter {
  final ThemePalette palette;
  _DesktopPatternPainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle dot pattern.
    final paint = Paint()
      ..color = palette.accent.withOpacity(0.035)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DesktopPatternPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

class _DesktopIcon extends StatefulWidget {
  final AppRegistryEntry entry;
  final ThemePalette palette;
  final VoidCallback onOpen;

  const _DesktopIcon({
    required this.entry,
    required this.palette,
    required this.onOpen,
  });

  @override
  State<_DesktopIcon> createState() => _DesktopIconState();
}

class _DesktopIconState extends State<_DesktopIcon> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _selected = true),
      onDoubleTap: widget.onOpen,
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: _selected
              ? widget.palette.desktopIconSelected
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _selected
                ? widget.palette.accent.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(widget.entry.icon,
                  size: 36, color: widget.palette.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              widget.entry.nameKey.tr(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.palette.textPrimary,
                fontSize: 11,
                height: 1.2,
                shadows: [
                  Shadow(
                    color: widget.palette.shellBackground.withOpacity(0.9),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
