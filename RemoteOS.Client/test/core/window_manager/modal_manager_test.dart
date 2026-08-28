import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/window_manager/modal_manager.dart';
import 'package:remoteos_client/core/window_manager/window_manager.dart';

void main() {
  RemoteWindow owner() => RemoteWindow(
        id: 'owner',
        appId: 'test-app',
        title: 'Owner',
        child: const SizedBox.shrink(),
        icon: Icons.widgets_outlined,
        bounds: const Rect.fromLTWH(20, 20, 640, 480),
      );

  test('opens an owner-bound managed dialog and returns its result', () async {
    final windows = WindowManagerNotifier();
    final item = owner();
    windows.state = [item];
    final modals = ModalManager(windows);

    final result = modals.open<String>(
      ownerId: item.id,
      spec: const ModalSpec(
        title: 'Prompt',
        icon: Icons.help_outline,
        child: SizedBox.shrink(),
      ),
    );
    final dialog = windows.state.singleWhere((window) => window.isModal);
    expect(dialog.modalOwnerId, item.id);
    expect(windows.isBlocked(item.id), isTrue);

    modals.complete(dialog.id, 'accepted');
    expect(await result, 'accepted');
    expect(windows.isBlocked(item.id), isFalse);
  });

  test('rejects opening a modal for a non-existent owner', () {
    expect(
      () => ModalManager(WindowManagerNotifier()).open(
        ownerId: 'missing',
        spec: const ModalSpec(
          title: 'Prompt',
          icon: Icons.help_outline,
          child: SizedBox.shrink(),
        ),
      ),
      throwsStateError,
    );
  });
}
