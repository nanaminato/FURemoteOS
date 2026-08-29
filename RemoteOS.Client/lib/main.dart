import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:window_manager/window_manager.dart';
import 'package:go_router/go_router.dart';

import 'app/bootstrap.dart';
import 'app/dependency_injection.dart';
import 'core/theme/theme_service.dart';
import 'core/theme/theme_models.dart';
import 'core/auth/auth_service.dart';
import 'core/localization/modular_asset_loader.dart';
import 'core/localization/language_catalog.dart';
import 'core/shell/desktop_window_shell.dart';
import 'core/runtime/desktop_runtime.dart';
import 'core/runtime/startup_failure_app.dart';
import 'features/workspace/application/workspace_sync_coordinator.dart';
import 'screens/login/login_screen.dart';
import 'app/shell/desktop_shell_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = await DesktopRuntime.initialize();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(runtime.log
        .error(details.exception, details.stack ?? StackTrace.current));
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(runtime.log.error(error, stackTrace));
    return true;
  };

  try {
    await EasyLocalization.ensureInitialized();
    await windowManager.ensureInitialized();
    final languageCatalog = await LanguageCatalog.load();

    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      // The sign-in screen is deliberately scroll-free, so its compact
      // Remote Desktop Connection layout is protected by a real minimum size.
      minimumSize: Size(760, 700),
      center: true,
      // Keep the native surface opaque while diagnosing the desktop white
      // screen.  Transparent Windows surfaces rely on DWM composition before
      // Flutter submits its first scene and can obscure an otherwise healthy
      // widget tree on some graphics-driver combinations.
      backgroundColor: Color(0xFFF4F7FB),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      title: 'RemoteOS',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setResizable(true);
      await windowManager.show();
      await windowManager.focus();
    });

    runApp(ProviderScope(
      overrides: bootstrapRemoteOs(
        catalog: languageCatalog,
        runtimeLog: runtime.log,
      ),
      child: _RootLocalizationWrapper(catalog: languageCatalog),
    ));
  } catch (error, stackTrace) {
    await runtime.log.error(error, stackTrace);
    runApp(StartupFailureApp(message: error.toString()));
  }
}

class _RootLocalizationWrapper extends StatelessWidget {
  const _RootLocalizationWrapper({required this.catalog});

  final LanguageCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return EasyLocalization(
      supportedLocales:
          catalog.languages.map((language) => language.locale).toList(),
      path: 'assets/translations',
      assetLoader: ModularAssetLoader(catalog: catalog),
      fallbackLocale: catalog.fallbackLocale,
      useFallbackTranslations: true,
      useOnlyLangCode: false,
      child: const RemoteOSApp(),
    );
  }
}

class RemoteOSApp extends ConsumerStatefulWidget {
  const RemoteOSApp({super.key});

  @override
  ConsumerState<RemoteOSApp> createState() => _RemoteOSAppState();
}

class _RemoteOSAppState extends ConsumerState<RemoteOSApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final log = _optionalLog;
    _router = GoRouter(
      initialLocation: '/login',
      debugLogDiagnostics: true,
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        final atLogin = state.matchedLocation == '/login';

        final redirected = !auth.isAuthenticated && !atLogin ? '/login'
            : auth.isAuthenticated && atLogin ? '/desktop'
            : null;
        if (log != null) {
          unawaited(log.info(
            '[router] request=${state.uri} auth={authenticated:${auth.isAuthenticated}'
            ' state:${auth.state} error:${auth.errorMessage == null ? null : '<redacted>'}} '
            'matched=${state.matchedLocation} redirectedTo=${redirected ?? '<stay>'}',
          ));
        }
        return redirected;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) {
            if (log != null) {
              unawaited(log.info('[router] Building LoginScreen uri=${state.uri}'));
            }
            return const LoginScreen();
          },
        ),
        GoRoute(
          path: '/desktop',
          builder: (context, state) {
            if (log != null) {
              unawaited(log.info('[router] Building DesktopShellView uri=${state.uri}'));
            }
            return const DesktopShellView();
          },
        ),
      ],
      errorBuilder: (context, state) {
        if (log != null) {
          unawaited(log.info('[router] errorBuilder uri=${state.uri} '
              'error=${state.error ?? '<none>'}'));
        }
        return Scaffold(
          body: Center(child: Text('Page not found: ${state.uri}\n${state.error}')),
        );
      },
    );
  }

  RuntimeLog? get _optionalLog {
    try {
      return di.isRegistered<RuntimeLog>() ? di<RuntimeLog>() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use GoRouter's built-in `redirect` (see initState) for the canonical
    // auth→route mapping.  An extra ref.listen here would issue a parallel
    // _router.go() while LoginScreen is already navigating, which GoRouter
    // can collapse into a no-op or race into a blank intermediate frame on
    // slower hosts.  The redirect callback is both deterministic and runs
    // before any route builds, so it covers direct-link, first-frame, and
    // token-expiry transitions equally.

    final themeState = ref.watch(themeProvider);
    final brightness = themeState.resolveBrightness(context);
    final palette = themeState.resolvePalette(brightness);
    final themeData = buildThemeData(palette, brightness);
    final log = _optionalLog;

    // Replace the default grey/red error box with a readable on-screen card
    // so that if the desktop frame throws during its first build, the user
    // still sees something actionable instead of a pure-white screen.
    ErrorWidget.builder = (details) {
      final msg = 'Build error: ${details.exceptionAsString()}';
      if (log != null) {
        unawaited(log.error(details.exception, details.stack ?? StackTrace.current));
      }
      return Container(
        color: const Color(0xFF2A0F12),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3B1518),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF8A2E36)),
            ),
            constraints: const BoxConstraints(maxWidth: 720),
            child: SelectableText.rich(
              TextSpan(
                style: const TextStyle(color: Color(0xFFFFF1F2), fontSize: 13, height: 1.45),
                children: [
                  const TextSpan(
                    text: 'RemoteOS build failure (non-fatal, reported to remoteos.log)\n\n',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFFFB3B9)),
                  ),
                  TextSpan(text: msg),
                  const TextSpan(text: '\n\nStack:\n'),
                  TextSpan(
                    text: (details.stack?.toString() ?? '').split('\n').take(40).join('\n'),
                    style: const TextStyle(color: Color(0xFFF8C9CD)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    return MaterialApp.router(
      title: 'RemoteOS',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: themeData,
      darkTheme: buildThemeData(
        themeState.resolvePalette(Brightness.dark),
        Brightness.dark,
      ),
      themeMode: switch (themeState.kind) {
        ThemeKind.light => ThemeMode.light,
        ThemeKind.dark => ThemeMode.dark,
        ThemeKind.system => ThemeMode.system,
      },
      routerConfig: _router,
      builder: (context, child) {
        final viewport = View.of(context);
        final physical = viewport.physicalSize;
        final logical = MediaQuery.sizeOf(context);
        if (log != null) {
          unawaited(log.info(
            '[shell] MaterialApp builder; child=${child?.runtimeType}'
            ' physical=${physical.width.toStringAsFixed(0)}x${physical.height.toStringAsFixed(0)}'
            ' logical=${logical.width.toStringAsFixed(1)}x${logical.height.toStringAsFixed(1)}',
          ));
        }
        return DesktopWindowShell(
          child: child ?? const SizedBox.shrink(),
          onCloseRequested: () async {
            // Best-effort flush: logout flush happens in DesktopScreen too;
            // the app shell flush protects against closing via the host
            // window chrome before any managed desktop is mounted.
            try {
              await ref
                  .read(workspaceSyncProvider.notifier)
                  .flush()
                  .timeout(const Duration(seconds: 2));
            } catch (_) {
              // Persisting workspace data is best-effort during shutdown.
            }
            await windowManager.close();
          },
        );
      },
    );
  }
}
