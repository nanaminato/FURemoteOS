import 'dart:convert';

import 'package:flutter/services.dart';

class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.route,
    required this.title,
    required this.markdown,
  });

  final String id;
  final String route;
  final String title;
  final String markdown;
}

class HelpLanguageContent {
  const HelpLanguageContent({
    required this.code,
    required this.displayName,
    required this.articles,
  });

  final String code;
  final String displayName;
  final Map<String, HelpArticle> articles;
}

/// Offline guides packaged as assets with the built-in client application.
class HelpCenterCatalog {
  const HelpCenterCatalog(this._languages);

  static const _root = 'assets/help_center';
  final Map<String, HelpLanguageContent> _languages;

  Iterable<HelpLanguageContent> get languages => _languages.values;

  HelpLanguageContent resolveLanguage(String requested) {
    final exact = _languages[requested];
    if (exact != null) return exact;
    final neutral = requested.split('-').first.toLowerCase();
    return _languages.values.firstWhere(
      (content) => content.code.split('-').first.toLowerCase() == neutral,
      orElse: () => _languages['en']!,
    );
  }

  static Future<HelpCenterCatalog> load() async {
    final content = <String, HelpLanguageContent>{};
    for (final language in const ['en', 'zh-CN', 'ja-JP']) {
      final decoded = jsonDecode(
        await rootBundle.loadString('$_root/$language/index.json'),
      ) as Map<String, dynamic>;
      final articles = <String, HelpArticle>{};
      await _readNodes(
          language, decoded['nodes'] as List? ?? const [], articles);
      content[language] = HelpLanguageContent(
        code: language,
        displayName: decoded['displayName'] as String? ?? language,
        articles: articles,
      );
    }
    return HelpCenterCatalog(content);
  }

  static Future<void> _readNodes(
    String language,
    List nodes,
    Map<String, HelpArticle> target,
  ) async {
    for (final raw in nodes.whereType<Map>()) {
      final node = Map<String, dynamic>.from(raw);
      final route = node['route'] as String?;
      final file = node['file'] as String?;
      if (route != null && file != null) {
        final article = HelpArticle(
          id: node['id'] as String? ?? route,
          route: route,
          title: node['title'] as String? ?? route,
          markdown: await rootBundle.loadString('$_root/$language/$file'),
        );
        target[article.route] = article;
      }
      final children = node['children'];
      if (children is List) await _readNodes(language, children, target);
    }
  }
}
