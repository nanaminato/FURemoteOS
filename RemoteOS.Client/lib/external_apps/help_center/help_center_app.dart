import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'help_center_package.dart';

/// Read-only localized guide window supplied by the Help Center package.
class HelpCenterApp extends StatelessWidget {
  const HelpCenterApp({super.key, required this.package});

  final HelpCenterPackage package;

  @override
  Widget build(BuildContext context) {
    package.selectLanguage(context.locale);
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: package,
      builder: (context, _) => Row(
        children: [
          SizedBox(
            width: 230,
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
                  _GuideTile(
                    label: 'app.help_center.docker_install'.tr(),
                    selected: package.route == 'docker/install',
                    onTap: () => package.selectRoute('docker/install'),
                  ),
                  _GuideTile(
                    label: 'app.help_center.docker_uninstall'.tr(),
                    selected: package.route == 'docker/uninstall',
                    onTap: () => package.selectRoute('docker/uninstall'),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: colors.outlineVariant),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: SelectableText(
                package.articleForCurrentLanguage(),
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        selected: selected,
        title: Text(label),
        onTap: onTap,
      );
}
