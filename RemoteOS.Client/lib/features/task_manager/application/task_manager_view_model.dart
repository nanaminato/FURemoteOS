// Task Manager ViewModel (ARCHITECTURE.md § 9).
//
// Presentation state is a single [ValueNotifier<TaskManagerUiState>].
// Commands model the user intents that have async execution state: starting
// the data session, refreshing the process list, and killing a process.
// StreamSubscriptions (hub snapshots/reconnects) and the periodic process
// Timer are owned here and disposed via the parent ViewModel.

import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';

import '../../../core/commands/base_view_model.dart';
import '../../system_monitor/data/performance_hub.dart';
import '../../system_monitor/data/remote_system_monitor_api.dart';
import '../data/repositories/remote_task_repository.dart';
import '../domain/task_repository.dart';
import '../domain/task_ui_state.dart';

/// Factory used by the app shell to construct a transient VM.
/// The PerformanceHub is a riverpod-owned object, so the owning ConsumerState
/// (task_manager_app.dart) resolves it and hands it in via the [hub] parameter.
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
    trackDisposable(refreshProcessesCommand);
    trackDisposable(_killProcessCommand);
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

  // ---- Gate helpers (used by View to gate UI actions) ----
  // command_it v1.x does not expose canExecuteListenable on command factories,
  // so the enabled-state decisions are exposed as helpers instead.  The
  // Command instances still provide `canRun`/`isRunning` execution state.

  bool canRefreshProcesses() => !_s.isLoading;

  // ---- Computed helpers for resource-specific history values ----

  List<PerformanceResourceInfo> resourceChoices(
    PerformanceInfo? info,
    PerformanceResource resource,
  ) {
    if (info == null) return const [];
    return switch (resource) {
      PerformanceResource.filesystem => info.filesystems,
      PerformanceResource.disk => info.disks,
      PerformanceResource.network => info.networks,
      _ => const [],
    };
  }

  double historyValue(
    PerformanceSnapshot s,
    PerformanceResource resource,
    String? selectedId,
  ) {
    switch (resource) {
      case PerformanceResource.cpu:
        return s.cpuPercent;
      case PerformanceResource.memory:
        return s.memoryTotalBytes == 0
            ? 0
            : s.memoryUsedBytes * 100 / s.memoryTotalBytes;
      case PerformanceResource.filesystem:
        if (selectedId == null) {
          return s.filesystemTotalBytes == 0
              ? 0
              : s.filesystemUsedBytes * 100 / s.filesystemTotalBytes;
        }
        for (final entry in s.filesystems) {
          if (entry.id == selectedId) {
            return entry.totalBytes == 0
                ? 0
                : entry.usedBytes * 100 / entry.totalBytes;
          }
        }
        return 0;
      case PerformanceResource.disk:
        if (selectedId == null) {
          return (s.diskReadBytesPerSecond + s.diskWriteBytesPerSecond)
              .toDouble();
        }
        for (final entry in s.disks) {
          if (entry.id == selectedId) {
            return (entry.readBytesPerSecond + entry.writeBytesPerSecond)
                .toDouble();
          }
        }
        return 0;
      case PerformanceResource.network:
        if (selectedId == null) {
          return (s.networkReceiveBytesPerSecond + s.networkSendBytesPerSecond)
              .toDouble();
        }
        for (final entry in s.networks) {
          if (entry.id == selectedId) {
            return (entry.receiveBytesPerSecond + entry.sendBytesPerSecond)
                .toDouble();
          }
        }
        return 0;
    }
  }

  // ---- UI mutators (not Commands — pure presentation toggles) ----

  void setTabIndex(int index) => _mutate((s) => s.copyWith(tabIndex: index));

  void selectResource(PerformanceResource resource) {
    _mutate((s) => s.copyWith(
          selectedResource: resource,
          clearSelectedResourceId: true,
        ));
  }

  void setSelectedResourceId(String? id) =>
      _mutate((s) => s.copyWith(selectedResourceId: id));

  void setProcessFilter(String value) {
    _mutate((s) => s.copyWith(processFilter: value));
    // Auto-refresh the filtered list immediately.  Throttling is handled on
    // the server side by the 5s periodic timer; per-keystroke refresh keeps
    // the UX responsive for interactive filtering without accumulating
    // redundant calls since an in-flight query will overwrite the list.
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

  void consumePendingMessage() =>
      _mutate((s) => s.copyWith(clearPendingMessage: true));

  // ---- Commands ----

  /// Performs the initial startup handshake: history, info, hub connect.
  late final startCommand = Command.createAsyncNoParamNoResult(_startInternal);

  /// Re-runs the process query using the current filter.
  late final refreshProcessesCommand =
      Command.createAsyncNoParamNoResult(_refreshProcessesInternal);

  /// Kills a process by id.  Expects the caller to invoke with [killProcess(pid)]
  /// via the [killProcess] helper.
  late final _killProcessCommand =
      Command.createAsyncNoResult<int>((pid) async {
    final result = await _repository.killProcess(pid);
    if (result.success) {
      _mutate((s) => s.copyWith(
            pendingMessage: 'Process ended',
          ));
    } else if (result.requiresElevation) {
      _mutate((s) => s.copyWith(
            pendingMessage: 'Elevation required',
          ));
    } else {
      _mutate((s) => s.copyWith(
            pendingMessage: result.error ?? 'Unable to end process',
          ));
    }
    // Refresh after kill so the UI reflects server state (including any
    // elevation-triggered failure where the process is still running).
    await _refreshProcessesInternal();
  });

  /// Public helper matching the Avalonia kill-process API: wraps the int
  /// parameter in a typed command invocation so the View doesn't need to
  /// understand command_it parameter types.
  Future<void> killProcess(int pid) async {
    if (!_killProcessCommand.canRun.value) return;
    _killProcessCommand(pid);
    // Command.run fires and updates state asynchronously; wait for the
    // execution to settle so callers right after refresh see a consistent
    // process list (command_it v9.x void run → value via isRunning listenable).
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
      // Real-time snapshots + reconnect recovery.
      _snapshots?.cancel();
      _snapshots = _repository.snapshotStream.listen((snapshot) {
        _mutate((s) {
          final updated = _appendHistory(s.history, snapshot);
          return s.copyWith(snapshot: snapshot, history: updated);
        });
      });
      _reconnects?.cancel();
      _reconnects =
          _repository.reconnectedStream.listen((_) => _recoverHistory());
      await _repository.ensureMonitoringConnected();
      await _refreshProcessesInternal();
      _restartProcessTimer();
    } catch (error) {
      _mutate((s) => s.copyWith(
            hasError: true,
            errorMessage: '$error',
          ));
    } finally {
      _mutate((s) => s.copyWith(isLoading: false));
    }
  }

  Future<void> _refreshProcessesInternal() async {
    try {
      final page = await _repository.queryProcesses(filter: _s.processFilter);
      _mutate((s) => s.copyWith(processes: page));
    } catch (error) {
      _mutate((s) => s.copyWith(
            hasError: true,
            errorMessage: '$error',
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
    if (_s.autoRefresh) {
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

  @override
  void dispose() {
    _processTimer?.cancel();
    _snapshots?.cancel();
    _reconnects?.cancel();
    super.dispose();
  }
}
