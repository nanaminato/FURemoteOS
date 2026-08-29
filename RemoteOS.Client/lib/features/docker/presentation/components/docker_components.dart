// Docker feature — shared presentation components.
//
// Small reusable widgets: header, nav, activity strip, generic tables, card
// wrappers and other building blocks. Kept in one file because each widget
// is tiny (~50-150 lines) and semantically part of one layout vocabulary.
//
// These components only depend on Flutter UI types, ThemePalette and the
// public [DockerViewModel] surface (convenience getters + callbacks).

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../../../core/window_manager/window_manager.dart';
import '../../application/docker_view_model.dart';

// =============================================================================
// Navigation
// =============================================================================

class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ThemePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: selected ? palette.accentMuted : Colors.transparent,
                  borderRadius: BorderRadius.circular(5)),
              child: Row(children: [
                Icon(icon,
                    size: 17,
                    color: selected ? palette.accent : palette.textSecondary),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: palette.textPrimary)))
              ]))));
}

// =============================================================================
// Workspace header
// =============================================================================

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.vm,
    required this.palette,
  });

  final DockerViewModel vm;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
          color: palette.surfaceSunken,
          border: Border(bottom: BorderSide(color: palette.borderSubtle))),
      child: Row(children: [
        Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('🐳', style: TextStyle(fontSize: 25)))),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('app.docker_manager'.tr(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary)),
              Text('docker.subtitle'.tr(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: palette.textTertiary)),
            ])),
        const SizedBox(width: 16),
        Tooltip(
            message: 'docker.status.open_install_guide'.tr(),
            child: Material(
                color: palette.accentMuted,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                    // No Help Center app exists in this client; tapping mirrors
                    // the Avalonia activation failure path.
                    onTap: vm.isDockerInstallRequired
                        ? () => vm.statusNote(
                            'docker.status.install_guide_unavailable'.tr())
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.accent)),
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Text(vm.statusText,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: palette.textPrimary)))))),
      ]));
}

// =============================================================================
// Operation activity strip
// =============================================================================

class OperationActivity extends StatelessWidget {
  const OperationActivity({
    super.key,
    required this.vm,
    required this.palette,
  });

  final DockerViewModel vm;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
          color: palette.accentMuted,
          border: Border(bottom: BorderSide(color: palette.borderStrong))),
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: palette.accentMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.borderStrong)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(vm.operationTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary))),
              if (vm.isOperationRunning)
                Text('docker.operation.running_label'.tr(),
                    style: TextStyle(color: palette.info, fontSize: 12)),
            ]),
            if (vm.isOperationRunning)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: palette.borderSubtle,
                      color: palette.accent)),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text('docker.operation.logs'.tr(),
                    style: TextStyle(
                        fontSize: 13, color: palette.textSecondary)),
                children: [
                  Container(
                      constraints:
                          const BoxConstraints(minHeight: 88, maxHeight: 180),
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: palette.borderSubtle)),
                      child: SingleChildScrollView(
                          child: SelectableText(
                              vm.operationLog.isEmpty ? ' ' : vm.operationLog,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: palette.textPrimary)))),
                ]),
          ])));
}

// =============================================================================
// Page primitives
// =============================================================================

class PageCard extends StatelessWidget {
  const PageCard({super.key, required this.palette, required this.child});

  final ThemePalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.borderSubtle)),
      child: child);
}

class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.text,
    required this.palette,
    this.trailing,
  });

  final String text;
  final ThemePalette palette;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary))),
        if (trailing != null) ...trailing!,
      ]);
}

class HintText extends StatelessWidget {
  const HintText(this.text, this.palette, {super.key});

  final String text;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: palette.textSecondary, height: 1.4));
}

class ReadOnlyBlock extends StatelessWidget {
  const ReadOnlyBlock({
    super.key,
    required this.text,
    required this.palette,
    this.minHeight = 32,
    this.maxHeight = 160,
    this.mono = false,
  });

  final String text;
  final ThemePalette palette;
  final double minHeight;
  final double maxHeight;
  final bool mono;

  @override
  Widget build(BuildContext context) => Container(
      constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: palette.surfaceSunken,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: palette.borderSubtle)),
      child: SingleChildScrollView(
          child: SelectableText(text.isEmpty ? ' ' : text,
              style: TextStyle(
                  fontSize: mono ? 12 : 13,
                  fontFamily: mono ? 'monospace' : null,
                  color: palette.textPrimary))));
}

// =============================================================================
// Generic Docker data table (single-selection, horizontally scrollable)
// =============================================================================

class DockerTable<T> extends StatelessWidget {
  const DockerTable({
    super.key,
    required this.rows,
    required this.columns,
    required this.cell,
    required this.selected,
    required this.onSelected,
    required this.palette,
    this.minWidth = 700,
    this.height,
    this.onDoubleTap,
  });

  final List<T> rows;
  final List<(String, double)> columns;
  final String Function(T, int) cell;
  final T? selected;
  final ValueChanged<T?> onSelected;
  final ThemePalette palette;
  final double minWidth;
  final double? height;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: height,
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: GestureDetector(
              onDoubleTap: selected == null ? null : onDoubleTap,
              child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minWidth),
                  child: DataTable(
                      headingRowColor:
                          WidgetStatePropertyAll(palette.surfaceSunken),
                      headingRowHeight: 34,
                      dataRowMinHeight: 34,
                      dataRowMaxHeight: 34,
                      columnSpacing: 18,
                      columns: [
                        for (var index = 0; index < columns.length; index++)
                          DataColumn(
                              label: SizedBox(
                                  width: columns[index].$2,
                                  child: Text(columns[index].$1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: palette.textSecondary))))
                      ],
                      rows: [
                        for (final row in rows)
                          DataRow(
                              selected: identical(row, selected),
                              onSelectChanged: (value) =>
                                  onSelected(value == true ? row : null),
                              cells: [
                                for (var index = 0;
                                    index < columns.length;
                                    index++)
                                  DataCell(SizedBox(
                                      width: columns[index].$2,
                                      child: Text(cell(row, index),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: palette.textPrimary))))
                              ])
                      ])))));
}

// =============================================================================
// Overview metric card
// =============================================================================

class OverviewMetric extends StatelessWidget {
  const OverviewMetric(this.label, this.value, this.palette, {super.key});

  final String label;
  final String value;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: palette.textSecondary)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary)),
      ]));
}

// =============================================================================
// Shared style: danger-styled outlined button
// =============================================================================

Widget dangerButton(String label, ThemePalette palette, VoidCallback? onPressed,
        {double? width, Key? key}) =>
    SizedBox(
        key: key,
        width: width,
        child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(foregroundColor: palette.danger),
            child: Text(label)));

// =============================================================================
// Dialog helpers (footer, label) — reused across all 8 dialogs
// =============================================================================

class DialogFooter extends ConsumerWidget {
  const DialogFooter({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          actions[index],
        ],
      ]);
}

class DialogLabel extends StatelessWidget {
  const DialogLabel(this.text, this.palette, {super.key});

  final String text;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 13, color: palette.textSecondary));
}

// =============================================================================
// Generic reusable text-field helpers used in dialogs.
// =============================================================================

List<String> splitLines(TextEditingController ctrl) => ctrl.text
    .split('\n')
    .map((entry) => entry.trim())
    .where((entry) => entry.isNotEmpty)
    .toList();

/// Copy to clipboard utility (used by container details dialog).
Future<void> copyToClipboard(String text) =>
    Clipboard.setData(ClipboardData(text: text));

/// Helper for Consumer dialogs: dismiss the current dialog window.
void dismissCurrentDialog(WidgetRef ref, BuildContext context) {
  ref
      .read(modalManagerProvider)
      .dismiss(RemoteModalScope.of(context).windowId);
}

/// Helper for Consumer dialogs: complete the current dialog with a result.
void completeCurrentDialog<T>(WidgetRef ref, BuildContext context, T result) {
  ref
      .read(modalManagerProvider)
      .complete(RemoteModalScope.of(context).windowId, result);
}

/// Helper: get the current modal window ID.
String currentModalWindowId(BuildContext context) =>
    RemoteModalScope.of(context).windowId;
