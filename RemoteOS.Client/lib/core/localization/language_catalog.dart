import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A language available to the RemoteOS UI.
///
/// The display name lives with the pack rather than in another locale's
/// translations.  This means an externally installed language can always be
/// selected, even when none of the bundled languages know its name.
class LanguageOption {
  const LanguageOption({
    required this.localeTag,
    required this.displayName,
    required this.sortOrder,
    required this.builtIn,
  });

  final String localeTag;
  final String displayName;
  final int sortOrder;
  final bool builtIn;

  Locale get locale => _localeFromTag(localeTag);
}

/// Discovers bundled languages and optional user-installed language packs.
///
/// Bundled metadata belongs in `assets/translations/catalog.json`; code never
/// needs updating when a shipped language is added.  A user pack is a single
/// JSON file in [defaultLanguagePackDirectory] (or `REMOTEOS_LANGUAGE_PACKS`)
/// and contains its own locale, display name, and translations.
class LanguageCatalog {
  LanguageCatalog._({
    required List<LanguageOption> languages,
    required this.fallbackLocaleTag,
    required List<String> bundles,
    required Map<String, Map<String, dynamic>> externalTranslations,
  })  : languages = List.unmodifiable(
            languages..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))),
        bundles = List.unmodifiable(bundles),
        _externalTranslations = Map.unmodifiable(externalTranslations);

  static const _catalogAsset = 'assets/translations/catalog.json';

  final List<LanguageOption> languages;
  final String fallbackLocaleTag;
  final List<String> bundles;
  final Map<String, Map<String, dynamic>> _externalTranslations;

  Locale get fallbackLocale => _localeFromTag(fallbackLocaleTag);

  bool isBuiltIn(String localeTag) => languages.any((language) =>
      language.builtIn && _sameTag(language.localeTag, localeTag));

  Map<String, dynamic>? externalTranslationsFor(String localeTag) {
    for (final entry in _externalTranslations.entries) {
      if (_sameTag(entry.key, localeTag)) return entry.value;
    }
    return null;
  }

  static Future<LanguageCatalog> load({
    AssetBundle? bundle,
    Directory? languagePackDirectory,
  }) async {
    final source =
        jsonDecode(await (bundle ?? rootBundle).loadString(_catalogAsset));
    if (source is! Map<String, dynamic>) {
      throw const FormatException('The translation catalog must be an object.');
    }

    final bundles = _stringList(source['bundles'], 'bundles');
    final fallbackLocale =
        _requiredString(source['fallbackLocale'], 'fallbackLocale');
    final rawLanguages = source['languages'];
    if (rawLanguages is! List || rawLanguages.isEmpty) {
      throw const FormatException(
          'The translation catalog needs at least one language.');
    }

    final languages = <LanguageOption>[];
    final knownTags = <String>{};
    for (final rawLanguage in rawLanguages) {
      if (rawLanguage is! Map<String, dynamic>) {
        throw const FormatException('Each catalog language must be an object.');
      }
      final tag = _requiredString(rawLanguage['locale'], 'languages[].locale');
      if (!knownTags.add(tag.toLowerCase())) {
        throw FormatException(
            'The translation catalog contains $tag more than once.');
      }
      languages.add(LanguageOption(
        localeTag: tag,
        displayName: _requiredString(
            rawLanguage['displayName'], 'languages[].displayName'),
        sortOrder: rawLanguage['sortOrder'] is int
            ? rawLanguage['sortOrder'] as int
            : languages.length * 10,
        builtIn: true,
      ));
    }

    if (!knownTags.contains(fallbackLocale.toLowerCase())) {
      throw FormatException(
          'The fallback locale $fallbackLocale is not listed in the translation catalog.');
    }

    final externalTranslations = <String, Map<String, dynamic>>{};
    final externalOptions = <String, LanguageOption>{};
    final directory = languagePackDirectory ?? defaultLanguagePackDirectory();
    if (await directory.exists()) {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
          continue;
        }
        try {
          final pack = await _readLanguagePack(entity);
          externalTranslations[pack.option.localeTag] = pack.translations;
          externalOptions[pack.option.localeTag.toLowerCase()] = pack.option;
        } on FormatException {
          // Optional user content must never keep the client from opening.
        } on IOException {
          // A pack can disappear while it is being inspected.
        }
      }
    }

    final mergedLanguages = <LanguageOption>[
      for (final language in languages)
        if (externalOptions.remove(language.localeTag.toLowerCase())
            case final override?)
          // An override changes its own label/order, but it must still load
          // the bundled fragments before applying its partial translation map.
          LanguageOption(
            localeTag: language.localeTag,
            displayName: override.displayName,
            sortOrder: override.sortOrder,
            builtIn: true,
          )
        else
          language,
      ...externalOptions.values,
    ];

    return LanguageCatalog._(
      languages: mergedLanguages,
      fallbackLocaleTag: fallbackLocale,
      bundles: bundles,
      externalTranslations: externalTranslations,
    );
  }

  /// Default location for user-owned language packs on each desktop platform.
  static Directory defaultLanguagePackDirectory() {
    final override = Platform.environment['REMOTEOS_LANGUAGE_PACKS'];
    if (override != null && override.trim().isNotEmpty) {
      return Directory(override.trim());
    }

    final environment = Platform.environment;
    if (Platform.isWindows) {
      final appData = environment['APPDATA'] ?? environment['USERPROFILE'];
      return Directory(
          '${appData ?? '.'}${Platform.pathSeparator}RemoteOS${Platform.pathSeparator}languages');
    }
    if (Platform.isMacOS) {
      final home = environment['HOME'] ?? '.';
      return Directory(
          '$home${Platform.pathSeparator}Library${Platform.pathSeparator}Application Support${Platform.pathSeparator}RemoteOS${Platform.pathSeparator}languages');
    }

    final configHome = environment['XDG_CONFIG_HOME'] ??
        '${environment['HOME'] ?? '.'}${Platform.pathSeparator}.config';
    return Directory(
        '$configHome${Platform.pathSeparator}RemoteOS${Platform.pathSeparator}languages');
  }

  static Future<_ExternalLanguagePack> _readLanguagePack(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('${file.path} must contain a JSON object.');
    }
    final locale = _requiredString(decoded['locale'], '${file.path}: locale');
    final displayName =
        _requiredString(decoded['displayName'], '${file.path}: displayName');
    final translations = decoded['translations'];
    if (translations is! Map<String, dynamic>) {
      throw FormatException('${file.path}: translations must be an object.');
    }

    return _ExternalLanguagePack(
      option: LanguageOption(
        localeTag: locale,
        displayName: displayName,
        sortOrder:
            decoded['sortOrder'] is int ? decoded['sortOrder'] as int : 1000,
        builtIn: false,
      ),
      translations: _deepCopy(translations),
    );
  }
}

class _ExternalLanguagePack {
  const _ExternalLanguagePack({
    required this.option,
    required this.translations,
  });

  final LanguageOption option;
  final Map<String, dynamic> translations;
}

String _requiredString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$field must be a non-empty string.');
}

List<String> _stringList(Object? value, String field) {
  if (value is! List || value.any((entry) => entry is! String)) {
    throw FormatException('$field must be an array of strings.');
  }
  return value.cast<String>();
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

Locale _localeFromTag(String tag) {
  final parts = tag.replaceAll('_', '-').split('-');
  final scriptIndex = parts.length > 1 && parts[1].length == 4 ? 1 : null;
  final countryIndex = scriptIndex == null
      ? (parts.length > 1 ? 1 : null)
      : (parts.length > 2 ? 2 : null);
  return Locale.fromSubtags(
    languageCode: parts.first,
    scriptCode: scriptIndex == null ? null : parts[scriptIndex],
    countryCode: countryIndex == null ? null : parts[countryIndex],
  );
}

bool _sameTag(String left, String right) =>
    left.replaceAll('_', '-').toLowerCase() ==
    right.replaceAll('_', '-').toLowerCase();

/// The composition root supplies the loaded catalog once, before the UI starts.
final languageCatalogProvider = Provider<LanguageCatalog>(
  (ref) =>
      throw StateError('LanguageCatalog must be overridden at app startup.'),
);
