import '../../system_monitor/data/remote_system_monitor_api.dart';
import 'task_repository.dart';

enum TaskPerformanceKind { cpu, memory, filesystem, disk, network }

class TaskPerformanceItem {
  const TaskPerformanceItem(
      {required this.kind,
      required this.id,
      required this.title,
      required this.subtitle,
      required this.metric,
      required this.sideDetail,
      required this.chartMaximum,
      required this.history,
      required this.details});
  final TaskPerformanceKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String metric;
  final String sideDetail;
  final double chartMaximum;
  final List<double> history;
  final List<(String, String)> details;
  String get key => '${kind.name}:$id';
}

List<TaskPerformanceItem> buildTaskPerformanceItems(PerformanceInfo? info,
    PerformanceSnapshot? current, List<PerformanceSnapshot> history) {
  if (info == null) return const [];
  List<double> values(double Function(PerformanceSnapshot s) selector) =>
      [for (final sample in history) selector(sample)];
  final cpu = current?.cpu;
  final memory = current?.memory;
  final items = <TaskPerformanceItem>[
    TaskPerformanceItem(
        kind: TaskPerformanceKind.cpu,
        id: 'cpu',
        title: 'CPU',
        subtitle: info.cpuModel ?? '—',
        metric: '${cpu?.totalPercent.toStringAsFixed(0) ?? '—'}%',
        sideDetail: _frequency(cpu?.currentFrequencyMHz),
        chartMaximum: 100,
        history: values((s) => s.cpu.totalPercent),
        details: [
          ('利用率', '${cpu?.totalPercent.toStringAsFixed(0) ?? '—'}%'),
          ('速度', _frequency(cpu?.currentFrequencyMHz)),
          ('进程', _n(cpu?.processCount)),
          ('线程', _n(cpu?.threadCount)),
          ('句柄', _n(cpu?.handleCount)),
          ('运行时间', _uptime(current?.uptimeSeconds)),
          ('基准速度', _frequency(info.baseFrequencyMHz)),
          ('插槽', _n(info.socketCount)),
          ('内核', _n(info.physicalCores)),
          ('逻辑处理器', _n(info.logicalProcessors)),
          (
            '虚拟化',
            info.virtualizationEnabled == null
                ? '—'
                : info.virtualizationEnabled!
                    ? '已启用'
                    : '未启用'
          ),
          ('L1 缓存', _bytes(info.l1CacheBytes)),
          ('L2 缓存', _bytes(info.l2CacheBytes)),
          ('L3 缓存', _bytes(info.l3CacheBytes)),
        ]),
    TaskPerformanceItem(
        kind: TaskPerformanceKind.memory,
        id: 'memory',
        title: '内存',
        subtitle: TaskRepository.formatBytes(info.memoryTotalBytes),
        metric: '${_bytes(memory?.usedBytes)} / ${_bytes(memory?.totalBytes)}',
        sideDetail:
            '${_percent(memory?.usedBytes, memory?.totalBytes).toStringAsFixed(0)}%',
        chartMaximum: 100,
        history:
            values((s) => _percent(s.memory.usedBytes, s.memory.totalBytes)),
        details: [
          ('使用中', _bytes(memory?.usedBytes)),
          ('可用', _bytes(memory?.availableBytes)),
          ('已缓存', _bytes(memory?.cachedBytes)),
          ('交换空间', _bytes(memory?.swapUsedBytes)),
          ('总内存', _bytes(memory?.totalBytes)),
          ('缓冲区', _bytes(memory?.bufferedBytes)),
          ('交换总量', _bytes(memory?.swapTotalBytes ?? info.swapTotalBytes)),
        ]),
  ];
  for (final resource in info.filesystems) {
    final now = _byId(current?.filesystems, resource.id);
    items.add(TaskPerformanceItem(
        kind: TaskPerformanceKind.filesystem,
        id: resource.id,
        title: resource.name,
        subtitle: resource.detail ?? '',
        metric: '${_bytes(now?.usedBytes)} / ${_bytes(now?.totalBytes)}',
        sideDetail: '${now?.percent.toStringAsFixed(0) ?? '—'}%',
        chartMaximum: 100,
        history: values((s) => _byId(s.filesystems, resource.id)?.percent ?? 0),
        details: [
          ('已用空间', _bytes(now?.usedBytes)),
          ('可用空间', _bytes(now?.availableBytes)),
          ('总容量', _bytes(now?.totalBytes)),
          ('使用率', '${now?.percent.toStringAsFixed(0) ?? '—'}%')
        ]));
  }
  for (final resource in info.disks) {
    final now = _byId(current?.disks, resource.id);
    final currentRate =
        (now?.readBytesPerSecond ?? 0) + (now?.writeBytesPerSecond ?? 0);
    final diskHistory = values((s) {
      final item = _byId(s.disks, resource.id);
      return ((item?.readBytesPerSecond ?? 0) +
              (item?.writeBytesPerSecond ?? 0))
          .toDouble();
    });
    // Anchor chart Y-axis to the *largest* value in the rolling window,
    // not just the current snapshot.  A disk that has a short burst I/O
    // and then goes idle would otherwise drive chartMaximum to near-zero
    // and the burst spike would draw far above the panel top.
    final peakRate = [
      ...diskHistory,
      currentRate.toDouble(),
    ].fold<double>(0, (a, b) => a > b ? a : b);
    items.add(TaskPerformanceItem(
        kind: TaskPerformanceKind.disk,
        id: resource.id,
        title: resource.name,
        subtitle: resource.detail ?? '磁盘 I/O',
        metric: '读取 ${TaskRepository.formatRate(now?.readBytesPerSecond ?? 0)}',
        sideDetail:
            '写入 ${TaskRepository.formatRate(now?.writeBytesPerSecond ?? 0)}',
        chartMaximum: (peakRate * 1.25).clamp(1048576, double.infinity),
        history: diskHistory,
        details: [
          ('读取速度', TaskRepository.formatRate(now?.readBytesPerSecond ?? 0)),
          ('写入速度', TaskRepository.formatRate(now?.writeBytesPerSecond ?? 0)),
          ('读取 IOPS', now?.readIops.toStringAsFixed(0) ?? '—'),
          ('写入 IOPS', now?.writeIops.toStringAsFixed(0) ?? '—')
        ]));
  }
  for (final resource in info.networks) {
    final now = _byId(current?.networks, resource.id);
    final currentRate =
        (now?.receiveBytesPerSecond ?? 0) + (now?.sendBytesPerSecond ?? 0);
    final netHistory = values((s) {
      final item = _byId(s.networks, resource.id);
      return ((item?.receiveBytesPerSecond ?? 0) +
              (item?.sendBytesPerSecond ?? 0))
          .toDouble();
    });
    final peakRate = [
      ...netHistory,
      currentRate.toDouble(),
    ].fold<double>(0, (a, b) => a > b ? a : b);
    items.add(TaskPerformanceItem(
        kind: TaskPerformanceKind.network,
        id: resource.id,
        title: resource.name,
        subtitle: resource.detail ?? '网络适配器',
        metric: '发送 ${TaskRepository.formatRate(now?.sendBytesPerSecond ?? 0)}',
        sideDetail:
            '接收 ${TaskRepository.formatRate(now?.receiveBytesPerSecond ?? 0)}',
        chartMaximum: (peakRate * 1.25).clamp(1048576, double.infinity),
        history: netHistory,
        details: [
          ('发送', TaskRepository.formatRate(now?.sendBytesPerSecond ?? 0)),
          ('接收', TaskRepository.formatRate(now?.receiveBytesPerSecond ?? 0)),
          ('已发送', _bytes(now?.bytesSent)),
          ('已接收', _bytes(now?.bytesReceived))
        ]));
  }
  return items;
}

T? _byId<T>(List<T>? values, String id) =>
    values?.cast<dynamic>().where((v) => v.id == id).cast<T>().firstOrNull;

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _bytes(int? value) =>
    value == null ? '—' : TaskRepository.formatBytes(value);
String _n(num? value) => value == null ? '—' : value.toStringAsFixed(0);
double _percent(int? used, int? total) =>
    total == null || total == 0 || used == null ? 0 : used * 100 / total;
String _frequency(double? value) => value == null
    ? '—'
    : value >= 1000
        ? '${(value / 1000).toStringAsFixed(2)} GHz'
        : '${value.toStringAsFixed(0)} MHz';
String _uptime(int? seconds) {
  if (seconds == null) return '—';
  final d = Duration(seconds: seconds);
  return '${d.inDays} days ${(d.inHours % 24).toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
