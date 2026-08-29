import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/theme_service.dart';
import '../shared/widgets.dart';

/// System (About) page: shows RemoteOS version, connection status, account,
/// host platform, workspace and device info. Mirrors the Avalonia
/// `SystemPage.axaml` layout.
class SettingsSystemPage extends ConsumerWidget {
  const SettingsSystemPage({super.key, required this.palette});

  final ThemePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final hostPlatform = Platform.operatingSystem;
    final deviceName = Platform.localHostname;
    final connected = auth.isAuthenticated;
    final nowStr = DateTime.now().toString().substring(0, 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('settings.page.system'.tr(),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary)),
              const SizedBox(height: 2),
              Text('settings.system.tagline'.tr(),
                  style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                      height: 1.35)),
            ],
          ),
        ),
        SettingsCard(palette: palette, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('settings.about'.tr(),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.textSecondary)),
          ),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.version'.tr(),
              value: 'RemoteOS 0.1'),
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
        ]),
        const SizedBox(height: 16),
        SettingsCard(palette: palette, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('settings.account_workspace'.tr(),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.textSecondary)),
          ),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.username'.tr(),
              value: auth.username ?? '—'),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.host_platform'.tr(),
              value: hostPlatform),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.workspace'.tr(),
              value: '${auth.workspaceName ?? '—'} Workspace'),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.device'.tr(),
              value: deviceName),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.device_role'.tr(),
              value: 'Controller'),
          SettingsInfoRow(
              palette: palette,
              label: 'settings.last_login'.tr(),
              value: nowStr),
        ]),
        const SizedBox(height: 16),
        Text('settings.system.description'.tr(),
            style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary.withValues(alpha: 0.75))),
      ],
    );
  }
}
