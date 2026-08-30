import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/apps/help_center/help_center_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads localized Help Center markdown from bundled assets', () async {
    final catalog = await HelpCenterCatalog.load();

    final english = catalog.resolveLanguage('en-US');
    final chinese = catalog.resolveLanguage('zh');
    final japanese = catalog.resolveLanguage('ja-JP');

    expect(english.articles['docker/install']?.markdown, contains('systemd'));
    expect(chinese.articles['docker/install']?.title, '安装 Docker');
    expect(japanese.articles['docker/uninstall']?.title, 'Docker をアンインストールする');
  });
}
