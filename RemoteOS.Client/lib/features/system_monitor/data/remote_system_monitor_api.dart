import '../../../core/network/remoteos_api.dart';

/// Typed subset of the Task Manager REST contract.  Realtime updates arrive
/// on the Performance Hub; these routes provide initial state and recovery.
class RemoteSystemMonitorApi {
  RemoteSystemMonitorApi(this._api);

  final RemoteOsApi _api;

  Future<PerformanceSnapshot> snapshot() async => PerformanceSnapshot.fromJson(
      _asMap(await _api.getJson('/api/v1/system/performance/snapshot')));

  Future<PerformanceInfo> info() async => PerformanceInfo.fromJson(
      _asMap(await _api.getJson('/api/v1/system/performance/info')));

  Future<List<PerformanceSnapshot>> history({int seconds = 60}) async {
    final value = await _api.getJson('/api/v1/system/performance/history',
        query: {'seconds': seconds.clamp(1, 60).toString()});
    return _asList(value)
        .map((item) => PerformanceSnapshot.fromJson(_asMap(item)))
        .toList();
  }

  Future<ProcessPage> processes(
      {String? filter, String sort = 'memory'}) async {
    final query = <String, String>{
      'page': '1',
      'pageSize': '100',
      'sort': sort
    };
    if (filter != null && filter.trim().isNotEmpty)
      query['filter'] = filter.trim();
    return ProcessPage.fromJson(_asMap(
        await _api.getJson('/api/v1/system/processes/query', query: query)));
  }

  Future<KillProcessResult> kill(int id, {bool force = false}) async =>
      KillProcessResult.fromJson(_asMap(await _api.sendJson(
          'DELETE', '/api/v1/system/processes/$id',
          query: {'force': '$force'})));
}

class PerformanceSnapshot {
  const PerformanceSnapshot(
      {required this.sequence,
      required this.cpuPercent,
      required this.memoryUsedBytes,
      required this.memoryTotalBytes,
      required this.filesystemUsedBytes,
      required this.filesystemTotalBytes,
      required this.diskReadBytesPerSecond,
      required this.diskWriteBytesPerSecond,
      required this.networkReceiveBytesPerSecond,
      required this.networkSendBytesPerSecond,
      required this.filesystems,
      required this.disks,
      required this.networks,
      required this.cpu,
      required this.memory,
      required this.uptimeSeconds,
      required this.timestamp});
  final int sequence;
  final double cpuPercent;
  final int memoryUsedBytes;
  final int memoryTotalBytes;
  final int filesystemUsedBytes;
  final int filesystemTotalBytes;
  final int diskReadBytesPerSecond;
  final int diskWriteBytesPerSecond;
  final int networkReceiveBytesPerSecond;
  final int networkSendBytesPerSecond;
  final List<FilesystemUsage> filesystems;
  final List<DiskMetrics> disks;
  final List<NetworkMetrics> networks;
  final CpuMetrics cpu;
  final MemoryMetrics memory;
  final int uptimeSeconds;
  final DateTime? timestamp;

  factory PerformanceSnapshot.fromJson(Map<String, dynamic> json) =>
      PerformanceSnapshot(
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        cpuPercent: (json['cpu'] as Map?)?['totalPercent'] is num
            ? ((json['cpu'] as Map)['totalPercent'] as num).toDouble()
            : 0,
        memoryUsedBytes: (json['memory'] as Map?)?['usedBytes'] is num
            ? ((json['memory'] as Map)['usedBytes'] as num).toInt()
            : 0,
        memoryTotalBytes: (json['memory'] as Map?)?['totalBytes'] is num
            ? ((json['memory'] as Map)['totalBytes'] as num).toInt()
            : 0,
        filesystemUsedBytes: _sum(json['filesystems'], 'usedBytes'),
        filesystemTotalBytes: _sum(json['filesystems'], 'totalBytes'),
        diskReadBytesPerSecond: _sum(json['disks'], 'readBytesPerSecond'),
        diskWriteBytesPerSecond: _sum(json['disks'], 'writeBytesPerSecond'),
        networkReceiveBytesPerSecond:
            _sum(json['networks'], 'receiveBytesPerSecond'),
        networkSendBytesPerSecond: _sum(json['networks'], 'sendBytesPerSecond'),
        filesystems: _asList(json['filesystems'])
            .map((entry) => FilesystemUsage.fromJson(_asMap(entry)))
            .toList(),
        disks: _asList(json['disks'])
            .map((entry) => DiskMetrics.fromJson(_asMap(entry)))
            .toList(),
        networks: _asList(json['networks'])
            .map((entry) => NetworkMetrics.fromJson(_asMap(entry)))
            .toList(),
        cpu: CpuMetrics.fromJson(_asMap(json['cpu'])),
        memory: MemoryMetrics.fromJson(_asMap(json['memory'])),
        uptimeSeconds: (json['uptimeSeconds'] as num?)?.toInt() ?? 0,
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
      );
}

class CpuMetrics {
  const CpuMetrics({required this.totalPercent, this.currentFrequencyMHz, this.processCount, this.threadCount, this.handleCount});
  final double totalPercent;
  final double? currentFrequencyMHz;
  final int? processCount;
  final int? threadCount;
  final int? handleCount;
  factory CpuMetrics.fromJson(Map<String, dynamic> json) => CpuMetrics(
        totalPercent: (json['totalPercent'] as num?)?.toDouble() ?? 0,
        currentFrequencyMHz: (json['currentFrequencyMHz'] as num?)?.toDouble(),
        processCount: (json['processCount'] as num?)?.toInt(),
        threadCount: (json['threadCount'] as num?)?.toInt(),
        handleCount: (json['handleCount'] as num?)?.toInt(),
      );
}

class MemoryMetrics {
  const MemoryMetrics({required this.totalBytes, required this.usedBytes, required this.availableBytes, this.cachedBytes, this.bufferedBytes, this.swapUsedBytes, this.swapTotalBytes});
  final int totalBytes;
  final int usedBytes;
  final int availableBytes;
  final int? cachedBytes;
  final int? bufferedBytes;
  final int? swapUsedBytes;
  final int? swapTotalBytes;
  factory MemoryMetrics.fromJson(Map<String, dynamic> json) => MemoryMetrics(
        totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
        usedBytes: (json['usedBytes'] as num?)?.toInt() ?? 0,
        availableBytes: (json['availableBytes'] as num?)?.toInt() ?? 0,
        cachedBytes: (json['cachedBytes'] as num?)?.toInt(),
        bufferedBytes: (json['bufferedBytes'] as num?)?.toInt(),
        swapUsedBytes: (json['swapUsedBytes'] as num?)?.toInt(),
        swapTotalBytes: (json['swapTotalBytes'] as num?)?.toInt(),
      );
}

class FilesystemUsage {
  const FilesystemUsage(
      {required this.id, required this.usedBytes, required this.totalBytes, required this.availableBytes, required this.percent});
  final String id;
  final int usedBytes;
  final int totalBytes;
  final int availableBytes;
  final double percent;
  factory FilesystemUsage.fromJson(Map<String, dynamic> json) =>
      FilesystemUsage(
          id: json['id']?.toString() ?? '',
          usedBytes: (json['usedBytes'] as num?)?.toInt() ?? 0,
          totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
          availableBytes: (json['availableBytes'] as num?)?.toInt() ?? 0,
          percent: (json['percent'] as num?)?.toDouble() ?? 0);
}

class DiskMetrics {
  const DiskMetrics(
      {required this.id,
      required this.readBytesPerSecond,
      required this.writeBytesPerSecond, required this.readIops, required this.writeIops});
  final String id;
  final int readBytesPerSecond;
  final int writeBytesPerSecond;
  final double readIops;
  final double writeIops;
  factory DiskMetrics.fromJson(Map<String, dynamic> json) => DiskMetrics(
      id: json['id']?.toString() ?? '',
      readBytesPerSecond: (json['readBytesPerSecond'] as num?)?.toInt() ?? 0,
      writeBytesPerSecond: (json['writeBytesPerSecond'] as num?)?.toInt() ?? 0,
      readIops: (json['readIops'] as num?)?.toDouble() ?? 0,
      writeIops: (json['writeIops'] as num?)?.toDouble() ?? 0);
}

class NetworkMetrics {
  const NetworkMetrics(
      {required this.id,
      required this.receiveBytesPerSecond,
      required this.sendBytesPerSecond, required this.bytesReceived, required this.bytesSent});
  final String id;
  final int receiveBytesPerSecond;
  final int sendBytesPerSecond;
  final int bytesReceived;
  final int bytesSent;
  factory NetworkMetrics.fromJson(Map<String, dynamic> json) => NetworkMetrics(
      id: json['id']?.toString() ?? '',
      receiveBytesPerSecond:
          (json['receiveBytesPerSecond'] as num?)?.toInt() ?? 0,
      sendBytesPerSecond: (json['sendBytesPerSecond'] as num?)?.toInt() ?? 0,
      bytesReceived: (json['bytesReceived'] as num?)?.toInt() ?? 0,
      bytesSent: (json['bytesSent'] as num?)?.toInt() ?? 0);
}

/// Low-frequency Task Manager metadata used for resource details; values that
/// the Server cannot sample remain nullable rather than being faked as zero.
class PerformanceInfo {
  const PerformanceInfo(
      {required this.cpuModel,
      required this.logicalProcessors,
      required this.memoryTotalBytes,
      this.physicalCores,
      this.baseFrequencyMHz,
      this.socketCount,
      this.virtualizationEnabled,
      this.l1CacheBytes,
      this.l2CacheBytes,
      this.l3CacheBytes,
      this.swapTotalBytes,
      required this.filesystems,
      required this.disks,
      required this.networks});
  final String? cpuModel;
  final int logicalProcessors;
  final int memoryTotalBytes;
  final int? physicalCores;
  final double? baseFrequencyMHz;
  final int? socketCount;
  final bool? virtualizationEnabled;
  final int? l1CacheBytes;
  final int? l2CacheBytes;
  final int? l3CacheBytes;
  final int? swapTotalBytes;
  final List<PerformanceResourceInfo> filesystems;
  final List<PerformanceResourceInfo> disks;
  final List<PerformanceResourceInfo> networks;
  factory PerformanceInfo.fromJson(Map<String, dynamic> json) {
    final cpu = _asMap(json['cpu']);
    final memory = _asMap(json['memory']);
    List<PerformanceResourceInfo> resources(Object? source) => _asList(source)
        .map((entry) => PerformanceResourceInfo.fromJson(_asMap(entry)))
        .where((item) => item.id.isNotEmpty)
        .toList();
    return PerformanceInfo(
        cpuModel: cpu['model']?.toString(),
        logicalProcessors: (cpu['logicalProcessorCount'] as num?)?.toInt() ?? 0,
        memoryTotalBytes: (memory['totalBytes'] as num?)?.toInt() ?? 0,
        physicalCores: (cpu['physicalCoreCount'] as num?)?.toInt(),
        baseFrequencyMHz: (cpu['baseFrequencyMHz'] as num?)?.toDouble(),
        socketCount: (cpu['socketCount'] as num?)?.toInt(),
        virtualizationEnabled: cpu['virtualizationEnabled'] as bool?,
        l1CacheBytes: (cpu['l1CacheBytes'] as num?)?.toInt(),
        l2CacheBytes: (cpu['l2CacheBytes'] as num?)?.toInt(),
        l3CacheBytes: (cpu['l3CacheBytes'] as num?)?.toInt(),
        swapTotalBytes: (memory['swapTotalBytes'] as num?)?.toInt(),
        filesystems: resources(json['filesystems']),
        disks: resources(json['disks']),
        networks: resources(json['networks']));
  }
}

class PerformanceResourceInfo {
  const PerformanceResourceInfo({required this.id, required this.name, this.detail});
  final String id;
  final String name;
  final String? detail;
  factory PerformanceResourceInfo.fromJson(Map<String, dynamic> json) =>
      PerformanceResourceInfo(
          id: json['id']?.toString() ?? '',
          name: json['name']?.toString() ?? json['id']?.toString() ?? '',
          detail: (json['mountPoint'] ?? json['model'] ?? json['linkSpeedBitsPerSecond'])?.toString());
}

class ProcessPage {
  const ProcessPage({required this.items, required this.totalCount, this.sampledAt});
  final List<RemoteProcess> items;
  final int totalCount;
  final DateTime? sampledAt;
  factory ProcessPage.fromJson(Map<String, dynamic> json) => ProcessPage(
      items: _asList(json['items'])
          .map((item) => RemoteProcess.fromJson(_asMap(item)))
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      sampledAt: DateTime.tryParse(json['sampledAt']?.toString() ?? ''));
}

class RemoteProcess {
  const RemoteProcess(
      {required this.id,
      required this.name,
      required this.cpuPercent,
      required this.memoryBytes,
      required this.threadCount,
      this.userName});
  final int id;
  final String name;
  final double cpuPercent;
  final int memoryBytes;
  final int threadCount;
  final String? userName;
  factory RemoteProcess.fromJson(Map<String, dynamic> json) => RemoteProcess(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      cpuPercent: (json['cpuPercent'] as num?)?.toDouble() ?? 0,
      memoryBytes: (json['memoryBytes'] as num?)?.toInt() ?? 0,
      threadCount: (json['threadCount'] as num?)?.toInt() ?? 0,
      userName: json['userName']?.toString());
}

class KillProcessResult {
  const KillProcessResult(
      {required this.success, required this.requiresElevation, this.error});
  final bool success;
  final bool requiresElevation;
  final String? error;
  factory KillProcessResult.fromJson(Map<String, dynamic> json) =>
      KillProcessResult(
          success: json['success'] == true,
          requiresElevation: json['requiresElevation'] == true,
          error: json['error']?.toString());
}

Map<String, dynamic> _asMap(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const <String, dynamic>{};
List<Object?> _asList(Object? value) =>
    value is List ? value.cast<Object?>() : const [];
int _sum(Object? records, String field) => _asList(records).fold<int>(
    0, (sum, record) => sum + ((_asMap(record)[field] as num?)?.toInt() ?? 0));
