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

  group('focus raises modal chain together', () {
    RemoteWindow w(String id, {String? modalOwnerId, int z = 0}) =>
        RemoteWindow(
          id: id,
          appId: 'test-app',
          title: id,
          child: const SizedBox.shrink(),
          icon: Icons.widgets_outlined,
          bounds: const Rect.fromLTWH(50, 50, 300, 200),
          zOrder: z,
          modalOwnerId: modalOwnerId,
        );

    test('focus owner raises owner and its single modal together', () {
      // Setup: A (modal owner) with B (modal of A), plus unrelated E above.
      // After focus(A) the chain [A, B] must both end up z-wise above E,
      // and A.z < B.z (owner below its modal).
      final manager = WindowManagerNotifier();
      final a = w('A');
      final b = w('B', modalOwnerId: 'A');
      final e = w('E');
      manager.state = [a, b, e];
      // Seed z values via _zCounter: E above both.
      manager.focus(e.id); // bump E
      final eZbefore = e.zOrder;

      manager.focus(a.id); // focus owner A

      // Chain members both end up above unrelated E.
      expect(a.zOrder, greaterThan(eZbefore));
      expect(b.zOrder, greaterThan(eZbefore));
      // Internal order preserved: owner below its modal.
      expect(a.zOrder, lessThan(b.zOrder));
    });

    test('focus modal raises owner + modal (same as focusing owner)', () {
      // A-模态B. Clicking B activates B (topmost) and lifts A too.
      final manager = WindowManagerNotifier();
      final a = w('A');
      final b = w('B', modalOwnerId: 'A');
      final e = w('E');
      manager.state = [a, b, e];
      manager.focus(e.id);
      final eZbefore = e.zOrder;

      manager.focus(b.id); // focus the modal itself

      expect(a.zOrder, greaterThan(eZbefore));
      expect(b.zOrder, greaterThan(eZbefore));
      expect(a.zOrder, lessThan(b.zOrder));
    });

    test('focus chain member activates deep topmost for 3-level nesting', () {
      // A -模态B -模态C,  D,  E-模态F.
      // Click A or B or C → the topmost C should get highest z in chain,
      // and [A, B, C] should all be raised above unrelated windows (D, E, F).
      final manager = WindowManagerNotifier();
      final a = w('A');
      final b = w('B', modalOwnerId: 'A');
      final c = w('C', modalOwnerId: 'B');
      final d = w('D');
      final e = w('E');
      final f = w('F', modalOwnerId: 'E');
      manager.state = [a, b, c, d, e, f];
      // Raise D, E-F above everything initially to challenge the chain-lift.
      manager.focus(d.id);
      manager.focus(f.id); // lifts [E, F]
      final dZbefore = d.zOrder;
      final eZbefore = e.zOrder;
      final fZbefore = f.zOrder;

      // Focus middle-of-chain B.
      manager.focus(b.id);

      // The A-B-C chain is lifted as a group above the previously-raised
      // (and now unrelated) windows D/E/F.
      expect(a.zOrder, greaterThan(dZbefore));
      expect(b.zOrder, greaterThan(dZbefore));
      expect(c.zOrder, greaterThan(dZbefore));
      expect(a.zOrder, greaterThan(eZbefore));
      expect(a.zOrder, greaterThan(fZbefore));
      // Internal chain order remains strict: A < B < C.
      expect(a.zOrder, lessThan(b.zOrder));
      expect(b.zOrder, lessThan(c.zOrder));
      // Unrelated chain [E, F] keeps its own internal order untouched.
      expect(e.zOrder, lessThan(f.zOrder));
    });

    test('focus topmost of sibling groups lifts only its own chain', () {
      // Groups: (A-模态B) and (C-模态D) plus lone E.
      // Focus B → only A and B should move; C, D, E relative order unchanged.
      final manager = WindowManagerNotifier();
      final a = w('A');
      final b = w('B', modalOwnerId: 'A');
      final c = w('C');
      final d = w('D', modalOwnerId: 'C');
      final e = w('E');
      manager.state = [a, b, c, d, e];
      // First lift group (C,D) so it is above (A,B) initially.
      manager.focus(d.id);
      final cZbefore = c.zOrder;
      final dZbefore = d.zOrder;
      final eZbefore = e.zOrder;

      manager.focus(a.id); // now focus owner A of group (A,B)

      // Group (A,B) is now on top of everything.
      expect(b.zOrder, greaterThan(dZbefore));
      expect(a.zOrder, greaterThan(dZbefore));
      expect(a.zOrder, lessThan(b.zOrder));
      // Unrelated group (C,D) and lone window E keep their exact z values.
      expect(c.zOrder, equals(cZbefore));
      expect(d.zOrder, equals(dZbefore));
      expect(e.zOrder, equals(eZbefore));
    });

    test('focus a standalone window works like the old single-bump', () {
      final manager = WindowManagerNotifier();
      final lone = w('LONE');
      manager.state = [lone];

      manager.focus(lone.id);

      // No throw, window remains present.
      expect(manager.state, contains(lone));
    });

    test('focus unknown id is a no-op (preserves state list identity semantic)',
        () {
      final manager = WindowManagerNotifier();
      final a = w('A');
      final before = List<RemoteWindow>.of(manager.state = [a]);

      manager.focus('does-not-exist');

      // No change emitted: same count, same element, no z bumps visible.
      expect(manager.state.length, equals(before.length));
    });
  });

  group('showDialog lifts owner chain (same semantics as focus)', () {
    RemoteWindow plain(String id) => RemoteWindow(
          id: id,
          appId: 'test-app',
          title: id,
          child: const SizedBox.shrink(),
          icon: Icons.widgets_outlined,
          bounds: const Rect.fromLTWH(50, 50, 300, 200),
        );

    test('opening first dialog lifts owner + new modal above unrelated windows',
        () async {
      final manager = WindowManagerNotifier();
      final a = plain('A');
      final d = plain('D');
      final e = plain('E');
      // Seed with three windows, then bring D and E above A via focus.
      manager.state = [a, d, e];
      // Kick _zCounter so focus(d) and focus(e) produce strictly higher z
      // values than A's freshly-assigned chain-lift z.
      manager.focus(a.id); // A.z = 0, counter = 1
      manager.focus(d.id); // D.z = 1, counter = 2
      manager.focus(e.id); // E.z = 2, counter = 3
      final dZbefore = d.zOrder;
      final eZbefore = e.zOrder;
      final aZbefore = a.zOrder;
      // Sanity: after three focuses, A is strictly the lowest.
      expect(aZbefore, lessThan(dZbefore));
      expect(aZbefore, lessThan(eZbefore));
      expect(dZbefore, lessThan(eZbefore));

      // Open a modal dialog on top of A.
      final future = manager.showDialog<int>(
        owner: a,
        title: 'Modal B',
        icon: Icons.help_outline,
        child: const SizedBox.shrink(),
      );
      final dialog = manager.state.singleWhere((w) => w.isModal);

      // A and the new dialog B are both lifted above unrelated D and E.
      expect(a.zOrder, greaterThan(dZbefore));
      expect(a.zOrder, greaterThan(eZbefore));
      expect(dialog.zOrder, greaterThan(d.zOrder));
      expect(dialog.zOrder, greaterThan(e.zOrder));
      // Owner stays strictly below its modal.
      expect(a.zOrder, lessThan(dialog.zOrder));
      // Unrelated D and E were not touched (kept their z values).
      expect(d.zOrder, equals(dZbefore));
      expect(e.zOrder, equals(eZbefore));
      // Cleanup so Future doesn't leak.
      manager.close(dialog.id);
      await future;
    });

    test('opening nested dialog lifts root owner + intermediate + topmost',
        () async {
      final manager = WindowManagerNotifier();
      final a = plain('A');
      manager.state = [a];
      // Open first-level modal B on A.
      final fB = manager.showDialog<int>(
        owner: a,
        title: 'Modal B',
        icon: Icons.help_outline,
        child: const SizedBox.shrink(),
      );
      final b = manager.state.singleWhere((w) => w.isModal && w.modalOwnerId == a.id);
      // Add unrelated E, focus E so it goes above [A, B].
      final e = plain('E');
      manager.state = [...manager.state, e];
      manager.focus(e.id);
      final eZbefore = e.zOrder;
      expect(a.zOrder, lessThan(eZbefore));
      expect(b.zOrder, lessThan(eZbefore));

      // Open nested modal C owned by B.
      final fC = manager.showDialog<int>(
        owner: b,
        title: 'Modal C',
        icon: Icons.help_outline,
        child: const SizedBox.shrink(),
      );
      final c = manager.state.singleWhere((w) => w.modalOwnerId == b.id);

      // All three chain members are now above the unrelated E.
      expect(a.zOrder, greaterThan(eZbefore));
      expect(b.zOrder, greaterThan(eZbefore));
      expect(c.zOrder, greaterThan(eZbefore));
      // Strict internal ordering A < B < C.
      expect(a.zOrder, lessThan(b.zOrder));
      expect(b.zOrder, lessThan(c.zOrder));
      // E's z has not been rewritten.
      expect(e.zOrder, equals(eZbefore));

      // Drain futures to avoid state leak warnings.
      manager.close(c.id);
      await fC;
      manager.completeDialog(b.id);
      await fB;
    });
  });
}

Widget _emptyApp(BuildContext context) => const SizedBox.shrink();
