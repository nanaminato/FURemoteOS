import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_models.dart';
import 'theme_palette_defaults.dart';

/// A resolved palette of named [Color] values.
class ThemePalette {
  final Map<String, Color> colors;

  ThemePalette(Map<String, String> hexColors)
      : colors = hexColors.map((key, value) => MapEntry(key, _parseHex(value)));

  Color get appBackground => colors['AppBackground']!;
  Color get shellBackground => colors['ShellBackground']!;
  Color get surface => colors['Surface']!;
  Color get surfaceRaised => colors['SurfaceRaised']!;
  Color get surfaceSunken => colors['SurfaceSunken']!;
  Color get surfaceHover => colors['SurfaceHover']!;
  Color get surfacePressed => colors['SurfacePressed']!;

  Color get textPrimary => colors['TextPrimary']!;
  Color get textSecondary => colors['TextSecondary']!;
  Color get textTertiary => colors['TextTertiary']!;
  Color get textDisabled => colors['TextDisabled']!;
  Color get textOnAccent => colors['TextOnAccent']!;
  Color get textOnDanger => colors['TextOnDanger']!;

  Color get borderSubtle => colors['BorderSubtle']!;
  Color get borderDefault => colors['BorderDefault']!;
  Color get borderStrong => colors['BorderStrong']!;
  Color get focusBorder => colors['FocusBorder']!;
  Color get focusRing => colors['FocusRing']!;

  Color get accent => colors['Accent']!;
  Color get accentHover => colors['AccentHover']!;
  Color get accentPressed => colors['AccentPressed']!;
  Color get accentMuted => colors['AccentMuted']!;
  Color get selectionBackground => colors['SelectionBackground']!;
  Color get selectionForeground => colors['SelectionForeground']!;

  Color get success => colors['Success']!;
  Color get successMuted => colors['SuccessMuted']!;
  Color get warning => colors['Warning']!;
  Color get warningMuted => colors['WarningMuted']!;
  Color get danger => colors['Danger']!;
  Color get dangerHover => colors['DangerHover']!;
  Color get dangerPressed => colors['DangerPressed']!;
  Color get info => colors['Info']!;

  Color get taskbarBackground => colors['TaskbarBackground']!;
  Color get taskbarForeground => colors['TaskbarForeground']!;
  Color get startMenuBackground => colors['StartMenuBackground']!;
  Color get windowFrameBackground => colors['WindowFrameBackground']!;
  Color get windowTitleBarBackground => colors['WindowTitleBarBackground']!;
  Color get windowTitleForeground => colors['WindowTitleForeground']!;
  Color get windowInactiveTitleForeground =>
      colors['WindowInactiveTitleForeground']!;
  Color get shadow => colors['Shadow']!;
  Color get desktopIconHover => colors['DesktopIconHover']!;
  Color get desktopIconSelected => colors['DesktopIconSelected']!;
  Color get cardShadow => colors['CardShadow']!;
  Color get flyoutShadow => colors['FlyoutShadow']!;
  Color get dangerMuted => colors['DangerMuted']!;

  static Color _parseHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

/// ThemeNotifier holds the current theme state and exposes methods to change it.
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState());

  // --- Public state accessors ---------------------------------------------
  //
  // MVVM services and repositories read current theme state via get_it; the
  // standard riverpod `state` field is package-private so access must go
  // through this explicit getter.  This matches AGENTS.md § 2 (don't bypass
  // StateNotifier privacy without documenting the intentionality).
  ThemeState get currentState => state;

  ThemePreferencesDto get preferences => state.preferences;

  /// Resolve the current ThemePalette without a BuildContext.  Falls back
  /// to `platformDispatcher.platformBrightness` because the settings repo
  /// is invoked during clipboard actions outside a Flutter view.
  ThemePalette currentPalette() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return state.resolvePalette(
      state.kind == ThemeKind.system
          ? brightness
          : (state.kind == ThemeKind.dark ? Brightness.dark : Brightness.light),
    );
  }

  void setThemeKind(ThemeKind kind) {
    state = state.copyWith(kind: kind);
  }

  void setPaletteId(String paletteId) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(paletteId: paletteId),
    );
  }

  void setAccentOverride(String? color) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(accentOverride: color),
    );
  }

  void setPreferences(ThemePreferencesDto preferences) {
    state = state.copyWith(preferences: preferences);
  }
}

/// Immutable theme state.
class ThemeState {
  final ThemeKind kind;
  final ThemePreferencesDto preferences;

  const ThemeState({
    this.kind = ThemeKind.system,
    this.preferences = ThemePreferencesDto.defaults,
  });

  ThemeState copyWith({
    ThemeKind? kind,
    ThemePreferencesDto? preferences,
  }) =>
      ThemeState(
        kind: kind ?? this.kind,
        preferences: preferences ?? this.preferences,
      );

  bool get isDark => kind == ThemeKind.dark;

  /// Resolve effective brightness (respects System mode via the BuildContext).
  Brightness resolveBrightness(BuildContext context) {
    switch (kind) {
      case ThemeKind.light:
        return Brightness.light;
      case ThemeKind.dark:
        return Brightness.dark;
      case ThemeKind.system:
        return MediaQuery.of(context).platformBrightness;
    }
  }

  /// Resolve palette for the given brightness.
  ThemePalette resolvePalette(Brightness brightness) =>
      ThemePalette(ThemePaletteDefaults.resolve(
        preferences,
        brightness == Brightness.dark,
      ));
}

/// Riverpod provider for ThemeNotifier.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(),
);

/// Convenience watcher: resolved ThemePalette given current brightness.
ThemePalette watchPalette(WidgetRef ref, BuildContext context) {
  final state = ref.watch(themeProvider);
  return state.resolvePalette(state.resolveBrightness(context));
}

/// Build Material [ThemeData] from RemoteOS palette.
ThemeData buildThemeData(ThemePalette palette, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: palette.accent,
    onPrimary: palette.textOnAccent,
    primaryContainer: palette.accentMuted,
    onPrimaryContainer: palette.textPrimary,
    secondary: palette.info,
    onSecondary: palette.textOnAccent,
    error: palette.danger,
    onError: palette.textOnDanger,
    surface: palette.surface,
    onSurface: palette.textPrimary,
    surfaceContainerHighest: palette.surfaceRaised,
    onSurfaceVariant: palette.textSecondary,
    outline: palette.borderDefault,
    outlineVariant: palette.borderSubtle,
    scrim: palette.windowFrameBackground.withOpacity(0.4),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.shellBackground,
    canvasColor: palette.surface,
    dividerColor: palette.borderDefault,
    disabledColor: palette.textDisabled,
    focusColor: palette.focusRing,
    hoverColor: palette.surfaceHover,
    highlightColor: palette.surfacePressed,
    splashColor: palette.accent.withOpacity(0.15),
    fontFamily: 'Segoe UI Variable',
    textTheme: _buildTextTheme(palette, isDark),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      foregroundColor: palette.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: palette.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: palette.accent,
      disabledColor: palette.textDisabled,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.textOnAccent,
        minimumSize: const Size(88, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return palette.accentHover;
          if (states.contains(WidgetState.pressed))
            return palette.accentPressed;
          if (states.contains(WidgetState.disabled))
            return palette.textDisabled;
          return palette.accent;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        minimumSize: const Size(88, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        side: BorderSide(color: palette.borderDefault),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.accent,
        minimumSize: const Size(88, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.focusBorder, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.danger),
      ),
      hintStyle: TextStyle(color: palette.textTertiary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: palette.cardShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: palette.borderSubtle),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      shadowColor: palette.flyoutShadow,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: palette.borderSubtle),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.textSecondary,
      textColor: palette.textPrimary,
      tileColor: Colors.transparent,
      selectedColor: palette.accent,
      selectedTileColor: palette.accentMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.accent,
      linearTrackColor: palette.surfaceSunken,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: palette.accent,
      unselectedLabelColor: palette.textSecondary,
      indicatorColor: palette.accent,
      dividerColor: palette.borderSubtle,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return palette.textOnAccent;
        return palette.textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return palette.accent;
        return palette.borderStrong;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return palette.accent;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(palette.textOnAccent),
      side: BorderSide(color: palette.borderDefault),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return palette.accent;
        return Colors.transparent;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.accent,
      inactiveTrackColor: palette.surfaceSunken,
      thumbColor: palette.accent,
      overlayColor: palette.accent.withOpacity(0.12),
    ),
  );
}

TextTheme _buildTextTheme(ThemePalette palette, bool isDark) {
  return TextTheme(
    displayLarge: TextStyle(
        color: palette.textPrimary, fontSize: 57, fontWeight: FontWeight.w400),
    displayMedium: TextStyle(
        color: palette.textPrimary, fontSize: 45, fontWeight: FontWeight.w400),
    displaySmall: TextStyle(
        color: palette.textPrimary, fontSize: 36, fontWeight: FontWeight.w400),
    headlineLarge: TextStyle(
        color: palette.textPrimary, fontSize: 32, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(
        color: palette.textPrimary, fontSize: 28, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(
        color: palette.textPrimary, fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(
        color: palette.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(
        color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(
        color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(
        color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(
        color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400),
    labelLarge: TextStyle(
        color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500),
    labelSmall: TextStyle(
        color: palette.textTertiary, fontSize: 11, fontWeight: FontWeight.w500),
  );
}

/// Extension for quick access to palette on BuildContext.
extension ThemePaletteX on BuildContext {
  ThemePalette get palette {
    final container = ProviderScope.containerOf(this, listen: false);
    final state = container.read(themeProvider);
    return state.resolvePalette(
      MediaQuery.of(this).platformBrightness,
    );
  }
}
