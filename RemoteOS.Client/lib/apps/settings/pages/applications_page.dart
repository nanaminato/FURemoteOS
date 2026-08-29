import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/apps/app_registry.dart';
import '../../../core/theme/theme_service.dart';
import '../dialogs/settings_dialogs.dart';
import '../models.dart';
import '../settings_controller.dart';
import '../shared/widgets.dart';

/// Applications Settings page. Toggles between an installed-apps list and a
/// detail page for the selected entry. The detail page exposes open,
/// permissions, uninstall (disabled for built-in) and data management plus
/// the browser link-open target selector. Matches Avalonia's
/// `ApplicationsPage.axaml` and `AppDetailsPage.axaml` layout.
class SettingsApplicationsPage extends ConsumerWidget {
  const SettingsApplicationsPage({super.key, required this.palette});
  final ThemePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    if (state.appsSubpage == AppsSubpage.appDetails &&
        state.selectedAppId != null) {
      return _AppDetails(
          palette: palette, appId: state.selectedAppId!, parentState: state);
    }
    return _InstalledAppsList(palette: palette, state: state);
  }
}

class _InstalledAppsList extends ConsumerWidget {
  const _InstalledAppsList({required this.palette, required this.state});
  final ThemePalette palette;
  final SettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(appRegistryProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
            palette: palette,
            icon: Icons.apps_rounded,
            title: 'settings.page.applications'.tr(),
            subtitle: 'settings.apps.description'.tr()),
        if (state.appsActionStatus.isNotEmpty) ...[
          const SizedBox(height: 12),
          _statusBanner(palette, state.appsActionStatus),
        ],
        const SizedBox(height: 20),
        SettingsSectionTitle(
            palette: palette, title: 'settings.page.applications'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: palette, children: [
          for (final entry in registry.all)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => ctrl.openAppDetails(entry.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.accentMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(entry.icon, size: 20, color: palette.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.nameKey.tr(),
                              style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('settings.built_in'.tr(),
                              style: TextStyle(
                                  color: palette.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: palette.textTertiary),
                  ],
                ),
              ),
            ),
        ]),
      ],
    );
  }
}

class _AppDetails extends ConsumerWidget {
  const _AppDetails({
    required this.palette,
    required this.appId,
    required this.parentState,
  });
  final ThemePalette palette;
  final String appId;
  final SettingsState parentState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(appRegistryProvider);
    final entry = registry.get(appId);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final state = ref.watch(settingsControllerProvider);
    final isBrowser = appId == 'browser';
    final permissions = fakePermissionsFor(appId);
    const canUninstall = false; // MVP: only built-in apps are shipped
    if (entry == null) {
      // Should not happen, but fail safe.
      ctrl.openInstalledAppsList();
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: ctrl.openInstalledAppsList,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: palette.textSecondary),
                const SizedBox(width: 4),
                Text('settings.back_to_apps'.tr(),
                    style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SettingsCard(palette: palette, children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.accentMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(entry.icon, size: 28, color: palette.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.nameKey.tr(),
                        style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('ID: $appId',
                        style: TextStyle(
                            color: palette.textTertiary,
                            fontSize: 11,
                            fontFamily: 'monospace')),
                    const SizedBox(height: 6),
                    Text(() {
                      // ignore: dead_code
                      if (canUninstall) {
                        return 'settings.uninstall_available'.tr();
                      }
                      return 'settings.built_in'.tr();
                    }(),
                        style: TextStyle(
                            color: palette.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ctrl.launchApp(appId, entry.nameKey.tr(),
                      context: context),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text('common.open'.tr(),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await showInfoDialog(
                        context,
                        ref,
                        'settings.app_permissions'.tr(),
                        permissions.join('\n'));
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: Text('settings.manage_permissions'.tr(),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (!canUninstall) return;
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text('settings.uninstall'.tr(),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ctrl.clearLocalAppData,
                  icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                  label: Text('settings.clear_data'.tr(),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ]),
        if (state.appsActionStatus.isNotEmpty) ...[
          const SizedBox(height: 12),
          _statusBanner(palette, state.appsActionStatus),
        ],
        const SizedBox(height: 16),
        SettingsSectionTitle(
            palette: palette, title: 'settings.app_permissions'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: palette, children: [
          Text(
              permissions.isEmpty
                  ? 'settings.apps.no_permissions'.tr()
                  : 'settings.apps.permissions_requested'
                      .tr(namedArgs: {'count': '${permissions.length}'}),
              style: TextStyle(color: palette.textSecondary, fontSize: 12)),
          if (permissions.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final perm in permissions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 14, color: palette.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(perm,
                          style: TextStyle(
                              color: palette.textPrimary, fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ]),
        if (isBrowser) ...[
          const SizedBox(height: 16),
          SettingsSectionTitle(
              palette: palette, title: 'settings.apps.browser.settings'.tr()),
          const SizedBox(height: 8),
          SettingsCard(palette: palette, children: [
            Text('settings.apps.browser.link_open_target'.tr(),
                style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('settings.apps.browser.link_open_target'.tr(),
                  style: TextStyle(color: palette.textPrimary, fontSize: 13)),
              value: 0,
              groupValue: state.browserLinkTarget,
              onChanged: (v) => ctrl.setBrowserLinkTarget(v ?? 0),
            ),
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('settings.apps.browser.link_open_target'.tr(),
                  style: TextStyle(color: palette.textPrimary, fontSize: 13)),
              value: 1,
              groupValue: state.browserLinkTarget,
              onChanged: (v) => ctrl.setBrowserLinkTarget(v ?? 1),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.browserLinkTargetSaving
                        ? null
                        : ctrl.saveBrowserLinkTarget,
                    icon: state.browserLinkTargetSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text('common.save'.tr(),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            if (state.browserLinkTargetStatus.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(state.browserLinkTargetStatus,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12)),
            ],
          ]),
        ],
      ],
    );
  }
}

Widget _statusBanner(ThemePalette palette, String text) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: palette.accentMuted,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: palette.accent.withValues(alpha: 0.2)),
    ),
    child:
        Text(text, style: TextStyle(color: palette.textPrimary, fontSize: 12)),
  );
}
