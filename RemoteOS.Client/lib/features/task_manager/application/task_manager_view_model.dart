// Task Manager ViewModel (ARCHITECTURE.md § 9).
//
// Presentation state is a single [ValueNotifier<TaskManagerUiState>].
// Commands model the user intents that have async execution state: starting
// the data session, refreshing (tab-aware), and killing a process.
// StreamSubscriptions (hub snapshots/reconnects/disconnects) and the periodic
// process Timer are owned here and disposed with this ViewModel.
//
// Behavior mirrors the Avalonia TaskManagerViewModel:
//  - Performance tab is driven by PerformanceItems built from PerformanceInfo;
//  - Processes tab uses a server-side paged query with a 5-second auto-refresh
//    that is only enabled while this tab is active;
//  - Kill operations produce a KillFeedback banner with localized progress/error
//    messages, identical to Avalonia's IsVisible feedback bar.

import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import '../../../core/commands/base_view_model.dart';
import '../../system_monitor/data/performance_hub.dart';
import '../../system_monitor/data/remote_system_monitor_api.dart';
import '../data/repositories/remote_task_repository.dart';
import '../domain/task_performance_item.dart';
import '../domain/task_repository.dart';
import '../domain/task_ui_state.dart';

/// Factory used by the app shell to construct a transient VM.
TaskManagerViewModel createTaskManagerViewModel({
  required RemoteSystemMonitorApi api,
  required PerformanceHub hub,
}) =>
    TaskManagerViewModel(
      repository: RemoteTaskRepository(api: api, hub: hub),
    );

class TaskManagerViewModel extends ViewModel {
  TaskManagerViewModel({required TaskRepository repository})
      : _repository = repository {
    trackDisposable(state);
    trackDisposable(startCommand);
    trackDisposable(refreshCommand);
    trackDisposable(refreshProcessesCommand);
    trackDisposable(_killProcessCommand);
    trackDisposable(clearFilterCommand);
  }

  final TaskRepository _repository;

  // ---- Streams / Timers owned by this VM ----
  StreamSubscription<PerformanceSnapshot>? _snapshots;
  StreamSubscription<void>? _reconnects;
  Timer? _processTimer;

  // ---- Presentation state ----
  final ValueNotifier<TaskManagerUiState> state =
      ValueNotifier<TaskManagerUiState>(TaskManagerUiState.initial());

  TaskManagerUiState get _s => state.value;
  void _mutate(TaskManagerUiState Function(TaskManagerUiState s) fn) =>
      state.value = fn(state.value);

  // ---- Gate helpers used by View to gate UI actions ----

  bool canRefreshProcesses() => !_s.isLoading;

  // ---- Performance item list + selection (Avalonia PerformanceItems) ----

  List<TaskPerformanceItem> get performanceItems =>
      buildTaskPerformanceItems(_s.info, _s.snapshot, _s.history);

  TaskPerformanceItem? get selectedPerformanceItem {
    for (final item in performanceItems) {
      if (item.key == _s.selectedPerformanceKey) return item;
    }
    return performanceItems.isEmpty ? null : performanceItems.first;
  }

  void selectPerformanceItem(TaskPerformanceItem item) => _mutate(
      (s) => s.copyWith(selectedPerformanceKey: item.key));

  // ---- UI mutators (pure presentation toggles — not Commands) ----

  void setTabIndex(int index) {
    _mutate((s) => s.copyWith(tabIndex: index));
    _restartProcessTimer();
    // Avalonia behavior: when switching to Processes, refresh immediately
    // if the list hasn't been loaded yet; otherwise rely on auto-refresh.
    if (index == 1 &&
        _s.processes == null &&
        canRefreshProcesses() &&
        refreshProcessesCommand.canRun.value) {
      refreshProcessesCommand();
    }
  }

  void setProcessFilter(String value) {
    _mutate((s) => s.copyWith(processFilter: value));
    // Server-side filter: re-run the query so the list matches the filter.
    // Throttling is enforced server-side and by the refresh-command guard.
    if (canRefreshProcesses() && refreshProcessesCommand.canRun.value) {
      refreshProcessesCommand();
    }
  }

  void clearProcessFilter() {
    _mutate((s) => s.copyWith(processFilter: ''));
    if (canRefreshProcesses() && refreshProcessesCommand.canRun.value) {
      refreshProcessesCommand();
    }
  }

  void setAutoRefresh(bool enabled) {
    _mutate((s) => s.copyWith(autoRefresh: enabled));
    _restartProcessTimer();
  }

  void selectProcess(int? processId) => _mutate((s) => s.copyWith(
        selectedProcessId: processId,
        clearSelectedProcess: processId == null,
      ));

  void consumePendingMessage() =>
      _mutate((s) => s.copyWith(clearPendingMessage: true));

  RemoteProcess? get selectedProcess {
    final id = _s.selectedProcessId;
    if (id == null) return null;
    for (final process in _s.processes?.items ?? const <RemoteProcess>[]) {
      if (process.id == id) return process;
    }
    return null;
  }

  // ---- Commands ----

  /// Performs the initial startup handshake: history + info, then hub connect.
  late final startCommand = Command.createAsyncNoParamNoResult(_startInternal);

  /// Avalonia-style RefreshCommand: refreshes whichever tab is currently
  /// active (performance → reloads info/history snapshot; processes →
  /// re-queries the process list).
  late final refreshCommand = Command.createAsyncNoParamNoResult(() async {
    if (_s.tabIndex == 1) {
      await _refreshProcessesInternal();
    } else {
      await _refreshPerformanceInternal();
    }
  });

  /// Re-runs the process query using the current filter.
  late final refreshProcessesCommand =
      Command.createAsyncNoParamNoResult(_refreshProcessesInternal);

  /// Clears the current process filter. Matches Avalonia ClearFilterCommand.
  late final clearFilterCommand =
      Command.createSyncNoParamNoResult(clearProcessFilter);

  /// Kills a process by id. Public entry point is [killProcess].
  late final _killProcessCommand =
      Command.createAsyncNoResult<int>((pid) async {
    final target = selectedProcess;
    if (target == null) return;
    _mutate((s) => s.copyWith(
          killFeedback: 'task_manager.process.terminating'
              .tr(args: [target.name, '${target.id}']),
        ));
    final result = await _repository.killProcess(pid);
    if (result.success) {
      _mutate((s) => s.copyWith(
            killFeedback: 'task_manager.process.terminated'
                .tr(args: [target.name, '${target.id}']),
            clearSelectedProcess: true,
          ));
    } else if (result.requiresElevation) {
      _mutate((s) => s.copyWith(
            killFeedback: 'task_manager.process.elevation_required'
                .tr(args: [target.name, '${target.id}', result.error ?? '']),
          ));
    } else {
      _mutate((s) => s.copyWith(
            killFeedback: 'task_manager.process.termination_failed'
                .tr(args: [result.error ?? '']),
          ));
    }
    // Refresh after kill so the UI reflects server state, including cases
    // where an elevation-required failure leaves the process still running.
    await _refreshProcessesInternal();
  });

  /// Public helper matching the Avalonia kill-process command surface. Waits
  /// for execution to settle so callers observe a consistent process list.
  Future<void> killProcess(int pid) async {
    if (!_killProcessCommand.canRun.value) return;
    _killProcessCommand(pid);
    // ignore: discarded_futures
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 8));
      return _killProcessCommand.isRunningSync.value;
    }).timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {},
    );
  }

  bool canKillProcess(int pid) =>
      !_s.isLoading && _killProcessCommand.canRun.value;

  // ---- Internal implementation ----

  Future<void> _startInternal() async {
    try {
      final results = await Future.wait([
        _repository.getHistory(),
        _repository.getInfo(),
      ]);
      final history = results[0] as List<PerformanceSnapshot>;
      final info = results[1] as PerformanceInfo;
      _mutate((s) => s.copyWith(
            info: info,
            history: history,
            snapshot: history.isEmpty ? null : history.last,
          ));
      if (history.isEmpty) {
        // TODO(remoteos-migration): expose a snapshot REST fallback in the
        // repository; for now mark connection as waiting for a hub sample.
        _mutate((s) => s.copyWith(
              connectionStatus: 'task_manager.connection.waiting'.tr(),
            ));
      }
      try {
        await _repository.ensureMonitoringConnected();
        _mutate((s) => s.copyWith(
              connectionStatus: 'task_manager.connection.live'.tr(),
            ));
      } catch (error) {
        _mutate((s) => s.copyWith(
              connectionStatus: 'task_manager.connection.snapshot'.tr(),
              statusText: 'task_manager.status.collect_failed'
                  .tr(args: ['$error']),
            ));
      }
      // Real-time snapshots + reconnect recovery.
      _snapshots?.cancel();
      _snapshots = _repository.snapshotStream.listen((snapshot) {
        _mutate((s) {
          final updated = _appendHistory(s.history, snapshot);
          return s.copyWith(
            snapshot: snapshot,
            history: updated,
            statusText: _formatUpdatedStatus(snapshot, s.processTotalCount),
          );
        });
      });
      _reconnects?.cancel();
      _reconnects =
          _repository.reconnectedStream.listen((_) async {
        _mutate((s) => s.copyWith(
              connectionStatus: 'task_manager.connection.recovering'.tr(),
            ));
        await _recoverHistory();
        _mutate((s) => s.copyWith(
              connectionStatus: 'task_manager.connection.live'.tr(),
            ));
      });
      await _refreshProcessesInternal();
      _restartProcessTimer();
    } catch (error) {
      _mutate((s) => s.copyWith(
            hasError: true,
            errorMessage: '$error',
            connectionStatus: 'task_manager.connection.unavailable'.tr(),
            statusText:
                'task_manager.status.collect_failed'.tr(args: ['$error']),
          ));
    } finally {
      _mutate((s) => s.copyWith(isLoading: false));
    }
  }

  Future<void> _refreshPerformanceInternal() async {
    try {
      final results = await Future.wait([
        _repository.getHistory(),
        _repository.getInfo(),
      ]);
      final history = results[0] as List<PerformanceSnapshot>;
      final info = results[1] as PerformanceInfo;
      _mutate((s) => s.copyWith(
            info: info,
            history: history,
            snapshot: history.isEmpty ? s.snapshot : history.last,
            connectionStatus: s.connectionStatus ==
                    'task_manager.connection.live'.tr()
                ? s.connectionStatus
                : 'task_manager.connection.updated'.tr(),
          ));
    } catch (error) {
      _mutate((s) => s.copyWith(
            hasError: true,
            errorMessage: '$error',
            connectionStatus: 'task_manager.connection.unavailable'.tr(),
            statusText:
                'task_manager.status.collect_failed'.tr(args: ['$error']),
          ));
    }
  }

  Future<void> _refreshProcessesInternal() async {
    try {
      final page = await _repository.queryProcesses(filter: _s.processFilter);
      final count = page.totalCount;
      final cpu = _s.snapshot?.cpuPercent.toStringAsFixed(1) ?? '0.0';
      final when = page.sampledAt ?? _s.snapshot?.timestamp ?? DateTime.now();
      final time = DateFormat('HH:mm:ss').format(when.toLocal());
      _mutate((s) => s.copyWith(
            processes: page,
            processTotalCount: count,
            statusText: 'task_manager.status.updated'
                .tr(args: [time, cpu, '$count']),
            clearSelectedProcess: page.items
                .every((process) => process.id != s.selectedProcessId),
          ));
    } catch (error) {
      _mutate((s) => s.copyWith(
            hasError: true,
            errorMessage: '$error',
            statusText:
                'task_manager.status.collect_failed'.tr(args: ['$error']),
          ));
    }
  }

  Future<void> _recoverHistory() async {
    try {
      final history = await _repository.getHistory();
      if (history.isEmpty) return;
      _mutate((s) => s.copyWith(
            history: history,
            snapshot: history.last,
          ));
    } catch (_) {
      // Keep last valid snapshot if recovery is temporarily unavailable;
      // the next regular snapshot on the hub will continue the stream.
    }
  }

  List<PerformanceSnapshot> _appendHistory(
    List<PerformanceSnapshot> previous,
    PerformanceSnapshot incoming,
  ) {
    if (previous.isNotEmpty && incoming.sequence <= previous.last.sequence) {
      return previous;
    }
    final updated = List<PerformanceSnapshot>.of(previous)..add(incoming);
    while (updated.length > 60) {
      updated.removeAt(0);
    }
    return updated;
  }

  void _restartProcessTimer() {
    _processTimer?.cancel();
    // Avalonia behavior: timer runs only while the Processes tab is active
    // and auto-refresh is enabled.
    if (_s.autoRefresh && _s.tabIndex == 1) {
      _processTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) {
          if (canRefreshProcesses() && refreshProcessesCommand.canRun.value) {
            refreshProcessesCommand();
          }
        },
      );
    }
  }

  String _formatUpdatedStatus(PerformanceSnapshot snapshot, int processCount) {
    final time = DateFormat('HH:mm:ss')
        .format(snapshot.timestamp?.toLocal() ?? DateTime.now());
    final cpu = snapshot.cpuPercent.toStringAsFixed(1);
    return 'task_manager.status.updated'
        .tr(args: [time, cpu, '$processCount']);
  }

  @override
  void dispose() {
    _processTimer?.cancel();
    _snapshots?.cancel();
    _reconnects?.cancel();
    super.dispose();
  }
}
