import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A language available to the RemoteOS UI.
///
/// The display name and sort order are stored alongside each locale's own
/// `common.json`, so externally installed language packs remain selectable
/// even when no bundled language knows their names.
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
/// Each bundled language is a subdirectory of `assets/translations/` whose
/// name is the locale tag (for example `en-US/`).  The directory contains one
/// JSON file per bundle (`common.json`, `docker.json`, …).  Only `common.json`
/// carries metadata:
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
/// A user-installed language pack lives in [defaultLanguagePackDirectory] (or
/// the `REMOTEOS_LANGUAGE_PACKS` environment variable) and follows the same
/// layout so external translators can ship a drop-in locale directory.
class LanguageCatalog {
  LanguageCatalog._({
    required List<LanguageOption> languages,
    required List<String> bundles,
    required Map<String, Map<String, dynamic>> externalTranslations,
  })  : languages = List.unmodifiable(
            languages..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))),
        bundles = List.unmodifiable(bundles),
        _externalTranslations = Map.unmodifiable(externalTranslations);

  /// Hard-coded fallback locale.  The bundled `en-US/` directory MUST exist.
  static const fallbackLocaleTag = 'en-US';

  /// Asset root that contains one subdirectory per locale.
  static const _assetRoot = 'assets/translations';

  final List<LanguageOption> languages;
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
    final sourceBundle = bundle ?? rootBundle;

    // --- Discover built-in locales by probing common.json ---
    // We can't list asset subdirectories at runtime, so we try known locale
    // names.  Missing ones are silently skipped.
    final candidates = <String>[
      'en-US',
      'zh-CN',
      'ja-JP',
    ];
    final languages = <LanguageOption>[];
    final knownTags = <String>{};
    final discoveredBundles = <String>{};

    for (final tag in candidates) {
      final commonPath = '$_assetRoot/$tag/common.json';
      try {
        final raw = await sourceBundle.loadString(commonPath);
        final parsed = jsonDecode(raw);
        if (parsed is! Map<String, dynamic>) continue;

        final displayName =
            _requiredString(parsed['DisplayName'], '$commonPath: DisplayName');
        final sortOrder = parsed['SortOrder'] is int
            ? parsed['SortOrder'] as int
            : languages.length * 10;

        if (!knownTags.add(tag.toLowerCase())) continue;
        languages.add(LanguageOption(
          localeTag: tag,
          displayName: displayName,
          sortOrder: sortOrder,
          builtIn: true,
        ));
      } on FlutterError {
        // Asset missing — the locale is simply not shipped.
      } on FormatException {
        continue;
      } catch (_) {
        // Custom test bundles may throw errors other than FlutterError when an
        // asset is missing.  Treat any load failure as "locale not shipped"
        // so bundle discovery is tolerant of non-standard asset bundles.
        continue;
      }

      // Probe other files in this locale dir to discover bundle names.
      // We don't have a directory listing, so we also try a known set.
      for (final file in <String>[
        'common',
        'apps',
        'code_editor',
        'docker',
        'explorer',
        'firewall',
        'login',
        'notepad',
        'settings',
        'shell',
        'task_manager',
        'terminal',
      ]) {
        final path = '$_assetRoot/$tag/$file.json';
        try {
          await sourceBundle.loadString(path);
          discoveredBundles.add(file);
        } catch (_) {
          // Not present in this locale — fine, it may be added later.
        }
      }
    }

    if (!knownTags.contains(fallbackLocaleTag.toLowerCase())) {
      throw FormatException(
          'The fallback locale $fallbackLocaleTag must ship with the '
          'application (missing assets/translations/$fallbackLocaleTag/common.json).');
    }

    final bundles = discoveredBundles.toList()..sort();

    // --- Scan external language packs ---
    final externalTranslations = <String, Map<String, dynamic>>{};
    final externalOptions = <String, LanguageOption>{};
    final directory = languagePackDirectory ?? defaultLanguagePackDirectory();
    if (await directory.exists()) {
      Future<void> readPack(Directory dir) async {
        try {
          final pack = await _readLanguagePack(dir);
          externalTranslations[pack.option.localeTag] = pack.translations;
          externalOptions[pack.option.localeTag.toLowerCase()] = pack.option;
        } on FormatException {
          // Optional user content must never keep the client from opening.
        } on IOException {
          // Malformed filesystem entries are skipped so unrelated files next
          // to a language pack do not break startup.
        }
      }

      // The root directory may be a single-locale pack (e.g. test temp
      // directories that place common.json at the root).  Otherwise treat
      // immediate subdirectories as locale packs.
      final rootCommon =
          File('${directory.path}${Platform.pathSeparator}common.json');
      if (await rootCommon.exists()) {
        await readPack(directory);
      } else {
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is! Directory) continue;
          await readPack(entity);
        }
      }
    }

    final mergedLanguages = <LanguageOption>[
      for (final language in languages)
        if (externalOptions.remove(language.localeTag.toLowerCase())
            case final override?)
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
      bundles: bundles,
      externalTranslations: externalTranslations,
    );
  }

  /// Default location for user-owned language packs on each desktop platform.
  ///
  /// A pack is a directory whose name is the locale tag and that contains
  /// `common.json` (and optionally other bundle files), mirroring the bundled
  /// layout.
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

  /// Reads an external language pack directory.
  ///
  /// Returns a flattened map of every `Strings` section from every bundle
  /// JSON found inside.  Only `common.json` carries [LanguageOption] metadata;
  /// if it is missing the pack is rejected.
  static Future<_ExternalLanguagePack> _readLanguagePack(Directory dir) async {
    final commonFile = File('${dir.path}${Platform.pathSeparator}common.json');
    if (!await commonFile.exists()) {
      throw FormatException(
          '${dir.path}: external language pack must contain common.json.');
    }

    final commonRaw = await commonFile.readAsString();
    final commonParsed = jsonDecode(commonRaw);
    if (commonParsed is! Map<String, dynamic>) {
      throw FormatException('${commonFile.path}: must contain a JSON object.');
    }

    final locale =
        _requiredString(commonParsed['Culture'], '${commonFile.path}: Culture');
    final displayName = _requiredString(
        commonParsed['DisplayName'], '${commonFile.path}: DisplayName');

    // Collect strings from every bundle file in this directory.
    final allStrings = <String, dynamic>{};
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      try {
        final raw = await entity.readAsString();
        final parsed = jsonDecode(raw);
        if (parsed is! Map<String, dynamic>) continue;
        final strings = parsed['Strings'];
        if (strings is! Map<String, dynamic>) continue;
        _mergeFlat(allStrings, strings);
      } on FormatException {
        continue;
      } on IOException {
        continue;
      }
    }

    return _ExternalLanguagePack(
      option: LanguageOption(
        localeTag: locale,
        displayName: displayName,
        sortOrder: commonParsed['SortOrder'] is int
            ? commonParsed['SortOrder'] as int
            : 1000,
        builtIn: false,
      ),
      translations: _deepCopy(allStrings),
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

void _mergeFlat(Map<String, dynamic> target, Map<String, dynamic> source) {
  for (final entry in source.entries) {
    target[entry.key] = entry.value;
  }
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
