import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/theme/theme_palette_defaults.dart';
import 'package:remoteos_client/core/theme/theme_service.dart';
import 'package:remoteos_client/features/settings/presentation/components/settings_widgets.dart';

void main() {
  testWidgets('SettingsComboBox tolerates duplicate persisted item values',
      (tester) async {
    final palette = ThemePalette(ThemePaletteDefaults.resolve(null, false));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsComboBox<String>(
          palette: palette,
          value: 'builtin:cobalt',
          items: const [
            DropdownMenuItem(value: 'builtin:cobalt', child: Text('Cobalt')),
            DropdownMenuItem(
                value: 'builtin:cobalt', child: Text('Cobalt duplicate')),
          ],
          onChanged: (_) {},
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Cobalt'), findsOneWidget);
  });
}
