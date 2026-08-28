// Settings business logic + state controller.
//
// In accordance with AGENTS.md rule 3 (pages only do layout) and rule 8
// (page state managed by Controller/ViewModel), all mutable state,
// persistence, clipboard and network operations live here. Pages only
// read the state via `ref.watch(settingsControllerProvider)` and call
// methods for user actions.

import 'dart:convert';
import 'dart:io' show HttpClient, NetworkInterface;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/apps/app_registry.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/theme_models.dart';
import '../../core/theme/theme_palette_defaults.dart';
import '../../core/theme/theme_service.dart';
import '../../core/window_manager/window_manager.dart';
import '../../features/workspace/application/workspace_sync_coordinator.dart';
import '../../features/workspace/domain/workspace_models.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// Public state
// ---------------------------------------------------------------------------

@immutable
class SettingsState {
  const SettingsState({
    required this.defaultMappings,
    required this.appOptions,
    required this.availableSchemes,
    required this.imageMirrors,
    required this.imageMirrorStatus,
    required this.imageMirrorsLoading,
    required this.networkTesting,
    required this.networkLatencyText,
    required this.networkAddrLoading,
    required this.networkAddrStatus,
    required this.networkAddresses,
    required this.appsSubpage,
    required this.selectedAppId,
    required this.appsActionStatus,
    required this.browserLinkTargetSaving,
    required this.browserLinkTargetStatus,
    required this.browserLinkTarget,
    required this.devModeEnabled,
    required this.devPairingToken,
    required this.networkInspectorStatus,
    required this.accentError,
    required this.sampleClock,
  });

  final List<DefaultAppMappingUi> defaultMappings;
  final List<AppOptionUi> appOptions;
  final List<String> availableSchemes;
  final List<ImageMirrorUi> imageMirrors;
  final String imageMirrorStatus;
  final bool imageMirrorsLoading;
  final bool networkTesting;
  final String networkLatencyText;
  final bool networkAddrLoading;
  final String networkAddrStatus;
  final List<({String iface, String address})> networkAddresses;
  final AppsSubpage appsSubpage;
  final String? selectedAppId;
  final String appsActionStatus;
  final bool browserLinkTargetSaving;
  final String browserLinkTargetStatus;
  final int browserLinkTarget;
  final bool devModeEnabled;
  final String devPairingToken;
  final String networkInspectorStatus;
  final String? accentError;
  final DateTime sampleClock;

  SettingsState copyWith({
    List<DefaultAppMappingUi>? defaultMappings,
    List<AppOptionUi>? appOptions,
    List<String>? availableSchemes,
    List<ImageMirrorUi>? imageMirrors,
    String? imageMirrorStatus,
    bool? imageMirrorsLoading,
    bool? networkTesting,
    String? networkLatencyText,
    bool? networkAddrLoading,
    String? networkAddrStatus,
    List<({String iface, String address})>? networkAddresses,
    AppsSubpage? appsSubpage,
    String? selectedAppId,
    String? appsActionStatus,
    bool? browserLinkTargetSaving,
    String? browserLinkTargetStatus,
    int? browserLinkTarget,
    bool? devModeEnabled,
    String? devPairingToken,
    String? networkInspectorStatus,
    String? accentError,
    DateTime? sampleClock,
    bool clearSelectedAppId = false,
  }) {
    return SettingsState(
      defaultMappings: defaultMappings ?? this.defaultMappings,
      appOptions: appOptions ?? this.appOptions,
      availableSchemes: availableSchemes ?? this.availableSchemes,
      imageMirrors: imageMirrors ?? this.imageMirrors,
      imageMirrorStatus: imageMirrorStatus ?? this.imageMirrorStatus,
      imageMirrorsLoading: imageMirrorsLoading ?? this.imageMirrorsLoading,
      networkTesting: networkTesting ?? this.networkTesting,
      networkLatencyText: networkLatencyText ?? this.networkLatencyText,
      networkAddrLoading: networkAddrLoading ?? this.networkAddrLoading,
      networkAddrStatus: networkAddrStatus ?? this.networkAddrStatus,
      networkAddresses: networkAddresses ?? this.networkAddresses,
      appsSubpage: appsSubpage ?? this.appsSubpage,
      selectedAppId: clearSelectedAppId ? null : (selectedAppId ?? this.selectedAppId),
      appsActionStatus: appsActionStatus ?? this.appsActionStatus,
      browserLinkTargetSaving: browserLinkTargetSaving ?? this.browserLinkTargetSaving,
      browserLinkTargetStatus: browserLinkTargetStatus ?? this.browserLinkTargetStatus,
      browserLinkTarget: browserLinkTarget ?? this.browserLinkTarget,
      devModeEnabled: devModeEnabled ?? this.devModeEnabled,
      devPairingToken: devPairingToken ?? this.devPairingToken,
      networkInspectorStatus: networkInspectorStatus ?? this.networkInspectorStatus,
      accentError: accentError ?? this.accentError,
      sampleClock: sampleClock ?? this.sampleClock,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController(ref);
});

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this.ref)
      : super(SettingsState(
          defaultMappings: const [],
          appOptions: const [],
          availableSchemes: const [],
          imageMirrors: const [],
          imageMirrorStatus: '',
          imageMirrorsLoading: false,
          networkTesting: false,
          networkLatencyText: '',
          networkAddrLoading: false,
          networkAddrStatus: '',
          networkAddresses: const [],
          appsSubpage: AppsSubpage.installedApps,
          selectedAppId: null,
          appsActionStatus: '',
          browserLinkTargetSaving: false,
          browserLinkTargetStatus: '',
          browserLinkTarget: 0,
          devModeEnabled: false,
          devPairingToken: 'R0-A1B2C3D4-E5F6',
          networkInspectorStatus: '',
          accentError: null,
          sampleClock: DateTime.now(),
        ));

  final Ref ref;

  // ----- Bootstrapping -----------------------------------------------------

  void bootstrap() {
    final registry = ref.read(appRegistryProvider);
    final apps = <AppOptionUi>[];
    for (final e in registry.all) {
      apps.add(AppOptionUi(
        id: e.id,
        displayName: e.nameKey.tr(),
        schemes: defaultSchemesFor(e.id),
        extensions: defaultExtensionsFor(e.id),
      ));
    }

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

    final prefs = ref.read(workspaceSyncProvider).preferences;
    final defaultMappings = prefs?.defaultApps
            .map((m) => DefaultAppMappingUi(scheme: m.scheme, appId: m.appId))
            .toList(growable: false) ??
        const <DefaultAppMappingUi>[];

    final imageMirrors = <ImageMirrorUi>[
      ImageMirrorUi(
        id: '',
        name: 'settings.image_mirrors.docker_hub'.tr(),
        endpoint: 'registry-1.docker.io',
        isDefault: true,
        isSelected: true,
      ),
    ];

    state = state.copyWith(
      appOptions: apps,
      availableSchemes: sorted,
      defaultMappings: defaultMappings,
      imageMirrors: imageMirrors,
      imageMirrorStatus: '',
      devModeEnabled: false,
      networkInspectorStatus:
          'settings.network_inspector.requires_developer_mode'.tr(),
    );
  }

  // ----- Persistence helpers ----------------------------------------------

  void _persistWorkspacePreferences(
      WorkspacePreferences Function(WorkspacePreferences current) updater) {
    final current = ref.read(workspaceSyncProvider).preferences;
    if (current == null) return;
    ref.read(workspaceSyncProvider.notifier).queuePreferences(updater(current));
  }

  void queueTheme() {
    final current = ref.read(themeProvider);
    ref
        .read(workspaceSyncProvider.notifier)
        .queueTheme(current.kind, current.preferences);
  }

  void persistDefaultApps() {
    _persistWorkspacePreferences((prefs) => prefs.copyWith(
          defaultApps: state.defaultMappings
              .map((m) => WorkspaceDefaultAppMapping(
                  scheme: m.scheme, appId: m.appId))
              .toList(growable: false),
        ));
  }

  // ----- Theme / accent ----------------------------------------------------

  /// Parses the accent input and either writes it through ThemeService or
  /// surfaces an error. Called whenever the accent TextField content changes.
  void applyAccentInput(String raw, TextEditingController ctrl) {
    final value = raw.trim();
    if (value.isEmpty) {
      state = state.copyWith(accentError: null);
      ref.read(themeProvider.notifier).setAccentOverride(null);
      queueTheme();
      return;
    }
    final upper = value.toUpperCase();
    if (!ThemePaletteDefaults.isColor(upper)) {
      state = state.copyWith(accentError: 'settings.accent.invalid'.tr());
      return;
    }
    state = state.copyWith(accentError: null);
    ref.read(themeProvider.notifier).setAccentOverride(upper);
    queueTheme();
  }

  // ----- Theme Import / Export / Delete -----------------------------------

  /// Returns a human readable status message that the page can display.
  Future<String> importTheme() async {
    final themeState = ref.read(themeProvider);
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
    ref.read(themeProvider.notifier).setPreferences(updated);
    queueTheme();
    return 'settings.theme_import.complete'.tr();
  }

  Future<String> exportTheme() async {
    final prefs = ref.read(themeProvider).preferences;
    if (!prefs.paletteId.startsWith('custom:')) return '';
    final id = prefs.paletteId.substring('custom:'.length);
    final palette =
        // ignore: prefer_cast_nullable, package:collection not guaranteed
        _firstWhereOrNull(prefs.customPalettes, (p) => p.id == id);
    if (palette == null) return '';
    try {
      await Clipboard.setData(ClipboardData(text: jsonEncode(palette.toJson())));
      return 'settings.theme_export.copied'.tr(args: [palette.name]);
    } catch (_) {
      return 'settings.theme_export.failed'.tr();
    }
  }

  Future<bool> deleteTheme(Future<bool?> Function(String, String) confirm) async {
    final prefs = ref.read(themeProvider).preferences;
    if (!prefs.paletteId.startsWith('custom:')) return false;
    final id = prefs.paletteId.substring('custom:'.length);
    final palette = _firstWhereOrNull(prefs.customPalettes, (p) => p.id == id);
    if (palette == null) return false;
    final ok = await confirm(
        'settings.theme_delete.confirmation.title'.tr(),
        'settings.theme_delete.confirmation.message'.tr(args: [palette.name]));
    if (ok != true) return false;
    final remaining =
        prefs.customPalettes.where((p) => p.id != id).toList(growable: false);
    final updated = prefs.copyWith(
      paletteId: ThemePreferencesDto.defaults.paletteId,
      customPalettes: remaining,
    );
    ref.read(themeProvider.notifier).setPreferences(updated);
    queueTheme();
    return true;
  }

  // ----- Time & Language helpers -----------------------------------------

  String timeZoneDisplayName() {
    try {
      return DateTime.now().timeZoneName;
    } catch (_) {
      return 'UTC';
    }
  }

  String formatTimeSample(DateTime t, String format, String langTag) {
    try {
      final culture = _safeLocale(langTag);
      final pattern = format == '12h' ? 'h:mm a' : 'HH:mm';
      return DateFormat(pattern, culture).format(t);
    } catch (_) {
      final pattern = format == '12h' ? 'h:mm a' : 'HH:mm';
      return DateFormat(pattern).format(t);
    }
  }

  String formatDateSample(DateTime t, String format, String langTag) {
    try {
      final culture = _safeLocale(langTag);
      final pattern = format
          .replaceAll('M', 'M')
          .replaceAll('d', 'd')
          .replaceAll('yyyy', 'y');
      return DateFormat(pattern, culture).format(t);
    } catch (_) {
      return DateFormat('y/M/d').format(t);
    }
  }

  String _safeLocale(String tag) {
    try {
      final parts = tag.replaceAll('_', '-').split('-');
      if (parts.length > 1 && parts[1].length == 2) return tag;
      return parts.first;
    } catch (_) {
      return 'en_US';
    }
  }

  // ----- Network -----------------------------------------------------------

  Future<void> testLatency() async {
    state = state.copyWith(
      networkTesting: true,
      networkLatencyText: 'settings.network.testing'.tr(),
    );
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated ||
        auth.serverUrl == null ||
        auth.accessToken == null) {
      state = state.copyWith(
        networkTesting: false,
        networkLatencyText: 'settings.network.cannot_test'.tr(),
      );
      return;
    }
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse('${auth.serverUrl}/api/v1/me');
      final req = await HttpClient().getUrl(uri)
        ..headers.set('Authorization', 'Bearer ${auth.accessToken}');
      final resp = await req.close();
      sw.stop();
      if (resp.statusCode >= 200 && resp.statusCode < 400) {
        state = state.copyWith(
            networkTesting: false,
            networkLatencyText: '${sw.elapsedMilliseconds} ms');
      } else {
        state = state.copyWith(
            networkTesting: false,
            networkLatencyText: 'settings.network.test_failed'
                .tr(args: ['HTTP ${resp.statusCode}']));
      }
    } catch (e) {
      state = state.copyWith(
          networkTesting: false,
          networkLatencyText:
              'settings.network.test_failed'.tr(args: [e.toString()]));
    }
  }

  Future<void> refreshAddresses() async {
    state = state.copyWith(
      networkAddrLoading: true,
      networkAddrStatus: 'settings.network.loading_addresses'.tr(),
    );
    await Future.delayed(const Duration(milliseconds: 400));
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
    state = state.copyWith(
      networkAddresses: addresses,
      networkAddrLoading: false,
      networkAddrStatus: addresses.isEmpty
          ? 'settings.network.no_addresses'.tr()
          : 'settings.network.addresses_found'.tr(args: ['${addresses.length}']),
    );
  }

  // ----- Applications subpage --------------------------------------------

  void openInstalledAppsList() {
    state = state.copyWith(
      appsSubpage: AppsSubpage.installedApps,
      appsActionStatus: '',
      clearSelectedAppId: true,
    );
  }

  void openAppDetails(String appId) {
    state = state.copyWith(
      appsSubpage: AppsSubpage.appDetails,
      selectedAppId: appId,
      appsActionStatus: '',
    );
  }

  Future<void> launchApp(String appId, String displayName,
      {required BuildContext? context}) async {
    try {
      final wm = ref.read(windowManagerProvider.notifier);
      final entry = ref.read(appRegistryProvider).get(appId);
      if (entry == null) {
        state = state.copyWith(appsActionStatus: 'settings.apps.not_launchable'.tr());
        return;
      }
      final ctx = context;
      if (ctx == null) return;
      wm.openApp(
        entry: entry,
        child: entry.windowBuilder(ctx),
      );
      state = state.copyWith(
          appsActionStatus: 'settings.apps.opened'.tr(args: [displayName]));
    } catch (_) {
      state = state.copyWith(appsActionStatus: 'settings.apps.not_launchable'.tr());
    }
  }

  void clearAppsActionStatus() => state = state.copyWith(appsActionStatus: '');

  void setBrowserLinkTarget(int v) => state = state.copyWith(browserLinkTarget: v);

  Future<void> saveBrowserLinkTarget() async {
    state = state.copyWith(
      browserLinkTargetSaving: true,
      browserLinkTargetStatus: '',
    );
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(
      browserLinkTargetSaving: false,
      browserLinkTargetStatus:
          'settings.apps.browser.link_open_target_saved'.tr(),
    );
  }

  void clearLocalAppData() {
    state = state.copyWith(appsActionStatus:
        'settings.apps.clear_data.complete_local'.tr());
  }

  // ----- Image Mirrors -----------------------------------------------------

  String selectedMirrorGroupValue() {
    final selected = _firstWhereOrNull(state.imageMirrors, (m) => m.isSelected);
    if (selected == null) return 'DEFAULT';
    return selected.isDefault ? 'DEFAULT' : selected.id;
  }

  void selectImageMirror(ImageMirrorUi mirror) {
    final next = [
      for (final m in state.imageMirrors)
        ImageMirrorUi(
          id: m.id,
          name: m.name,
          endpoint: m.endpoint,
          isDefault: m.isDefault,
          isSelected: identical(m, mirror) || (m == mirror),
        ),
    ];
    final status = mirror.isDefault
        ? 'settings.image_mirrors.default_selected'.tr()
        : 'settings.image_mirrors.selected'.tr(args: [mirror.name]);
    state = state.copyWith(imageMirrors: next, imageMirrorStatus: status);
  }

  void addImageMirror(String name, String endpoint,
      {required TextEditingController nameCtrl,
      required TextEditingController endpointCtrl}) {
    final trimmedName = name.trim();
    final trimmedEndpoint = endpoint.trim();
    if (trimmedName.isEmpty || trimmedEndpoint.isEmpty) {
      state = state
          .copyWith(imageMirrorStatus: 'settings.image_mirrors.required'.tr());
      return;
    }
    final next = List<ImageMirrorUi>.from(state.imageMirrors)
      ..add(ImageMirrorUi(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        name: trimmedName,
        endpoint: trimmedEndpoint,
        isDefault: false,
        isSelected: false,
      ));
    state = state.copyWith(
      imageMirrors: next,
      imageMirrorStatus: 'settings.image_mirrors.added'.tr(),
    );
    nameCtrl.clear();
    endpointCtrl.clear();
  }

  void removeImageMirror(ImageMirrorUi mirror) {
    final next = state.imageMirrors.where((m) => m != mirror).toList();
    final needFallback = mirror.isSelected;
    if (needFallback) {
      for (int i = 0; i < next.length; i++) {
        if (next[i].isDefault) {
          next[i] = ImageMirrorUi(
            id: next[i].id,
            name: next[i].name,
            endpoint: next[i].endpoint,
            isDefault: next[i].isDefault,
            isSelected: true,
          );
          break;
        }
      }
    }
    state = state.copyWith(
      imageMirrors: next,
      imageMirrorStatus: 'settings.image_mirrors.removed'.tr(),
    );
  }

  // ----- Default Apps ------------------------------------------------------

  void addDefaultMapping() {
    final used = state.defaultMappings
        .map((m) => m.scheme.toLowerCase())
        .toSet();
    final pick = state.availableSchemes.firstWhere(
        (s) => !used.contains(s.toLowerCase()),
        orElse: () => state.availableSchemes.first);
    final scheme = state.appOptions.isNotEmpty
        ? state.appOptions.first.id
        : 'browser';
    final next = List<DefaultAppMappingUi>.from(state.defaultMappings)
      ..add(DefaultAppMappingUi(scheme: pick, appId: scheme));
    state = state.copyWith(defaultMappings: next);
    persistDefaultApps();
  }

  List<AppOptionUi> compatibleAppsFor(String scheme) {
    if (scheme.startsWith('.')) {
      final declared = state.appOptions
          .where((a) => a.extensions
              .any((e) => e.toLowerCase() == scheme.toLowerCase()))
          .toList();
      if (declared.isNotEmpty) return declared;
      return state.appOptions.where((a) => a.extensions.isNotEmpty).toList();
    }
    const universal = {'http', 'https', 'mailto', 'ftp'};
    if (universal.contains(scheme.toLowerCase())) {
      return state.appOptions
          .where((a) =>
              a.schemes.any((s) => s.toLowerCase() == scheme.toLowerCase()) ||
              (universal.contains(scheme.toLowerCase()) && a.id == 'browser'))
          .toList();
    }
    return state.appOptions
        .where((a) => a.schemes
            .any((s) => s.toLowerCase() == scheme.toLowerCase()))
        .toList();
  }

  void updateDefaultAppScheme(DefaultAppMappingUi mapping, String value) {
    final scheme = value.trim();
    if (scheme.isEmpty) return;
    final next = [
      for (final m in state.defaultMappings)
        if (identical(m, mapping))
          (DefaultAppMappingUi(scheme: scheme, appId: m.appId))
        else
          m,
    ];
    state = state.copyWith(defaultMappings: next);
    persistDefaultApps();
  }

  void updateDefaultAppId(DefaultAppMappingUi mapping, String appId) {
    final next = [
      for (final m in state.defaultMappings)
        if (identical(m, mapping))
          (DefaultAppMappingUi(scheme: m.scheme, appId: appId))
        else
          m,
    ];
    state = state.copyWith(defaultMappings: next);
    persistDefaultApps();
  }

  void removeDefaultMapping(DefaultAppMappingUi mapping) {
    state = state.copyWith(
      defaultMappings: [
        for (final m in state.defaultMappings)
          if (!identical(m, mapping)) m,
      ],
    );
    persistDefaultApps();
  }

  // ----- Developer ---------------------------------------------------------

  void setDevMode(bool v) {
    state = state.copyWith(
      devModeEnabled: v,
      networkInspectorStatus: v
          ? 'settings.network_inspector.ready'.tr()
          : 'settings.network_inspector.requires_developer_mode'.tr(),
    );
  }

  void regeneratePairingToken() {
    final rand = List.generate(8,
        (i) => '0123456789ABCDEF'[(DateTime.now().microsecond + i) % 16]).join();
    state = state.copyWith(devPairingToken: 'R0-$rand-A1B2');
  }

  // ----- Misc --------------------------------------------------------------

  void setImageMirrorStatus(String s) {
    state = state.copyWith(imageMirrorStatus: s);
  }

  void tickSampleClock() {
    state = state.copyWith(sampleClock: DateTime.now());
  }
}

// ---------------------------------------------------------------------------
// Utility helpers
// ---------------------------------------------------------------------------

T? _firstWhereOrNull<T>(Iterable<T> source, bool Function(T it) test) {
  for (final it in source) {
    if (test(it)) return it;
  }
  return null;
}
