// Firewall reusable UI components (AGENTS.md § 7 — split by semantic
// responsibility, not tiny meaningless fragments).
//
// * [FirewallChoiceField]: labelled dropdown that mirrors the Avalonia
//   `ChoiceField` control.
// * [FirewallRuleTable]: single-select DataGrid-style rule list.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../data/remote_firewall_api.dart';

/// Labelled dropdown, mirroring the Avalonia `ChoiceField` (see original
/// firewall_app.dart `_ChoiceField`).
class FirewallChoiceField extends StatelessWidget {
  const FirewallChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    this.translationPrefix = 'firewall.choice.',
    this.width,
    this.onChanged,
  });

  final String label;
  final String value;
  final List<String> choices;
  final String translationPrefix;
  final double? width;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          DropdownButtonFormField<String>(
            value: choices.contains(value) ? value : choices.first,
            items: [
              for (final choice in choices)
                DropdownMenuItem(
                  value: choice,
                  child: Text('$translationPrefix$choice'.tr()),
                ),
            ],
            onChanged: onChanged,
            decoration: const InputDecoration(isDense: true),
          ),
        ],
      ),
    );
  }
}

/// Single-select rule table (replaces the inline `_RuleTable` from the
/// monolithic firewall_app.dart).  Column widths + ordering mirror the
/// Avalonia DataGrid.
class FirewallRuleTable extends StatelessWidget {
  const FirewallRuleTable({
    super.key,
    required this.rules,
    required this.selectedRule,
    required this.onSelectRule,
  });

  final List<FirewallRule> rules;
  final FirewallRule? selectedRule;
  final ValueChanged<FirewallRule?> onSelectRule;

  static const List<(String, double)> columns = <(String, double)>[
    ('firewall.rule.number', 70),
    ('firewall.rule.action', 90),
    ('firewall.rule.direction', 100),
    ('firewall.rule.protocol', 90),
    ('firewall.rule.source', 180),
    ('firewall.rule.destination', 180),
    ('firewall.rule.port', 110),
  ];

  static double get totalWidth =>
      columns.map((c) => c.$2).fold<double>(0, (sum, w) => sum + w);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(palette),
            const Divider(height: 1, thickness: 1),
            for (final rule in rules) _buildRow(context, palette, rule),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemePalette palette) {
    return Container(
      color: palette.surfaceSunken,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          for (final c in columns)
            SizedBox(
              width: c.$2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  c.$1.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(
      BuildContext context, ThemePalette palette, FirewallRule rule) {
    final selected = rule.number == selectedRule?.number;
    return Material(
      color: selected ? palette.selectionBackground : Colors.transparent,
      child: InkWell(
        onTap: () => onSelectRule(selected ? null : rule),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              for (int i = 0; i < columns.length; i++)
                SizedBox(
                  width: columns[i].$2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _valueAt(rule, i),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? palette.selectionForeground
                            : palette.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _valueAt(FirewallRule rule, int i) => switch (i) {
        0 => rule.number?.toString() ?? '',
        1 => rule.action,
        2 => rule.direction,
        3 => rule.protocol,
        4 => rule.source,
        5 => rule.destination,
        6 => rule.port,
        _ => '',
      };
}
