import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remoteos_client/app/shell/components/desktop_window_layer.dart';
import 'package:remoteos_client/core/shell/desktop_window_shell.dart';
import 'package:remoteos_client/core/window_manager/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const windowManagerChannel = MethodChannel('window_manager');
  var isFullScreen = false;
  var isMaximized = false;

  setUp(() {
    isFullScreen = false;
    isMaximized = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, (call) async {
      switch (call.method) {
        case 'isMaximized':
          return isMaximized;
        case 'maximize':
          isMaximized = true;
          return null;
        case 'unmaximize':
          isMaximized = false;
          return null;
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

  testWidgets('uses platform maximize state after leaving full screen',
      (tester) async {
    isMaximized = true;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DesktopWindowShell(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.filter_none_rounded), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pump();
    expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pump();
    expect(find.byIcon(Icons.filter_none_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.filter_none_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.crop_square_rounded), findsOneWidget);
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

  testWidgets('reordering windows keeps title-bar drag state with its window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final manager = WindowManagerNotifier();
    final a = RemoteWindow(
      id: 'a',
      appId: 'test-app',
      title: 'A',
      icon: Icons.looks_one_outlined,
      bounds: const Rect.fromLTWH(10, 10, 360, 240),
      child: const SizedBox.shrink(),
    );
    final b = RemoteWindow(
      id: 'b',
      appId: 'test-app',
      title: 'B',
      icon: Icons.looks_two_outlined,
      bounds: const Rect.fromLTWH(460, 10, 360, 240),
      child: const SizedBox.shrink(),
    );
    manager.state = [a, b];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          windowManagerProvider.overrideWith((ref) => manager),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DesktopWindowLayer(
                  workArea: Rect.fromLTWH(0, 0, 960, 480),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final dragA = await tester.startGesture(const Offset(40, 28));
    await dragA.moveBy(const Offset(40, 0));
    await tester.pump();
    await dragA.moveBy(const Offset(30, 0));
    await tester.pump();
    await dragA.up();
    await tester.pump();

    expect(a.bounds.left, 40);

    final dragB = await tester.startGesture(const Offset(490, 28));
    await dragB.moveBy(const Offset(30, 0));
    await tester.pump();
    await dragB.moveBy(const Offset(30, 0));
    await tester.pump();
    await dragB.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(a.bounds.left, 40);
    expect(b.bounds.left, 490);
    expect(find.byKey(const ValueKey('remote-window-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('remote-window-b')), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
