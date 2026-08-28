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
  final DateTime? timestamp;

  factory PerformanceSnapshot.fromJson(Map<String, dynamic> json) =>
      PerformanceSnapshot(
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        cpuPercent:
            ((json['cpu'] as Map?)?['totalPercent'] as num?)?.toDouble() ?? 0,
        memoryUsedBytes:
            ((json['memory'] as Map?)?['usedBytes'] as num?)?.toInt() ?? 0,
        memoryTotalBytes:
            ((json['memory'] as Map?)?['totalBytes'] as num?)?.toInt() ?? 0,
        filesystemUsedBytes: _sum(json['filesystems'], 'usedBytes'),
        filesystemTotalBytes: _sum(json['filesystems'], 'totalBytes'),
        diskReadBytesPerSecond: _sum(json['disks'], 'readBytesPerSecond'),
        diskWriteBytesPerSecond: _sum(json['disks'], 'writeBytesPerSecond'),
        networkReceiveBytesPerSecond:
            _sum(json['networks'], 'receiveBytesPerSecond'),
        networkSendBytesPerSecond: _sum(json['networks'], 'sendBytesPerSecond'),
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
      );
}

/// Low-frequency Task Manager metadata used for resource details; values that
/// the Server cannot sample remain nullable rather than being faked as zero.
class PerformanceInfo {
  const PerformanceInfo(
      {required this.cpuModel,
      required this.logicalProcessors,
      required this.memoryTotalBytes,
      required this.filesystems,
      required this.disks,
      required this.networks});
  final String? cpuModel;
  final int logicalProcessors;
  final int memoryTotalBytes;
  final List<String> filesystems;
  final List<String> disks;
  final List<String> networks;
  factory PerformanceInfo.fromJson(Map<String, dynamic> json) {
    final cpu = _asMap(json['cpu']);
    final memory = _asMap(json['memory']);
    List<String> names(Object? source) => _asList(source)
        .map((entry) =>
            _asMap(entry)['name']?.toString() ??
            _asMap(entry)['id']?.toString() ??
            '')
        .where((name) => name.isNotEmpty)
        .toList();
    return PerformanceInfo(
        cpuModel: cpu['model']?.toString(),
        logicalProcessors: (cpu['logicalProcessorCount'] as num?)?.toInt() ?? 0,
        memoryTotalBytes: (memory['totalBytes'] as num?)?.toInt() ?? 0,
        filesystems: names(json['filesystems']),
        disks: names(json['disks']),
        networks: names(json['networks']));
  }
}

class ProcessPage {
  const ProcessPage({required this.items, required this.totalCount});
  final List<RemoteProcess> items;
  final int totalCount;
  factory ProcessPage.fromJson(Map<String, dynamic> json) => ProcessPage(
      items: _asList(json['items'])
          .map((item) => RemoteProcess.fromJson(_asMap(item)))
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0);
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
