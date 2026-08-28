import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/remoteos_api.dart';
import '../../core/theme/theme_service.dart';
import '../../features/system_monitor/data/performance_hub.dart';
import '../../features/system_monitor/data/remote_system_monitor_api.dart';

class TaskManagerApp extends ConsumerStatefulWidget {
  const TaskManagerApp({super.key});
  @override
  ConsumerState<TaskManagerApp> createState() => _TaskManagerAppState();
}

class _TaskManagerAppState extends ConsumerState<TaskManagerApp> {
  late final RemoteSystemMonitorApi _api;
  StreamSubscription<PerformanceSnapshot>? _subscription;
  StreamSubscription<void>? _reconnectSubscription;
  Timer? _processTimer;
  final _filterController = TextEditingController();
  PerformanceSnapshot? _snapshot;
  PerformanceInfo? _info;
  final List<PerformanceSnapshot> _history = [];
  _PerformanceResource _selectedResource = _PerformanceResource.cpu;
  String? _selectedResourceId;
  ProcessPage? _processes;
  String _filter = '';
  String? _error;
  bool _loading = true;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _api = RemoteSystemMonitorApi(ref.read(remoteOsApiProvider));
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final responses = await Future.wait([_api.history(), _api.info()]);
      final history = responses[0] as List<PerformanceSnapshot>;
      _info = responses[1] as PerformanceInfo;
      _history.addAll(history);
      if (history.isNotEmpty) _snapshot = history.last;
      final hub = ref.read(performanceHubProvider);
      _subscription = hub.snapshots.listen((snapshot) {
        if (mounted)
          setState(() {
            _snapshot = snapshot;
            _appendSnapshot(snapshot);
          });
      });
      _reconnectSubscription = hub.reconnected.listen((_) => _recoverHistory());
      await hub.connect();
      await _refreshProcesses();
      _restartProcessTimer();
    } catch (error) {
      _error = '$error';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshProcesses() async {
    try {
      final page = await _api.processes(filter: _filter);
      if (mounted) setState(() => _processes = page);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _recoverHistory() async {
    try {
      final history = await _api.history();
      if (mounted && history.isNotEmpty) {
        setState(() {
          _history.clear();
          _history.addAll(history);
          _snapshot = history.last;
        });
      }
    } catch (_) {
      // Keep the last valid snapshot if recovery is temporarily unavailable.
    }
  }

  void _appendSnapshot(PerformanceSnapshot snapshot) {
    if (_history.isNotEmpty && snapshot.sequence <= _history.last.sequence)
      return;
    _history.add(snapshot);
    while (_history.length > 60) {
      _history.removeAt(0);
    }
  }

  void _restartProcessTimer() {
    _processTimer?.cancel();
    if (_autoRefresh) {
      _processTimer = Timer.periodic(
          const Duration(seconds: 5), (_) => _refreshProcesses());
    }
  }

  @override
  void dispose() {
    _processTimer?.cancel();
    _subscription?.cancel();
    _reconnectSubscription?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
            color: palette.surface,
            child: const TabBar(
                tabs: [Tab(text: 'Performance'), Tab(text: 'Processes')])),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: TextStyle(color: palette.danger))),
        Expanded(
            child: TabBarView(
                children: [_performance(palette), _processList(palette)])),
      ]),
    );
  }

  Widget _performance(ThemePalette palette) {
    final snapshot = _snapshot;
    if (snapshot == null)
      return const Center(child: Text('Waiting for performance samples…'));
    final memory = snapshot.memoryTotalBytes == 0
        ? 0.0
        : snapshot.memoryUsedBytes * 100 / snapshot.memoryTotalBytes;
    return SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 16, runSpacing: 16, children: [
                _metric(
                    palette,
                    _PerformanceResource.cpu,
                    'CPU',
                    '${snapshot.cpuPercent.toStringAsFixed(1)}%',
                    snapshot.cpuPercent,
                    Icons.memory_outlined),
                _metric(
                    palette,
                    _PerformanceResource.memory,
                    'Memory',
                    '${_bytes(snapshot.memoryUsedBytes)} / ${_bytes(snapshot.memoryTotalBytes)}',
                    memory,
                    Icons.storage_outlined),
                _metric(
                    palette,
                    _PerformanceResource.filesystem,
                    'Filesystem',
                    '${_bytes(snapshot.filesystemUsedBytes)} / ${_bytes(snapshot.filesystemTotalBytes)}',
                    snapshot.filesystemTotalBytes == 0
                        ? 0
                        : snapshot.filesystemUsedBytes *
                            100 /
                            snapshot.filesystemTotalBytes,
                    Icons.folder_outlined),
                _metric(
                    palette,
                    _PerformanceResource.disk,
                    'Disk I/O',
                    'Read ${_rate(snapshot.diskReadBytesPerSecond)} · Write ${_rate(snapshot.diskWriteBytesPerSecond)}',
                    0,
                    Icons.save_outlined),
                _metric(
                    palette,
                    _PerformanceResource.network,
                    'Network',
                    'Receive ${_rate(snapshot.networkReceiveBytesPerSecond)} · Send ${_rate(snapshot.networkSendBytesPerSecond)}',
                    0,
                    Icons.network_check_outlined),
              ]),
              const SizedBox(height: 28),
              Text('${_selectedResource.label} · Last 60 seconds',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              if (_resourceChoices.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButton<String?>(
                    value: _selectedResourceId,
                    hint: const Text('All resources'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('All resources')),
                      for (final item in _resourceChoices)
                        DropdownMenuItem<String?>(
                            value: item.id, child: Text(item.name))
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedResourceId = value)),
              ],
              const SizedBox(height: 10),
              SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: CustomPaint(
                      painter: _HistoryPainter(
                          _history.map(_historyValue).toList(),
                          palette.accent))),
              const SizedBox(height: 14),
              _detailPanel(palette),
            ])));
  }

  Widget _detailPanel(ThemePalette palette) {
    final info = _info;
    if (info == null) return const SizedBox.shrink();
    final lines = switch (_selectedResource) {
      _PerformanceResource.cpu => [
          ('Model', info.cpuModel ?? '—'),
          ('Logical processors', '${info.logicalProcessors}')
        ],
      _PerformanceResource.memory => [
          ('Total memory', _bytes(info.memoryTotalBytes))
        ],
      _PerformanceResource.filesystem => [
          (
            'Filesystems',
            info.filesystems.isEmpty
                ? '—'
                : info.filesystems.map((item) => item.name).join(', ')
          )
        ],
      _PerformanceResource.disk => [
          (
            'Disks',
            info.disks.isEmpty
                ? '—'
                : info.disks.map((item) => item.name).join(', ')
          )
        ],
      _PerformanceResource.network => [
          (
            'Network interfaces',
            info.networks.isEmpty
                ? '—'
                : info.networks.map((item) => item.name).join(', ')
          )
        ],
    };
    return Wrap(spacing: 28, runSpacing: 8, children: [
      for (final line in lines)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(line.$1,
              style: TextStyle(fontSize: 12, color: palette.textSecondary)),
          Text(line.$2, style: const TextStyle(fontSize: 16))
        ])
    ]);
  }

  List<PerformanceResourceInfo> get _resourceChoices =>
      switch (_selectedResource) {
        _PerformanceResource.filesystem => _info?.filesystems ?? const [],
        _PerformanceResource.disk => _info?.disks ?? const [],
        _PerformanceResource.network => _info?.networks ?? const [],
        _ => const []
      };

  double _historyValue(PerformanceSnapshot item) => switch (_selectedResource) {
        _PerformanceResource.cpu => item.cpuPercent,
        _PerformanceResource.memory => item.memoryTotalBytes == 0
            ? 0
            : item.memoryUsedBytes * 100 / item.memoryTotalBytes,
        _PerformanceResource.filesystem => _filesystemValue(item),
        _PerformanceResource.disk => _diskValue(item),
        _PerformanceResource.network => _networkValue(item)
      };

  double _filesystemValue(PerformanceSnapshot item) {
    final selected = _selectedResourceId;
    if (selected == null) {
      return item.filesystemTotalBytes == 0
          ? 0
          : item.filesystemUsedBytes * 100 / item.filesystemTotalBytes;
    }
    FilesystemUsage? filesystem;
    for (final entry in item.filesystems) {
      if (entry.id == selected) {
        filesystem = entry;
        break;
      }
    }
    return filesystem == null || filesystem.totalBytes == 0
        ? 0
        : filesystem.usedBytes * 100 / filesystem.totalBytes;
  }

  double _diskValue(PerformanceSnapshot item) {
    final selected = _selectedResourceId;
    if (selected == null) {
      return (item.diskReadBytesPerSecond + item.diskWriteBytesPerSecond)
          .toDouble();
    }
    DiskMetrics? disk;
    for (final entry in item.disks) {
      if (entry.id == selected) {
        disk = entry;
        break;
      }
    }
    return disk == null
        ? 0
        : (disk.readBytesPerSecond + disk.writeBytesPerSecond).toDouble();
  }

  double _networkValue(PerformanceSnapshot item) {
    final selected = _selectedResourceId;
    if (selected == null) {
      return (item.networkReceiveBytesPerSecond +
              item.networkSendBytesPerSecond)
          .toDouble();
    }
    NetworkMetrics? network;
    for (final entry in item.networks) {
      if (entry.id == selected) {
        network = entry;
        break;
      }
    }
    return network == null
        ? 0
        : (network.receiveBytesPerSecond + network.sendBytesPerSecond)
            .toDouble();
  }

  Widget _metric(ThemePalette palette, _PerformanceResource resource,
          String title, String value, double progress, IconData icon) =>
      SizedBox(
          width: 310,
          child: InkWell(
              onTap: () => setState(() {
                    _selectedResource = resource;
                    _selectedResourceId = null;
                  }),
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(icon, color: palette.accent),
                              const SizedBox(width: 8),
                              Text(title)
                            ]),
                            const SizedBox(height: 18),
                            Text(value,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                                value: (progress / 100).clamp(0, 1))
                          ])))));

  Widget _processList(ThemePalette palette) => Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _filterController,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Filter processes'),
                      onChanged: (value) {
                        _filter = value;
                        _refreshProcesses();
                      })),
              IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshProcesses),
              TextButton(
                  onPressed: () {
                    _filterController.clear();
                    _filter = '';
                    _refreshProcesses();
                  },
                  child: const Text('Clear')),
              Text('Auto refresh',
                  style: TextStyle(color: palette.textSecondary)),
              Switch(
                  value: _autoRefresh,
                  onChanged: (value) => setState(() {
                        _autoRefresh = value;
                        _restartProcessTimer();
                      })),
            ])),
        Expanded(
            child: ListView(children: [
          for (final process in _processes?.items ?? const <RemoteProcess>[])
            ListTile(
                title: Text(process.name),
                subtitle: Text(
                    'PID ${process.id} · ${process.userName ?? '—'} · ${process.threadCount} threads'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      '${process.cpuPercent.toStringAsFixed(1)}% · ${_bytes(process.memoryBytes)}'),
                  IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'End task',
                      onPressed: () async {
                        final result = await _api.kill(process.id);
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(result.success
                                  ? 'Process ended'
                                  : (result.requiresElevation
                                      ? 'Elevation required'
                                      : result.error ??
                                          'Unable to end process'))));
                        await _refreshProcesses();
                      })
                ]))
        ])),
      ]);
}

String _bytes(int value) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var number = value.toDouble();
  var index = 0;
  while (number >= 1024 && index < units.length - 1) {
    number /= 1024;
    index++;
  }
  return '${number.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
}

String _rate(int value) => '${_bytes(value)}/s';

enum _PerformanceResource { cpu, memory, filesystem, disk, network }

extension on _PerformanceResource {
  String get label => switch (this) {
        _PerformanceResource.cpu => 'CPU',
        _PerformanceResource.memory => 'Memory',
        _PerformanceResource.filesystem => 'Filesystem',
        _PerformanceResource.disk => 'Disk I/O',
        _PerformanceResource.network => 'Network',
      };
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(this.values, this.color);
  final List<double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withOpacity(.18)
      ..strokeWidth = 1;
    for (var step = 1; step < 4; step++)
      canvas.drawLine(Offset(0, size.height * step / 4),
          Offset(size.width, size.height * step / 4), grid);
    if (values.length < 2) return;
    final maxValue =
        values.reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final point = Offset(size.width * index / (values.length - 1),
          size.height - (values[index] / maxValue) * size.height);
      if (index == 0)
        path.moveTo(point.dx, point.dy);
      else
        path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_HistoryPainter old) =>
      old.values != values || old.color != color;
}
