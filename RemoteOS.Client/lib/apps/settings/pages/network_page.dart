import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/theme_service.dart';
import '../settings_controller.dart';
import '../shared/widgets.dart';

/// Network diagnostic page. Reports connection/authentication status,
/// latency to the server and the list of local network addresses. Matches
/// Avalonia's `NetworkPage.axaml` surface area.
class SettingsNetworkPage extends ConsumerWidget {
  const SettingsNetworkPage({super.key, required this.palette});
  final ThemePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final connected = auth.isAuthenticated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
            palette: palette,
            icon: Icons.network_check_rounded,
            title: 'settings.page.network'.tr(),
            subtitle: 'settings.network.description'.tr()),
        const SizedBox(height: 20),
        SettingsSectionTitle(
            palette: palette, title: 'settings.network.connection'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: palette, children: [
          SettingsInfoRow(
            palette: palette,
            label: 'settings.connection_status'.tr(),
            value: connected
                ? 'settings.value.connected'.tr()
                : 'settings.value.not_connected'.tr(),
            valueColor: connected ? palette.success : palette.textTertiary,
          ),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.server'.tr(),
              value: auth.serverUrl ?? '—'),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.workspace'.tr(),
              value: auth.workspaceName ?? '—'),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.network.latency'.tr(),
              value: state.networkLatencyText.isEmpty
                  ? 'settings.network.not_tested'.tr()
                  : state.networkLatencyText),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 180),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (connected && !state.networkTesting)
                      ? ctrl.testLatency
                      : null,
                  icon: state.networkTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.speed_rounded, size: 16),
                  label: Text('settings.test_connection'.tr(),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 20),
        SettingsSectionTitle(
            palette: palette, title: 'settings.network.addresses'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: palette, children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    state.networkAddrStatus.isEmpty
                        ? 'settings.network.not_loaded'.tr()
                        : state.networkAddrStatus,
                    style:
                        TextStyle(color: palette.textSecondary, fontSize: 12)),
              ),
              OutlinedButton.icon(
                onPressed:
                    !state.networkAddrLoading ? ctrl.refreshAddresses : null,
                icon: state.networkAddrLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text('settings.network.refresh_addresses'.tr(),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (state.networkAddresses.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            for (int i = 0; i < state.networkAddresses.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 180,
                      child: Text(state.networkAddresses[i].iface,
                          style: TextStyle(
                              color: palette.textSecondary, fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(state.networkAddresses[i].address,
                          style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 13,
                              fontFamily: 'monospace')),
                    ),
                  ],
                ),
              ),
          ],
        ]),
      ],
    );
  }
}
