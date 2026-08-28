import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/window_manager/window_manager.dart';
import 'package:remoteos_client/core/apps/app_registry.dart';

void main() {
  RemoteWindow window({
    String id = 'owner',
    Rect bounds = const Rect.fromLTWH(50, 60, 420, 300),
  }) =>
      RemoteWindow(
        id: id,
        appId: 'test-app',
        title: 'Test',
        child: const SizedBox.shrink(),
        icon: Icons.widgets_outlined,
        bounds: bounds,
      );

  test('completing a managed dialog removes it exactly once', () async {
    final manager = WindowManagerNotifier();
    final owner = window();
    manager.state = [owner];

    final result = manager.showDialog<int>(
      owner: owner,
      title: 'Confirm',
      icon: Icons.help_outline,
      child: const SizedBox.shrink(),
    );
    final dialog = manager.state.singleWhere((item) => item.isModal);
    manager.completeDialog(dialog.id, 42);

    expect(await result, 42);
    expect(manager.state, [owner]);
  });

  test('closing an owner cancels its complete modal chain', () async {
    final manager = WindowManagerNotifier();
    final owner = window();
    manager.state = [owner];
    final first = manager.showDialog<String>(
      owner: owner,
      title: 'First',
      icon: Icons.help_outline,
      child: const SizedBox.shrink(),
    );
    final firstDialog = manager.state.singleWhere((item) => item.isModal);
    final second = manager.showDialog<String>(
      owner: firstDialog,
      title: 'Second',
      icon: Icons.help_outline,
      child: const SizedBox.shrink(),
    );

    manager.close(owner.id);

    expect(await first, isNull);
    expect(await second, isNull);
    expect(manager.state, isEmpty);
  });

  test('restore preserves the window state before minimization', () {
    final manager = WindowManagerNotifier();
    final item = window();
    manager.state = [item];
    const workArea = Rect.fromLTWH(0, 0, 1000, 700);

    manager.toggleMaximize(item.id, workArea);
    manager.minimize(item.id);
    manager.restore(item.id);

    expect(item.state, RemoteWindowState.maximized);
    expect(item.bounds, workArea);
  });

  test('internal fullscreen preserves bounds for restoration', () {
    final manager = WindowManagerNotifier();
    final item = window();
    manager.state = [item];
    final originalBounds = item.bounds;
    const workArea = Rect.fromLTWH(0, 0, 1000, 700);

    manager.toggleFullscreen(item.id, workArea);
    expect(item.state, RemoteWindowState.fullscreen);
    expect(item.bounds, workArea);

    manager.toggleFullscreen(item.id, workArea);
    expect(item.state, RemoteWindowState.normal);
    expect(item.bounds, originalBounds);
  });

  test('move and resize obey visible-area and minimum-size constraints', () {
    final manager = WindowManagerNotifier();
    final item = window(bounds: const Rect.fromLTWH(100, 100, 420, 300));
    manager.state = [item];
    const workArea = Rect.fromLTWH(0, 0, 800, 600);

    manager.move(item.id, const Offset(-1000, -1000), workArea);
    expect(item.bounds.left, -300);
    expect(item.bounds.top, 0);

    manager.resize(
        item.id, 'bottomRight', const Offset(-1000, -1000), workArea);
    expect(item.bounds.width, item.minimumSize.width);
    expect(item.bounds.height, item.minimumSize.height);
  });

  test('uses a restored workspace size when opening an app', () {
    final manager = WindowManagerNotifier();
    const entry = AppRegistryEntry(
      id: 'notepad',
      nameKey: 'app.notepad',
      icon: Icons.edit_note_outlined,
      windowBuilder: _emptyApp,
      defaultSize: Size(600, 400),
    );

    final opened = manager.openApp(
      entry: entry,
      child: const SizedBox.shrink(),
      initialSize: const Size(720, 520),
      screenSize: const Size(1280, 720),
    );

    expect(opened.bounds.size, const Size(720, 520));
  });
}

Widget _emptyApp(BuildContext context) => const SizedBox.shrink();
