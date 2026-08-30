import 'package:flutter/material.dart';

import '../../core/apps/application_manifest.dart';

/// Precompiled adapter for the declarative Help Center `.roapp` sample.
///
/// Its content is local and it exposes no Shell service or host path. This is
/// the supported Flutter AOT equivalent of the Avalonia sample package.
class HelpCenterPackage extends ChangeNotifier {
  static final manifest = ApplicationManifest(
    id: 'com.remoteos.example.help-center',
    version: '0.1.0-dev',
    descriptionKey: 'app.help_center.description',
    instancePolicy: ApplicationInstancePolicy.singleWindow,
    supportedUriSchemes: const ['help'],
    isExternal: true,
  );

  String _language = 'en';
  String _route = 'docker/install';

  String get language => _language;
  String get route => _route;

  bool canHandle(Uri uri) {
    if (uri.scheme.toLowerCase() != 'help' ||
        uri.host.toLowerCase() != 'guide') {
      return false;
    }
    return _articles.containsKey(uri.path.replaceFirst(RegExp(r'^/'), ''));
  }

  void handle(Uri uri) {
    if (!canHandle(uri)) return;
    _route = uri.path.replaceFirst(RegExp(r'^/'), '');
    final requested = uri.queryParameters['lang'];
    if (requested != null && _articles.containsKey(_route)) {
      _language = _resolveLanguage(requested);
    }
    notifyListeners();
  }

  void selectLanguage(Locale locale) {
    final next = _resolveLanguage(locale.toLanguageTag());
    if (next == _language) return;
    _language = next;
    notifyListeners();
  }

  void selectRoute(String value) {
    if (!_articles.containsKey(value) || value == _route) return;
    _route = value;
    notifyListeners();
  }

  String articleForCurrentLanguage() =>
      _articles[_route]![_language] ?? _articles[_route]!['en']!;

  static String _resolveLanguage(String value) {
    final normalized = value.toLowerCase();
    if (normalized.startsWith('zh')) return 'zh-CN';
    if (normalized.startsWith('ja')) return 'ja';
    return 'en';
  }

  static const _articles = <String, Map<String, String>>{
    'docker/install': {
      'en':
          '# Install Docker\n\nOpen Docker Manager from the RemoteOS start menu. The connected server must expose the Docker capability.\n\n1. Choose **Install Docker**.\n2. Review the server-side permission prompt.\n3. Refresh the engine status after installation completes.',
      'zh-CN':
          '# 安装 Docker\n\n从 RemoteOS 开始菜单打开 Docker 管理器。已连接的服务器必须提供 Docker 能力。\n\n1. 选择“安装 Docker”。\n2. 查看服务器端权限提示。\n3. 安装完成后刷新引擎状态。',
      'ja':
          '# Docker をインストールする\n\nRemoteOS のスタートメニューから Docker Manager を開きます。接続中のサーバーには Docker capability が必要です。\n\n1. **Install Docker** を選びます。\n2. サーバー側の権限確認を確認します。\n3. 完了後にエンジン状態を更新します。',
    },
    'docker/uninstall': {
      'en':
          '# Uninstall Docker\n\nStop workloads first. In Docker Manager, select **Uninstall Docker** and confirm the server-side operation. Existing images and volumes can be removed only by an explicit server-side choice.',
      'zh-CN':
          '# 卸载 Docker\n\n请先停止工作负载。在 Docker 管理器中选择“卸载 Docker”，并确认服务器端操作。现有镜像和卷只能在服务器端明确选择后删除。',
      'ja':
          '# Docker をアンインストールする\n\n先にワークロードを停止します。Docker Manager で **Uninstall Docker** を選び、サーバー側の操作を確認します。イメージとボリュームの削除には明示的なサーバー側の選択が必要です。',
    },
  };
}

/// Application-lifetime package state. Its window widget listens to this
/// notifier; closing the managed window does not lose the current guide.
abstract final class HelpCenterPackages {
  static final instance = HelpCenterPackage();
}
