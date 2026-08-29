// Remote Task Manager repository implementation (ARCHITECTURE.md § 11).
//
// Rest calls are delegated to [RemoteSystemMonitorApi]; realtime streams
// come from the application-scope [PerformanceHub] so reconnects are
// coordinated application-wide rather than per window.

import 'dart:async';

import '../../../system_monitor/data/performance_hub.dart';
import '../../../system_monitor/data/remote_system_monitor_api.dart';
import '../../domain/task_repository.dart';

class RemoteTaskRepository implements TaskRepository {
  RemoteTaskRepository({
    required RemoteSystemMonitorApi api,
    required PerformanceHub hub,
  })  : _api = api,
        _hub = hub;

  final RemoteSystemMonitorApi _api;
  final PerformanceHub _hub;

  @override
  Future<PerformanceInfo> getInfo() => _api.info();

  @override
  Future<List<PerformanceSnapshot>> getHistory({int seconds = 60}) =>
      _api.history(seconds: seconds);

  @override
  Stream<PerformanceSnapshot> get snapshotStream => _hub.snapshots;

  @override
  Stream<void> get reconnectedStream => _hub.reconnected;

  @override
  Future<void> ensureMonitoringConnected() => _hub.connect();

  @override
  Future<ProcessPage> queryProcesses({
    required String filter,
    String sort = 'memory',
  }) =>
      _api.processes(
          filter: filter.trim().isEmpty ? null : filter.trim(), sort: sort);

  @override
  Future<KillResult> killProcess(int id, {bool force = false}) async {
    final result = await _api.kill(id, force: force);
    return KillResult(
      success: result.success,
      requiresElevation: result.requiresElevation,
      error: result.error,
    );
  }
}
