import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/screens/login/login_screen.dart';
import 'package:remoteos_client/core/localization/language_catalog.dart';
import 'package:remoteos_client/core/localization/modular_asset_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('expanded login options fit without a scrolling form',
      (tester) async {
    await EasyLocalization.ensureInitialized();
    await tester.binding.setSurfaceSize(const Size(800, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final catalog = await LanguageCatalog.load();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales:
            catalog.languages.map((language) => language.locale).toList(),
        path: 'assets/translations',
        assetLoader: ModularAssetLoader(catalog: catalog),
        fallbackLocale: catalog.fallbackLocale,
        child: ProviderScope(
          overrides: [languageCatalogProvider.overrideWithValue(catalog)],
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

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(Scrollbar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
