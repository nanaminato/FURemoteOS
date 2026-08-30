import 'package:flutter/foundation.dart';

/// App-owned activation state contains only a validated Shell URI. It never
/// exposes another app's widget, ViewModel, repository, or host path.
class SettingsActivation extends ChangeNotifier {
  Uri? _current;
  Uri? get current => _current;

  void handle(Uri uri) {
    _current = uri;
    notifyListeners();
  }
}

abstract final class BuiltinAppActivations {
  static final settings = SettingsActivation();

  static bool canHandleSettings(Uri uri) {
    if (uri.scheme != 'remoteos' || uri.host != 'settings') return false;
    final segments = uri.pathSegments;
    if (segments.length == 1) {
      return segments.single == 'personalization' || segments.single == 'apps';
    }
    return segments.length == 3 &&
        segments[0] == 'apps' &&
        segments[1].isNotEmpty &&
        segments[2] == 'permissions';
  }
}
