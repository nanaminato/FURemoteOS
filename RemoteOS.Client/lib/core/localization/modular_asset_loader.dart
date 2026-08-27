import 'dart:convert';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

import 'language_catalog.dart';

/// Loads each feature's translation bundle and exposes them as one catalog.
///
/// Translation keys stay stable (for example, `settings.title`), while the
/// files that own them live next to their feature-level catalog.
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

    // Load English (or another configured source locale) first.  An optional
    // pack is allowed to translate only the strings it owns without exposing
    // resource keys for the rest of the UI.
    final localesToLoad = <String>{activeCatalog.fallbackLocaleTag, localeName};
    for (final tag in localesToLoad) {
      if (!activeCatalog.isBuiltIn(tag)) continue;
      final definedKeys = <String>{};
      for (final bundle in activeCatalog.bundles) {
        final assetPath = '$path/$bundle/$tag.json';
        final decoded = jsonDecode(await sourceBundle.loadString(assetPath));
        if (decoded is! Map<String, dynamic>) {
          throw FormatException(
              'Translation bundle must be a JSON object: $assetPath');
        }
        for (final key in _leafKeys(decoded)) {
          if (!definedKeys.add(key)) {
            throw FormatException(
                'Duplicate translation key "$key" in locale $tag.');
          }
        }
        _merge(localizedStrings, decoded);
      }
    }

    final external = activeCatalog.externalTranslationsFor(localeName);
    if (external != null) _merge(localizedStrings, external);

    return localizedStrings;
  }

  static Iterable<String> _leafKeys(
    Map<String, dynamic> source, {
    String prefix = '',
  }) sync* {
    for (final entry in source.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value case final Map<String, dynamic> nested) {
        yield* _leafKeys(nested, prefix: key);
      } else {
        yield key;
      }
    }
  }

  static void _merge(Map<String, dynamic> target, Map<String, dynamic> source) {
    for (final entry in source.entries) {
      final current = target[entry.key];
      final incoming = entry.value;
      if (current is Map<String, dynamic> && incoming is Map<String, dynamic>) {
        _merge(current, incoming);
      } else {
        target[entry.key] = incoming;
      }
    }
  }
}
