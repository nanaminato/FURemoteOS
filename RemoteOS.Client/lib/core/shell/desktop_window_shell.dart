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
  const DesktopWindowShell({super.key, required this.child});

  final Widget child;

  @override
  State<DesktopWindowShell> createState() => _DesktopWindowShellState();
}

class _DesktopWindowShellState extends State<DesktopWindowShell>
    with WindowListener {
  static const _titleBarHeight = 36.0;

  bool _isMaximized = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadWindowState();
  }

  Future<void> _loadWindowState() async {
    final windowState = await Future.wait([
      windowManager.isMaximized(),
      windowManager.isFullScreen(),
    ]);
    if (mounted) {
      setState(() {
        _isMaximized = windowState[0];
        _isFullScreen = windowState[1];
      });
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullScreen = false);
  }

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> _toggleFullScreen() =>
      windowManager.setFullScreen(!_isFullScreen);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? colorScheme.onSurface;

    // MaterialApp.builder is above the Navigator's Overlay.  The custom
    // title-bar controls are siblings of that Navigator, so they need their
    // own Overlay for Tooltip (and future popup) support.
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => Focus(
            autofocus: true,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.f11):
                    _toggleFullScreen,
                if (_isFullScreen)
                  const SingleActivator(LogicalKeyboardKey.escape):
                      _toggleFullScreen,
              },
              // The shell is outside Navigator/Scaffold, so it must supply
              // its own Material for the title-bar InkWell controls.
              child: Material(
                color: colorScheme.surface,
                child: Column(
                  children: [
                    if (!_isFullScreen)
                      SizedBox(
                        height: _titleBarHeight,
                        child: Row(
                          children: [
                            Expanded(
                              child: DragToMoveArea(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onDoubleTap: _toggleMaximize,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
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
                              tooltip: (_isMaximized
                                      ? 'common.restore'
                                      : 'common.maximize')
                                  .tr(),
                              icon: _isMaximized
                                  ? Icons.filter_none_rounded
                                  : Icons.crop_square_rounded,
                              onPressed: _toggleMaximize,
                            ),
                            _WindowControlButton(
                              tooltip: _isFullScreen
                                  ? 'shell.full_screen.exit'.tr()
                                  : 'shell.full_screen.enter_tooltip'.tr(),
                              icon: _isFullScreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              onPressed: _toggleFullScreen,
                            ),
                            _WindowControlButton(
                              tooltip: 'common.close'.tr(),
                              icon: Icons.close_rounded,
                              isCloseButton: true,
                              onPressed: windowManager.close,
                            ),
                          ],
                        ),
                      ),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
