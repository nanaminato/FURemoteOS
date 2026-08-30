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

  testWidgets('keeps desktop menus above the taskbar work area',
      (tester) async {
    final controller = RemoteContextMenuController();
    await pumpHost(tester, controller, const []);

    controller.show(
      const Offset(400, 540),
      const [
        ContextMenuAction(label: 'View', onSelected: _noop),
        ContextMenuAction(label: 'Refresh', onSelected: _noop),
        ContextMenuAction(label: 'Configure', onSelected: _noop),
        ContextMenuAction(label: 'Explorer', onSelected: _noop),
        ContextMenuAction(label: 'Terminal', onSelected: _noop),
      ],
      availableBounds: const Rect.fromLTWH(0, 0, 800, 552),
    );
    await tester.pump();

    expect(
      tester.getBottomRight(find.text('Terminal')).dy,
      lessThanOrEqualTo(552),
    );
  });

  testWidgets('an explicitly expanded positioned stack consumes its viewport',
      (tester) async {
    const desktopKey = Key('desktop-stack');
    final controller = RemoteContextMenuController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) => SizedBox.expand(
              child: ContextMenuHost(
                controller: controller,
                child: Stack(
                  key: desktopKey,
                  children: const [
                    Positioned.fill(child: ColoredBox(color: Colors.blue)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(desktopKey)), const Size(800, 600));
  });
}

void _noop() {}
