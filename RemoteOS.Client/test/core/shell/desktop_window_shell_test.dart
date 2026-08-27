import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/shell/desktop_window_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const windowManagerChannel = MethodChannel('window_manager');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, (call) async {
      switch (call.method) {
        case 'isMaximized':
        case 'isFullScreen':
          return false;
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
}
