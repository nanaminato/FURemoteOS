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
      if (items.isEmpty || selected == null) return const Center(child: CircularProgressIndicator());
      return Row(children: [
        SizedBox(width: 236, child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
          for (final item in items) _PerformanceNavItem(item: item, selected: item.key == selected.key, onTap: () => vm.selectPerformanceItem(item)),
        ])),
        VerticalDivider(width: 1, thickness: 1, color: context.palette.borderSubtle),
        Expanded(child: _PerformanceDetail(item: selected)),
      ]);
    },
  );
}

class _PerformanceNavItem extends StatelessWidget {
  const _PerformanceNavItem({required this.item, required this.selected, required this.onTap});
  final TaskPerformanceItem item; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true, selected: selected, onTap: onTap,
    leading: Icon(_icon(item.kind), color: _color(item.kind)),
    title: Text(item.title, overflow: TextOverflow.ellipsis),
    subtitle: Text(item.metric, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: Text(item.sideDetail, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
  );
}

class _PerformanceDetail extends StatelessWidget {
  const _PerformanceDetail({required this.item});
  final TaskPerformanceItem item;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(26, 16, 24, 22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)), Text(item.subtitle, style: const TextStyle(fontSize: 12))])), Text(item.metric, style: const TextStyle(fontSize: 19))]),
      const SizedBox(height: 16),
      const Text('最近 60 秒', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
      SizedBox(height: 270, width: double.infinity, child: CustomPaint(painter: HistoryPainter(item.history, _color(item.kind), maximum: item.chartMaximum))),
      const SizedBox(height: 18),
      Wrap(spacing: 24, runSpacing: 14, children: [for (final detail in item.details) SizedBox(width: 110, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(detail.$1, style: const TextStyle(fontSize: 12)), Text(detail.$2, style: const TextStyle(fontSize: 17))]))]),
    ]),
  );
}

IconData _icon(TaskPerformanceKind kind) => switch (kind) { TaskPerformanceKind.cpu => Icons.circle, TaskPerformanceKind.memory => Icons.circle, TaskPerformanceKind.filesystem => Icons.circle, TaskPerformanceKind.disk => Icons.circle, TaskPerformanceKind.network => Icons.circle };
Color _color(TaskPerformanceKind kind) => switch (kind) { TaskPerformanceKind.cpu => const Color(0xFF0078D4), TaskPerformanceKind.memory => const Color(0xFF8A2BE2), TaskPerformanceKind.filesystem => const Color(0xFF1A9B58), TaskPerformanceKind.disk => const Color(0xFFA65E00), TaskPerformanceKind.network => const Color(0xFFC45A00) };
