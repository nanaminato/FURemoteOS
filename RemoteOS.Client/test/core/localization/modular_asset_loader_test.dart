import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:remoteos_client/core/localization/language_catalog.dart';
import 'package:remoteos_client/core/localization/modular_asset_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('merges every feature catalog for each configured locale', () async {
    final languageCatalog = await LanguageCatalog.load();
    final loader = ModularAssetLoader(catalog: languageCatalog);

    for (final language in languageCatalog.languages) {
      final locale = language.locale;
      final catalog = await loader.load('assets/translations', locale);

      expect(catalog['common'], isA<Map<String, dynamic>>());
      expect(catalog['login'], isA<Map<String, dynamic>>());
      expect(catalog['shell'], isA<Map<String, dynamic>>());
      expect(catalog['settings'], isA<Map<String, dynamic>>());
      expect(catalog['app'], isA<Map<String, dynamic>>());
    }
  });

  test('discovers a user language pack and falls back for missing keys',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('remoteos-language-');
    addTearDown(() => directory.delete(recursive: true));
    final pack = File('${directory.path}${Platform.pathSeparator}fr-FR.json');
    await pack.writeAsString('''
{
  "locale": "fr-FR",
  "displayName": "Français",
  "translations": {
    "common": { "connect": "Se connecter" },
    "login": { "title": "Connexion Bureau à distance" }
  }
}
''');

    final languageCatalog =
        await LanguageCatalog.load(languagePackDirectory: directory);
    final french = languageCatalog.languages.singleWhere(
      (language) => language.localeTag == 'fr-FR',
    );
    final catalog = await ModularAssetLoader(catalog: languageCatalog).load(
      'assets/translations',
      french.locale,
    );

    expect(french.displayName, 'Français');
    expect(catalog['common']['connect'], 'Se connecter');
    expect(catalog['common']['cancel'], 'Cancel');
    expect(catalog['login']['title'], 'Connexion Bureau à distance');
  });

  test('rejects duplicate keys across feature bundles', () async {
    final assets = _TestAssetBundle({
      'assets/translations/catalog.json': jsonEncode({
        'fallbackLocale': 'en-US',
        'bundles': ['shared', 'login'],
        'languages': [
          {'locale': 'en-US', 'displayName': 'English', 'sortOrder': 0},
        ],
      }),
      'assets/translations/shared/en-US.json': jsonEncode({
        'common': {'connect': 'Connect'},
      }),
      'assets/translations/login/en-US.json': jsonEncode({
        'common': {'connect': 'Sign in'},
      }),
    });
    final directory =
        await Directory.systemTemp.createTemp('remoteos-language-empty-');
    addTearDown(() => directory.delete(recursive: true));
    final catalog = await LanguageCatalog.load(
        bundle: assets, languagePackDirectory: directory);
    final loader = ModularAssetLoader(catalog: catalog, assetBundle: assets);

    await expectLater(
      loader.load('assets/translations', const Locale('en', 'US')),
      throwsA(isA<FormatException>()),
    );
  });
}

class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle(this.resources);

  final Map<String, String> resources;

  @override
  Future<ByteData> load(String key) async {
    final value = resources[key];
    if (value == null) throw StateError('Missing test asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
