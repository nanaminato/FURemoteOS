import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/task_manager_view_model.dart';
import '../../domain/task_performance_item.dart';
import 'task_manager_components.dart';

class AvaloniaPerformanceWorkspace extends StatelessWidget {
  const AvaloniaPerformanceWorkspace({super.key, required this.vm});
  final TaskManagerViewModel vm;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: vm.state,
        builder: (_, __) {
          final items = vm.performanceItems;
          final selected = vm.selectedPerformanceItem;
          if (items.isEmpty || selected == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Row(children: [
            SizedBox(
                width: 236,
                child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final item in items)
                        _PerformanceNavItem(
                            item: item,
                            selected: item.key == selected.key,
                            onTap: () => vm.selectPerformanceItem(item)),
                    ])),
            VerticalDivider(
                width: 1, thickness: 1, color: context.palette.borderSubtle),
            Expanded(child: _PerformanceDetail(item: selected)),
          ]);
        },
      );
}

class _PerformanceNavItem extends StatelessWidget {
  const _PerformanceNavItem(
      {required this.item, required this.selected, required this.onTap});
  final TaskPerformanceItem item;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        selected: selected,
        onTap: onTap,
        leading: Icon(_icon(item.kind), color: _color(item.kind)),
        title: Text(item.title, overflow: TextOverflow.ellipsis),
        subtitle:
            Text(item.metric, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(item.sideDetail,
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis),
      );
}

class _PerformanceDetail extends StatelessWidget {
  const _PerformanceDetail({required this.item});
  final TaskPerformanceItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _color(item.kind);
    // Mirrors Avalonia `metric-label` (FontSize 12, Opacity 0.67).
    final labelStyle = TextStyle(fontSize: 12, color: palette.textSecondary);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 16, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 0: title + subtitle (left) | metric (right, bottom-aligned).
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(item.subtitle,
                        style: TextStyle(
                            fontSize: 12, color: palette.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(item.metric, style: const TextStyle(fontSize: 19)),
            ],
          ),
          const SizedBox(height: 4),
          // Row 1: "最近 60 秒" (left) | SideDetail (right).
          Row(
            children: [
              Text('task_manager.last_60_seconds'.tr(), style: labelStyle),
              const Spacer(),
              if (item.sideDetail.isNotEmpty)
                Text(item.sideDetail, style: labelStyle),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: 60s history chart (height 270, anchored to chartMaximum).
          SizedBox(
            height: 270,
            width: double.infinity,
            child: CustomPaint(
                painter: HistoryPainter(item.history, color,
                    maximum: item.chartMaximum)),
          ),
          const SizedBox(height: 4),
          // Row 3: "60 秒" (left) | "现在" (right) — chart axis labels.
          Row(
            children: [
              Text('60 秒', style: labelStyle),
              const Spacer(),
              Text('现在', style: labelStyle),
            ],
          ),
          const SizedBox(height: 10),
          // Row 4: details panel — branch on kind to match Avalonia XAML.
          _buildDetails(labelStyle),
        ],
      ),
    );
  }

  Widget _buildDetails(TextStyle labelStyle) => switch (item.kind) {
        TaskPerformanceKind.cpu => _buildCpuDetails(labelStyle),
        TaskPerformanceKind.memory => _buildMemoryDetails(labelStyle),
        _ => _buildStandardDetails(labelStyle),
      };

  (String, String) _cell(int index) =>
      index < item.details.length ? item.details[index] : ('', '—');

  // CPU panel: 6 big fields (3-col grid, r0: 2 cells / r1: 3 cells / r2: 1 cell)
  // + 8 small fields in a right column.  Layout matches Avalonia
  // TaskManagerMainView.axaml Grid.Row=4 IsCpu branch (cols 82,82,82 +
  // right Auto,*).
  Widget _buildCpuDetails(TextStyle labelStyle) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82 * 3 + 8 * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _bigCell(_cell(0), 82, 21, labelStyle),
                    const SizedBox(width: 8),
                    _bigCell(_cell(1), 82, 21, labelStyle),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _bigCell(_cell(2), 82, 19, labelStyle),
                    const SizedBox(width: 8),
                    _bigCell(_cell(3), 82, 19, labelStyle),
                    const SizedBox(width: 8),
                    _bigCell(_cell(4), 82, 19, labelStyle),
                  ],
                ),
                const SizedBox(height: 8),
                _bigCell(_cell(5), 82, 19, labelStyle),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 6; i <= 13; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 6 ? 0 : 3),
                    child: _smallRow(_cell(i), 82, 12, labelStyle),
                  ),
              ],
            ),
          ),
        ],
      );

  // Memory panel: 4 big fields (2x2, 21px) + 3 small fields in a right
  // column (13px).  Matches Avalonia IsMemory branch (cols 125,125 +
  // right Auto,*).
  Widget _buildMemoryDetails(TextStyle labelStyle) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125 * 2 + 12,
            child: Column(
              children: [
                Row(
                  children: [
                    _bigCell(_cell(0), 125, 21, labelStyle),
                    const SizedBox(width: 12),
                    _bigCell(_cell(1), 125, 21, labelStyle),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _bigCell(_cell(2), 125, 21, labelStyle),
                    const SizedBox(width: 12),
                    _bigCell(_cell(3), 125, 21, labelStyle),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 4; i <= 6; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 4 ? 0 : 5),
                    child: _smallRow(_cell(i), null, 13, labelStyle),
                  ),
              ],
            ),
          ),
        ],
      );

  // Filesystem / Disk / Network panel: 4 fields in a 2x2 grid (21/18px).
  // Matches Avalonia UsesStandardDetails branch (cols 160,160).
  Widget _buildStandardDetails(TextStyle labelStyle) => Column(
        children: [
          Row(
            children: [
              _bigCell(_cell(0), 160, 21, labelStyle),
              const SizedBox(width: 18),
              _bigCell(_cell(1), 160, 21, labelStyle),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _bigCell(_cell(2), 160, 18, labelStyle),
              const SizedBox(width: 18),
              _bigCell(_cell(3), 160, 18, labelStyle),
            ],
          ),
        ],
      );

  Widget _bigCell((String, String) detail, double width, double fontSize,
          TextStyle labelStyle) =>
      SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail.$1,
                style: labelStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
            const SizedBox(height: 2),
            Text(detail.$2,
                style: TextStyle(fontSize: fontSize),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ],
        ),
      );

  // Right-column small field row. [labelWidth] null → label sized to content
  // (memory panel); non-null → fixed label column (CPU panel).
  Widget _smallRow((String, String) detail, double? labelWidth,
          double valueFontSize, TextStyle labelStyle) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (labelWidth == null)
            Text(detail.$1, style: labelStyle, overflow: TextOverflow.ellipsis)
          else
            SizedBox(
              width: labelWidth,
              child: Text(detail.$1,
                  style: labelStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(detail.$2,
                style: TextStyle(fontSize: valueFontSize),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
        ],
      );
}

IconData _icon(TaskPerformanceKind kind) => switch (kind) {
      TaskPerformanceKind.cpu => Icons.circle,
      TaskPerformanceKind.memory => Icons.circle,
      TaskPerformanceKind.filesystem => Icons.circle,
      TaskPerformanceKind.disk => Icons.circle,
      TaskPerformanceKind.network => Icons.circle
    };
Color _color(TaskPerformanceKind kind) => switch (kind) {
      TaskPerformanceKind.cpu => const Color(0xFF0078D4),
      TaskPerformanceKind.memory => const Color(0xFF8A2BE2),
      TaskPerformanceKind.filesystem => const Color(0xFF1A9B58),
      TaskPerformanceKind.disk => const Color(0xFFA65E00),
      TaskPerformanceKind.network => const Color(0xFFC45A00)
    };
