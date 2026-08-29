// Task Manager UI state (single ValueNotifier projection per View).
//
// Contains:
//   * performance tab state (snapshots, selected item key, info, history)
//   * processes tab state (filter, page, auto-refresh, kill feedback, counts)

import 'package:flutter/foundation.dart';

import '../../system_monitor/data/remote_system_monitor_api.dart';

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
    required this.connectionStatus,
    required this.statusText,
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
        killFeedback: '',
        processTotalCount: 0,
        connectionStatus: 'task_manager.connection.initializing',
        statusText: 'task_manager.status.collecting',
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
  final String killFeedback; // empty → hidden; mirrors Avalonia KillFeedback
  final int processTotalCount;
  final String
      connectionStatus; // short label on the top bar (e.g. "实时连接")
  final String statusText; // detailed status with timestamp/cpu/process counts
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
    String? killFeedback,
    int? processTotalCount,
    String? connectionStatus,
    String? statusText,
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
      connectionStatus: connectionStatus ?? this.connectionStatus,
      statusText: statusText ?? this.statusText,
      tabIndex: tabIndex ?? this.tabIndex,
    );
  }
}
