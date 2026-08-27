import 'dart:convert';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

/// Loads each feature's translation bundle and exposes them as one catalog.
///
/// Translation keys stay stable (for example, `settings.title`), while the
/// files that own them live next to their feature-level catalog.
class ModularAssetLoader extends AssetLoader {
  const ModularAssetLoader();

  static const _bundles = <String>[
    'shared',
    'login',
    'shell',
    'settings',
    'apps',
  ];

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final localeName = locale.toStringWithSeparator(separator: '-');
    final catalog = <String, dynamic>{};

    for (final bundle in _bundles) {
      final assetPath = '$path/$bundle/$localeName.json';
      final decoded = jsonDecode(await rootBundle.loadString(assetPath));
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
            'Translation bundle must be a JSON object: $assetPath');
      }
      _merge(catalog, decoded);
    }

    return catalog;
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
