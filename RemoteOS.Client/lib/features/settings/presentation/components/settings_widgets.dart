// Reusable UI widgets shared across all Settings pages.
//
// Purely layout / theme components — they depend only on ThemePalette
// tokens, never on feature state (AGENTS.md § 8).  Import this file from
// settings pages via the feature-first location
// `features/settings/presentation/components/settings_widgets.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/dependency_injection.dart' as app_di show di;
import '../../../../core/theme/theme_service.dart';

/// A hero section shown at the top of each Settings page with an icon, a
/// title and an optional subtitle. Mirrors Avalonia's `FASettingsExpander`
/// heading style.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.palette,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.accentMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: palette.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!,
                    style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                        height: 1.35)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A small bold label used to announce sub-sections inside a page.
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(
      {super.key, required this.title, required this.palette});
  final String title;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: palette.textSecondary),
      ),
    );
  }
}

/// A Fluent-style card container used to group related rows.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.palette, required this.children});
  final ThemePalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                    height: 1, color: palette.borderSubtle, thickness: 1),
              ),
          ],
        ],
      ),
    );
  }
}

/// A simple label + value row used in the System / About sections.
class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    required this.palette,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 180,
          child: Text(label,
              style: TextStyle(color: palette.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                color: valueColor ?? palette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// A label (with optional description) plus an arbitrary control row. Used
/// heavily by the ComboBox fields in Personalization and Time/Language pages.
class SettingsLabeledRow extends StatelessWidget {
  const SettingsLabeledRow({
    super.key,
    required this.label,
    required this.control,
    this.description,
    required this.palette,
  });
  final String label;
  final Widget control;
  final String? description;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(description!,
                    style:
                        TextStyle(color: palette.textTertiary, fontSize: 11)),
              ],
            ],
          ),
        ),
        Expanded(child: control),
      ],
    );
  }
}

/// A minimal dropdown wrapper used by Personalization and Default Apps pages.
class SettingsComboBox<T> extends StatelessWidget {
  const SettingsComboBox({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.palette,
  });
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          items: items,
          onChanged: onChanged,
          dropdownColor: palette.surface,
          style: TextStyle(color: palette.textPrimary, fontSize: 13),
        ),
      ),
    );
  }
}

ThemePalette watchPalette(WidgetRef ref, BuildContext context) =>
    WatchItExtension.readPalette(context);

/// Tiny extension so watchPalette() works from legacy riverpod call sites.
extension WatchItExtension on BuildContext {
  static ThemePalette readPalette(BuildContext context) {
    final notifier = getPaletteNotifier(context);
    return notifier.currentPalette();
  }

  static ThemeNotifier getPaletteNotifier(BuildContext context) {
    try {
      final notifier = app_di.di<ThemeNotifier>();
      return notifier;
    } catch (_) {
      rethrow;
    }
  }
}
