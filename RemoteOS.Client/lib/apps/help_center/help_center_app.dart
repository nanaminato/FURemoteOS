import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/apps/builtin_app_activations.dart';
import 'help_center_controller.dart';

/// Built-in, offline Help Center. Guides remain asset resources rather than
/// source-code strings so content can grow without expanding the UI module.
class HelpCenterApp extends StatefulWidget {
  const HelpCenterApp({super.key, required this.activation});

  final HelpCenterActivation activation;

  @override
  State<HelpCenterApp> createState() => _HelpCenterAppState();
}

class _HelpCenterAppState extends State<HelpCenterApp> {
  late final HelpCenterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HelpCenterController()..load();
    widget.activation.addListener(_applyActivation);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyActivation());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.selectLanguage(context.locale.toLanguageTag());
  }

  @override
  void dispose() {
    widget.activation.removeListener(_applyActivation);
    _controller.dispose();
    super.dispose();
  }

  void _applyActivation() {
    final uri = widget.activation.current;
    if (uri != null) _controller.activate(uri);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final catalog = _controller.catalog;
        if (catalog == null) {
          return Center(
            child: _controller.loadError == null
                ? const CircularProgressIndicator()
                : Text('app.help_center.load_failed'.tr()),
          );
        }
        final language = catalog.resolveLanguage(_controller.language);
        final article = _controller.currentArticle;
        return Row(
          children: [
            SizedBox(
              width: 260,
              child: ColoredBox(
                color: colors.surface,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('app.help_center.title'.tr(),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    DropdownButton<String>(
                      value: language.code,
                      isExpanded: true,
                      items: [
                        for (final item in catalog.languages)
                          DropdownMenuItem(
                            value: item.code,
                            child: Text(item.displayName),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) _controller.selectLanguage(value);
                      },
                    ),
                    const Divider(),
                    for (final guide in language.articles.values)
                      ListTile(
                        dense: true,
                        selected: guide.route == _controller.route,
                        title: Text(guide.title),
                        onTap: () => _controller.selectRoute(guide.route),
                      ),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: colors.outlineVariant),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: article == null
                    ? Text('app.help_center.guide_not_found'.tr())
                    : _MarkdownDocument(markdown: article.markdown),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarkdownDocument extends StatelessWidget {
  const _MarkdownDocument({required this.markdown});
  final String markdown;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final blocks = <Widget>[];
    var inCode = false;
    final code = StringBuffer();
    for (final line in markdown.split('\n')) {
      if (line.trim() == '```') {
        if (inCode) {
          blocks.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            color: colors.surfaceContainerHighest,
            child: SelectableText(code.toString(),
                style: const TextStyle(fontFamily: 'monospace')),
          ));
          code.clear();
        }
        inCode = !inCode;
      } else if (inCode) {
        code.writeln(line);
      } else if (line.startsWith('# ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(line.substring(2),
              style: Theme.of(context).textTheme.headlineSmall),
        ));
      } else if (line.startsWith('## ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(line.substring(3),
              style: Theme.of(context).textTheme.titleLarge),
        ));
      } else if (line.isNotEmpty) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SelectableText(line,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(height: 1.55)),
        ));
      } else {
        blocks.add(const SizedBox(height: 4));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }
}
