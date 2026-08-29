import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/theme_service.dart';
import '../application/task_manager_view_model.dart';
import '../domain/task_ui_state.dart';
import 'components/task_manager_components.dart';
import 'components/task_manager_performance_workspace.dart';

/// Desktop task manager shell. Layout mirrors Avalonia TaskManagerMainView:
/// a top border holds the two tab buttons, a tab-aware refresh button, and
/// two lines of status text (connection status + detailed timestamped line).
/// Each tab owns a dense desktop workspace rather than a mobile card layout.
///
/// This View owns all localization + timestamp formatting per AGENTS.md § 8.
class TaskManagerView extends StatefulWidget {
  const TaskManagerView({super.key, required this.vm});
  final TaskManagerViewModel vm;

  @override
  State<TaskManagerView> createState() => _TaskManagerViewState();
}

class _TaskManagerViewState extends State<TaskManagerView> {
  TaskManagerUiState get _state => widget.vm.state.value;

  @override
  void initState() {
    super.initState();
    if (widget.vm.startCommand.canRun.value) {
      widget.vm.startCommand.runAsync();
    }
  }

  // ---- Translation helpers: enum → key + namedArgs ----

  /// Maps ConnectionState enum to its translation key.
  static String _connectionKey(TaskConnectionState state) {
    switch (state) {
      case TaskConnectionState.initializing:
        return 'task_manager.connection.initializing';
      case TaskConnectionState.live:
        return 'task_manager.connection.live';
      case TaskConnectionState.snapshot:
        return 'task_manager.connection.snapshot';
      case TaskConnectionState.updated:
        return 'task_manager.connection.updated';
      case TaskConnectionState.recovering:
        return 'task_manager.connection.recovering';
      case TaskConnectionState.disconnected:
        return 'task_manager.connection.disconnected';
      case TaskConnectionState.unavailable:
        return 'task_manager.connection.unavailable';
      case TaskConnectionState.waiting:
        return 'task_manager.connection.waiting';
    }
  }

  /// Builds the detail status text from raw state data.
  /// Returns null when there is nothing to show.
  static String? _buildStatusText(TaskManagerUiState state) {
    switch (state.statusKind) {
      case TaskManagerStatusKind.collecting:
        return 'task_manager.status.collecting'.tr();
      case TaskManagerStatusKind.updated:
        final time = DateFormat('HH:mm:ss')
            .format(state.lastUpdatedTime?.toLocal() ?? DateTime.now());
        return 'task_manager.status.updated'.tr(namedArgs: {
          'time': time,
          'cpu': state.currentCpuPercent.toStringAsFixed(1),
          'count': '${state.processTotalCount}',
        });
      case TaskManagerStatusKind.failed:
        return 'task_manager.status.collect_failed'.tr(namedArgs: {
          'error': state.errorMessage ?? '',
        });
      case TaskManagerStatusKind.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ValueListenableBuilder(
      valueListenable: widget.vm.state,
      builder: (context, state, _) => Column(children: [
        // --- Top bar: matches Avalonia DockPanel Top Border ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.borderSubtle))),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(children: [
                  _tabButton('task_manager.performance', 0),
                  _tabButton('task_manager.processes', 1),
                ]),
                const SizedBox(width: 8),
                // Avalonia: Button with Text content, tooltip=F5, Padding=12,5
                Tooltip(
                  message: 'F5',
                  child: TextButton(
                      onPressed: () => widget.vm.refreshCommand.runAsync(),
                      child: Text('common.refresh'.tr())),
                ),
                const SizedBox(width: 12),
                // Two status lines: ConnectionStatus + StatusText
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_connectionKey(state.connectionState).tr(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: palette.textSecondary
                                .withValues(alpha: 0.8))),
                    Text(_buildStatusText(state) ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: palette.textSecondary
                                .withValues(alpha: 0.55))),
                  ],
                )),
              ]),
        ),
        if (state.isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
              child: state.tabIndex == 0
                  ? AvaloniaPerformanceWorkspace(vm: widget.vm)
                  : ProcessWorkspace(vm: widget.vm)),
      ]),
    );
  }

  Widget _tabButton(String key, int index) => TextButton(
        onPressed: () => widget.vm.setTabIndex(index),
        style: _state.tabIndex == index
            ? TextButton.styleFrom(
                backgroundColor:
                    context.palette.accent.withValues(alpha: 0.08),
                foregroundColor: context.palette.accent,
              )
            : null,
        child: Text(key.tr(),
            style: TextStyle(
                fontWeight: _state.tabIndex == index ? FontWeight.w700 : null)),
      );
}
