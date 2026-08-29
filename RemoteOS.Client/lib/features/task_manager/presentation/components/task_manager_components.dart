// Task Manager visual components split by responsibility.
//
// * [ResourceMetricsGrid]: 5 summary cards (CPU/Memory/Filesystem/Disk/Net).
// * [ResourceDetailPanel]: metadata panel below the history chart.
// * [HistoryPainter]: line-chart CustomPainter for the last 60s window.
// * [ProcessListPane]: filter + process list + kill actions.

import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../system_monitor/data/remote_system_monitor_api.dart';
import '../../application/task_manager_view_model.dart';
import '../../domain/task_repository.dart';

// =============================================================================
// Resource metrics grid
// =============================================================================

class ResourceMetricsGrid extends StatelessWidget {
  const ResourceMetricsGrid({super.key, required this.vm});

  final TaskManagerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: vm.state,
      builder: (context, _) {
        final s = vm.state.value;
        final snapshot = s.snapshot;
        if (snapshot == null) {
          return const Center(
            child: Text('Waiting for performance samples…'),
          );
        }
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _tile(
              palette: palette,
              resource: PerformanceResource.cpu,
              selected: s.selectedResource == PerformanceResource.cpu,
              title: 'CPU',
              value: '${snapshot.cpuPercent.toStringAsFixed(1)}%',
              progress: snapshot.cpuPercent,
              onTap: () => vm.selectResource(PerformanceResource.cpu),
            ),
            _tile(
              palette: palette,
              resource: PerformanceResource.memory,
              selected: s.selectedResource == PerformanceResource.memory,
              title: 'Memory',
              value:
                  '${TaskRepository.formatBytes(snapshot.memoryUsedBytes)} / ${TaskRepository.formatBytes(snapshot.memoryTotalBytes)}',
              progress: s.memoryPercent,
              onTap: () => vm.selectResource(PerformanceResource.memory),
            ),
            _tile(
              palette: palette,
              resource: PerformanceResource.filesystem,
              selected: s.selectedResource == PerformanceResource.filesystem,
              title: 'Filesystem',
              value:
                  '${TaskRepository.formatBytes(snapshot.filesystemUsedBytes)} / ${TaskRepository.formatBytes(snapshot.filesystemTotalBytes)}',
              progress: s.filesystemPercent,
              onTap: () => vm.selectResource(PerformanceResource.filesystem),
            ),
            _tile(
              palette: palette,
              resource: PerformanceResource.disk,
              selected: s.selectedResource == PerformanceResource.disk,
              title: 'Disk I/O',
              value:
                  'Read ${TaskRepository.formatRate(snapshot.diskReadBytesPerSecond)} · Write ${TaskRepository.formatRate(snapshot.diskWriteBytesPerSecond)}',
              progress: 0,
              onTap: () => vm.selectResource(PerformanceResource.disk),
            ),
            _tile(
              palette: palette,
              resource: PerformanceResource.network,
              selected: s.selectedResource == PerformanceResource.network,
              title: 'Network',
              value:
                  'Receive ${TaskRepository.formatRate(snapshot.networkReceiveBytesPerSecond)} · Send ${TaskRepository.formatRate(snapshot.networkSendBytesPerSecond)}',
              progress: 0,
              onTap: () => vm.selectResource(PerformanceResource.network),
            ),
          ],
        );
      },
    );
  }

  Widget _tile({
    required ThemePalette palette,
    required PerformanceResource resource,
    required bool selected,
    required String title,
    required String value,
    required double progress,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 310,
      child: InkWell(
        onTap: onTap,
        child: Card(
          shape: selected
              ? RoundedRectangleBorder(
                  side: BorderSide(color: palette.accent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(resource.icon, color: palette.accent),
                    const SizedBox(width: 8),
                    Text(title),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (progress / 100).clamp(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Resource history chart + detail panel
// =============================================================================

class ResourceHistorySection extends StatelessWidget {
  const ResourceHistorySection({super.key, required this.vm});

  final TaskManagerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: vm.state,
      builder: (context, _) {
        final s = vm.state.value;
        final choices = vm.resourceChoices(s.info, s.selectedResource);
        final values = [
          for (final item in s.history)
            vm.historyValue(item, s.selectedResource, s.selectedResourceId),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.selectedResource.label} · Last 60 seconds',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (choices.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButton<String?>(
                value: s.selectedResourceId,
                hint: const Text('All resources'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All resources'),
                  ),
                  for (final item in choices)
                    DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(item.name),
                    )
                ],
                onChanged: vm.setSelectedResourceId,
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              width: double.infinity,
              child: CustomPaint(
                painter: HistoryPainter(values, palette.accent),
              ),
            ),
            const SizedBox(height: 14),
            ResourceDetailPanel(vm: vm),
          ],
        );
      },
    );
  }
}

class ResourceDetailPanel extends StatelessWidget {
  const ResourceDetailPanel({super.key, required this.vm});

  final TaskManagerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: vm.state,
      builder: (context, _) {
        final info = vm.state.value.info;
        if (info == null) return const SizedBox.shrink();
        final resource = vm.state.value.selectedResource;
        final List<(String, String)> lines = switch (resource) {
          PerformanceResource.cpu => [
              ('Model', info.cpuModel ?? '—'),
              ('Logical processors', '${info.logicalProcessors}'),
            ],
          PerformanceResource.memory => [
              (
                'Total memory',
                TaskRepository.formatBytes(info.memoryTotalBytes)
              ),
            ],
          PerformanceResource.filesystem => [
              (
                'Filesystems',
                info.filesystems.isEmpty
                    ? '—'
                    : info.filesystems.map((i) => i.name).join(', '),
              ),
            ],
          PerformanceResource.disk => [
              (
                'Disks',
                info.disks.isEmpty
                    ? '—'
                    : info.disks.map((i) => i.name).join(', '),
              ),
            ],
          PerformanceResource.network => [
              (
                'Network interfaces',
                info.networks.isEmpty
                    ? '—'
                    : info.networks.map((i) => i.name).join(', '),
              ),
            ],
        };
        return Wrap(
          spacing: 28,
          runSpacing: 8,
          children: [
            for (final line in lines)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.$1,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                  Text(
                    line.$2,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              )
          ],
        );
      },
    );
  }
}

/// Line chart painter; kept with the components layer because it is a pure
/// visual helper with no behaviour.
class HistoryPainter extends CustomPainter {
  const HistoryPainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withValues(alpha: .18)
      ..strokeWidth = 1;
    for (var step = 1; step < 4; step++) {
      canvas.drawLine(
        Offset(0, size.height * step / 4),
        Offset(size.width, size.height * step / 4),
        grid,
      );
    }
    if (values.length < 2) return;
    final maxValue =
        values.reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final pt = Offset(
        size.width * index / (values.length - 1),
        size.height - (values[index] / maxValue) * size.height,
      );
      if (index == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(HistoryPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

// =============================================================================
// Process list pane
// =============================================================================

class ProcessListPane extends StatefulWidget {
  const ProcessListPane({super.key, required this.vm});

  final TaskManagerViewModel vm;

  @override
  State<ProcessListPane> createState() => _ProcessListPaneState();
}

class _ProcessListPaneState extends State<ProcessListPane> {
  final _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filterController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Filter processes',
                  ),
                  onChanged: widget.vm.setProcessFilter,
                ),
              ),
              ListenableBuilder(
                listenable: widget.vm.refreshProcessesCommand,
                builder: (context, _) => IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: widget.vm.refreshProcessesCommand.canRun.value
                      ? () => widget.vm.refreshProcessesCommand()
                      : null,
                ),
              ),
              TextButton(
                onPressed: () {
                  _filterController.clear();
                  widget.vm.clearProcessFilter();
                },
                child: const Text('Clear'),
              ),
              Text(
                'Auto refresh',
                style: TextStyle(color: palette.textSecondary),
              ),
              ListenableBuilder(
                listenable: widget.vm.state,
                builder: (context, _) => Switch(
                  value: widget.vm.state.value.autoRefresh,
                  onChanged: widget.vm.setAutoRefresh,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.vm.state,
            builder: (context, _) {
              final list = widget.vm.state.value.processes?.items ??
                  const <RemoteProcess>[];
              return ListView(
                children: [
                  for (final process in list)
                    _processTile(context, palette, process),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _processTile(
    BuildContext context,
    ThemePalette palette,
    RemoteProcess process,
  ) {
    return ListTile(
      title: Text(process.name),
      subtitle: Text(
        'PID ${process.id} · ${process.userName ?? '—'} · ${process.threadCount} threads',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${process.cpuPercent.toStringAsFixed(1)}% · ${TaskRepository.formatBytes(process.memoryBytes)}',
          ),
          const SizedBox(width: 6),
          ListenableBuilder(
            listenable: widget.vm.state,
            builder: (context, _) {
              final enabled = widget.vm.canKillProcess(process.id);
              return IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'End task',
                onPressed: enabled
                    ? () {
                        // ignore: discarded_futures
                        widget.vm.killProcess(process.id);
                      }
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
