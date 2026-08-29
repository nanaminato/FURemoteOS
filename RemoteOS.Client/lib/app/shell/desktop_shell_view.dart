// Desktop shell view (ARCHITECTURE.md § 6).
//
// Responsibilities:
//   * Layout composition (background, icons, window layer, taskbar, start
//     menu).
//   * Ownership of focus nodes, scroll controllers, geometry.
//   * Forwarding user intents to [DesktopShellViewModel].
//   * Watching reactive state (overlay, theme, auth, window list) and
//     rebuilding only the affected subtrees.
//
// The view explicitly does NOT call HTTP, read repositories or write
// persistent settings — all of that lives in the VM layer / below.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart';
import 'package:window_manager/window_manager.dart' as desktop_wm;

import '../../../core/apps/app_registry.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/theme_service.dart';
import '../../../core/window_manager/context_menu_host.dart';
import '../../../core/window_manager/window_manager.dart';
import 'components/desktop_background.dart';
import 'components/desktop_icon.dart';
import 'components/desktop_start_menu.dart';
import 'components/desktop_taskbar.dart';
import 'components/desktop_window_layer.dart';
import 'desktop_shell_view_model.dart';

class DesktopShellView extends ConsumerStatefulWidget {
  const DesktopShellView({super.key});

  @override
  ConsumerState<DesktopShellView> createState() => _DesktopShellViewState();
}

class _DesktopShellViewState extends ConsumerState<DesktopShellView> {
  late final DesktopShellViewModel _vm;
  final _desktopMenu = RemoteContextMenuController();

  @override
  void initState() {
    super.initState();
    _vm = createDesktopShellViewModel(
      currentLocale: () => context.locale,
      setLocale: (locale) => context.setLocale(locale),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _vm.restoreDesktopCommand.run(RestoreDesktopRequest(
        screen: Size(size.width, size.height - 48),
        welcomeBuilder: (entry) => entry.windowBuilder(context),
      ));
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  // ---- Handlers -----------------------------------------------------------

  Future<void> _handleLogout() async {
    await _vm.logoutCommand.runAsync(null);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    context.go('/login');
  }

  Future<void> _handleShutdown() async {
    await _vm.shutdownCommand.runAsync(null);
    await desktop_wm.windowManager.close();
  }

  void _handleAppSelected(
      BuildContext context, Size workArea, AppRegistryEntry entry) {
    _vm.openAppCommand.run(OpenAppRequest(
      entry: entry,
      child: entry.windowBuilder(context),
      screenSize: workArea,
    ));
  }

  void _handleAppById(BuildContext context, Size workArea, String appId) {
    _vm.openAppByIdCommand.run(OpenAppByIdRequest(
      appId: appId,
      childBuilder: (entry) => entry.windowBuilder(context),
      screenSize: workArea,
    ));
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Session guard; kick unauthenticated users back to login.
    final authState = ref.watch(authProvider);
    if (!authState.isAuthenticated) {
      Future.microtask(() {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        context.go('/login');
      });
    }

    // Theme resolution.
    final palette = watchPalette(ref, context);
    final themeState = ref.watch(themeProvider);
    final brightness = themeState.resolveBrightness(context);
    final themeData = buildThemeData(palette, brightness);

    // Persist window layouts whenever the managed-window list changes.  Keep
    // the listener inside the View so the VM can be unit-tested without
    // riverpod directly.
    ref.listen<List<RemoteWindow>>(windowManagerProvider, (_, windows) {
      _vm.saveWindowLayouts(windows);
    });

    return Theme(
      data: themeData,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            const taskbarHeight = 48.0;
            final workArea = Rect.fromLTWH(
              0,
              0,
              constraints.maxWidth,
              constraints.maxHeight - taskbarHeight,
            );
            final workAreaSize = Size(workArea.width, workArea.height);
            return Container(
              color: palette.appBackground,
              child: ContextMenuHost(
                controller: _desktopMenu,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ContextMenuRegion(
                        controller: _desktopMenu,
                        entries: _menuEntries(context, workAreaSize),
                        child: DesktopBackground(palette: palette),
                      ),
                    ),
                    _IconsColumn(
                      palette: palette,
                      entries: _vm.desktopIcons,
                      onOpen: (entry) =>
                          _handleAppSelected(context, workAreaSize, entry),
                    ),
                    DesktopWindowLayer(workArea: workArea),
                    _DesktopOverlayObserver(
                      vm: _vm,
                      taskbarHeight: taskbarHeight,
                      onAppSelected: (entry) =>
                          _handleAppSelected(context, workAreaSize, entry),
                      onLogout: _handleLogout,
                      onShutdown: _handleShutdown,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: taskbarHeight,
                      child: DesktopTaskbar(
                        onStartPressed: _vm.toggleStartMenu,
                        onLogout: _handleLogout,
                        overlayNotifier: _vm.overlay,
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

  List<ContextMenuEntry> _menuEntries(BuildContext context, Size workArea) => [
        ContextMenuAction(
          label: 'Refresh',
          icon: Icons.refresh_rounded,
          onSelected: () => _vm.refreshCommand.run(null),
        ),
        const ContextMenuDivider(),
        ContextMenuAction(
          label: 'Task Manager',
          icon: Icons.monitor_heart_outlined,
          onSelected: () => _handleAppById(context, workArea, 'task_manager'),
        ),
        ContextMenuAction(
          label: 'Settings',
          icon: Icons.settings_outlined,
          onSelected: () => _handleAppById(context, workArea, 'settings'),
        ),
      ];
}

/// Local component: desktop icon column.
class _IconsColumn extends StatelessWidget {
  const _IconsColumn({
    required this.palette,
    required this.entries,
    required this.onOpen,
  });

  final ThemePalette palette;
  final List<AppRegistryEntry> entries;
  final void Function(AppRegistryEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      top: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in entries)
            DesktopIcon(
              entry: entry,
              palette: palette,
              onOpen: () => onOpen(entry),
            ),
        ],
      ),
    );
  }
}

/// Reactive composition: observes [DesktopShellViewModel.overlay] via
/// [watch_it] and mounts/unmounts the start menu region accordingly.
class _DesktopOverlayObserver extends WatchingWidget {
  const _DesktopOverlayObserver({
    required this.vm,
    required this.taskbarHeight,
    required this.onAppSelected,
    required this.onLogout,
    required this.onShutdown,
  });

  final DesktopShellViewModel vm;
  final double taskbarHeight;
  final ValueChanged<AppRegistryEntry> onAppSelected;
  final Future<void> Function() onLogout;
  final Future<void> Function() onShutdown;

  @override
  Widget build(BuildContext context) {
    final open = vm.overlay.value == DesktopOverlay.startMenu;
    if (!open) return const SizedBox.shrink();
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: vm.closeOverlay,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: 8,
          bottom: taskbarHeight + 8,
          child: DesktopStartMenu(
            onAppSelected: onAppSelected,
            onClose: vm.closeOverlay,
            onLogout: onLogout,
            onShutdown: onShutdown,
          ),
        ),
      ],
    );
  }
}
