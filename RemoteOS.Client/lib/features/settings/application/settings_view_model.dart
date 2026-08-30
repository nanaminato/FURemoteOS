// Settings feature — ViewModel (ARCHITECTURE.md § 9).
//
// Owns presentation state, commands and presentation decisions.
// Repository I/O (theme persistence, network I/O) is delegated to
// [SettingsRepository].
//
// NOTE: The legacy riverpod `settingsControllerProvider` is re-exposed in
// `settings_controller_riverpod.dart` so existing pages can migrate
// incrementally.  New code should construct the ViewModel via get_it.

import 'package:command_it/command_it.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../app/dependency_injection.dart';
import '../../../core/apps/app_registry.dart';
import '../../../core/apps/app_ids.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/commands/base_view_model.dart';
import '../../../core/theme/theme_palette_defaults.dart';
import '../../../core/theme/theme_service.dart';
import '../../../core/window_manager/window_manager.dart';
import '../../workspace/application/workspace_sync_coordinator.dart';
import '../data/settings_repository.dart';
import '../domain/settings_models.dart';
import '../domain/settings_state.dart';

class SettingsViewModel extends ViewModel {
  SettingsViewModel({
    required SettingsRepository repository,
    required AppRegistry registry,
    required ThemeNotifier theme,
    required WorkspaceSyncCoordinator workspace,
    required AuthNotifier auth,
  })  : _repository = repository,
        _registry = registry,
        _theme = theme,
        _workspace = workspace,
        _auth = auth {
    trackDisposable(state);
    trackDisposable(bootstrapCommand);
    trackDisposable(testLatencyCommand);
    trackDisposable(refreshAddressesCommand);
    trackDisposable(saveBrowserTargetCommand);
  }

  final SettingsRepository _repository;
  final AppRegistry _registry;
  final ThemeNotifier _theme;
  final WorkspaceSyncCoordinator _workspace;
  final AuthNotifier _auth;

  final ValueNotifier<SettingsState> state =
      ValueNotifier<SettingsState>(SettingsState.initial());

  // ----- Commands (command_it v9.x) ----------------------------------------

  late final bootstrapCommand =
      Command.createSyncNoParamNoResult(_bootstrapImpl);

  late final testLatencyCommand =
      Command.createAsyncNoParamNoResult(_testLatencyImpl);

  late final refreshAddressesCommand =
      Command.createAsyncNoParamNoResult(_refreshAddressesImpl);

  late final saveBrowserTargetCommand =
      Command.createAsyncNoParamNoResult(_saveBrowserTargetImpl);

  // ----- Bootstrap ---------------------------------------------------------

  void _bootstrapImpl() {
    final apps = _repository.buildAppOptions(_registry);
    final schemes = _repository.collectSchemes(apps);
    final defaultMappings = _repository.currentDefaultMappings(_workspace);
    final imageMirrors = <ImageMirrorUi>[
      ImageMirrorUi(
        id: '',
        name: 'settings.image_mirrors.docker'.tr(),
        endpoint: 'registry-1.docker.io',
        isDefault: true,
        isSelected: true,
      ),
    ];
    state.value = state.value.copyWith(
      appOptions: apps,
      availableSchemes: schemes,
      defaultMappings: defaultMappings,
      imageMirrors: imageMirrors,
      imageMirrorStatus: '',
      devModeEnabled: false,
      networkInspectorStatus:
          'settings.network_inspector.requires_developer_mode'.tr(),
    );
  }

  // ----- Theme accent ------------------------------------------------------

  void applyAccentInput(String raw, TextEditingController ctrl) {
    final value = raw.trim();
    if (value.isEmpty) {
      state.value = state.value.copyWith(accentError: null);
      _theme.setAccentOverride(null);
      _repository.queueTheme(_theme, _workspace);
      return;
    }
    final upper = value.toUpperCase();
    if (!ThemePaletteDefaults.isColor(upper)) {
      state.value =
          state.value.copyWith(accentError: 'settings.accent.invalid'.tr());
      return;
    }
    state.value = state.value.copyWith(accentError: null);
    _theme.setAccentOverride(upper);
    _repository.queueTheme(_theme, _workspace);
  }

  Future<String> importTheme() => _repository.importTheme(_theme, _workspace);
  Future<String> exportTheme() => _repository.exportTheme(_theme);

  Future<bool> deleteTheme(
          Future<bool?> Function(String, String) confirm) async =>
      _repository.deleteTheme(_theme, _workspace, confirm);

  void queueTheme() => _repository.queueTheme(_theme, _workspace);

  // ----- Clock / date formatting samples ----------------------------------

  String timeZoneDisplayName() {
    try {
      return DateTime.now().timeZoneName;
    } catch (_) {
      return 'UTC';
    }
  }

  String formatTimeSample(DateTime t, String format, String langTag) {
    final pattern = format == '12h' ? 'h:mm a' : 'HH:mm';
    try {
      return DateFormat(pattern, _safeLocale(langTag)).format(t);
    } catch (_) {
      return DateFormat(pattern).format(t);
    }
  }

  String formatDateSample(DateTime t, String format, String langTag) {
    final pattern = format
        .replaceAll('M', 'M')
        .replaceAll('d', 'd')
        .replaceAll('yyyy', 'y');
    try {
      return DateFormat(pattern, _safeLocale(langTag)).format(t);
    } catch (_) {
      return DateFormat('y/M/d').format(t);
    }
  }

  static String _safeLocale(String tag) {
    try {
      final parts = tag.replaceAll('_', '-').split('-');
      if (parts.length > 1 && parts[1].length == 2) return tag;
      return parts.first;
    } catch (_) {
      return 'en_US';
    }
  }

  // ----- Network -----------------------------------------------------------

  Future<void> _testLatencyImpl() async {
    final auth = _auth.current;
    state.value = state.value.copyWith(
      networkTesting: true,
      networkLatencyText: 'settings.network.testing'.tr(),
    );
    final result = await _repository.testLatency(
      serverUrl: auth.serverUrl,
      accessToken: auth.accessToken,
      authenticated: auth.isAuthenticated,
    );
    state.value = state.value.copyWith(
      networkTesting: false,
      networkLatencyText: result.text,
    );
  }

  Future<void> _refreshAddressesImpl() async {
    state.value = state.value.copyWith(
      networkAddrLoading: true,
      networkAddrStatus: 'settings.network.loading_addresses'.tr(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final addresses = await _repository.loadNetworkAddresses();
    state.value = state.value.copyWith(
      networkAddresses: addresses,
      networkAddrLoading: false,
      networkAddrStatus: addresses.isEmpty
          ? 'settings.network.no_addresses'.tr()
          : 'settings.network.addresses_found'
              .tr(namedArgs: {'count': '${addresses.length}'}),
    );
  }

  // ----- Applications subpage ---------------------------------------------

  void openInstalledAppsList() {
    state.value = state.value.copyWith(
      appsSubpage: AppsSubpage.installedApps,
      appsActionStatus: '',
      clearSelectedAppId: true,
    );
  }

  void openAppDetails(String appId) {
    state.value = state.value.copyWith(
      appsSubpage: AppsSubpage.appDetails,
      selectedAppId: appId,
      appsActionStatus: '',
    );
  }

  Future<void> launchApp(
    String appId,
    String displayName, {
    required BuildContext? context,
    required WindowManagerNotifier wm,
  }) async {
    try {
      final entry = _registry.get(appId);
      if (entry == null) {
        state.value = state.value
            .copyWith(appsActionStatus: 'settings.apps.not_launchable'.tr());
        return;
      }
      final ctx = context;
      if (ctx == null) return;
      wm.openApp(
        entry: entry,
        child: entry.windowBuilder(ctx),
      );
      state.value = state.value.copyWith(
          appsActionStatus:
              'settings.apps.opened'.tr(namedArgs: {'name': displayName}));
    } catch (_) {
      state.value = state.value
          .copyWith(appsActionStatus: 'settings.apps.not_launchable'.tr());
    }
  }

  void clearAppsActionStatus() =>
      state.value = state.value.copyWith(appsActionStatus: '');

  void setBrowserLinkTarget(int v) =>
      state.value = state.value.copyWith(browserLinkTarget: v);

  Future<void> _saveBrowserTargetImpl() async {
    state.value = state.value.copyWith(
      browserLinkTargetSaving: true,
      browserLinkTargetStatus: '',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    state.value = state.value.copyWith(
      browserLinkTargetSaving: false,
      browserLinkTargetStatus:
          'settings.apps.browser.link_open_target_saved'.tr(),
    );
  }

  void clearLocalAppData() {
    state.value = state.value.copyWith(
        appsActionStatus: 'settings.apps.clear_data.complete_local'.tr());
  }

  // ----- Image Mirrors -----------------------------------------------------

  String selectedMirrorGroupValue() {
    for (final m in state.value.imageMirrors) {
      if (m.isSelected) return m.isDefault ? 'DEFAULT' : m.id;
    }
    return 'DEFAULT';
  }

  void selectImageMirror(ImageMirrorUi mirror) {
    final next = [
      for (final m in state.value.imageMirrors)
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
        : 'settings.image_mirrors.selected'
            .tr(namedArgs: {'name': mirror.name});
    state.value =
        state.value.copyWith(imageMirrors: next, imageMirrorStatus: status);
  }

  void addImageMirror(
    String name,
    String endpoint, {
    required TextEditingController nameCtrl,
    required TextEditingController endpointCtrl,
  }) {
    final trimmedName = name.trim();
    final trimmedEndpoint = endpoint.trim();
    if (trimmedName.isEmpty || trimmedEndpoint.isEmpty) {
      state.value = state.value
          .copyWith(imageMirrorStatus: 'settings.image_mirrors.required'.tr());
      return;
    }
    final next = List<ImageMirrorUi>.from(state.value.imageMirrors)
      ..add(ImageMirrorUi(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        name: trimmedName,
        endpoint: trimmedEndpoint,
        isDefault: false,
        isSelected: false,
      ));
    state.value = state.value.copyWith(
      imageMirrors: next,
      imageMirrorStatus: 'settings.image_mirrors.added'.tr(),
    );
    nameCtrl.clear();
    endpointCtrl.clear();
  }

  void removeImageMirror(ImageMirrorUi mirror) {
    var next = state.value.imageMirrors
        .where((m) => m != mirror)
        .toList(growable: false);
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
    state.value = state.value.copyWith(
      imageMirrors: next,
      imageMirrorStatus: 'settings.image_mirrors.removed'.tr(),
    );
  }

  // ----- Default Apps ------------------------------------------------------

  void addDefaultMapping() {
    final used =
        state.value.defaultMappings.map((m) => m.scheme.toLowerCase()).toSet();
    final pick = state.value.availableSchemes.firstWhere(
        (s) => !used.contains(s.toLowerCase()),
        orElse: () => state.value.availableSchemes.first);
    final scheme = state.value.appOptions.isNotEmpty
        ? state.value.appOptions.first.id
        : AppIds.browser;
    final next = List<DefaultAppMappingUi>.from(state.value.defaultMappings)
      ..add(DefaultAppMappingUi(scheme: pick, appId: scheme));
    state.value = state.value.copyWith(defaultMappings: next);
    _repository.persistDefaultApps(state.value, _workspace);
  }

  List<AppOptionUi> compatibleAppsFor(String scheme) {
    final appOptions = state.value.appOptions;
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

  void updateDefaultAppScheme(DefaultAppMappingUi mapping, String value) {
    final scheme = value.trim();
    if (scheme.isEmpty) return;
    final next = [
      for (final m in state.value.defaultMappings)
        if (identical(m, mapping))
          DefaultAppMappingUi(scheme: scheme, appId: m.appId)
        else
          m,
    ];
    state.value = state.value.copyWith(defaultMappings: next);
    _repository.persistDefaultApps(state.value, _workspace);
  }

  void updateDefaultAppId(DefaultAppMappingUi mapping, String appId) {
    final next = [
      for (final m in state.value.defaultMappings)
        if (identical(m, mapping))
          DefaultAppMappingUi(scheme: m.scheme, appId: appId)
        else
          m,
    ];
    state.value = state.value.copyWith(defaultMappings: next);
    _repository.persistDefaultApps(state.value, _workspace);
  }

  void removeDefaultMapping(DefaultAppMappingUi mapping) {
    state.value = state.value.copyWith(
      defaultMappings: [
        for (final m in state.value.defaultMappings)
          if (!identical(m, mapping)) m,
      ],
    );
    _repository.persistDefaultApps(state.value, _workspace);
  }

  // ----- Developer ---------------------------------------------------------

  void setDevMode(bool v) {
    state.value = state.value.copyWith(
      devModeEnabled: v,
      networkInspectorStatus: v
          ? 'settings.network_inspector.ready'.tr()
          : 'settings.network_inspector.requires_developer_mode'.tr(),
    );
  }

  void regeneratePairingToken() {
    final rand = List.generate(
            8, (i) => '0123456789ABCDEF'[(DateTime.now().microsecond + i) % 16])
        .join();
    state.value = state.value.copyWith(devPairingToken: 'R0-$rand-A1B2');
  }

  // ----- Misc status helpers -----------------------------------------------

  void setImageMirrorStatus(String s) {
    state.value = state.value.copyWith(imageMirrorStatus: s);
  }

  void tickSampleClock() {
    state.value = state.value.copyWith(sampleClock: DateTime.now());
  }
}

/// Create a new [SettingsViewModel] using application-scope singletons.
///
/// The returned instance is not shared — each Settings window gets its own
/// ViewModel because per-window state (page selection, TextField content
/// statuses, clock sample ticks) is inherently transient.
SettingsViewModel createSettingsViewModel() => SettingsViewModel(
      repository: di<SettingsRepository>(),
      registry: di<AppRegistry>(),
      theme: di<ThemeNotifier>(),
      workspace: di<WorkspaceSyncCoordinator>(),
      auth: di<AuthNotifier>(),
    );
