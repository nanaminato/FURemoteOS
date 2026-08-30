import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_service.dart';
import '../../../core/apps/app_ids.dart';
import '../models.dart';
import '../settings_controller.dart';
import '../shared/widgets.dart';

/// Default Apps settings page. Users can add scheme -> app associations,
/// pick the scheme via an autocomplete field (supporting URL schemes +
/// file extensions) and the target app via a ComboBox filtered to
/// compatible entries. Matches Avalonia's `DefaultAppsPage.axaml`.
class SettingsDefaultAppsPage extends ConsumerWidget {
  const SettingsDefaultAppsPage({super.key, required this.palette});
  final ThemePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('settings.page.default_apps'.tr(),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary)),
              const SizedBox(height: 2),
              Text('settings.default_apps.description'.tr(),
                  style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                      height: 1.35)),
            ],
          ),
        ),
        Row(
          children: [
            FilledButton.icon(
              onPressed: ctrl.addDefaultMapping,
              icon: const Icon(Icons.add, size: 16),
              label: Text('settings.default_apps.add'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.defaultMappings.isEmpty)
          Text('settings.default_apps.empty'.tr(),
              style: TextStyle(color: palette.textTertiary, fontSize: 12))
        else
          for (int i = 0; i < state.defaultMappings.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _DefaultAppRow(
                key: ValueKey(
                    'row_${identityHashCode(state.defaultMappings[i])}_$i'),
                palette: palette,
                mapping: state.defaultMappings[i],
                availableSchemes: state.availableSchemes,
                appOptions: state.appOptions,
                onSchemeChanged: (v) =>
                    ctrl.updateDefaultAppScheme(state.defaultMappings[i], v),
                onAppIdChanged: (v) =>
                    ctrl.updateDefaultAppId(state.defaultMappings[i], v),
                onRemove: () =>
                    ctrl.removeDefaultMapping(state.defaultMappings[i])),
          ],
      ],
    );
  }
}

class _DefaultAppRow extends StatelessWidget {
  const _DefaultAppRow({
    super.key,
    required this.palette,
    required this.mapping,
    required this.availableSchemes,
    required this.appOptions,
    required this.onSchemeChanged,
    required this.onAppIdChanged,
    required this.onRemove,
  });
  final ThemePalette palette;
  final DefaultAppMappingUi mapping;
  final List<String> availableSchemes;
  final List<AppOptionUi> appOptions;
  final ValueChanged<String> onSchemeChanged;
  final ValueChanged<String> onAppIdChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final compatible = _compatibleAppsFor(mapping.scheme);
    final appList = compatible.isNotEmpty ? compatible : appOptions;
    final currentApp =
        appOptions.where((a) => a.id == mapping.appId).firstOrNull ??
            appList.first;

    return SettingsCard(palette: palette, children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: _AutocompleteField(
              key: ValueKey(
                  'sch_${mapping.scheme}_${identityHashCode(mapping)}'),
              initialValue: mapping.scheme,
              suggestions: availableSchemes,
              labelText: 'settings.default_apps.scheme'.tr(),
              palette: palette,
              onSubmitted: onSchemeChanged,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SettingsComboBox<String>(
              palette: palette,
              value: appList.any((a) => a.id == currentApp.id)
                  ? currentApp.id
                  : appList.first.id,
              items: [
                for (final app in appList)
                  DropdownMenuItem(
                      value: app.id,
                      child: Text(app.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13))),
              ],
              onChanged: (v) {
                if (v == null) return;
                onAppIdChanged(v);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'common.delete'.tr(),
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: palette.textTertiary),
          ),
        ],
      ),
    ]);
  }

  List<AppOptionUi> _compatibleAppsFor(String scheme) {
    if (scheme.startsWith('.')) {
      final declared = appOptions
          .where((a) =>
              a.extensions.any((e) => e.toLowerCase() == scheme.toLowerCase()))
          .toList();
      if (declared.isNotEmpty) return declared;
      return appOptions.where((a) => a.extensions.isNotEmpty).toList();
    }
    const universal = {'http', 'https', 'mailto', 'ftp'};
    if (universal.contains(scheme.toLowerCase())) {
      return appOptions
          .where((a) =>
              a.schemes.any((s) => s.toLowerCase() == scheme.toLowerCase()) ||
              (universal.contains(scheme.toLowerCase()) &&
                  a.id == AppIds.browser))
          .toList();
    }
    return appOptions
        .where((a) =>
            a.schemes.any((s) => s.toLowerCase() == scheme.toLowerCase()))
        .toList();
  }
}

/// Autocomplete TextField used for scheme/extension input.
class _AutocompleteField extends StatefulWidget {
  const _AutocompleteField({
    super.key,
    required this.initialValue,
    required this.suggestions,
    required this.labelText,
    required this.palette,
    required this.onSubmitted,
  });
  final String initialValue;
  final List<String> suggestions;
  final String labelText;
  final ThemePalette palette;
  final ValueChanged<String> onSubmitted;

  @override
  State<_AutocompleteField> createState() => _AutocompleteFieldState();
}

class _AutocompleteFieldState extends State<_AutocompleteField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: _ctrl,
      focusNode: FocusNode(),
      optionsBuilder: (value) {
        final text = value.text.trim().toLowerCase();
        if (text.isEmpty) return widget.suggestions.take(20);
        return widget.suggestions
            .where((s) => s.toLowerCase().contains(text))
            .take(20);
      },
      onSelected: (v) {
        _ctrl.text = v;
        widget.onSubmitted(v);
      },
      fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) =>
          TextField(
        controller: controller,
        focusNode: focusNode,
        onSubmitted: (_) {
          onFieldSubmitted();
          widget.onSubmitted(controller.text);
        },
        style: TextStyle(color: widget.palette.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          labelText: widget.labelText,
          labelStyle:
              TextStyle(color: widget.palette.textSecondary, fontSize: 12),
        ),
      ),
      optionsViewBuilder: (ctx, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          color: widget.palette.surfaceRaised,
          child: SizedBox(
            width: 200,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (c, i) {
                final opt = options.elementAt(i);
                return InkWell(
                  onTap: () => onSelected(opt),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(opt,
                        style: TextStyle(
                            color: widget.palette.textPrimary, fontSize: 13)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
