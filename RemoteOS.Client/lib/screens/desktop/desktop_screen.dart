import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart' as desktop_wm;

import '../../core/theme/theme_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/apps/app_registry.dart';
import '../../core/window_manager/window_manager.dart';
import '../widgets/taskbar.dart';
import '../widgets/start_menu.dart';

class DesktopScreen extends ConsumerStatefulWidget {
  const DesktopScreen({super.key});

  @override
  ConsumerState<DesktopScreen> createState() => _DesktopScreenState();
}

class _DesktopScreenState extends ConsumerState<DesktopScreen> {
  bool _startMenuOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoOpenWelcome());
  }

  void _autoOpenWelcome() {
    final wm = ref.read(windowManagerProvider.notifier);
    final registry = ref.read(appRegistryProvider);
    final welcome = registry.get('welcome');
    if (welcome != null) {
      final screen = MediaQuery.of(context).size;
      wm.openApp(
        entry: welcome,
        child: welcome.windowBuilder(context),
        screenSize: screen,
      );
    }
  }

  void _toggleStartMenu() => setState(() => _startMenuOpen = !_startMenuOpen);
  void _closeStartMenu() => setState(() => _startMenuOpen = false);

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  Future<void> _shutdown() async {
    await _logout();
    await desktop_wm.windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
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
              child: Stack(
                children: [
                  _buildDesktopBackground(palette, constraints),
                  _buildDesktopIcons(context, workArea),
                  _buildWindowLayer(workArea),
                  if (_startMenuOpen) _buildStartMenuScrim(),
                  if (_startMenuOpen)
                    Positioned(
                      left: 8,
                      bottom: taskbarHeight + 8,
                      child: StartMenu(
                        onAppSelected: (entry) {
                          final wm = ref.read(windowManagerProvider.notifier);
                          wm.openApp(
                            entry: entry,
                            child: entry.windowBuilder(context),
                            screenSize: Size(constraints.maxWidth, workArea.height),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopBackground(ThemePalette palette, BoxConstraints constraints) {
    return Positioned.fill(
      child: DecoratedBox(
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
          final registry = ProviderScope.containerOf(context, listen: false).read(appRegistryProvider);
          final entry = registry.get(pair.$1);
          if (entry == null) return const SizedBox.shrink();
          return _DesktopIcon(
            entry: entry,
            palette: palette,
            onOpen: () {
              final wm = ref.read(windowManagerProvider.notifier);
              wm.openApp(
                entry: entry,
                child: entry.windowBuilder(context),
                screenSize: Size(workArea.width, workArea.height),
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
        child: Stack(
          children: sorted
              .map((w) => RemoteWindowChrome(window: w, workArea: workArea))
              .toList(),
        ),
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
          color: _selected ? widget.palette.desktopIconSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _selected ? widget.palette.accent.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(widget.entry.icon, size: 36, color: widget.palette.textPrimary),
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
