import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/window_manager/context_menu_host.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester,
    RemoteContextMenuController controller,
    List<ContextMenuEntry> entries,
  ) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextMenuHost(
              controller: controller,
              child: ContextMenuRegion(
                controller: controller,
                entries: entries,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

  testWidgets('opens at a secondary click and invokes enabled actions',
      (tester) async {
    final controller = RemoteContextMenuController();
    var invoked = false;
    await pumpHost(tester, controller, [
      ContextMenuAction(label: 'Open', onSelected: () => invoked = true),
      const ContextMenuAction(
          label: 'Disabled', enabled: false, onSelected: _noop),
    ]);

    await tester.tapAt(const Offset(790, 590), buttons: kSecondaryMouseButton);
    await tester.pump();
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
    expect(controller.isOpen, isTrue);

    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(invoked, isTrue);
    expect(controller.isOpen, isFalse);
  });

  testWidgets('opens submenus and closes on Escape', (tester) async {
    final controller = RemoteContextMenuController();
    await pumpHost(tester, controller, const [
      ContextMenuSubmenu(
        label: 'Open with',
        entries: [ContextMenuAction(label: 'Notepad', onSelected: _noop)],
      ),
    ]);

    controller.show(const Offset(30, 30), const [
      ContextMenuSubmenu(
        label: 'Open with',
        entries: [ContextMenuAction(label: 'Notepad', onSelected: _noop)],
      ),
    ]);
    await tester.pump();
    await tester.tap(find.text('Open with'));
    await tester.pump();
    expect(find.text('Notepad'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.isOpen, isFalse);
  });
}

void _noop() {}
