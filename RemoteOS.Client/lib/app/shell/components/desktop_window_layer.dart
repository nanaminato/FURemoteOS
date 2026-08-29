// Desktop window layer.  Renders the managed-window stack: modal blockers
// and RemoteWindowChrome sorted by z-order.  Reads reactively from the
// WindowManagerNotifier via watch_it / riverpod interoperability.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/window_manager/window_manager.dart';

class DesktopWindowLayer extends ConsumerWidget {
  const DesktopWindowLayer({super.key, required this.workArea});

  final Rect workArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    : sorted
                        .firstWhere((item) => item.id == window.modalOwnerId),
              ),
            RemoteWindowChrome(window: window, workArea: workArea),
          ],
        ]),
      ),
    );
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
