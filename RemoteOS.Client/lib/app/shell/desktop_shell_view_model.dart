// Desktop shell ViewModel (ARCHITECTURE.md § 7).
//
// Owns presentation state for the desktop workspace: which overlays are open,
// last-saved layout fingerprint for deduplicated writes, and commands for
// restore/logout/shutdown/refresh/open-app.
//
// This ViewModel intentionally imports [dart:ui] types (Locale, Size) via
// `package:flutter/foundation.dart` / `dart:ui` — these are presentation
// primitives, not Flutter widget types.  Because open-app commands still
// carry a pre-built child Widget (created by the View) through to the
// WindowManager, the request payloads accept a generic `Object` which is
// cast at the call site.  This keeps the ViewModel free of `BuildContext`
// and `Widget` construction.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Widget;
import 'package:command_it/command_it.dart';

import '../../app/dependency_injection.dart';
import '../../core/apps/app_registry.dart';
import '../../core/apps/app_ids.dart';
import '../../core/apps/application_runtime.dart';
import '../../core/commands/base_view_model.dart';
import '../../core/localization/language_catalog.dart';
import '../../core/theme/theme_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/window_manager/window_manager.dart';
import '../../features/workspace/application/workspace_sync_coordinator.dart';
import '../../features/workspace/domain/workspace_models.dart';

/// Which overlay is currently mounted on the desktop.
enum DesktopOverlay {
  none,
  startMenu,
}

/// Builds a managed-window child for a registered app entry.  This callback
/// lives in the View layer because it needs a real [BuildContext] to look
/// up inherited widgets (translations, theme, riverpod overrides, …).
typedef AppChildBuilder = Object? Function(AppRegistryEntry entry);

class DesktopShellViewModel extends ViewModel {
  DesktopShellViewModel({
    required AppRegistry registry,
    required AuthNotifier auth,
    required ThemeNotifier theme,
    required WindowManagerNotifier windows,
    required ApplicationRuntime applications,
    required WorkspaceSyncCoordinator workspace,
    required LanguageCatalog catalog,
    required ValueGetter<Locale> currentLocale,
    required Future<void> Function(Locale) setLocale,
  })  : _registry = registry,
        _auth = auth,
        _theme = theme,
        _windows = windows,
        _applications = applications,
        _workspace = workspace,
        _catalog = catalog,
        _currentLocale = currentLocale,
        _setLocale = setLocale {
    trackDisposable(overlay);
    trackDisposable(desktopIconsVisible);
    trackDisposable(refreshCommand);
    trackDisposable(openAppCommand);
    trackDisposable(openAppByIdCommand);
    trackDisposable(logoutCommand);
    trackDisposable(shutdownCommand);
    trackDisposable(restoreDesktopCommand);
  }

  final AppRegistry _registry;
  final AuthNotifier _auth;
  final ThemeNotifier _theme;
  final WindowManagerNotifier _windows;
  final ApplicationRuntime _applications;
  final WorkspaceSyncCoordinator _workspace;
  final LanguageCatalog _catalog;
  final ValueGetter<Locale> _currentLocale;
  final Future<void> Function(Locale) _setLocale;

  // ---------------------------------------------------------------------------
  // Observable presentation state
  // ---------------------------------------------------------------------------

  final ValueNotifier<DesktopOverlay> overlay =
      ValueNotifier(DesktopOverlay.none);
  final ValueNotifier<bool> desktopIconsVisible = ValueNotifier(true);

  String? _lastQueuedLayoutFingerprint;

  // ---------------------------------------------------------------------------
  // Commands (command_it v9.x API — see § 3 of ARCHITECTURE.md)
  // ---------------------------------------------------------------------------

  /// Empty command that drives a setState-level refresh.  Used by the
  /// desktop context menu "Refresh" entry.  The UI layer reads reactive
  /// notifiers, so the command itself has no work to do — merely invoking
  /// it lets tests/consumers observe execution state.
  late final refreshCommand = Command.createSyncNoParamNoResult(() {});

  /// Opens an app using an already-built child Widget (wrapped as Object).
  late final openAppCommand = Command.createSyncNoResult<OpenAppRequest>((req) {
    final saved = _workspace
        .debugLayoutsSnapshot()
        .windows
        .where((w) => w.key == req.entry.id);
    final Size? size =
        saved.isEmpty ? null : Size(saved.first.width, saved.first.height);
    _applications.launch(
      req.entry.id,
      buildWindow: (_) => req.child as Widget,
      screenSize: req.screenSize,
      initialSize: size,
    );
    overlay.value = DesktopOverlay.none;
  });

  /// Opens an app by registry ID.  The View must supply the [childBuilder]
  /// because the ViewModel is not allowed to own [BuildContext].
  late final openAppByIdCommand =
      Command.createSyncNoResult<OpenAppByIdRequest>((req) {
    if (req.activationUri != null) {
      _applications.activate(
        AppActivationRequest(uri: req.activationUri!),
        buildWindow: (entry) => req.childBuilder(entry) as Widget,
        screenSize: req.screenSize,
      );
      overlay.value = DesktopOverlay.none;
      return;
    }
    final entry = _registry.get(req.appId);
    if (entry == null) return;
    openAppCommand.run(OpenAppRequest(
      entry: entry,
      child: req.childBuilder(entry),
      screenSize: req.screenSize,
    ));
  });

  late final logoutCommand = Command.createAsyncNoParamNoResult(() async {
    overlay.value = DesktopOverlay.none;
    await _workspace.flush();
    await _auth.logout();
  });

  late final shutdownCommand = Command.createAsyncNoParamNoResult(() async {
    await logoutCommand.runAsync(null);
  });

  /// Runs once the host Flutter view is mounted.  Applies persisted theme
  /// and locale, then (optionally) opens the Welcome app.  [screen] is the
  /// initial desktop work area size; [welcomeBuilder] lets the View create
  /// the Welcome app child with a real BuildContext if desired (pass
  /// `null` to skip opening welcome, e.g. tests).
  late final restoreDesktopCommand =
      Command.createAsyncNoResult<RestoreDesktopRequest>((req) async {
    await _workspace.load();
    final preferences = _workspace.debugPreferencesSnapshot();
    if (preferences != null) {
      _theme
        ..setThemeKind(preferences.theme)
        ..setPreferences(preferences.themePreferences);
      final match = _catalog.languages
          .where((option) => option.localeTag == preferences.language);
      if (match.isNotEmpty) {
        final desired = match.first.locale;
        if (desired != _currentLocale()) await _setLocale(desired);
      }
    }
    final welcome = _registry.get(AppIds.welcome);
    if (welcome != null && req.welcomeBuilder != null) {
      final built = req.welcomeBuilder!(welcome);
      openAppCommand.run(OpenAppRequest(
        entry: welcome,
        child: built,
        screenSize: req.screen,
      ));
    }
  });

  // ---------------------------------------------------------------------------
  // Window layout persistence (callable from tests without rendering).
  // ---------------------------------------------------------------------------

  void saveWindowLayouts(List<RemoteWindow> windows) {
    final sizes = <String, WorkspaceWindowSize>{};
    for (final window in windows.where((w) => !w.isModal)) {
      final bounds = window.restoreBounds ?? window.bounds;
      sizes[window.appId] = WorkspaceWindowSize(
        key: window.appId,
        width: bounds.width.clamp(240, 3840).toDouble(),
        height: bounds.height.clamp(160, 2160).toDouble(),
      );
    }
    if (sizes.isEmpty) return;
    final layouts = WorkspaceWindowLayouts(windows: sizes.values.toList());
    final fingerprint =
        layouts.windows.map((w) => '${w.key}:${w.width}:${w.height}').join('|');
    if (fingerprint == _lastQueuedLayoutFingerprint) return;
    _lastQueuedLayoutFingerprint = fingerprint;
    _workspace.queueLayouts(layouts);
  }

  // ---------------------------------------------------------------------------
  // Overlay state (toggles belong in the VM so tests can assert them)
  // ---------------------------------------------------------------------------

  void toggleStartMenu() {
    overlay.value = overlay.value == DesktopOverlay.startMenu
        ? DesktopOverlay.none
        : DesktopOverlay.startMenu;
  }

  void closeOverlay() => overlay.value = DesktopOverlay.none;

  void toggleDesktopIcons() =>
      desktopIconsVisible.value = !desktopIconsVisible.value;

  List<AppRegistryEntry> get desktopIcons => [
        for (final id in const [
          AppIds.explorer,
          AppIds.browser,
          AppIds.settings,
          AppIds.terminal
        ])
          if (_registry.get(id) != null) _registry.get(id)!,
      ];
}

/// Request payload for opening an app from a pre-built child Widget.
class OpenAppRequest {
  const OpenAppRequest({
    required this.entry,
    required this.child,
    required this.screenSize,
  });

  final AppRegistryEntry entry;

  /// The built Flutter Widget for the app window.  Kept typed as [Object]
  /// so the request DTO stays free of Flutter rendering types; the open-app
  /// command performs the cast before passing it to the window manager.
  final Object? child;

  final Size screenSize;
}

/// Request payload for opening an app by ID.  The View supplies the child
/// builder so it can pull a [BuildContext] for inner widgets that read
/// inherited assets (translations, theme, …).
class OpenAppByIdRequest {
  const OpenAppByIdRequest({
    required this.appId,
    required this.childBuilder,
    required this.screenSize,
    this.activationUri,
  });

  final String appId;
  final AppChildBuilder childBuilder;
  final Size screenSize;
  final Uri? activationUri;
}

class RestoreDesktopRequest {
  const RestoreDesktopRequest({
    required this.screen,
    required this.welcomeBuilder,
  });

  final Size screen;
  final AppChildBuilder? welcomeBuilder;
}

/// Create a [DesktopShellViewModel] using the application-scope singletons
/// plus context-level locale accessors.  The resulting ViewModel is owned
/// (and disposed) by the view.
DesktopShellViewModel createDesktopShellViewModel({
  required ValueGetter<Locale> currentLocale,
  required Future<void> Function(Locale) setLocale,
}) =>
    DesktopShellViewModel(
      registry: di<AppRegistry>(),
      auth: di<AuthNotifier>(),
      theme: di<ThemeNotifier>(),
      windows: di<WindowManagerNotifier>(),
      applications: di<ApplicationRuntime>(),
      workspace: di<WorkspaceSyncCoordinator>(),
      catalog: di<LanguageCatalog>(),
      currentLocale: currentLocale,
      setLocale: setLocale,
    );
