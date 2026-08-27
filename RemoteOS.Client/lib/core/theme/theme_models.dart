import 'package:flutter/material.dart';

/// Theme kinds matching the Protocol's ThemeKind enum.
enum ThemeKind {
  light,
  dark,
  system,
}

/// Built-in palette IDs.
class PaletteIds {
  static const String remoteosBlue = 'builtin:remoteos-blue';
  static const String nord = 'builtin:nord';
  static const String catppuccin = 'builtin:catppuccin';
}

/// A palette DTO (mirrors Protocol DTO for client use).
class ThemePaletteDto {
  final int formatVersion;
  final String id;
  final String name;
  final Map<String, String>? lightColors;
  final Map<String, String>? darkColors;

  const ThemePaletteDto({
    this.formatVersion = 2,
    required this.id,
    required this.name,
    this.lightColors,
    this.darkColors,
  });
}

/// Theme preferences DTO (mirrors Protocol DTO).
class ThemePreferencesDto {
  final String styleId;
  final String paletteId;
  final String? accentOverride;
  final List<ThemePaletteDto> customPalettes;

  const ThemePreferencesDto({
    this.styleId = 'remoteos',
    this.paletteId = PaletteIds.remoteosBlue,
    this.accentOverride,
    this.customPalettes = const [],
  });

  ThemePreferencesDto copyWith({
    String? styleId,
    String? paletteId,
    String? accentOverride,
    List<ThemePaletteDto>? customPalettes,
    bool clearAccentOverride = false,
  }) {
    return ThemePreferencesDto(
      styleId: styleId ?? this.styleId,
      paletteId: paletteId ?? this.paletteId,
      accentOverride:
          clearAccentOverride ? null : (accentOverride ?? this.accentOverride),
      customPalettes: customPalettes ?? this.customPalettes,
    );
  }

  static const ThemePreferencesDto defaults = ThemePreferencesDto();
}

/// Token contract for required palette keys.
class ThemePaletteContract {
  static const Set<String> requiredColorTokens = {
    'AppBackground',
    'ShellBackground',
    'Surface',
    'SurfaceRaised',
    'SurfaceSunken',
    'SurfaceHover',
    'SurfacePressed',
    'TextPrimary',
    'TextSecondary',
    'TextTertiary',
    'TextDisabled',
    'TextOnAccent',
    'TextOnDanger',
    'BorderSubtle',
    'BorderDefault',
    'BorderStrong',
    'FocusBorder',
    'FocusRing',
    'Accent',
    'AccentHover',
    'AccentPressed',
    'AccentMuted',
    'SelectionBackground',
    'SelectionForeground',
    'Success',
    'SuccessMuted',
    'Warning',
    'WarningMuted',
    'Danger',
    'DangerHover',
    'DangerPressed',
    'DangerMuted',
    'Info',
  };

  static const Set<String> colorTokens = {
    ...requiredColorTokens,
    ...{
      'TaskbarBackground',
      'TaskbarForeground',
      'StartMenuBackground',
      'WindowFrameBackground',
      'WindowTitleBarBackground',
      'WindowTitleForeground',
      'WindowInactiveTitleForeground',
      'OverlayScrim',
      'Shadow',
      'DesktopIconHover',
      'DesktopIconSelected',
      'CardShadow',
      'FlyoutShadow',
      'DialogScrim',
      'ChartGridLine',
      'ChartSeries1',
      'ChartSeries2',
      'ChartSeries3',
      'ChartSeries4',
      'ChartSeries5',
      'ChartSeries6',
      'ChartSeries7',
      'ChartSeries8',
    }
  };
}
