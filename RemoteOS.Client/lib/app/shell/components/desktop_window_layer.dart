// Desktop window layer.  Renders the managed-window stack: modal blockers
// and RemoteWindowChrome sorted by z-order.  Reads reactively from the
// WindowManagerNotifier via watch_it / riverpod interoperability.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_injection.dart';
import '../../../core/runtime/desktop_runtime.dart';
import '../../../core/window_manager/window_manager.dart';

class DesktopWindowLayer extends ConsumerWidget {
  const DesktopWindowLayer({super.key, required this.workArea});

  final Rect workArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(windowManagerProvider);
    final log = _optionalLog();
    unawaited(log?.info(
      '[window-layer] build windows=${windows.length} '
      'workArea=LTWH(${workArea.left},${workArea.top},${workArea.width},${workArea.height})',
    ));
    final sorted = List<RemoteWindow>.from(windows)
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    for (final w in sorted) {
      unawaited(log?.info(
        '[window-layer] window id=${w.id} appId=${w.appId} state=${w.state} '
        'zOrder=${w.zOrder} title=${w.title} '
        'bounds=LTWH(${w.bounds.left},${w.bounds.top},${w.bounds.width},${w.bounds.height})',
      ));
    }
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
                    : sorted
                        .firstWhere((item) => item.id == window.modalOwnerId),
              ),
            _ErrorGuardedWindowChrome(window: window, workArea: workArea),
          ],
        ]),
      ),
    );
  }

  RuntimeLog? _optionalLog() {
    try {
      return di.isRegistered<RuntimeLog>() ? di<RuntimeLog>() : null;
    } catch (_) {
      return null;
    }
  }
}

/// Wraps a single [RemoteWindowChrome] build with a log-and-continue guard so
/// that a failing managed window never collapses the whole desktop into a
/// blank frame.  If the real chrome throws during build, we emit a tiny
/// placeholder with the window id/title instead.
class _ErrorGuardedWindowChrome extends ConsumerWidget {
  final RemoteWindow window;
  final Rect workArea;
  const _ErrorGuardedWindowChrome({required this.window, required this.workArea});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = _optionalLog();
    unawaited(log?.info(
      '[window-chrome] build id=${window.id} appId=${window.appId} '
      'state=${window.state}',
    ));
    try {
      return Builder(
        builder: (context) {
          final result =
              RemoteWindowChrome(window: window, workArea: workArea);
          unawaited(log?.info(
            '[window-chrome] RemoteWindowChrome constructed id=${window.id}',
          ));
          return result;
        },
      );
    } catch (error, stack) {
      unawaited(log?.error(
        AssertionError('[window-chrome] build failed for '
            'id=${window.id} appId=${window.appId}: $error'),
        stack,
      ));
      return Positioned.fromRect(
        rect: window.bounds,
        child: Container(
          color: const Color(0xFF8A2E36),
          padding: const EdgeInsets.all(8),
          child: SelectableText.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              children: [
                TextSpan(
                  text: 'Window ${window.appId} failed to render.\n\n',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '$error\n$stack'),
              ],
            ),
          ),
        ),
      );
    }
  }

  RuntimeLog? _optionalLog() {
    try {
      return di.isRegistered<RuntimeLog>() ? di<RuntimeLog>() : null;
    } catch (_) {
      return null;
    }
  }
}

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
        child: ColoredBox(color: Colors.black.withValues(alpha: 0.16)),
      ),
    );
  }
}
