import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/theme/theme_models.dart';
import 'package:remoteos_client/core/theme/theme_palette_defaults.dart';

void main() {
  test('built-in palettes resolve every protocol-required token', () {
    for (final paletteId in [
      PaletteIds.remoteosBlue,
      PaletteIds.nord,
      PaletteIds.catppuccin,
    ]) {
      for (final dark in [false, true]) {
        final colors = ThemePaletteDefaults.resolve(
          ThemePreferencesDto(paletteId: paletteId),
          dark,
        );
        expect(ThemePaletteDefaults.isComplete(colors), isTrue);
      }
    }
  });

  test('custom v2 variants and accent overrides derive their dependent roles',
      () {
    final preferences = ThemePreferencesDto(
      paletteId: 'custom:violet',
      accentOverride: '#663399',
      customPalettes: const [
        ThemePaletteDto(
          id: 'violet',
          name: 'Violet',
          lightColors: {'Surface': '#FAFAFA', 'Accent': '#5522AA'},
          darkColors: {'Surface': '#202030', 'Accent': '#BBAAFF'},
        ),
      ],
    );

    final light = ThemePaletteDefaults.resolve(preferences, false);
    final dark = ThemePaletteDefaults.resolve(preferences, true);
    expect(light['Surface'], '#FAFAFA');
    expect(dark['Surface'], '#202030');
    expect(light['Accent'], '#663399');
    expect(dark['Accent'], '#663399');
    expect(light['AccentHover'], isNot('#663399'));
    expect(light['FocusRing'], isNotEmpty);
    expect(light['TextOnAccent'], anyOf('#000000', '#FFFFFF'));
  });

  test('legacy v1 custom palettes only apply to their declared mode', () {
    const palette = ThemePaletteDto(
      formatVersion: 1,
      id: 'legacy',
      name: 'Legacy',
      mode: 'dark',
      colors: {'Accent': '#112233'},
    );
    final preferences = const ThemePreferencesDto(
      paletteId: 'custom:legacy',
      customPalettes: [palette],
    );

    expect(
        ThemePaletteDefaults.resolve(preferences, true)['Accent'], '#112233');
    expect(
      ThemePaletteDefaults.resolve(preferences, false)['Accent'],
      ThemePaletteDefaults.lightBase['Accent'],
    );
  });

  test('theme preference JSON preserves Protocol v1 and v2 payloads', () {
    final preferences = ThemePreferencesDto.fromJson({
      'styleId': 'remoteos',
      'paletteId': 'custom:legacy',
      'accentOverride': '#ABCDEF',
      'customPalettes': [
        {
          'formatVersion': 1,
          'id': 'legacy',
          'name': 'Legacy',
          'mode': 'dark',
          'colors': {'Accent': '#112233'},
        },
        {
          'formatVersion': 2,
          'id': 'modern',
          'name': 'Modern',
          'lightColors': {'Accent': '#445566'},
          'darkColors': {'Accent': '#778899'},
        },
      ],
    });

    expect(preferences.customPalettes, hasLength(2));
    expect(preferences.customPalettes.first.mode, 'dark');
    expect(preferences.toJson()['customPalettes'], hasLength(2));
  });

  test('client accepts only palette tokens accepted by the server contract',
      () {
    final colors = ThemePaletteDefaults.resolve(
      const ThemePreferencesDto(
        paletteId: 'custom:strict',
        customPalettes: [
          ThemePaletteDto(
            id: 'strict',
            name: 'Strict',
            lightColors: {'DangerMuted': '#000000'},
          ),
        ],
      ),
      false,
    );

    expect(
        colors['DangerMuted'], ThemePaletteDefaults.lightBase['DangerMuted']);
  });
}
