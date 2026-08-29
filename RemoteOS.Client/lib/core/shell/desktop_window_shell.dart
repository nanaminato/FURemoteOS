import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// The custom chrome for the desktop application's top-level window.
///
/// The native title bar is hidden so that the RemoteOS UI has a consistent
/// appearance across supported desktop platforms. `DragToMoveArea` delegates
/// moving the window back to the platform, while the OS retains ownership of
/// the resize border and its minimum-size constraints.
class DesktopWindowShell extends StatefulWidget {
  const DesktopWindowShell({
    super.key,
    required this.child,
    this.onCloseRequested,
  });

  final Widget child;
  final Future<void> Function()? onCloseRequested;

  @override
  State<DesktopWindowShell> createState() => _DesktopWindowShellState();
}

class _DesktopWindowShellState extends State<DesktopWindowShell>
    with WindowListener {
  static const _titleBarHeight = 36.0;

  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool _isTogglingFullScreen = false;
  int _windowStateRequest = 0;
  late final OverlayEntry _titleBarEntry;

  @override
  void initState() {
    super.initState();
    _titleBarEntry = OverlayEntry(builder: _buildTitleBar);
    windowManager.addListener(this);
    _refreshWindowState();
  }

  /// Reads platform state instead of trusting window listener ordering. In
  /// particular, some platforms emit maximize/unmaximize events around a
  /// fullscreen transition in an order that does not reflect the final state.
  Future<void> _refreshWindowState() async {
    final request = ++_windowStateRequest;
    final windowState = await Future.wait([
      windowManager.isMaximized(),
      windowManager.isFullScreen(),
    ]);
    if (mounted && request == _windowStateRequest) {
      setState(() {
        _isMaximized = windowState[0];
        _isFullScreen = windowState[1];
      });
      _titleBarEntry.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    unawaited(_refreshWindowState());
  }

  @override
  void onWindowUnmaximize() {
    unawaited(_refreshWindowState());
  }

  @override
  void onWindowEnterFullScreen() {
    unawaited(_refreshWindowState());
  }

  @override
  void onWindowLeaveFullScreen() {
    unawaited(_refreshWindowState());
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _refreshWindowState();
  }

  Future<void> _toggleFullScreen() async {
    if (_isTogglingFullScreen) return;

    setState(() => _isTogglingFullScreen = true);
    try {
      // Do not rely only on the native enter/leave callbacks here.  On
      // Windows they are not consistently delivered after leaving fullscreen,
      // which left the Flutter title bar permanently hidden.
      final enteringFullScreen = !await windowManager.isFullScreen();
      await windowManager.setFullScreen(enteringFullScreen);
      await _refreshWindowState();
    } finally {
      if (mounted) setState(() => _isTogglingFullScreen = false);
    }
  }

  @override
  Widget _buildTitleBar(BuildContext context) {
    if (_isFullScreen) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? colorScheme.onSurface;

    return SizedBox(
      height: _titleBarHeight,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _toggleMaximize,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.desktop_windows_rounded,
                        size: 17,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RemoteOS',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _WindowControlButton(
            tooltip: 'common.minimize'.tr(),
            icon: Icons.remove_rounded,
            onPressed: windowManager.minimize,
          ),
          _WindowControlButton(
            tooltip: (_isMaximized ? 'common.restore' : 'common.maximize').tr(),
            icon: _isMaximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            onPressed: _toggleMaximize,
          ),
          _WindowControlButton(
            tooltip: 'shell.full_screen.enter_tooltip'.tr(),
            icon: Icons.fullscreen_rounded,
            onPressed: _toggleFullScreen,
          ),
          _WindowControlButton(
            tooltip: 'common.close'.tr(),
            icon: Icons.close_rounded,
            isCloseButton: true,
            onPressed: widget.onCloseRequested ?? windowManager.close,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox.expand(
      child: Focus(
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f11): _toggleFullScreen,
            if (_isFullScreen)
              const SingleActivator(LogicalKeyboardKey.escape):
                  _toggleFullScreen,
          },
          child: Material(
            color: colorScheme.surface,
            child: Column(
              children: [
                SizedBox(
                  height: _isFullScreen ? 0 : _titleBarHeight,
                  child: Overlay(initialEntries: [_titleBarEntry]),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatelessWidget {
  const _WindowControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isCloseButton = false,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool isCloseButton;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        Theme.of(context).iconTheme.color ?? colorScheme.onSurface;

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onPressed,
        hoverColor: isCloseButton
            ? Colors.red.shade700
            : colorScheme.primary.withValues(alpha: 0.12),
        child: SizedBox(
          width: 46,
          height: _DesktopWindowShellState._titleBarHeight,
          child: Icon(icon, size: 18, color: foreground),
        ),
      ),
    );
  }
}
