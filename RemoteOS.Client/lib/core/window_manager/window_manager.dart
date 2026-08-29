import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/dependency_injection.dart';
import '../apps/app_registry.dart';
import '../runtime/desktop_runtime.dart';
import '../theme/theme_service.dart';

/// Window state constants.
enum RemoteWindowState { normal, minimized, maximized, fullscreen }

/// Data for a single managed window.
class RemoteWindow {
  final String id;
  final String appId;
  final String title;
  final Widget child;
  final IconData icon;

  Rect bounds;
  Rect? restoreBounds;
  RemoteWindowState? stateBeforeMinimize;
  final Size minimumSize;
  RemoteWindowState state;
  int zOrder;
  final String? modalOwnerId;
  final Completer<Object?>? _modalCompletion;

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
    this.modalOwnerId,
    Completer<Object?>? modalCompletion,
  }) : _modalCompletion = modalCompletion;

  bool get isModal => modalOwnerId != null;
}

/// State notifier for the window manager.
class WindowManagerNotifier extends StateNotifier<List<RemoteWindow>> {
  WindowManagerNotifier() : super([]);

  int _zCounter = 0;

  /// Keeps the next assigned z-order above any restored or externally seeded
  /// window. Layout restoration can populate [state] without going through
  /// [openApp], so [_zCounter] cannot be assumed to be current.
  void _ensureNextZOrderAbove(List<RemoteWindow> windows) {
    var highest = -1;
    for (final window in windows) {
      if (window.zOrder > highest) highest = window.zOrder;
    }
    if (_zCounter <= highest) _zCounter = highest + 1;
  }

  /// Whether the active-modal chain for [windowId] is already ordered on top
  /// of every unrelated window.  Used by [focus] to avoid a pointless
  /// z-bump + state notification that causes desktop-wide rebuilds.
  bool _chainAlreadyTopmost(List<RemoteWindow> snapshot, String windowId) {
    final byId = <String, RemoteWindow>{for (final w in snapshot) w.id: w};
    var root = byId[windowId];
    if (root == null) return true; // nothing to focus
    while (root!.modalOwnerId != null) {
      final parent = byId[root.modalOwnerId!];
      if (parent == null) break;
      root = parent;
    }
    // Walk the chain root → topmost modal; collect ids.
    final chain = <RemoteWindow>[root];
    while (true) {
      final parent = chain.last;
      RemoteWindow? topChild;
      for (final w in snapshot) {
        if (w.modalOwnerId != parent.id) continue;
        if (topChild == null || w.zOrder > topChild.zOrder) {
          topChild = w;
        }
      }
      if (topChild == null) break;
      chain.add(topChild);
    }
    final chainZ = chain.map((w) => w.zOrder).toList();
    final minChainZ = chainZ.reduce((x, y) => x < y ? x : y);
    for (final w in snapshot) {
      if (chain.contains(w)) continue; // skip self
      // Equal z-order is not a stable visual ordering, so the target chain
      // must be strictly above every unrelated window before focus is a no-op.
      if (w.zOrder >= minChainZ) return false;
    }
    return true;
  }

  /// Open a new window from an app registry entry.
  RemoteWindow openApp({
    required AppRegistryEntry entry,
    required Widget child,
    String? title,
    Rect? initialBounds,
    Size? initialSize,
    Size? screenSize,
  }) {
    final log = _optionalLog;
    unawaited(log?.info(
      '[windows] openApp appId=${entry.id} title=${title ?? entry.nameKey} '
      'allowMultipleInstances=${entry.allowMultipleInstances} '
      'initialBounds=$initialBounds initialSize=$initialSize '
      'screenSize=$screenSize defaultSize=${entry.defaultSize} '
      'minimumSize=${entry.minimumSize}',
    ));
    if (!entry.allowMultipleInstances) {
      final existing = state.where((w) => w.appId == entry.id).toList();
      if (existing.isNotEmpty) {
        unawaited(log?.info(
          '[windows] openApp existing instance found id=${existing.first.id} '
          'state=${existing.first.state}; focusing instead',
        ));
        focus(existing.first.id);
        if (existing.first.state == RemoteWindowState.minimized) {
          restore(existing.first.id);
        }
        return existing.first;
      }
    }
    final id = const Uuid().v4();
    // Guard against transient zero or negative sizes during the first desktop
    // frame.  Using such sizes would produce non-finite bounds and either
    // throw during layout or render a blank desktop on sign-in.
    final safeScreen = _sanitizeSize(screenSize, const Size(1280, 720));
    final Size? safeInitial = initialSize == null
        ? null
        : _sanitizeSize(initialSize, entry.defaultSize);
    final defaultRect = initialBounds ??
        _centerRect(
          safeInitial ?? entry.defaultSize,
          safeScreen,
        );
    unawaited(log?.info(
      '[windows] openApp computing bounds safeScreen=${safeScreen.width}x${safeScreen.height} '
      'safeInitial=${safeInitial == null ? '<registry>' : '${safeInitial.width}x${safeInitial.height}'} '
      'bounds=LTWH(${defaultRect.left},${defaultRect.top},${defaultRect.width},${defaultRect.height})',
    ));
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
    unawaited(log?.info(
      '[windows] openApp created windowId=$id totalWindows=${state.length}',
    ));
    return window;
  }

  RuntimeLog? get _optionalLog {
    try {
      return di.isRegistered<RuntimeLog>() ? di<RuntimeLog>() : null;
    } catch (_) {
      return null;
    }
  }

  Size _sanitizeSize(Size? input, Size fallback) {
    final candidate = input ?? fallback;
    final width = candidate.width.isFinite && candidate.width >= 240
        ? candidate.width
        : fallback.width;
    final height = candidate.height.isFinite && candidate.height >= 160
        ? candidate.height
        : fallback.height;
    return Size(width, height);
  }

  Rect _centerRect(Size size, Size screen) {
    final left = ((screen.width - size.width) / 2).clamp(0.0, screen.width);
    final top = ((screen.height - size.height) / 2 - 20)
        .clamp(0.0, (screen.height - 20).clamp(0.0, double.infinity));
    return Rect.fromLTWH(left, top, size.width, size.height);
  }

  /// Focus (raise to top) a window, respecting modal chains.
  ///
  /// If `windowId` belongs to a modal family (owner or any descendant modal),
  /// the entire chain from root owner down to the currently active topmost
  /// modal is raised together as an atomic group. The topmost modal ends up
  /// with the highest z-order so it stays visually on top of its owners, and
  /// every owner in between is also brought above unrelated windows. This
  /// matches desktop behavior where clicking any window in a modal chain
  /// activates the deepest modal and lifts the whole group.
  void focus(String windowId) {
    final list = List<RemoteWindow>.of(state);
    // Fast-path: when the chain already sits on top of every unrelated window
    // there is no reason to bump z values and re-emit state; every listener
    // would rebuild for the same visual.  This matters in particular for the
    // implicit focus() fired from RemoteWindowChrome on each keystroke when
    // the terminal regains input focus.
    if (_chainAlreadyTopmost(list, windowId)) return;
    final byId = <String, RemoteWindow>{
      for (final w in list) w.id: w,
    };
    final start = byId[windowId];
    if (start == null) return;
    _ensureNextZOrderAbove(list);

    // 1) Walk up to the root owner (window with no modal owner).
    RemoteWindow root = start;
    while (root.modalOwnerId != null) {
      final parent = byId[root.modalOwnerId!];
      if (parent == null) break;
      root = parent;
    }

    // 2) Build the active chain root -> ... -> topmost active modal.
    // At each level pick the direct child modal with the highest zOrder, i.e.
    // the one that is currently visually above its siblings.
    final activeChain = <RemoteWindow>[root];
    while (true) {
      final parent = activeChain.last;
      RemoteWindow? topChild;
      for (final w in list) {
        if (w.modalOwnerId != parent.id) continue;
        if (topChild == null || w.zOrder > topChild.zOrder) {
          topChild = w;
        }
      }
      if (topChild == null) break;
      activeChain.add(topChild);
    }

    // 3) Raise the chain in root-first order so internal z-order is preserved:
    // root < level-1 modal < ... < topmost, all above unrelated windows.
    // Produce a new list so StateNotifier fires a change notification.
    final chainIds = <String>{for (final w in activeChain) w.id};
    final updated = <RemoteWindow>[];
    // Emit unrelated windows first in their existing order.
    for (final w in list) {
      if (chainIds.contains(w.id)) continue;
      updated.add(w);
    }
    // Append the chain with sequentially bumped z values. The view sorts
    // windows by zOrder so root < level-1 < ... < topmost renders correctly.
    for (final w in activeChain) {
      w.zOrder = _zCounter++;
      updated.add(w);
    }
    state = updated;
  }

  /// Close a window.
  void close(String windowId) {
    final closingIds = <String>{windowId};
    // Closing an owner also cancels every nested modal, matching the old
    // WindowManager's modal-chain teardown.
    while (true) {
      final descendants = state
          .where((window) =>
              window.modalOwnerId != null &&
              closingIds.contains(window.modalOwnerId))
          .map((window) => window.id)
          .toSet();
      if (descendants.every(closingIds.contains)) break;
      closingIds.addAll(descendants);
    }
    for (final window
        in state.where((window) => closingIds.contains(window.id))) {
      final completion = window._modalCompletion;
      if (completion != null && !completion.isCompleted) completion.complete();
    }
    final next =
        state.where((window) => !closingIds.contains(window.id)).toList();
    if (next.length == state.length) return;
    state = next;
  }

  /// Opens a real managed modal window and returns its completion value. Its
  /// owner remains visible but cannot receive pointer input until completion.
  Future<T?> showDialog<T>({
    required RemoteWindow owner,
    required String title,
    required IconData icon,
    required Widget child,
    Size preferredSize = const Size(460, 320),
  }) {
    final completion = Completer<Object?>();
    final width = preferredSize.width
        .clamp(
            320.0, (owner.bounds.width - 48).clamp(320.0, preferredSize.width))
        .toDouble();
    final height = preferredSize.height
        .clamp(220.0,
            (owner.bounds.height - 56).clamp(220.0, preferredSize.height))
        .toDouble();
    final bounds = Rect.fromLTWH(
        owner.bounds.left + (owner.bounds.width - width) / 2,
        owner.bounds.top + (owner.bounds.height - height) / 2,
        width,
        height);
    final id = const Uuid().v4();
    final dialog = RemoteWindow(
      id: id,
      appId: owner.appId,
      title: title,
      child: RemoteModalScope(windowId: id, child: child),
      icon: icon,
      bounds: bounds,
      minimumSize: const Size(320, 220),
      zOrder: _zCounter++,
      modalOwnerId: owner.id,
      modalCompletion: completion,
    );
    state = [...state, dialog];
    // Lifting the owner + any existing modals together with the new dialog
    // matches the click/focus path: opening a modal raises the whole chain
    // above unrelated windows, with the new dialog ending up topmost.
    // Note: this is intentionally the raw `state = ` setter because adding a
    // brand-new dialog always changes the list (a new id was appended) — the
    // deep-equal path would return false anyway and just burn cycles.
    focus(id);
    return completion.future.then((value) => value as T?);
  }

  void completeDialog<T>(String windowId, [T? value]) {
    final matches = state.where((w) => w.id == windowId);
    final dialog = matches.isEmpty ? null : matches.first;
    final completion = dialog?._modalCompletion;
    if (completion != null && !completion.isCompleted)
      completion.complete(value);
    close(windowId);
  }

  bool isBlocked(String windowId) =>
      state.any((w) => w.modalOwnerId == windowId);

  /// Minimize a window.
  void minimize(String windowId) {
    state = [
      for (final w in state)
        if (w.id == windowId && w.state != RemoteWindowState.minimized)
          w
            ..stateBeforeMinimize = w.state
            ..state = RemoteWindowState.minimized
        else
          w,
    ];
  }

  /// Restore a minimized window.
  void restore(String windowId) {
    _ensureNextZOrderAbove(state);
    state = [
      for (final w in state)
        if (w.id == windowId)
          w
            ..state = w.stateBeforeMinimize ?? RemoteWindowState.normal
            ..stateBeforeMinimize = null
            ..zOrder = _zCounter++
        else
          w,
    ];
  }

  /// Toggle maximize / restore.
  void toggleMaximize(String windowId, Rect? screenWorkArea) {
    _ensureNextZOrderAbove(state);
    state = [
      for (final w in state)
        if (w.id == windowId)
          if (w.state == RemoteWindowState.maximized)
            w
              ..state = RemoteWindowState.normal
              ..bounds = w.restoreBounds ?? w.bounds
              ..zOrder = _zCounter++
          else
            _maximize(w, screenWorkArea)
        else
          w,
    ];
  }

  RemoteWindow _maximize(RemoteWindow window, Rect? screenWorkArea) {
    window.restoreBounds = window.bounds;
    return window
      ..state = RemoteWindowState.maximized
      ..bounds = screenWorkArea ?? window.bounds
      ..zOrder = _zCounter++;
  }

  /// Toggle an internal window between its normal/maximized presentation and
  /// the entire managed host work area. The host taskbar remains available.
  void toggleFullscreen(String windowId, Rect workArea) {
    _ensureNextZOrderAbove(state);
    state = [
      for (final w in state)
        if (w.id == windowId)
          if (w.state == RemoteWindowState.fullscreen)
            w
              ..state = RemoteWindowState.normal
              ..bounds = w.restoreBounds ?? w.bounds
              ..zOrder = _zCounter++
          else
            w
              ..restoreBounds = w.bounds
              ..state = RemoteWindowState.fullscreen
              ..bounds = workArea
              ..zOrder = _zCounter++
        else
          w,
    ];
  }

  /// Move a window to a new position.
  void move(
    String windowId,
    Offset delta,
    Rect constraints, {
    Rect? startBounds,
  }) {
    // Most onPanUpdate ticks deliver a zero delta (the pointer hasn't moved
    // since the last sample).  Compute the target rect up-front and skip the
    // list rebuild entirely when nothing changed.
    Rect? target;
    for (final w in state) {
      if (w.id == windowId) {
        final bounds = startBounds ?? w.bounds;
        final moved = bounds.shift(delta);
        final left = moved.left
            .clamp(-moved.width + 120.0, constraints.right - 120.0)
            .toDouble();
        final top = moved.top
            .clamp(constraints.top, constraints.bottom - 36.0)
            .toDouble();
        target = Rect.fromLTWH(left, top, moved.width, moved.height);
        if (target == w.bounds) return; // no-op drag tick
        break;
      }
    }
    if (target == null) return;
    state = [
      for (final w in state)
        if (w.id == windowId) (w..bounds = target) else w,
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
    Rect? target;
    for (final w in state) {
      if (w.id == windowId) {
        target = _applyResize(
          startBounds ?? w.bounds,
          w.minimumSize,
          edge,
          delta,
          constraints,
        );
        if (target == w.bounds) return; // no-op resize tick
        break;
      }
    }
    if (target == null) return;
    state = [
      for (final w in state)
        if (w.id == windowId) (w..bounds = target) else w,
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

/// Makes the owning managed dialog available to arbitrary dialog content.
/// Call `completeDialog(RemoteModalScope.of(context).windowId, value)` from a
/// Consumer widget to close it with a result.
class RemoteModalScope extends InheritedWidget {
  const RemoteModalScope(
      {super.key, required this.windowId, required super.child});
  final String windowId;

  static RemoteModalScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RemoteModalScope>()!;

  @override
  bool updateShouldNotify(RemoteModalScope oldWidget) =>
      windowId != oldWidget.windowId;
}

/// Exposes the managed window owning an application subtree. Applications use
/// it to create owner-bound dialogs without depending on desktop screen code.
class RemoteWindowScope extends InheritedWidget {
  const RemoteWindowScope(
      {super.key, required this.window, required super.child});
  final RemoteWindow window;

  static RemoteWindowScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RemoteWindowScope>()!;

  @override
  bool updateShouldNotify(RemoteWindowScope oldWidget) =>
      oldWidget.window != window;
}

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
    final isFullscreen = win.state == RemoteWindowState.fullscreen;
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
          child: AbsorbPointer(
            absorbing: wm.isBlocked(win.id),
            child: Container(
              decoration: BoxDecoration(
                color: palette.windowFrameBackground,
                borderRadius:
                    BorderRadius.circular(isMaximized || isFullscreen ? 0 : 8),
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
                      _buildTitleBar(
                          palette, wm, win, isMaximized, isFullscreen),
                      Divider(
                        height: 1,
                        color: palette.borderSubtle,
                        thickness: 1,
                      ),
                      Expanded(
                        child: RemoteWindowScope(
                          window: win,
                          child: _GuardedWindowChild(window: win),
                        ),
                      ),
                    ],
                  ),
                  if (!isMaximized && !isFullscreen)
                    _buildResizeHandles(palette, wm, win),
                ],
              ),
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
    bool isFullscreen,
  ) {
    return GestureDetector(
      onPanStart: (details) {
        // A drag is a single activation. Raise the window here, rather than
        // coupling focus work to every pointer update.
        wm.focus(win.id);
        _dragStart = details.globalPosition;
        _startBounds = win.bounds;
      },
      onPanUpdate: (details) {
        if (isMaximized || isFullscreen) return;
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
              icon: isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              palette: palette,
              hoverColor: palette.surfaceHover,
              onPressed: () => wm.toggleFullscreen(win.id, widget.workArea),
              tooltip: isFullscreen
                  ? 'shell.full_screen.exit'.tr()
                  : 'shell.full_screen.enter_tooltip'.tr(),
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

/// Wraps the user-supplied managed-window child with a build-time try/catch
/// and a diagnostic post-frame log.  This keeps a crashing app window from
/// taking the entire desktop shell with it, and lets us narrow failures to
/// the child widget even when the Flutter view loses the host connection
/// before the error card finishes drawing.
class _GuardedWindowChild extends ConsumerStatefulWidget {
  final RemoteWindow window;
  const _GuardedWindowChild({required this.window});

  @override
  ConsumerState<_GuardedWindowChild> createState() =>
      _GuardedWindowChildState();
}

class _GuardedWindowChildState extends ConsumerState<_GuardedWindowChild> {
  bool _built = false;

  RuntimeLog? get _localLog {
    try {
      return di.isRegistered<RuntimeLog>() ? di<RuntimeLog>() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final log = _localLog;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(log?.info(
        '[window-child] first frame painted id=${widget.window.id} '
        'appId=${widget.window.appId}',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final log = _localLog;
    if (!_built) {
      _built = true;
      unawaited(log?.info(
        '[window-child] building id=${widget.window.id} '
        'appId=${widget.window.appId} childType=${widget.window.child.runtimeType}',
      ));
    }
    try {
      return Builder(builder: (context) => widget.window.child);
    } catch (error, stack) {
      unawaited(log?.error(
        AssertionError('[window-child] build threw for '
            'id=${widget.window.id} appId=${widget.window.appId}: $error'),
        stack,
      ));
      return Container(
        color: const Color(0xFF8A2E36),
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          child: SelectableText.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 11),
              children: [
                TextSpan(
                  text:
                      'App window ${widget.window.appId} failed to render.\n\n',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '$error\n\n$stack'),
              ],
            ),
          ),
        ),
      );
    }
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
