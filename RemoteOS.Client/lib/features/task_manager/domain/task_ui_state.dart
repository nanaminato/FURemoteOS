// Task Manager UI state (single ValueNotifier projection per View).
//
// Contains:
//   * performance tab state (snapshots, selected item key, info, history)
//   * processes tab state (filter, page, auto-refresh, kill feedback, counts)
//
// Design rule (AGENTS.md § 8-9):
//   * This state does NOT hold pre-localized UI text. The View owns translation
//     and formatting; this file only carries raw data + enums.

import 'package:flutter/foundation.dart';

import '../../system_monitor/data/remote_system_monitor_api.dart';

/// SignalR / live-monitor connection lifecycle. Mirrors the translation keys
/// under `task_manager.connection.*`. The View maps each value to its key.
///
/// Renamed to [TaskConnectionState] to avoid colliding with Flutter's own
/// `ConnectionState` enum from `package:flutter/src/widgets/async.dart`.
enum TaskConnectionState {
  initializing,
  live,
  snapshot,
  updated,
  recovering,
  disconnected,
  unavailable,
  waiting,
}

/// The kind of detail status line to render under the connection badge.
/// `none` means no detail line should be shown.
enum TaskManagerStatusKind { collecting, updated, failed, none }

/// Kill-process feedback payload (data, not text). The View owns localization.
@immutable
class KillFeedback {
  const KillFeedback({
    required this.kind,
    required this.processName,
    required this.processId,
    this.errorMessage,
  });

  final KillFeedbackKind kind;
  final String processName;
  final int processId;
  final String? errorMessage;
}

enum KillFeedbackKind { terminating, terminated, elevationRequired, failed }

@immutable
class TaskManagerUiState {
  const TaskManagerUiState({
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.info,
    required this.snapshot,
    required this.history,
    required this.selectedPerformanceKey,
    required this.processes,
    required this.selectedProcessId,
    required this.processFilter,
    required this.autoRefresh,
    required this.pendingMessage,
    required this.killFeedback,
    required this.processTotalCount,
    required this.connectionState,
    required this.statusKind,
    required this.lastUpdatedTime,
    required this.currentCpuPercent,
    required this.tabIndex,
  });

  factory TaskManagerUiState.initial() => const TaskManagerUiState(
        isLoading: true,
        hasError: false,
        errorMessage: null,
        info: null,
        snapshot: null,
        history: [],
        selectedPerformanceKey: 'cpu:cpu',
        processes: null,
        selectedProcessId: null,
        processFilter: '',
        autoRefresh: true,
        pendingMessage: null,
        killFeedback: null,
        processTotalCount: 0,
        connectionState: TaskConnectionState.initializing,
        statusKind: TaskManagerStatusKind.collecting,
        lastUpdatedTime: null,
        currentCpuPercent: 0,
        tabIndex: 0,
      );

  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final PerformanceInfo? info;
  final PerformanceSnapshot? snapshot;
  final List<PerformanceSnapshot> history;
  final String selectedPerformanceKey;
  final ProcessPage? processes;
  final int? selectedProcessId;
  final String processFilter;
  final bool autoRefresh;
  final String?
      pendingMessage; // one-shot SnackBar message, null after consumed
  final KillFeedback?
      killFeedback; // null → hidden; mirrors Avalonia KillFeedback visibility
  final int processTotalCount;
  final TaskConnectionState connectionState;
  final TaskManagerStatusKind statusKind;
  final DateTime? lastUpdatedTime; // raw timestamp, View formats + localizes
  final double currentCpuPercent; // raw CPU percent (0..100)
  final int tabIndex;

  TaskManagerUiState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    bool clearError = false,
    PerformanceInfo? info,
    PerformanceSnapshot? snapshot,
    List<PerformanceSnapshot>? history,
    String? selectedPerformanceKey,
    ProcessPage? processes,
    int? selectedProcessId,
    bool clearSelectedProcess = false,
    String? processFilter,
    bool? autoRefresh,
    String? pendingMessage,
    bool clearPendingMessage = false,
    KillFeedback? killFeedback,
    int? processTotalCount,
    TaskConnectionState? connectionState,
    TaskManagerStatusKind? statusKind,
    DateTime? lastUpdatedTime,
    double? currentCpuPercent,
    int? tabIndex,
  }) {
    return TaskManagerUiState(
      isLoading: isLoading ?? this.isLoading,
      hasError: clearError ? false : (hasError ?? this.hasError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      info: info ?? this.info,
      snapshot: snapshot ?? this.snapshot,
      history: history ?? this.history,
      selectedPerformanceKey:
          selectedPerformanceKey ?? this.selectedPerformanceKey,
      processes: processes ?? this.processes,
      selectedProcessId: clearSelectedProcess
          ? null
          : (selectedProcessId ?? this.selectedProcessId),
      processFilter: processFilter ?? this.processFilter,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      pendingMessage:
          clearPendingMessage ? null : (pendingMessage ?? this.pendingMessage),
      killFeedback: killFeedback ?? this.killFeedback,
      processTotalCount: processTotalCount ?? this.processTotalCount,
      connectionState: connectionState ?? this.connectionState,
      statusKind: statusKind ?? this.statusKind,
      lastUpdatedTime: lastUpdatedTime ?? this.lastUpdatedTime,
      currentCpuPercent: currentCpuPercent ?? this.currentCpuPercent,
      tabIndex: tabIndex ?? this.tabIndex,
    );
  }
}
