// Compatibility adapter bridging the feature-first SettingsViewModel
// (get_it + watch_it) to the legacy riverpod StateNotifier API.
//
// All real state and business logic now lives in
// `lib/features/settings/application/settings_view_model.dart` +
// `lib/features/settings/data/settings_repository.dart`.  This adapter
// keeps `settingsControllerProvider` functional so existing pages, the
// settings_app shell, dialogs and tests do not need to be patched in lock
// step.  New features should depend on [SettingsViewModel] directly.
//
// Architectural rationale (AGENTS.md § 36 "preserve buildability"):
// keeping the riverpod API during migration means we can migrate pages
// one at a time without breaking the application shell.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/window_manager/window_manager.dart';
import '../../features/settings/application/settings_view_model.dart';
import '../../features/settings/domain/settings_models.dart';
import '../../features/settings/domain/settings_state.dart';

export '../../features/settings/domain/settings_state.dart' show SettingsState;

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
  // Reuse the same factory the feature exposes, so every provider scope
  // gets its own transient ViewModel — matching the legacy behaviour.
  final vm = createSettingsViewModel();
  return SettingsController._(ref, vm);
});

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController._(this.ref, this.vm) : super(vm.state.value) {
    _onStateChanged();
    _sub = _onStateChanged;
    vm.state.addListener(_sub!);
    bootstrap();
  }

  final Ref ref;
  final SettingsViewModel vm;
  VoidCallback? _sub;

  void _onStateChanged() {
    state = vm.state.value;
  }

  @override
  void dispose() {
    final s = _sub;
    if (s != null) {
      vm.state.removeListener(s);
    }
    vm.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Legacy surface — thin forwarding shims onto the new SettingsViewModel.
  //
  // The signatures intentionally match the previous riverpod controller so
  // call sites can continue working while pages migrate.
  // -------------------------------------------------------------------------

  void bootstrap() {
    // ignore: discarded_futures
    vm.bootstrapCommand();
    state = vm.state.value;
  }

  // --- Theme / accent -----------------------------------------------------

  void applyAccentInput(String raw, TextEditingController ctrl) =>
      vm.applyAccentInput(raw, ctrl);

  void queueTheme() => vm.queueTheme();

  Future<String> importTheme() => vm.importTheme();

  Future<String> exportTheme() => vm.exportTheme();

  Future<bool> deleteTheme(
          Future<bool?> Function(String, String) confirm) async =>
      vm.deleteTheme(confirm);

  // --- Time & language ----------------------------------------------------

  String timeZoneDisplayName() => vm.timeZoneDisplayName();

  String formatTimeSample(DateTime t, String format, String langTag) =>
      vm.formatTimeSample(t, format, langTag);

  String formatDateSample(DateTime t, String format, String langTag) =>
      vm.formatDateSample(t, format, langTag);

  // --- Network ------------------------------------------------------------

  Future<void> testLatency() => vm.testLatencyCommand.runAsync();

  Future<void> refreshAddresses() => vm.refreshAddressesCommand.runAsync();

  // --- Applications subpage ----------------------------------------------

  void openInstalledAppsList() => vm.openInstalledAppsList();

  void openAppDetails(String appId) => vm.openAppDetails(appId);

  Future<void> launchApp(String appId, String displayName,
          {required BuildContext? context}) async =>
      vm.launchApp(
        appId,
        displayName,
        context: context,
        wm: ref.read(windowManagerProvider.notifier),
      );

  void clearAppsActionStatus() => vm.clearAppsActionStatus();

  void setBrowserLinkTarget(int v) => vm.setBrowserLinkTarget(v);

  Future<void> saveBrowserLinkTarget() =>
      vm.saveBrowserTargetCommand.runAsync();

  void clearLocalAppData() => vm.clearLocalAppData();

  // --- Image mirrors ------------------------------------------------------

  String selectedMirrorGroupValue() => vm.selectedMirrorGroupValue();

  void selectImageMirror(ImageMirrorUi mirror) => vm.selectImageMirror(mirror);

  void addImageMirror(
    String name,
    String endpoint, {
    required TextEditingController nameCtrl,
    required TextEditingController endpointCtrl,
  }) =>
      vm.addImageMirror(name, endpoint,
          nameCtrl: nameCtrl, endpointCtrl: endpointCtrl);

  void removeImageMirror(ImageMirrorUi mirror) => vm.removeImageMirror(mirror);

  // --- Default apps -------------------------------------------------------

  void addDefaultMapping() => vm.addDefaultMapping();

  List<AppOptionUi> compatibleAppsFor(String scheme) =>
      vm.compatibleAppsFor(scheme);

  void updateDefaultAppScheme(DefaultAppMappingUi mapping, String value) =>
      vm.updateDefaultAppScheme(mapping, value);

  void updateDefaultAppId(DefaultAppMappingUi mapping, String appId) =>
      vm.updateDefaultAppId(mapping, appId);

  void removeDefaultMapping(DefaultAppMappingUi mapping) =>
      vm.removeDefaultMapping(mapping);

  // Legacy persistence helper — still in use by tests / page callers that
  // explicitly flush the default-apps mapping after batch updates.  The
  // ViewModel already persists mutations, but leaving the entry point
  // avoids a behavior change for existing callers.
  void persistDefaultApps() {
    // Intentional no-op: persistence is handled synchronously inside the
    // SettingsViewModel for each mutation.
  }

  // --- Developer ----------------------------------------------------------

  void setDevMode(bool v) => vm.setDevMode(v);

  void regeneratePairingToken() => vm.regeneratePairingToken();

  // --- Misc ---------------------------------------------------------------

  void setImageMirrorStatus(String s) => vm.setImageMirrorStatus(s);

  void tickSampleClock() => vm.tickSampleClock();
}
