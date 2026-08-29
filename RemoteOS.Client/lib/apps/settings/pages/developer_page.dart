import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_service.dart';
import '../dialogs/settings_dialogs.dart';
import '../settings_controller.dart';
import '../shared/widgets.dart';

/// Developer page. Toggles developer mode, shows the local pairing endpoint
/// (`http://127.0.0.1:5092`), a pairing token regenerate action and an
/// entry point for the network inspector when the dev mode is enabled.
/// Mirrors Avalonia's `DeveloperPage.axaml`.
class SettingsDeveloperPage extends ConsumerWidget {
  const SettingsDeveloperPage({super.key, required this.palette});
  final ThemePalette palette;

  static const String devEndpoint = 'http://127.0.0.1:5092';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
            palette: palette,
            icon: Icons.developer_mode_rounded,
            title: 'settings.page.developer'.tr(),
            subtitle: 'settings.developer_mode.description'.tr()),
        const SizedBox(height: 20),
        SettingsCard(palette: palette, children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('settings.developer_mode.title'.tr(),
                        style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('settings.developer_mode.note'.tr(),
                        style: TextStyle(
                            color: palette.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: state.devModeEnabled,
                onChanged: ctrl.setDevMode,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.connection_address'.tr(),
              value: devEndpoint),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 180,
                  child: Text('settings.pairing_token'.tr(),
                      style: TextStyle(
                          color: palette.textSecondary, fontSize: 13)),
                ),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: palette.surfaceSunken,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: palette.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(state.devPairingToken,
                              style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 12,
                                  fontFamily: 'monospace')),
                        ),
                        OutlinedButton.icon(
                          onPressed: ctrl.regeneratePairingToken,
                          icon: const Icon(Icons.autorenew_rounded, size: 14),
                          label: Text('settings.regenerate'.tr(),
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        SettingsSectionTitle(
            palette: palette, title: 'settings.network_inspector'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: palette, children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('settings.network_inspector'.tr(),
                        style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(state.networkInspectorStatus,
                        style: TextStyle(
                            color: palette.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: state.devModeEnabled
                    ? () {
                        showInfoSnack(
                            context, 'settings.network_inspector.ready'.tr(),
                            onFallback: () => ctrl.setImageMirrorStatus(
                                'settings.network_inspector.ready'.tr()));
                      }
                    : null,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text('settings.network_inspector.open'.tr(),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
