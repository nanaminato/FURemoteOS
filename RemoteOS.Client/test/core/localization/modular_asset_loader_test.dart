import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/localization/modular_asset_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('merges every feature catalog for each supported locale', () async {
    const loader = ModularAssetLoader();

    for (final locale in const [
      Locale('en', 'US'),
      Locale('zh', 'CN'),
      Locale('ja', 'JP'),
    ]) {
      final catalog = await loader.load('assets/translations', locale);

      expect(catalog['common'], isA<Map<String, dynamic>>());
      expect(catalog['login'], isA<Map<String, dynamic>>());
      expect(catalog['shell'], isA<Map<String, dynamic>>());
      expect(catalog['settings'], isA<Map<String, dynamic>>());
      expect(catalog['app'], isA<Map<String, dynamic>>());
    }
  });
}
