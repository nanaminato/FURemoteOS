import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/localization/language_catalog.dart';
import 'package:remoteos_client/core/localization/modular_asset_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every static tr() key used by the client is available in each locale',
      () async {
    final catalog = await LanguageCatalog.load();
    final loader = ModularAssetLoader(catalog: catalog);
    final usedKeys = await _readStaticTranslationKeys();

    for (final language in catalog.languages) {
      final translations = await loader.load(
        'assets/translations',
        language.locale,
      );
      for (final key in usedKeys) {
        expect(
          translations[key],
          isA<String>(),
          reason: '${language.localeTag} is missing translation key $key',
        );
      }
    }
  });
}

Future<Set<String>> _readStaticTranslationKeys() async {
  final keys = <String>{};
  final expression = RegExp(r'''['"]([a-z][a-z0-9_.]+)['"]\s*\.tr\(''');

  await for (final entity in Directory('lib').list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = await entity.readAsString();
    keys.addAll(expression
        .allMatches(source)
        .map((match) => match.group(1)!)
        .where((key) => key.isNotEmpty));
  }

  return keys;
}
