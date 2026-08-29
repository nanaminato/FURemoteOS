import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/language_catalog.dart';
import '../../../core/theme/theme_service.dart';
import '../../../features/workspace/application/workspace_sync_coordinator.dart';
import '../settings_controller.dart';
import '../shared/widgets.dart';

/// tiny helper to avoid duplicate extension definitions across pages.
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

/// Time & Language settings page. Provides time/date format selectors,
/// timezone readout, display language and region ComboBoxes. Matches the
/// corresponding Avalonia `TimeLanguagePage.axaml` set of controls.
class SettingsTimeLanguagePage extends ConsumerWidget {
  const SettingsTimeLanguagePage({super.key, required this.palette});
  final ThemePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.watch(settingsControllerProvider.notifier);
    final state = ref.watch(settingsControllerProvider);
    final languages = ref.watch(languageCatalogProvider).languages;
    final prefs = ref.watch(workspaceSyncProvider).preferences;
    final timeFormat = prefs?.timeFormat ?? '24h';
    final dateFormat = prefs?.dateFormat ?? 'yyyy/M/d';
    final language = prefs?.language ?? 'en-US';
    final region = prefs?.region ?? 'en-US';

    const timeFormats = ['24h', '12h'];
    const dateFormats = ['yyyy/M/d', 'yyyy-MM-dd', 'M/d/yyyy', 'dddd, M/d'];
    const regions = ['zh-CN', 'en-US', 'ja-JP'];

    final t = state.sampleClock;
    final timeSample = ctrl.formatTimeSample(t, timeFormat, language);
    final dateSample = ctrl.formatDateSample(t, dateFormat, language);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
            palette: palette,
            icon: Icons.translate_rounded,
            title: 'settings.page.time_language'.tr(),
            subtitle: 'settings.language_region.description'.tr()),
        const SizedBox(height: 20),
        SettingsSectionTitle(
            palette: palette, title: 'settings.time.section'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: palette, children: [
          SettingsLabeledRow(
            palette: palette,
            label: 'settings.time.format'.tr(),
            description: timeSample,
            control: SettingsComboBox<String>(
              palette: palette,
              value: timeFormats.contains(timeFormat) ? timeFormat : '24h',
              items: [
                for (final f in timeFormats)
                  DropdownMenuItem(
                      value: f,
                      child: Text(f, style: const TextStyle(fontSize: 13))),
              ],
              onChanged: (v) {
                if (v == null) return;
                final current = ref.read(workspaceSyncProvider).preferences;
                if (current == null) return;
                ref
                    .read(workspaceSyncProvider.notifier)
                    .queuePreferences(current.copyWith(timeFormat: v));
              },
            ),
          ),
          const SizedBox(height: 8),
          SettingsLabeledRow(
            palette: palette,
            label: 'settings.date.format'.tr(),
            description: dateSample,
            control: SettingsComboBox<String>(
              palette: palette,
              value: dateFormats.contains(dateFormat) ? dateFormat : 'yyyy/M/d',
              items: [
                for (final f in dateFormats)
                  DropdownMenuItem(
                      value: f,
                      child: Text(f, style: const TextStyle(fontSize: 13))),
              ],
              onChanged: (v) {
                if (v == null) return;
                final current = ref.read(workspaceSyncProvider).preferences;
                if (current == null) return;
                ref
                    .read(workspaceSyncProvider.notifier)
                    .queuePreferences(current.copyWith(dateFormat: v));
              },
            ),
          ),
          const SizedBox(height: 8),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.time_zone'.tr(),
              value: ctrl.timeZoneDisplayName()),
        ]),
        const SizedBox(height: 20),
        SettingsSectionTitle(
            palette: palette, title: 'settings.language_region.section'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: palette, children: [
          SettingsLabeledRow(
            palette: palette,
            label: 'settings.display_language'.tr(),
            control: SettingsComboBox<String>(
              palette: palette,
              value: languages.any((l) => l.localeTag == language)
                  ? language
                  : (languages.firstOrNull?.localeTag ?? 'en-US'),
              items: [
                for (final l in languages)
                  DropdownMenuItem(
                      value: l.localeTag,
                      child: Text(l.displayName,
                          style: const TextStyle(fontSize: 13))),
              ],
              onChanged: (v) {
                if (v == null) return;
                final lang =
                    languages.where((x) => x.localeTag == v).firstOrNull;
                if (lang != null) {
                  // ignore: use_build_context_synchronously
                  context.setLocale(lang.locale);
                }
                final current = ref.read(workspaceSyncProvider).preferences;
                if (current == null) return;
                ref
                    .read(workspaceSyncProvider.notifier)
                    .queuePreferences(current.copyWith(language: v));
              },
            ),
          ),
          const SizedBox(height: 8),
          SettingsLabeledRow(
            palette: palette,
            label: 'settings.region_format'.tr(),
            control: SettingsComboBox<String>(
              palette: palette,
              value: regions.contains(region) ? region : 'en-US',
              items: [
                for (final r in regions)
                  DropdownMenuItem(
                      value: r,
                      child: Text(r, style: const TextStyle(fontSize: 13))),
              ],
              onChanged: (v) {
                if (v == null) return;
                final current = ref.read(workspaceSyncProvider).preferences;
                if (current == null) return;
                ref
                    .read(workspaceSyncProvider.notifier)
                    .queuePreferences(current.copyWith(region: v));
              },
            ),
          ),
        ]),
      ],
    );
  }
}
