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

      // All keys are flat dot-notation after migration.
      expect(catalog['common.connect'], isA<String>());
      expect(catalog['docker.login_required'], isA<String>());
      expect(catalog['shell.connection.not_connected'], isA<String>());
      expect(catalog['settings.title'], isA<String>());
      expect(catalog['login.title'], isA<String>());
      expect(catalog['apps.desktop_unknown'], isA<String>());
    }
  });

  test('discovers a user language pack and falls back for missing keys',
      () async {
    final packDir = await Directory.systemTemp.createTemp('remoteos-language-');
    addTearDown(() => packDir.delete(recursive: true));

    // External pack is a directory that mirrors the bundled layout.
    await File('${packDir.path}${Platform.pathSeparator}common.json')
        .writeAsString('''
{
  "Culture": "fr-FR",
  "DisplayName": "Français",
  "SortOrder": 30,
  "Strings": {
    "common.connect": "Se connecter",
    "login.title": "Connexion Bureau à distance"
  }
}
''');

    final languageCatalog =
        await LanguageCatalog.load(languagePackDirectory: packDir);
    final french = languageCatalog.languages.singleWhere(
      (language) => language.localeTag == 'fr-FR',
    );
    final catalog = await ModularAssetLoader(catalog: languageCatalog).load(
      'assets/translations',
      french.locale,
    );

    expect(french.displayName, 'Français');
    expect(catalog['common.connect'], 'Se connecter');
    // Missing key falls back to en-US from the bundled locale.
    expect(catalog['common.cancel'], 'Cancel');
    expect(catalog['login.title'], 'Connexion Bureau à distance');
  });

  test('rejects duplicate keys across feature bundles', () async {
    final assets = _TestAssetBundle({
      'assets/translations/en-US/common.json': jsonEncode({
        'Culture': 'en-US',
        'DisplayName': 'English',
        'SortOrder': 0,
        'Strings': {'common.connect': 'Connect'},
      }),
      'assets/translations/en-US/login.json': jsonEncode({
        'Strings': {'common.connect': 'Sign in'},
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
