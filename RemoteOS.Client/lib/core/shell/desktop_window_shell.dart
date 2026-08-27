import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadWindowState();
  }

  Future<void> _loadWindowState() async {
    final isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() => _isMaximized = isMaximized);
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

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? colorScheme.onSurface;

    return ColoredBox(
      color: colorScheme.surface,
      child: Column(
        children: [
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
                  tooltip: (_isMaximized ? 'common.restore' : 'common.maximize')
                      .tr(),
                  icon: _isMaximized
                      ? Icons.filter_none_rounded
                      : Icons.crop_square_rounded,
                  onPressed: _toggleMaximize,
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
