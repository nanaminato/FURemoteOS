// Terminal settings dialog (AGENTS.md § 18 — ModalHost / ModalCoordinator
// style).
//
// Hosted by [ModalManager] so the dialog stays scoped to the terminal app's
// own [RemoteWindowScope] (it cannot block the whole workspace window, and
// participates in desktop z-order/focus restoration like Avalonia's
// `RemoteWindow` modal).  The dialog closes itself via
// `RemoteModalScope.of(context).windowId` + `ModalManager.dismiss` instead of
// `Navigator.pop`, mirroring `NotepadSettingsDialog`.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../../../core/window_manager/window_manager.dart';

/// Settings dialog for the Terminal app: font family / size / color scheme.
///
/// Mirrors Avalonia's `TerminalSettingsView`.  Each change is forwarded to the
/// host view through the `on*Changed` callbacks so the live xterm buffer is
/// restyled immediately; the dialog itself only mirrors the current selection
/// so the dropdowns stay in sync while the modal is open.
class TerminalSettingsDialog extends ConsumerStatefulWidget {
  const TerminalSettingsDialog({
    super.key,
    required this.colorScheme,
    required this.fontSize,
    required this.fontFamily,
    required this.onColorSchemeChanged,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
  });

  final String colorScheme;
  final double fontSize;
  final String fontFamily;
  final ValueChanged<String> onColorSchemeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<String> onFontFamilyChanged;

  /// Default scheme name; matches Avalonia's `TerminalAppearance.DefaultScheme`
  /// ("Campbell").  The View uses this as the initial selection.
  static const String defaultScheme = 'Campbell';

  /// Available options.  Static so the host View does not need to keep its own
  /// copies in scope.
  static const List<String> colorSchemes = [
    defaultScheme,
    'One Half Dark',
    'Solarized Dark',
    'Light',
  ];
  static const List<double> fontSizes = [12, 14, 16, 18, 20, 24];
  static const List<String> fontFamilies = [
    'Cascadia Mono',
    'Consolas',
    'JetBrains Mono',
    'Courier New',
  ];

  @override
  ConsumerState<TerminalSettingsDialog> createState() =>
      _TerminalSettingsDialogState();
}

class _TerminalSettingsDialogState
    extends ConsumerState<TerminalSettingsDialog> {
  late String _colorScheme = widget.colorScheme;
  late double _fontSize = widget.fontSize;
  late String _fontFamily = widget.fontFamily;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'terminal.settings'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          _buildFontFamilyRow(),
          const SizedBox(height: 14),
          _buildFontSizeRow(),
          const SizedBox(height: 14),
          _buildColorSchemeRow(),
          const SizedBox(height: 16),
          Text(
            'terminal.settings.description'.tr(),
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => modals.dismiss(dialogId),
              child: Text('common.ok'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontFamilyRow() {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            'terminal.font_family'.tr(),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue:
                TerminalSettingsDialog.fontFamilies.contains(_fontFamily)
                    ? _fontFamily
                    : null,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            items: TerminalSettingsDialog.fontFamilies
                .map((f) => DropdownMenuItem<String>(value: f, child: Text(f)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _fontFamily = value);
              widget.onFontFamilyChanged(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFontSizeRow() {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            'terminal.font_size'.tr(),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<double>(
            initialValue: TerminalSettingsDialog.fontSizes.contains(_fontSize)
                ? _fontSize
                : null,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            items: TerminalSettingsDialog.fontSizes
                .map((s) => DropdownMenuItem<double>(
                      value: s,
                      child: Text(s.toStringAsFixed(0)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _fontSize = value);
              widget.onFontSizeChanged(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorSchemeRow() {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            'terminal.color_scheme'.tr(),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue:
                TerminalSettingsDialog.colorSchemes.contains(_colorScheme)
                    ? _colorScheme
                    : null,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            items: TerminalSettingsDialog.colorSchemes
                .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _colorScheme = value);
              widget.onColorSchemeChanged(value);
            },
          ),
        ),
      ],
    );
  }
}
