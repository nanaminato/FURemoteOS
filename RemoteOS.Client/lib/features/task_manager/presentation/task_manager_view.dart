import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/theme_service.dart';
import '../application/task_manager_view_model.dart';
import '../domain/task_ui_state.dart';
import 'components/task_manager_components.dart';
import 'components/task_manager_performance_workspace.dart';

/// Desktop task manager shell. It preserves Avalonia's two top-level tabs;
/// each page owns a dense desktop workspace rather than a mobile card layout.
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
    if (widget.vm.startCommand.canRun.value) widget.vm.startCommand.runAsync();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ValueListenableBuilder(
      valueListenable: widget.vm.state,
      builder: (context, state, _) => Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.borderSubtle))),
          child: Row(children: [
            _tabButton('task_manager.performance', 0),
            _tabButton('task_manager.processes', 1),
            const SizedBox(width: 8),
            IconButton(
                onPressed: () => widget.vm.refreshProcessesCommand.runAsync(),
                icon: const Icon(Icons.refresh),
                tooltip: 'common.refresh'.tr()),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    state.hasError
                        ? 'task_manager.status.collect_failed'.tr()
                        : 'task_manager.status.collecting'.tr(),
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12, color: palette.textSecondary))),
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
        child: Text(key.tr(),
            style: TextStyle(
                fontWeight: _state.tabIndex == index ? FontWeight.w700 : null)),
      );
}
