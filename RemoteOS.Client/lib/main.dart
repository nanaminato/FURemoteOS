import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:window_manager/window_manager.dart';
import 'package:go_router/go_router.dart';

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
import 'screens/desktop/desktop_screen.dart';

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
      backgroundColor: Colors.transparent,
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
      overrides: [languageCatalogProvider.overrideWithValue(languageCatalog)],
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
    _router = GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        final atLogin = state.matchedLocation == '/login';

        if (!auth.isAuthenticated && !atLogin) return '/login';
        if (auth.isAuthenticated && atLogin) return '/desktop';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/desktop',
          builder: (context, state) => const DesktopScreen(),
        ),
      ],
      errorBuilder: (context, state) =>
          Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthSessionState>(authProvider, (previous, next) {
      final current = _router.routeInformationProvider.value.uri.toString();
      if (next.isAuthenticated &&
          current != '/desktop' &&
          current.startsWith('/login')) {
        _router.go('/desktop');
      } else if (!next.isAuthenticated && !current.startsWith('/login')) {
        _router.go('/login');
      }
    });

    final themeState = ref.watch(themeProvider);
    final brightness = themeState.resolveBrightness(context);
    final palette = themeState.resolvePalette(brightness);
    final themeData = buildThemeData(palette, brightness);

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
      builder: (context, child) => VirtualWindowFrame(
        child: DesktopWindowShell(
          child: child ?? const SizedBox.shrink(),
          onCloseRequested: () async {
            await ref.read(workspaceSyncProvider.notifier).flush();
            await windowManager.close();
          },
        ),
      ),
    );
  }
}
