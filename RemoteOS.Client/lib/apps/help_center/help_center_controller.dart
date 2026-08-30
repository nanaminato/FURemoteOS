import 'package:flutter/foundation.dart';

import 'help_center_catalog.dart';

class HelpCenterController extends ChangeNotifier {
  HelpCenterCatalog? _catalog;
  String _language = 'en';
  String _route = 'docker/install';
  Object? _loadError;
  Uri? _pendingActivation;

  HelpCenterCatalog? get catalog => _catalog;
  String get language => _language;
  String get route => _route;
  Object? get loadError => _loadError;

  Future<void> load() async {
    try {
      _catalog = await HelpCenterCatalog.load();
      _language = _catalog!.resolveLanguage(_language).code;
      final pending = _pendingActivation;
      _pendingActivation = null;
      if (pending != null) activate(pending);
    } catch (error) {
      _loadError = error;
    }
    notifyListeners();
  }

  void selectLanguage(String requested) {
    final catalog = _catalog;
    if (catalog == null) {
      _language = requested;
      return;
    }
    final resolved = catalog.resolveLanguage(requested).code;
    if (resolved == _language) return;
    _language = resolved;
    notifyListeners();
  }

  void selectRoute(String route) {
    if (_catalog?.resolveLanguage(_language).articles.containsKey(route) !=
            true ||
        route == _route) {
      return;
    }
    _route = route;
    notifyListeners();
  }

  void activate(Uri uri) {
    if (_catalog == null) {
      _pendingActivation = uri;
      final requestedLanguage = uri.queryParameters['lang'];
      if (requestedLanguage != null) _language = requestedLanguage;
      return;
    }
    final route = uri.pathSegments.skip(1).join('/');
    if (route.isEmpty ||
        _catalog?.resolveLanguage(_language).articles.containsKey(route) !=
            true) {
      return;
    }
    final requestedLanguage = uri.queryParameters['lang'];
    if (requestedLanguage != null) selectLanguage(requestedLanguage);
    selectRoute(route);
  }

  HelpArticle? get currentArticle =>
      _catalog?.resolveLanguage(_language).articles[_route];
}
