import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../system_monitor/data/remote_system_monitor_api.dart';
import '../../application/task_manager_view_model.dart';
import '../../domain/task_repository.dart';

/// Avalonia-compatible Performance workspace: resource navigation occupies a
/// fixed desktop rail and the selected resource owns the large detail panel.
class PerformanceWorkspace extends StatelessWidget {
  const PerformanceWorkspace({super.key, required this.vm});
  final TaskManagerViewModel vm;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: vm.state,
        builder: (context, _) {
          final state = vm.state.value;
          final snapshot = state.snapshot;
          if (snapshot == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Row(children: [
            SizedBox(
                width: 236,
                child: _ResourceNavigation(vm: vm, snapshot: snapshot)),
            const VerticalDivider(width: 1),
            Expanded(child: _ResourceDetails(vm: vm, snapshot: snapshot)),
          ]);
        },
      );
}

class _ResourceNavigation extends StatelessWidget {
  const _ResourceNavigation({required this.vm, required this.snapshot});
  final TaskManagerViewModel vm;
  final PerformanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final state = vm.state.value;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final resource in PerformanceResource.values)
          ListTile(
            dense: true,
            selected: state.selectedResource == resource,
            leading: Icon(_icon(resource)),
            title: Text(_label(resource).tr()),
            subtitle: Text(_metric(resource),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => vm.selectResource(resource),
          ),
      ],
    );
  }

  String _metric(PerformanceResource resource) => switch (resource) {
        PerformanceResource.cpu => '${snapshot.cpuPercent.toStringAsFixed(1)}%',
        PerformanceResource.memory =>
          '${TaskRepository.formatBytes(snapshot.memoryUsedBytes)} / ${TaskRepository.formatBytes(snapshot.memoryTotalBytes)}',
        PerformanceResource.filesystem =>
          '${TaskRepository.formatBytes(snapshot.filesystemUsedBytes)} / ${TaskRepository.formatBytes(snapshot.filesystemTotalBytes)}',
        PerformanceResource.disk =>
          '${TaskRepository.formatRate(snapshot.diskReadBytesPerSecond)} · ${TaskRepository.formatRate(snapshot.diskWriteBytesPerSecond)}',
        PerformanceResource.network =>
          '${TaskRepository.formatRate(snapshot.networkReceiveBytesPerSecond)} · ${TaskRepository.formatRate(snapshot.networkSendBytesPerSecond)}',
      };
}

class _ResourceDetails extends StatelessWidget {
  const _ResourceDetails({required this.vm, required this.snapshot});
  final TaskManagerViewModel vm;
  final PerformanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = vm.state.value;
    final resource = state.selectedResource;
    final values = [
      for (final item in state.history)
        vm.historyValue(item, resource, state.selectedResourceId),
    ];
    final choices = vm.resourceChoices(state.info, resource);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 16, 24, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(_label(resource).tr(),
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w600))),
          Text(_currentValue(resource), style: const TextStyle(fontSize: 19)),
        ]),
        const SizedBox(height: 8),
        Text('task_manager.last_60_seconds'.tr(),
            style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        if (choices.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: DropdownButton<String?>(
              value: state.selectedResourceId,
              hint: Text('task_manager.all_resources'.tr()),
              items: [
                DropdownMenuItem<String?>(
                    value: null,
                    child: Text('task_manager.all_resources'.tr())),
                for (final item in choices)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: vm.setSelectedResourceId,
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
            height: 270,
            width: double.infinity,
            child:
                CustomPaint(painter: HistoryPainter(values, palette.accent))),
        const SizedBox(height: 14),
        _ResourceMetadata(resource: resource, info: state.info),
      ]),
    );
  }

  String _currentValue(PerformanceResource resource) => switch (resource) {
        PerformanceResource.cpu => '${snapshot.cpuPercent.toStringAsFixed(1)}%',
        PerformanceResource.memory =>
          TaskRepository.formatBytes(snapshot.memoryUsedBytes),
        PerformanceResource.filesystem =>
          TaskRepository.formatBytes(snapshot.filesystemUsedBytes),
        PerformanceResource.disk => TaskRepository.formatRate(
            snapshot.diskReadBytesPerSecond + snapshot.diskWriteBytesPerSecond),
        PerformanceResource.network => TaskRepository.formatRate(
            snapshot.networkReceiveBytesPerSecond +
                snapshot.networkSendBytesPerSecond),
      };
}

class _ResourceMetadata extends StatelessWidget {
  const _ResourceMetadata({required this.resource, required this.info});
  final PerformanceResource resource;
  final PerformanceInfo? info;

  @override
  Widget build(BuildContext context) {
    if (info == null) return const SizedBox.shrink();
    final lines = switch (resource) {
      PerformanceResource.cpu => [
          ('Model', info!.cpuModel ?? '—'),
          ('Logical processors', '${info!.logicalProcessors}')
        ],
      PerformanceResource.memory => [
          ('Total memory', TaskRepository.formatBytes(info!.memoryTotalBytes))
        ],
      PerformanceResource.filesystem => [
          ('Filesystems', info!.filesystems.map((item) => item.name).join(', '))
        ],
      PerformanceResource.disk => [
          ('Disks', info!.disks.map((item) => item.name).join(', '))
        ],
      PerformanceResource.network => [
          (
            'Network interfaces',
            info!.networks.map((item) => item.name).join(', ')
          )
        ],
    };
    return Wrap(spacing: 28, runSpacing: 12, children: [
      for (final line in lines)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(line.$1, style: const TextStyle(fontSize: 12)),
          Text(line.$2, style: const TextStyle(fontSize: 16)),
        ]),
    ]);
  }
}

class ProcessWorkspace extends StatefulWidget {
  const ProcessWorkspace({super.key, required this.vm});
  final TaskManagerViewModel vm;

  @override
  State<ProcessWorkspace> createState() => _ProcessWorkspaceState();
}

class _ProcessWorkspaceState extends State<ProcessWorkspace> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
                child: TextField(
                    controller: _filter,
                    onChanged: widget.vm.setProcessFilter,
                    decoration: InputDecoration(
                        hintText: 'task_manager.filter_placeholder'.tr()))),
            const SizedBox(width: 8),
            Text('task_manager.auto_refresh'.tr()),
            ListenableBuilder(
                listenable: widget.vm.state,
                builder: (_, __) => Switch(
                    value: widget.vm.state.value.autoRefresh,
                    onChanged: widget.vm.setAutoRefresh)),
            TextButton(
                onPressed: () {
                  _filter.clear();
                  widget.vm.clearProcessFilter();
                },
                child: Text('common.clear'.tr())),
            FilledButton(
              onPressed: _selectedProcess == null
                  ? null
                  : () => widget.vm.killProcess(_selectedProcess!.id),
              child: Text('task_manager.end_task'.tr()),
            ),
          ]),
        ),
        const _ProcessHeader(),
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
      ]);

  RemoteProcess? get _selectedProcess {
    final id = widget.vm.state.value.selectedProcessId;
    if (id == null) return null;
    for (final process
        in widget.vm.state.value.processes?.items ?? const <RemoteProcess>[]) {
      if (process.id == id) return process;
    }
    return null;
  }
}

class _ProcessHeader extends StatelessWidget {
  const _ProcessHeader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(children: [
          Expanded(flex: 3, child: Text('Name')),
          Expanded(child: Text('PID')),
          Expanded(child: Text('CPU')),
          Expanded(flex: 2, child: Text('Memory')),
          Expanded(flex: 2, child: Text('User')),
          Expanded(child: Text('Threads')),
        ]),
      );
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow(
      {required this.process, required this.selected, required this.onSelect});
  final RemoteProcess process;
  final bool selected;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) => ListTile(
        selected: selected,
        onTap: onSelect,
        title: Row(children: [
          Expanded(
              flex: 3,
              child: Text(process.name, overflow: TextOverflow.ellipsis)),
          Expanded(child: Text('${process.id}')),
          Expanded(child: Text('${process.cpuPercent.toStringAsFixed(1)}%')),
          Expanded(
              flex: 2,
              child: Text(TaskRepository.formatBytes(process.memoryBytes))),
          Expanded(
              flex: 2,
              child: Text(process.userName ?? '—',
                  overflow: TextOverflow.ellipsis)),
          Expanded(child: Text('${process.threadCount}')),
        ]),
      );
}

class HistoryPainter extends CustomPainter {
  /// [maximum] mirrors Avalonia's `PerformanceLineChart.Maximum`: when
  /// provided, the chart's Y axis is anchored to that value instead of being
  /// derived from the largest sample, so resource tabs whose current value is
  /// a rate (disk/network) keep a stable scale across samples.
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
    // Avalonia clamps the chart maximum to >= 1 so an all-zero sample does
    // not collapse the curve to the top of the panel.
    final max = (maximum ?? dataMax).clamp(1, double.infinity);
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final point = Offset(size.width * index / (values.length - 1),
          size.height - values[index] / max * size.height);
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

String _label(PerformanceResource resource) => switch (resource) {
      PerformanceResource.cpu => 'task_manager.cpu',
      PerformanceResource.memory => 'task_manager.memory',
      PerformanceResource.filesystem => 'task_manager.filesystem',
      PerformanceResource.disk => 'task_manager.disk',
      PerformanceResource.network => 'task_manager.network',
    };
IconData _icon(PerformanceResource resource) => switch (resource) {
      PerformanceResource.cpu => Icons.memory_outlined,
      PerformanceResource.memory => Icons.storage_outlined,
      PerformanceResource.filesystem => Icons.folder_outlined,
      PerformanceResource.disk => Icons.save_outlined,
      PerformanceResource.network => Icons.network_check_outlined,
    };
