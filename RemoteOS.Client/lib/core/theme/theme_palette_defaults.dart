import 'dart:math';
import 'theme_models.dart';

/// Single source of truth for RemoteOS built-in palette values and derived accent roles.
class ThemePaletteDefaults {
  static final Map<String, String> lightBase = {
    'AppBackground': '#F3F3F3',
    'ShellBackground': '#F7F7F7',
    'Surface': '#FFFFFF',
    'SurfaceRaised': '#FFFFFF',
    'SurfaceSunken': '#EEF3FA',
    'SurfaceHover': '#F0F0F0',
    'SurfacePressed': '#E5E5E5',
    'TextPrimary': '#1F1F1F',
    'TextSecondary': '#616161',
    'TextTertiary': '#72819A',
    'TextDisabled': '#A0A0A0',
    'TextOnAccent': '#FFFFFF',
    'TextOnDanger': '#FFFFFF',
    'BorderSubtle': '#E5EAF2',
    'BorderDefault': '#D6DCE5',
    'BorderStrong': '#8AB9E5',
    'FocusBorder': '#0078D4',
    'FocusRing': '#0078D4',
    'Accent': '#0078D4',
    'AccentHover': '#1A86D9',
    'AccentPressed': '#005A9E',
    'AccentMuted': '#E6F0FA',
    'SelectionBackground': '#E6F0FA',
    'SelectionForeground': '#1F1F1F',
    'Success': '#107C10',
    'SuccessMuted': '#DFF6DD',
    'Warning': '#C77A00',
    'WarningMuted': '#FFF4CE',
    'Danger': '#C42B1C',
    'DangerHover': '#B3271D',
    'DangerPressed': '#8F2117',
    'DangerMuted': '#FDE7E9',
    'Info': '#2369A7',
    'TaskbarBackground': '#F7F7F7',
    'TaskbarForeground': '#1F1F1F',
    'StartMenuBackground': '#FFFFFF',
    'WindowFrameBackground': '#FFFFFF',
    'WindowTitleBarBackground': '#F5F5F5',
    'WindowTitleForeground': '#202020',
    'WindowInactiveTitleForeground': '#4F4F4F',
    'OverlayScrim': '#66000000',
    'Shadow': '#22000000',
    'DesktopIconHover': '#220078D4',
    'DesktopIconSelected': '#330078D4',
    'CardShadow': '#22000000',
    'FlyoutShadow': '#22000000',
    'DialogScrim': '#3D000000',
    'ChartGridLine': '#E5EBF5',
    'ChartSeries1': '#0078D4',
    'ChartSeries2': '#107C10',
    'ChartSeries3': '#C77A00',
    'ChartSeries4': '#C42B1C',
    'ChartSeries5': '#7B61FF',
    'ChartSeries6': '#008272',
    'ChartSeries7': '#B146C2',
    'ChartSeries8': '#2369A7',
  };

  static final Map<String, String> darkBase = {
    'AppBackground': '#202020',
    'ShellBackground': '#202020',
    'Surface': '#2B2B2B',
    'SurfaceRaised': '#333333',
    'SurfaceSunken': '#252525',
    'SurfaceHover': '#3A3A3A',
    'SurfacePressed': '#454545',
    'TextPrimary': '#F5F5F5',
    'TextSecondary': '#C8C8C8',
    'TextTertiary': '#A8A8A8',
    'TextDisabled': '#777777',
    'TextOnAccent': '#FFFFFF',
    'TextOnDanger': '#FFFFFF',
    'BorderSubtle': '#3A3A3A',
    'BorderDefault': '#515151',
    'BorderStrong': '#6FAEE8',
    'FocusBorder': '#4CC2FF',
    'FocusRing': '#4CC2FF',
    'Accent': '#4CC2FF',
    'AccentHover': '#70D0FF',
    'AccentPressed': '#249DDB',
    'AccentMuted': '#174665',
    'SelectionBackground': '#174665',
    'SelectionForeground': '#FFFFFF',
    'Success': '#6CCB5F',
    'SuccessMuted': '#183C1B',
    'Warning': '#FFD166',
    'WarningMuted': '#4A3B14',
    'Danger': '#FF7262',
    'DangerHover': '#FF8C80',
    'DangerPressed': '#D94D40',
    'DangerMuted': '#3F1512',
    'Info': '#6AB8FF',
    'TaskbarBackground': '#242424',
    'TaskbarForeground': '#F5F5F5',
    'StartMenuBackground': '#2B2B2B',
    'WindowFrameBackground': '#2B2B2B',
    'WindowTitleBarBackground': '#333333',
    'WindowTitleForeground': '#F5F5F5',
    'WindowInactiveTitleForeground': '#B0B0B0',
    'OverlayScrim': '#99000000',
    'Shadow': '#66000000',
    'DesktopIconHover': '#334CC2FF',
    'DesktopIconSelected': '#554CC2FF',
    'CardShadow': '#66000000',
    'FlyoutShadow': '#66000000',
    'DialogScrim': '#66000000',
    'ChartGridLine': '#515151',
    'ChartSeries1': '#4CC2FF',
    'ChartSeries2': '#6CCB5F',
    'ChartSeries3': '#FFD166',
    'ChartSeries4': '#FF7262',
    'ChartSeries5': '#B9A7FF',
    'ChartSeries6': '#4FD1C5',
    'ChartSeries7': '#E9A8F2',
    'ChartSeries8': '#6AB8FF',
  };

  static final Map<String, String> nordLight = {
    'AppBackground': '#ECEFF4',
    'ShellBackground': '#E5E9F0',
    'Surface': '#FFFFFF',
    'SurfaceRaised': '#F8FAFC',
    'SurfaceSunken': '#E5E9F0',
    'TextPrimary': '#2E3440',
    'TextSecondary': '#4C566A',
    'TextTertiary': '#5E6A7D',
    'BorderDefault': '#D8DEE9',
    'Accent': '#5E81AC',
    'Info': '#88C0D0',
    'Success': '#A3BE8C',
    'Warning': '#EBCB8B',
    'Danger': '#BF616A',
  };

  static final Map<String, String> nordDark = {
    'AppBackground': '#2E3440',
    'ShellBackground': '#2E3440',
    'Surface': '#3B4252',
    'SurfaceRaised': '#434C5E',
    'SurfaceSunken': '#2E3440',
    'TextPrimary': '#ECEFF4',
    'TextSecondary': '#D8DEE9',
    'TextTertiary': '#B8C2D2',
    'BorderDefault': '#4C566A',
    'Accent': '#5E81AC',
    'Info': '#88C0D0',
    'Success': '#A3BE8C',
    'Warning': '#EBCB8B',
    'Danger': '#BF616A',
  };

  static final Map<String, String> catppuccinLight = {
    'AppBackground': '#EFF1F5',
    'ShellBackground': '#E6E9EF',
    'Surface': '#FFFFFF',
    'SurfaceRaised': '#F7F8FB',
    'SurfaceSunken': '#E6E9EF',
    'TextPrimary': '#4C4F69',
    'TextSecondary': '#6C6F85',
    'TextTertiary': '#7C7F93',
    'BorderDefault': '#CCD0DA',
    'Accent': '#1E66F5',
    'Info': '#04A5E5',
    'Success': '#40A02B',
    'Warning': '#DF8E1D',
    'Danger': '#D20F39',
  };

  static final Map<String, String> catppuccinDark = {
    'AppBackground': '#1E1E2E',
    'ShellBackground': '#1E1E2E',
    'Surface': '#313244',
    'SurfaceRaised': '#45475A',
    'SurfaceSunken': '#181825',
    'TextPrimary': '#CDD6F4',
    'TextSecondary': '#BAC2DE',
    'TextTertiary': '#A6ADC8',
    'BorderDefault': '#585B70',
    'Accent': '#89B4FA',
    'Info': '#89DCEB',
    'Success': '#A6E3A1',
    'Warning': '#F9E2AF',
    'Danger': '#F38BA8',
  };

  static Map<String, String> resolve(
      ThemePreferencesDto? preferences, bool dark) {
    final result = Map<String, String>.from(dark ? darkBase : lightBase);
    final source = preferences ?? ThemePreferencesDto.defaults;
    Map<String, String>? palette;

    switch (source.paletteId) {
      case PaletteIds.nord:
        palette = dark ? nordDark : nordLight;
        break;
      case PaletteIds.catppuccin:
        palette = dark ? catppuccinDark : catppuccinLight;
        break;
      default:
        if (source.paletteId.startsWith('custom:')) {
          palette = _resolveCustom(source, dark);
        }
    }

    if (palette != null) {
      _overlay(result, palette);
    } else {
      _applyDerivedRoles(result);
    }

    if (source.accentOverride != null &&
        source.accentOverride!.isNotEmpty &&
        isColor(source.accentOverride!)) {
      result['Accent'] = normalize(source.accentOverride!);
      _applyDerivedRoles(result);
    }

    return result;
  }

  static Map<String, String>? _resolveCustom(
      ThemePreferencesDto preferences, bool dark) {
    final id = preferences.paletteId.substring('custom:'.length);
    try {
      final palette = preferences.customPalettes.firstWhere((p) => p.id == id);
      if (palette.formatVersion >= 2) {
        return dark ? palette.darkColors : palette.lightColors;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static void _overlay(Map<String, String> target, Map<String, String> source) {
    for (final entry in source.entries) {
      if (ThemePaletteContract.colorTokens.contains(entry.key) &&
          isColor(entry.value)) {
        target[entry.key] = normalize(entry.value);
      }
    }
    _applyDerivedRoles(target);
  }

  static void _applyDerivedRoles(Map<String, String> target) {
    final accent = target['Accent']!;
    target['AccentHover'] = adjust(accent, 0.12);
    target['AccentPressed'] = adjust(accent, -0.16);
    target['AccentMuted'] = blend(accent, target['SurfaceRaised']!, 0.15);
    target['SelectionBackground'] =
        blend(accent, target['SurfaceRaised']!, 0.20);
    target['SelectionForeground'] =
        bestForeground(target['SelectionBackground']!);
    final focus = ensureContrast(accent, target['Surface']!, 3.0);
    target['FocusBorder'] = focus;
    target['FocusRing'] = focus;
    target['TextOnAccent'] = bestForeground(accent);
    target['TextOnDanger'] = bestForeground(target['Danger']!);
  }

  static String bestForeground(String background) =>
      contrast('#000000', background) >= contrast('#FFFFFF', background)
          ? '#000000'
          : '#FFFFFF';

  static String ensureContrast(
          String foreground, String background, double minimum) =>
      contrast(foreground, background) >= minimum
          ? foreground
          : bestForeground(background);

  static String blend(String foreground, String background, double alpha) {
    final fg = parse(foreground);
    final bg = parse(background);
    final r = (fg.r * alpha + bg.r * (1 - alpha)).round().clamp(0, 255);
    final g = (fg.g * alpha + bg.g * (1 - alpha)).round().clamp(0, 255);
    final b = (fg.b * alpha + bg.b * (1 - alpha)).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  static String adjust(String color, double amount) {
    final c = parse(color);
    int shift(int v) =>
        (v + (amount < 0 ? v : 255 - v) * amount).round().clamp(0, 255);
    return '#${shift(c.r).toRadixString(16).padLeft(2, '0')}'
            '${shift(c.g).toRadixString(16).padLeft(2, '0')}'
            '${shift(c.b).toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  static ({int r, int g, int b}) parse(String color) {
    final c = color.replaceFirst('#', '');
    final hex = c.length == 8 ? c.substring(2) : c;
    return (
      r: int.parse(hex.substring(0, 2), radix: 16),
      g: int.parse(hex.substring(2, 4), radix: 16),
      b: int.parse(hex.substring(4, 6), radix: 16),
    );
  }

  static double contrast(String first, String second) {
    double luminance(String color) {
      double channel(int value) {
        final c = value / 255.0;
        return c <= 0.04045
            ? c / 12.92
            : pow((c + 0.055) / 1.055, 2.4).toDouble();
      }

      final rgb = parse(color);
      return 0.2126 * channel(rgb.r) +
          0.7152 * channel(rgb.g) +
          0.0722 * channel(rgb.b);
    }

    final a = luminance(first);
    final b = luminance(second);
    return (max(a, b) + 0.05) / (min(a, b) + 0.05);
  }

  static bool isComplete(Map<String, String> colors) =>
      ThemePaletteContract.requiredColorTokens
          .every((key) => colors.containsKey(key) && isColor(colors[key]!));

  static bool isColor(String value) {
    if (value.length != 7 && value.length != 9) return false;
    if (value[0] != '#') return false;
    return value
        .substring(1)
        .split('')
        .every((c) => '0123456789ABCDEFabcdef'.contains(c));
  }

  static String normalize(String value) => value.toUpperCase();
}
