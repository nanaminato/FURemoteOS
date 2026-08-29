import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remoteos_client/core/shell/desktop_window_shell.dart';
import 'package:remoteos_client/core/window_manager/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const windowManagerChannel = MethodChannel('window_manager');
  var isFullScreen = false;

  setUp(() {
    isFullScreen = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, (call) async {
      switch (call.method) {
        case 'isMaximized':
          return false;
        case 'isFullScreen':
          return isFullScreen;
        case 'setFullScreen':
          isFullScreen = (call.arguments
              as Map<Object?, Object?>)['isFullScreen']! as bool;
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, null);
  });

  testWidgets('top-level title bar supplies Overlay and Material',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DesktopWindowShell(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gives the routed child the remaining viewport height',
      (tester) async {
    const bodyKey = Key('desktop-body');
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopWindowShell(
          child: Container(key: bodyKey),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byKey(bodyKey)), const Size(900, 664));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a builder-provided routed child at viewport size',
      (tester) async {
    const bodyKey = Key('builder-desktop-body');
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DesktopWindowShell(
          child: child ?? const SizedBox.shrink(),
        ),
        home: Container(key: bodyKey),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byKey(bodyKey)), const Size(900, 664));
    expect(tester.takeException(), isNull);
  });

  testWidgets('restores the custom title bar after leaving full screen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DesktopWindowShell(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pump();
    expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pump();
    expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebuilds the retained overlay entry when its child changes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DesktopWindowShell(
          child: Text('login'),
        ),
      ),
    );
    expect(find.text('login'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: DesktopWindowShell(
          child: Text('desktop'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('login'), findsNothing);
    expect(find.text('desktop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('managed windows lay out resize handles in their bounded overlay',
      (tester) async {
    final window = RemoteWindow(
      id: 'test-window',
      appId: 'test-app',
      title: 'Test window',
      icon: Icons.widgets_outlined,
      bounds: const Rect.fromLTWH(20, 20, 360, 280),
      child: const ColoredBox(color: Colors.blue),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                RemoteWindowChrome(
                  window: window,
                  workArea: const Rect.fromLTWH(0, 0, 640, 480),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
