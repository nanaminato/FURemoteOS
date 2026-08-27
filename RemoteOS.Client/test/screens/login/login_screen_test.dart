import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/screens/login/login_screen.dart';
import 'package:remoteos_client/core/localization/modular_asset_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('expanded login options scroll inside a short desktop window',
      (tester) async {
    await EasyLocalization.ensureInitialized();
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        assetLoader: const ModularAssetLoader(),
        fallbackLocale: const Locale('en', 'US'),
        child: ProviderScope(
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const LoginScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    final scrollView = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(scrollbar.controller, same(scrollView.controller));
    expect(tester.takeException(), isNull);
  });
}
