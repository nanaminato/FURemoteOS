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
  /// Protocol v1 import compatibility. The server normalizes it to v2.
  final String? mode;
  final Map<String, String>? colors;

  const ThemePaletteDto({
    this.formatVersion = 2,
    required this.id,
    required this.name,
    this.lightColors,
    this.darkColors,
    this.mode,
    this.colors,
  });

  factory ThemePaletteDto.fromJson(Map<String, dynamic> json) =>
      ThemePaletteDto(
        formatVersion: json['formatVersion'] as int? ?? 2,
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        lightColors: _colorMap(json['lightColors']),
        darkColors: _colorMap(json['darkColors']),
        mode: json['mode'] as String?,
        colors: _colorMap(json['colors']),
      );

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'id': id,
        'name': name,
        if (lightColors != null) 'lightColors': lightColors,
        if (darkColors != null) 'darkColors': darkColors,
        if (mode != null) 'mode': mode,
        if (colors != null) 'colors': colors,
      };
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

  factory ThemePreferencesDto.fromJson(Map<String, dynamic> json) {
    final rawPalettes = json['customPalettes'];
    return ThemePreferencesDto(
      styleId: json['styleId'] as String? ?? 'remoteos',
      paletteId: json['paletteId'] as String? ?? PaletteIds.remoteosBlue,
      accentOverride: json['accentOverride'] as String?,
      customPalettes: rawPalettes is List
          ? rawPalettes
              .whereType<Map<String, dynamic>>()
              .map(ThemePaletteDto.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'styleId': styleId,
        'paletteId': paletteId,
        'accentOverride': accentOverride,
        'customPalettes': customPalettes.map((palette) => palette.toJson()).toList(),
      };
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

Map<String, String>? _colorMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! String) return null;
    result[entry.key as String] = entry.value as String;
  }
  return result;
}
