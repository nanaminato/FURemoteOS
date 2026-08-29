import 'dart:convert';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

import 'language_catalog.dart';

/// Loads each feature's translation bundle and exposes them as one catalog.
///
/// The asset layout mirrors Avalonia's convention: `{locale}/{bundle}.json`
/// with each file shaped like
///
/// ```json
/// {
///   "Culture": "en-US",
///   "DisplayName": "English",
///   "SortOrder": 0,
///   "Strings": { "common.connect": "Connect" }
/// }
/// ```
///
/// Only `common.json` carries the three metadata fields; every other bundle
/// (apps, docker, …) has a plain `Strings` map at the top level.
class ModularAssetLoader extends AssetLoader {
  const ModularAssetLoader({this.catalog, this.assetBundle});

  final LanguageCatalog? catalog;
  final AssetBundle? assetBundle;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final activeCatalog = catalog ?? await LanguageCatalog.load();
    final sourceBundle = assetBundle ?? rootBundle;
    final localeName = locale.toStringWithSeparator(separator: '-');
    final localizedStrings = <String, dynamic>{};

    // Load the fallback locale first so every shipped key exists, then overlay
    // the active locale on top.
    final localesToLoad = <String>{
      LanguageCatalog.fallbackLocaleTag,
      localeName
    };
    for (final tag in localesToLoad) {
      if (!activeCatalog.isBuiltIn(tag)) continue;
      final definedKeys = <String>{};
      for (final bundle in activeCatalog.bundles) {
        final assetPath = '$path/$tag/$bundle.json';
        final decoded = jsonDecode(await sourceBundle.loadString(assetPath));
        if (decoded is! Map<String, dynamic>) {
          throw FormatException(
              'Translation bundle must be a JSON object: $assetPath');
        }
        final strings = decoded['Strings'];
        if (strings is! Map<String, dynamic>) {
          throw FormatException(
              'Translation bundle must contain a Strings map: $assetPath');
        }
        for (final key in strings.keys) {
          if (!definedKeys.add(key)) {
            throw FormatException(
                'Duplicate translation key "$key" in locale $tag.');
          }
        }
        _mergeFlat(localizedStrings, strings);
      }
    }

    final external = activeCatalog.externalTranslationsFor(localeName);
    if (external != null) _mergeFlat(localizedStrings, external);

    return localizedStrings;
  }

  static void _mergeFlat(
      Map<String, dynamic> target, Map<String, dynamic> source) {
    for (final entry in source.entries) {
      target[entry.key] = entry.value;
    }
  }
}
