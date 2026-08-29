// Task Manager UI state (single ValueNotifier projection per View).
//
// Contains:
//   * performance tab state (snapshots, selected resource, info, history)
//   * processes tab state (filter, page, auto-refresh, pending user message)

import 'package:flutter/foundation.dart';

import '../../system_monitor/data/remote_system_monitor_api.dart';
import '../domain/task_repository.dart';

@immutable
class TaskManagerUiState {
  const TaskManagerUiState({
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.info,
    required this.snapshot,
    required this.history,
    required this.selectedResource,
    required this.selectedResourceId,
    required this.selectedPerformanceKey,
    required this.processes,
    required this.selectedProcessId,
    required this.processFilter,
    required this.autoRefresh,
    required this.pendingMessage,
    required this.tabIndex,
  });

  factory TaskManagerUiState.initial() => const TaskManagerUiState(
        isLoading: true,
        hasError: false,
        errorMessage: null,
        info: null,
        snapshot: null,
        history: [],
        selectedResource: PerformanceResource.cpu,
        selectedResourceId: null,
        selectedPerformanceKey: 'cpu:cpu',
        processes: null,
        selectedProcessId: null,
        processFilter: '',
        autoRefresh: true,
        pendingMessage: null,
        tabIndex: 0,
      );

  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final PerformanceInfo? info;
  final PerformanceSnapshot? snapshot;
  final List<PerformanceSnapshot> history;
  final PerformanceResource selectedResource;
  final String? selectedResourceId;
  final String selectedPerformanceKey;
  final ProcessPage? processes;
  final int? selectedProcessId;
  final String processFilter;
  final bool autoRefresh;
  final String?
      pendingMessage; // one-shot SnackBar message, null after consumed
  final int tabIndex;

  double get memoryPercent {
    final s = snapshot;
    if (s == null || s.memoryTotalBytes == 0) return 0;
    return s.memoryUsedBytes * 100 / s.memoryTotalBytes;
  }

  double get filesystemPercent {
    final s = snapshot;
    if (s == null || s.filesystemTotalBytes == 0) return 0;
    return s.filesystemUsedBytes * 100 / s.filesystemTotalBytes;
  }

  TaskManagerUiState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    bool clearError = false,
    PerformanceInfo? info,
    PerformanceSnapshot? snapshot,
    List<PerformanceSnapshot>? history,
    PerformanceResource? selectedResource,
    String? selectedResourceId,
    bool clearSelectedResourceId = false,
    String? selectedPerformanceKey,
    ProcessPage? processes,
    int? selectedProcessId,
    bool clearSelectedProcess = false,
    String? processFilter,
    bool? autoRefresh,
    String? pendingMessage,
    bool clearPendingMessage = false,
    int? tabIndex,
  }) {
    return TaskManagerUiState(
      isLoading: isLoading ?? this.isLoading,
      hasError: clearError ? false : (hasError ?? this.hasError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      info: info ?? this.info,
      snapshot: snapshot ?? this.snapshot,
      history: history ?? this.history,
      selectedResource: selectedResource ?? this.selectedResource,
      selectedResourceId: clearSelectedResourceId
          ? null
          : (selectedResourceId ?? this.selectedResourceId),
      selectedPerformanceKey: selectedPerformanceKey ?? this.selectedPerformanceKey,
      processes: processes ?? this.processes,
      selectedProcessId: clearSelectedProcess
          ? null
          : (selectedProcessId ?? this.selectedProcessId),
      processFilter: processFilter ?? this.processFilter,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      pendingMessage:
          clearPendingMessage ? null : (pendingMessage ?? this.pendingMessage),
      tabIndex: tabIndex ?? this.tabIndex,
    );
  }
}
