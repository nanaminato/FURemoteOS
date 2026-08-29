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

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart' hide di;
import 'package:window_manager/window_manager.dart' as desktop_wm;

import '../../../app/dependency_injection.dart';
import '../../../core/apps/app_registry.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/runtime/desktop_runtime.dart';
import '../../../core/theme/theme_service.dart';
import '../../../core/window_manager/context_menu_host.dart';
import '../../../core/window_manager/window_manager.dart';
import '../../../features/workspace/application/workspace_sync_coordinator.dart';
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
  Size _desktopSize = Size.zero;
  BoxConstraints? _lastReportedEmptyConstraints;

  @override
  void initState() {
    super.initState();
    _vm = createDesktopShellViewModel(
      currentLocale: () => context.locale,
      setLocale: (locale) => context.setLocale(locale),
    );
    final log = _optionalRuntimeLog();
    unawaited(log?.info('[desktop] initState mounted=$mounted'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
          log?.info('[desktop] first post-frame callback, awaiting size'));
      _restoreWhenSized();
    });
  }

  RuntimeLog? _optionalRuntimeLog() {
    try {
      return di.isRegistered<RuntimeLog>() ? di<RuntimeLog>() : null;
    } catch (_) {
      return null;
    }
  }

  /// Captures the complete ancestor layout chain in one log record when the
  /// desktop receives an invalid viewport. This avoids requiring a separate
  /// DevTools screenshot for every parent of the collapsed desktop container.
  void _reportEmptyLayoutChain(
      BuildContext context, BoxConstraints constraints) {
    if (!kDebugMode ||
        (constraints.maxWidth > 0 && constraints.maxHeight > 0) ||
        _lastReportedEmptyConstraints == constraints) {
      return;
    }
    _lastReportedEmptyConstraints = constraints;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lines = <String>[
        '[desktop-layout] invalid LayoutBuilder constraints: $constraints',
      ];
      context.visitAncestorElements((element) {
        final renderObject = element.renderObject;
        if (renderObject is RenderBox) {
          lines.add(
            '  ${element.widget.runtimeType} '
            'render=${renderObject.runtimeType} '
            'size=${renderObject.size} '
            'constraints=${renderObject.constraints}',
          );
        } else {
          lines.add(
            '  ${element.widget.runtimeType} '
            'render=${renderObject?.runtimeType ?? '<none>'}',
          );
        }
        return true;
      });
      unawaited(_optionalRuntimeLog()?.info(lines.join('\n')));
    });
  }

  /// Waits for the actual desktop layout to reach a non-trivial size before
  /// asking the VM to restore the welcome app and window layouts.  The outer
  /// MediaQuery includes [DesktopWindowShell]'s title bar; using it here would
  /// center managed windows against a taller area than their Stack can render.
  Future<void> _restoreWhenSized() async {
    const taskbarHeight = 48.0;
    final log = _optionalRuntimeLog();
    var size = Size.zero;
    int attempts = 0;
    while (mounted) {
      size = _desktopSize;
      if (size.width >= 320 && size.height >= taskbarHeight + 240) break;
      attempts += 1;
      if (attempts >= 50) {
        // Give up: use the shipped minimum host size as a safe default so the
        // user still sees the desktop even if the OS window reports garbage.
        unawaited(log?.info(
          '[desktop] viewport size stalled at ${size.width.toStringAsFixed(1)}x'
          '${size.height.toStringAsFixed(1)} after ${attempts} polls; '
          'falling back to default 1280x764',
        ));
        size = const Size(1280, 764);
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (!mounted) break;
    }
    if (!mounted) {
      unawaited(log?.info(
          '[desktop] viewport ready but widget unmounted; aborting restore'));
      return;
    }
    final workArea =
        Size(size.width, (size.height - taskbarHeight).clamp(240.0, 4320.0));
    unawaited(log?.info(
      '[desktop] viewport ready viewport=${size.width.toStringAsFixed(1)}x'
      '${size.height.toStringAsFixed(1)} workArea=${workArea.width.toStringAsFixed(1)}x'
      '${workArea.height.toStringAsFixed(1)} attempts=$attempts; '
      'invoking restoreDesktopCommand',
    ));
    try {
      _vm.restoreDesktopCommand.run(RestoreDesktopRequest(
        screen: workArea,
        welcomeBuilder: (entry) => entry.windowBuilder(context),
      ));
      unawaited(
          log?.info('[desktop] restoreDesktopCommand finished synchronously'));
    } catch (error, stack) {
      unawaited(log?.error(error, stack));
      rethrow;
    }
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

    final log = _optionalRuntimeLog();
    unawaited(log?.info(
      '[desktop] build; authState=${authState.state} '
      'authenticated=${authState.isAuthenticated} '
      'theme=${themeState.kind} brightness=$brightness',
    ));

    return Theme(
      data: themeData,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            const taskbarHeight = 48.0;
            _reportEmptyLayoutChain(context, constraints);
            // LayoutBuilder receives the area below DesktopWindowShell's
            // custom title bar, unlike the root MediaQuery size.
            _desktopSize = constraints.biggest;
            final workArea = Rect.fromLTWH(
              0,
              0,
              constraints.maxWidth,
              constraints.maxHeight - taskbarHeight,
            );
            final workAreaSize = Size(workArea.width, workArea.height);
            // [Container] forwards Scaffold's loose body constraints to its
            // child. Every direct child of this Stack is Positioned, so a
            // loose Stack would correctly choose its smallest size (0×0).
            // Consume the LayoutBuilder viewport before entering that stack.
            return SizedBox.expand(
              child: Container(
                color: palette.appBackground,
                child: ContextMenuHost(
                  controller: _desktopMenu,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ContextMenuRegion(
                          controller: _desktopMenu,
                          entries: _menuEntries(context, workAreaSize),
                          child: DesktopBackground(
                            palette: palette,
                            wallpaperKey: ref
                                .watch(workspaceSyncProvider)
                                .preferences
                                ?.wallpaperKey,
                            serverUrl: authState.serverUrl,
                            workspaceId: authState.workspaceId,
                            accessToken: authState.accessToken,
                          ),
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
