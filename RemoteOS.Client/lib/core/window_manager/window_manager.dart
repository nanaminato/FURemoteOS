import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';
import '../apps/app_registry.dart';
import '../../core/theme/theme_service.dart';

/// Window state constants.
enum RemoteWindowState { normal, minimized, maximized }

/// Data for a single managed window.
class RemoteWindow {
  final String id;
  final String appId;
  final String title;
  final Widget child;
  final IconData icon;

  Rect bounds;
  final Size minimumSize;
  RemoteWindowState state;
  int zOrder;

  RemoteWindow({
    required this.id,
    required this.appId,
    required this.title,
    required this.child,
    required this.icon,
    required this.bounds,
    this.minimumSize = const Size(320, 240),
    this.state = RemoteWindowState.normal,
    this.zOrder = 0,
  });
}

/// State notifier for the window manager.
class WindowManagerNotifier extends StateNotifier<List<RemoteWindow>> {
  WindowManagerNotifier() : super([]);

  int _zCounter = 0;
  Rect? _restoreBounds;

  /// Open a new window from an app registry entry.
  RemoteWindow openApp({
    required AppRegistryEntry entry,
    required Widget child,
    String? title,
    Rect? initialBounds,
    Size? screenSize,
  }) {
    if (!entry.allowMultipleInstances) {
      final existing = state.where((w) => w.appId == entry.id).toList();
      if (existing.isNotEmpty) {
        focus(existing.first.id);
        if (existing.first.state == RemoteWindowState.minimized) {
          restore(existing.first.id);
        }
        return existing.first;
      }
    }
    final id = const Uuid().v4();
    final defaultRect = initialBounds ??
        _centerRect(entry.defaultSize, screenSize ?? const Size(1280, 720));
    final window = RemoteWindow(
      id: id,
      appId: entry.id,
      title: title ?? entry.nameKey.tr(),
      child: child,
      icon: entry.icon,
      bounds: defaultRect,
      minimumSize: entry.minimumSize,
      state: RemoteWindowState.normal,
      zOrder: _zCounter++,
    );
    state = [...state, window];
    return window;
  }

  Rect _centerRect(Size size, Size screen) {
    final left = (screen.width - size.width) / 2;
    final top = (screen.height - size.height) / 2 - 20;
    return Rect.fromLTWH(left, top, size.width, size.height);
  }

  /// Focus (raise to top) a window.
  void focus(String windowId) {
    state = [
      for (final w in state)
        if (w.id == windowId) w..zOrder = _zCounter++ else w,
    ];
  }

  /// Close a window.
  void close(String windowId) {
    state = state.where((w) => w.id != windowId).toList();
  }

  /// Minimize a window.
  void minimize(String windowId) {
    state = [
      for (final w in state)
        if (w.id == windowId) w..state = RemoteWindowState.minimized else w,
    ];
  }

  /// Restore a minimized window.
  void restore(String windowId) {
    state = [
      for (final w in state)
        if (w.id == windowId)
          w
            ..state = RemoteWindowState.normal
            ..zOrder = _zCounter++
        else
          w,
    ];
  }

  /// Toggle maximize / restore.
  void toggleMaximize(String windowId, Rect? screenWorkArea) {
    state = [
      for (final w in state)
        if (w.id == windowId)
          if (w.state == RemoteWindowState.maximized)
            w
              ..state = RemoteWindowState.normal
              ..bounds = _restoreBounds ?? w.bounds
              ..zOrder = _zCounter++
          else
            _maximize(w, screenWorkArea)
        else
          w,
    ];
  }

  RemoteWindow _maximize(RemoteWindow window, Rect? screenWorkArea) {
    _restoreBounds = window.bounds;
    return window
      ..state = RemoteWindowState.maximized
      ..bounds = screenWorkArea ?? window.bounds
      ..zOrder = _zCounter++;
  }

  /// Move a window to a new position.
  void move(
    String windowId,
    Offset delta,
    Rect constraints, {
    Rect? startBounds,
  }) {
    state = [
      for (final w in state)
        if (w.id == windowId)
          () {
            final bounds = startBounds ?? w.bounds;
            return w
              ..bounds = Rect.fromPoints(
                Offset(
                  (bounds.left + delta.dx)
                      .clamp(0.0, constraints.width - bounds.width),
                  (bounds.top + delta.dy)
                      .clamp(0.0, constraints.height - bounds.height),
                ),
                Offset(
                  (bounds.right + delta.dx)
                      .clamp(w.minimumSize.width, constraints.width),
                  (bounds.bottom + delta.dy)
                      .clamp(w.minimumSize.height, constraints.height),
                ),
              );
          }()
        else
          w,
    ];
  }

  /// Resize a window from an edge.
  void resize(
    String windowId,
    String edge,
    Offset delta,
    Rect constraints, {
    Rect? startBounds,
  }) {
    state = [
      for (final w in state)
        if (w.id == windowId)
          w
            ..bounds = _applyResize(
              startBounds ?? w.bounds,
              w.minimumSize,
              edge,
              delta,
              constraints,
            )
        else
          w,
    ];
  }

  static Rect _applyResize(
    Rect rect,
    Size minSize,
    String edge,
    Offset delta,
    Rect constraints,
  ) {
    double left = rect.left,
        top = rect.top,
        right = rect.right,
        bottom = rect.bottom;
    switch (edge) {
      case 'left':
        left = (left + delta.dx).clamp(0.0, right - minSize.width);
        break;
      case 'right':
        right =
            (right + delta.dx).clamp(left + minSize.width, constraints.width);
        break;
      case 'top':
        top = (top + delta.dy).clamp(0.0, bottom - minSize.height);
        break;
      case 'bottom':
        bottom =
            (bottom + delta.dy).clamp(top + minSize.height, constraints.height);
        break;
      case 'topLeft':
        left = (left + delta.dx).clamp(0.0, right - minSize.width);
        top = (top + delta.dy).clamp(0.0, bottom - minSize.height);
        break;
      case 'topRight':
        right =
            (right + delta.dx).clamp(left + minSize.width, constraints.width);
        top = (top + delta.dy).clamp(0.0, bottom - minSize.height);
        break;
      case 'bottomLeft':
        left = (left + delta.dx).clamp(0.0, right - minSize.width);
        bottom =
            (bottom + delta.dy).clamp(top + minSize.height, constraints.height);
        break;
      case 'bottomRight':
        right =
            (right + delta.dx).clamp(left + minSize.width, constraints.width);
        bottom =
            (bottom + delta.dy).clamp(top + minSize.height, constraints.height);
        break;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// Riverpod provider.
final windowManagerProvider =
    StateNotifierProvider<WindowManagerNotifier, List<RemoteWindow>>(
        (ref) => WindowManagerNotifier());

/// Draggable, resizable window chrome.
class RemoteWindowChrome extends ConsumerStatefulWidget {
  final RemoteWindow window;
  final Rect workArea;

  const RemoteWindowChrome({
    super.key,
    required this.window,
    required this.workArea,
  });

  @override
  ConsumerState<RemoteWindowChrome> createState() => _RemoteWindowChromeState();
}

class _RemoteWindowChromeState extends ConsumerState<RemoteWindowChrome> {
  Offset _dragStart = Offset.zero;
  Rect _startBounds = Rect.zero;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final wm = ref.read(windowManagerProvider.notifier);
    final win = widget.window;

    final isMaximized = win.state == RemoteWindowState.maximized;
    final isMinimized = win.state == RemoteWindowState.minimized;
    if (isMinimized) return const SizedBox.shrink();

    return Positioned.fromRect(
      rect: win.bounds,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        child: GestureDetector(
          onTap: () => wm.focus(win.id),
          // Bounds are updated for every drag/resize pointer event.  An
          // AnimatedContainer restarts its animation on each update, which is
          // especially noticeable as flickering on Linux desktop compositors.
          child: Container(
            decoration: BoxDecoration(
              color: palette.windowFrameBackground,
              borderRadius: BorderRadius.circular(isMaximized ? 0 : 8),
              border: Border.all(color: palette.borderDefault, width: 1),
              boxShadow: [
                BoxShadow(
                  color: palette.flyoutShadow,
                  blurRadius: isMaximized ? 0 : 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  children: [
                    _buildTitleBar(palette, wm, win, isMaximized),
                    Divider(
                      height: 1,
                      color: palette.borderSubtle,
                      thickness: 1,
                    ),
                    Expanded(child: win.child),
                  ],
                ),
                if (!isMaximized) _buildResizeHandles(palette, wm, win),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(
    ThemePalette palette,
    WindowManagerNotifier wm,
    RemoteWindow win,
    bool isMaximized,
  ) {
    return GestureDetector(
      onPanStart: (details) {
        _dragStart = details.globalPosition;
        _startBounds = win.bounds;
      },
      onPanUpdate: (details) {
        if (isMaximized) return;
        final delta = details.globalPosition - _dragStart;
        wm.move(
          win.id,
          delta,
          widget.workArea,
          startBounds: _startBounds,
        );
      },
      onDoubleTap: () => wm.toggleMaximize(win.id, widget.workArea),
      child: Container(
        height: 36,
        color: palette.windowTitleBarBackground,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(win.icon, size: 16, color: palette.windowTitleForeground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                win.title,
                style: TextStyle(
                  color: palette.windowTitleForeground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            _WindowButton(
              icon: Icons.remove_rounded,
              palette: palette,
              hoverColor: palette.surfaceHover,
              onPressed: () => wm.minimize(win.id),
              tooltip: 'common.minimize'.tr(),
            ),
            _WindowButton(
              icon: isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              palette: palette,
              hoverColor: palette.surfaceHover,
              onPressed: () => wm.toggleMaximize(win.id, widget.workArea),
              tooltip:
                  isMaximized ? 'common.restore'.tr() : 'common.maximize'.tr(),
            ),
            _WindowButton(
              icon: Icons.close_rounded,
              palette: palette,
              hoverColor: palette.danger,
              hoverForeground: palette.textOnDanger,
              onPressed: () => wm.close(win.id),
              tooltip: 'common.close'.tr(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeHandles(
    ThemePalette palette,
    WindowManagerNotifier wm,
    RemoteWindow win,
  ) {
    const size = 8.0;
    Widget handle({
      required String edge,
      required MouseCursor cursor,
      double? left,
      double? top,
      double? right,
      double? bottom,
      double? width,
      double? height,
    }) =>
        Positioned(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          width: width,
          height: height,
          child: MouseRegion(
            cursor: cursor,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                _dragStart = details.globalPosition;
                _startBounds = win.bounds;
              },
              onPanUpdate: (details) {
                final delta = details.globalPosition - _dragStart;
                wm.resize(
                  win.id,
                  edge,
                  delta,
                  widget.workArea,
                  startBounds: _startBounds,
                );
              },
              child: const SizedBox.expand(),
            ),
          ),
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        handle(
          edge: 'top',
          cursor: SystemMouseCursors.resizeUpDown,
          left: size,
          right: size,
          top: 0,
          height: size,
        ),
        handle(
          edge: 'bottom',
          cursor: SystemMouseCursors.resizeUpDown,
          left: size,
          right: size,
          bottom: 0,
          height: size,
        ),
        handle(
          edge: 'left',
          cursor: SystemMouseCursors.resizeLeftRight,
          left: 0,
          top: size,
          bottom: size,
          width: size,
        ),
        handle(
          edge: 'right',
          cursor: SystemMouseCursors.resizeLeftRight,
          right: 0,
          top: size,
          bottom: size,
          width: size,
        ),
        handle(
          edge: 'topLeft',
          cursor: SystemMouseCursors.resizeUpLeftDownRight,
          left: 0,
          top: 0,
          width: size,
          height: size,
        ),
        handle(
          edge: 'topRight',
          cursor: SystemMouseCursors.resizeUpRightDownLeft,
          right: 0,
          top: 0,
          width: size,
          height: size,
        ),
        handle(
          edge: 'bottomLeft',
          cursor: SystemMouseCursors.resizeUpRightDownLeft,
          left: 0,
          bottom: 0,
          width: size,
          height: size,
        ),
        handle(
          edge: 'bottomRight',
          cursor: SystemMouseCursors.resizeUpLeftDownRight,
          right: 0,
          bottom: 0,
          width: size,
          height: size,
        ),
      ],
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final ThemePalette palette;
  final Color hoverColor;
  final Color? hoverForeground;
  final VoidCallback onPressed;
  final String tooltip;

  const _WindowButton({
    required this.icon,
    required this.palette,
    required this.hoverColor,
    required this.onPressed,
    required this.tooltip,
    this.hoverForeground,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onPressed,
        customBorder: const RoundedRectangleBorder(),
        child: Ink(
          width: 46,
          height: 36,
          child: Icon(icon, size: 18, color: palette.windowTitleForeground),
        ),
        hoverColor: hoverColor,
        splashFactory: NoSplash.splashFactory,
      ),
    );
  }
}
