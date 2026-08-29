// Settings feature — repository interface + workspace-backed implementation.
//
// Responsibilities (ARCHITECTURE.md § 11):
//   * Translate between the workspace preferences DTO and domain-level
//     DefaultAppMappingUi / accent / theme sync operations.
//   * Own the clipboard side-effects for theme import/export (MVP: the
//     ViewModel performs the clipboard call directly, the repository just
//     encapsulates persistence + parsing).
//   * Expose a single `SettingsRepository` interface so tests can swap it.

import 'dart:convert';
import 'dart:io' show HttpClient, NetworkInterface;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

import '../../../core/apps/app_registry.dart';
import '../../../core/theme/theme_models.dart';
import '../../../core/theme/theme_palette_defaults.dart';
import '../../../core/theme/theme_service.dart';
import '../../workspace/application/workspace_sync_coordinator.dart';
import '../../workspace/domain/workspace_models.dart';
import '../domain/settings_models.dart';
import '../domain/settings_state.dart';

abstract class SettingsRepository {
  // ----- DTO -> UI mapping --------------------------------------------------

  List<AppOptionUi> buildAppOptions(AppRegistry registry);
  List<String> collectSchemes(List<AppOptionUi> apps);
  List<DefaultAppMappingUi> currentDefaultMappings(
      WorkspaceSyncCoordinator workspace);

  // ----- Theme persistence -------------------------------------------------

  void queueTheme(
    ThemeNotifier theme,
    WorkspaceSyncCoordinator workspace,
  );

  void persistDefaultApps(
    SettingsState state,
    WorkspaceSyncCoordinator workspace,
  );

  // ----- Theme clipboard import / export -----------------------------------

  Future<String> importTheme(
      ThemeNotifier theme, WorkspaceSyncCoordinator workspace);
  Future<String> exportTheme(ThemeNotifier theme);
  Future<bool> deleteTheme(
    ThemeNotifier theme,
    WorkspaceSyncCoordinator workspace,
    Future<bool?> Function(String title, String message) confirm,
  );

  // ----- Network I/O -------------------------------------------------------

  Future<({bool ok, String text})> testLatency({
    required String? serverUrl,
    required String? accessToken,
    required bool authenticated,
  });

  Future<List<({String iface, String address})>> loadNetworkAddresses();
}

class WorkspaceSettingsRepository implements SettingsRepository {
  WorkspaceSettingsRepository();

  @override
  List<AppOptionUi> buildAppOptions(AppRegistry registry) {
    final apps = <AppOptionUi>[];
    for (final e in registry.all) {
      apps.add(AppOptionUi(
        id: e.id,
        displayName: e.nameKey.tr(),
        schemes: defaultSchemesFor(e.id),
        extensions: defaultExtensionsFor(e.id),
      ));
    }
    return apps;
  }

  @override
  List<String> collectSchemes(List<AppOptionUi> apps) {
    final schemes = <String>{
      ...['http', 'https', 'mailto', 'ftp', 'file', 'remoteos'],
      for (final a in apps) ...a.schemes,
      for (final a in apps) ...a.extensions,
    };
    final sorted = schemes.toList()
      ..sort((a, b) {
        final ae = a.startsWith('.') ? 1 : 0;
        final be = b.startsWith('.') ? 1 : 0;
        if (ae != be) return ae.compareTo(be);
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return sorted;
  }

  @override
  List<DefaultAppMappingUi> currentDefaultMappings(
      WorkspaceSyncCoordinator workspace) {
    final prefs = workspace.debugPreferencesSnapshot();
    return prefs?.defaultApps
            .map((m) => DefaultAppMappingUi(scheme: m.scheme, appId: m.appId))
            .toList(growable: false) ??
        const <DefaultAppMappingUi>[];
  }

  @override
  void queueTheme(ThemeNotifier theme, WorkspaceSyncCoordinator workspace) {
    final themeState = theme.currentState;
    workspace.queueTheme(themeState.kind, themeState.preferences);
  }

  @override
  void persistDefaultApps(
      SettingsState state, WorkspaceSyncCoordinator workspace) {
    final current = workspace.debugPreferencesSnapshot();
    if (current == null) return;
    workspace.queuePreferences(current.copyWith(
      defaultApps: state.defaultMappings
          .map((m) =>
              WorkspaceDefaultAppMapping(scheme: m.scheme, appId: m.appId))
          .toList(growable: false),
    ));
  }

  @override
  Future<String> importTheme(
      ThemeNotifier theme, WorkspaceSyncCoordinator workspace) async {
    final themeState = theme.currentState;
    final current = themeState.preferences;
    if (current.customPalettes.length >= 20) {
      return 'settings.theme_import.limit'.tr();
    }
    String? jsonText;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      jsonText = data?.text;
    } catch (_) {}
    if (jsonText == null || jsonText.trim().isEmpty) {
      return 'settings.theme_import.clipboard_empty'.tr();
    }
    ThemePaletteDto dto;
    try {
      dto = ThemePaletteDto.fromJson(jsonDecode(jsonText));
    } catch (_) {
      return 'settings.theme_import.invalid'.tr();
    }
    if (dto.formatVersion != 1 && dto.formatVersion != 2) {
      return 'settings.theme_import.invalid'.tr();
    }
    if (dto.name.trim().isEmpty || dto.name.length > 80) {
      return 'settings.theme_import.invalid'.tr();
    }
    final colors = dto.formatVersion >= 2
        ? (dto.darkColors ?? dto.lightColors)
        : dto.colors;
    if (colors == null || !ThemePaletteDefaults.isComplete(colors)) {
      return 'settings.theme_import.inaccessible'.tr();
    }
    final id = dto.id.isEmpty
        ? 'imp_${DateTime.now().millisecondsSinceEpoch}'
        : dto.id;
    final existingIds = current.customPalettes.map((c) => c.id).toSet();
    var candidateId = id;
    int n = 1;
    while (existingIds.contains(candidateId)) {
      candidateId = '${id}_$n';
      n++;
    }
    final imported = ThemePaletteDto(
      formatVersion: dto.formatVersion,
      id: candidateId,
      name: dto.name.trim(),
      lightColors: dto.lightColors,
      darkColors: dto.darkColors,
      mode: dto.mode,
      colors: dto.colors,
    );
    final updated = current.copyWith(
      paletteId: 'custom:$candidateId',
      customPalettes: [...current.customPalettes, imported],
    );
    theme.setPreferences(updated);
    queueTheme(theme, workspace);
    return 'settings.theme_import.complete'.tr();
  }

  @override
  Future<String> exportTheme(ThemeNotifier theme) async {
    final prefs = theme.currentState.preferences;
    if (!prefs.paletteId.startsWith('custom:')) return '';
    final id = prefs.paletteId.substring('custom:'.length);
    final palette = prefs.customPalettes
        .cast<ThemePaletteDto?>()
        .firstWhere((c) => c?.id == id, orElse: () => null);
    if (palette == null) return '';
    try {
      await Clipboard.setData(ClipboardData(text: jsonEncode(palette.toJson())));
      return 'settings.theme_export.copied'.tr(args: [palette.name]);
    } catch (_) {
      return 'settings.theme_export.failed'.tr();
    }
  }

  @override
  Future<bool> deleteTheme(
    ThemeNotifier theme,
    WorkspaceSyncCoordinator workspace,
    Future<bool?> Function(String title, String message) confirm,
  ) async {
    final prefs = theme.currentState.preferences;
    if (!prefs.paletteId.startsWith('custom:')) return false;
    final id = prefs.paletteId.substring('custom:'.length);
    final palette = prefs.customPalettes
        .cast<ThemePaletteDto?>()
        .firstWhere((c) => c?.id == id, orElse: () => null);
    if (palette == null) return false;
    final ok = await confirm(
        'settings.theme_delete.confirmation.title'.tr(),
        'settings.theme_delete.confirmation.message'
            .tr(args: [palette.name]));
    if (ok != true) return false;
    final remaining =
        prefs.customPalettes.where((p) => p.id != id).toList(growable: false);
    final updated = prefs.copyWith(
      paletteId: ThemePreferencesDto.defaults.paletteId,
      customPalettes: remaining,
    );
    theme.setPreferences(updated);
    queueTheme(theme, workspace);
    return true;
  }

  @override
  Future<({bool ok, String text})> testLatency({
    required String? serverUrl,
    required String? accessToken,
    required bool authenticated,
  }) async {
    if (!authenticated || serverUrl == null || accessToken == null) {
      return (ok: false, text: 'settings.network.cannot_test'.tr());
    }
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse('$serverUrl/api/v1/me');
      final req = await HttpClient().getUrl(uri)
        ..headers.set('Authorization', 'Bearer $accessToken');
      final resp = await req.close();
      sw.stop();
      if (resp.statusCode >= 200 && resp.statusCode < 400) {
        return (ok: true, text: '${sw.elapsedMilliseconds} ms');
      }
      return (
        ok: false,
        text: 'settings.network.test_failed'
            .tr(args: ['HTTP ${resp.statusCode}'])
      );
    } catch (e) {
      return (
        ok: false,
        text: 'settings.network.test_failed'.tr(args: [e.toString()])
      );
    }
  }

  @override
  Future<List<({String iface, String address})>> loadNetworkAddresses() async {
    final addresses = <({String iface, String address})>[];
    try {
      for (final iface in await NetworkInterface.list()) {
        for (final addr in iface.addresses) {
          if (addr.address.startsWith('127.')) continue;
          if (addr.address == '::1') continue;
          addresses.add((iface: iface.name, address: addr.address));
        }
      }
    } catch (_) {}
    return addresses;
  }
}
