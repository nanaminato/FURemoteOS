import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../system_monitor/data/remote_system_monitor_api.dart';
import '../../application/task_manager_view_model.dart';
import '../../domain/task_repository.dart';
import '../../domain/task_ui_state.dart';

/// Processes-tab workspace + shared [HistoryPainter].
///
/// The older PerformanceWorkspace (based on a single PerformanceResource +
/// Dropdown) has been removed to match Avalonia: each filesystem, disk and
/// network resource is expanded into a dedicated navigation item. The
/// performance-tab rendering now lives exclusively in
/// [AvaloniaPerformanceWorkspace] (task_manager_performance_workspace.dart).
///
/// All localization uses namedArgs per project rule (AGENTS.md § 23).

class ProcessWorkspace extends StatefulWidget {
  const ProcessWorkspace({super.key, required this.vm});
  final TaskManagerViewModel vm;

  @override
  State<ProcessWorkspace> createState() => _ProcessWorkspaceState();
}

class _ProcessWorkspaceState extends State<ProcessWorkspace> {
  final _filter = TextEditingController();
  final _filterFocus = FocusNode();

  @override
  void dispose() {
    _filter.dispose();
    _filterFocus.dispose();
    super.dispose();
  }

  /// Maps KillFeedbackKind → translation key, with namedArgs built from payload.
  static String? _killFeedbackText(KillFeedback? fb) {
    if (fb == null) return null;
    switch (fb.kind) {
      case KillFeedbackKind.terminating:
        return 'task_manager.process.terminating'.tr(namedArgs: {
          'name': fb.processName,
          'pid': '${fb.processId}',
        });
      case KillFeedbackKind.terminated:
        return 'task_manager.process.terminated'.tr(namedArgs: {
          'name': fb.processName,
          'pid': '${fb.processId}',
        });
      case KillFeedbackKind.elevationRequired:
        return 'task_manager.process.elevation_required'.tr(namedArgs: {
          'name': fb.processName,
          'pid': '${fb.processId}',
          'error': fb.errorMessage ?? '',
        });
      case KillFeedbackKind.failed:
        return 'task_manager.process.termination_failed'.tr(namedArgs: {
          'error': fb.errorMessage ?? '',
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(children: [
      // Toolbar: matches Avalonia's
      // Grid(ColumnDefinitions="*,Auto,Auto,Auto,Auto"):
      //   Filter | process count | Auto-refresh | Clear | End task
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.borderSubtle))),
        child: Row(children: [
          Expanded(
              child: CallbackShortcuts(
            bindings: {
              // Avalonia: Esc in the filter box clears the text.
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (_filter.text.isNotEmpty) {
                  _filter.clear();
                  widget.vm.clearFilterCommand();
                }
              }
            },
            child: TextField(
                controller: _filter,
                focusNode: _filterFocus,
                onChanged: widget.vm.setProcessFilter,
                decoration: InputDecoration(
                    isDense: true,
                    hintText: 'task_manager.filter_placeholder'.tr())),
          )),
          const SizedBox(width: 8),
          ListenableBuilder(
              listenable: widget.vm.state,
              builder: (_, __) => Text(
                  'task_manager.process_count'.tr(namedArgs: {
                    'count': '${widget.vm.state.value.processTotalCount}'
                  }),
                  style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary.withValues(alpha: 0.7)))),
          const SizedBox(width: 8),
          ListenableBuilder(
              listenable: widget.vm.state,
              builder: (_, __) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('task_manager.auto_refresh'.tr()),
                      const SizedBox(width: 4),
                      Checkbox(
                        value: widget.vm.state.value.autoRefresh,
                        onChanged: (v) =>
                            widget.vm.setAutoRefresh(v ?? false),
                      ),
                    ],
                  )),
          const SizedBox(width: 4),
          TextButton(
              onPressed: () {
                _filter.clear();
                widget.vm.clearFilterCommand();
              },
              child: Text('common.clear'.tr())),
          const SizedBox(width: 4),
          ListenableBuilder(
              listenable: widget.vm.state,
              builder: (_, __) {
                final selected = widget.vm.selectedProcess;
                return FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => widget.vm.killProcess(selected.id),
                  child: Text('task_manager.end_task'.tr()),
                );
              }),
        ]),
      ),
      // Kill feedback banner — identical to Avalonia's IsVisible row.
      ListenableBuilder(
          listenable: widget.vm.state,
          builder: (_, __) {
            final feedback = widget.vm.state.value.killFeedback;
            final text = _killFeedbackText(feedback);
            if (text == null) return const SizedBox.shrink();
            return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                alignment: Alignment.centerLeft,
                child: Text(text,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis));
          }),
      // Column header + list body.
      Expanded(
          child: Column(children: [
        const _ProcessHeader(),
        const Divider(height: 1),
        Expanded(
            child: ListenableBuilder(
                listenable: widget.vm.state,
                builder: (_, __) {
                  final state = widget.vm.state.value;
                  final items =
                      state.processes?.items ?? const <RemoteProcess>[];
                  return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final process = items[index];
                        return _ProcessRow(
                            process: process,
                            selected: state.selectedProcessId == process.id,
                            onSelect: () =>
                                widget.vm.selectProcess(process.id));
                      });
                })),
      ])),
    ]);
  }
}

class _ProcessHeader extends StatelessWidget {
  const _ProcessHeader();

  @override
  Widget build(BuildContext context) {
    // Matches Avalonia's header column widths:
    // 2*,70,80,120,120,60 (Name,PID,CPU,Memory,User,Threads).
    final palette = context.palette;
    final textStyle = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        Expanded(flex: 2, child: Text('common.name'.tr(), style: textStyle)),
        SizedBox(width: 70, child: Text('PID', style: textStyle)),
        SizedBox(width: 80, child: Text('CPU', style: textStyle)),
        SizedBox(width: 120, child: Text('Memory', style: textStyle)),
        SizedBox(width: 120, child: Text('User', style: textStyle)),
        SizedBox(width: 60, child: Text('Threads', style: textStyle)),
      ]),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow(
      {required this.process, required this.selected, required this.onSelect});
  final RemoteProcess process;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
        onTap: onSelect,
        canRequestFocus: false,
        child: Container(
          color: selected
              ? palette.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(children: [
            Expanded(
                flex: 2,
                child: Text(process.name, overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 70,
                child: Text('${process.id}',
                    overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 80,
                child: Text('${process.cpuPercent.toStringAsFixed(1)}%',
                    overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 120,
                child: Text(TaskRepository.formatBytes(process.memoryBytes),
                    overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 120,
                child: Text(process.userName ?? '—',
                    overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 60,
                child: Text('${process.threadCount}',
                    overflow: TextOverflow.ellipsis)),
          ]),
        ));
  }
}

/// Shared line-chart painter used by both the legacy performance tab and the
/// new Avalonia-style detail panel. Mirrors Avalonia's PerformanceLineChart.
class HistoryPainter extends CustomPainter {
  const HistoryPainter(this.values, this.color, {this.maximum});
  final List<double> values;
  final Color color;
  final double? maximum;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withValues(alpha: .18)
      ..strokeWidth = 1;
    for (var step = 1; step < 4; step++) {
      canvas.drawLine(Offset(0, size.height * step / 4),
          Offset(size.width, size.height * step / 4), grid);
    }
    if (values.length < 2) return;
    final dataMax = values.reduce((a, b) => a > b ? a : b);
    final max = (maximum ?? dataMax).clamp(1, double.infinity);
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final rawY = size.height - values[index] / max * size.height;
      final y = rawY.clamp(0.0, size.height);
      final point = Offset(size.width * index / (values.length - 1), y);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(HistoryPainter old) =>
      old.values != values || old.color != color || old.maximum != maximum;
}
