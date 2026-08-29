// Task Manager main View (ARCHITECTURE.md § 8).
//
// Thin orchestration layer:
//   * owns the SnackBar / Scaffold plumbing for one-shot messages
//   * wires the TabController to the ViewModel state
//   * composes the two feature-specific components from
//     `components/task_manager_components.dart`.

import 'package:flutter/material.dart';

import '../../../core/theme/theme_service.dart';
import '../application/task_manager_view_model.dart';
import '../domain/task_ui_state.dart';
import 'components/task_manager_components.dart';

class TaskManagerView extends StatefulWidget {
  const TaskManagerView({super.key, required this.vm});

  final TaskManagerViewModel vm;

  @override
  State<TaskManagerView> createState() => _TaskManagerViewState();
}

class _TaskManagerViewState extends State<TaskManagerView> {
  static const _tabs = [
    Tab(text: 'Performance'),
    Tab(text: 'Processes'),
  ];

  TaskManagerUiState get _ui => widget.vm.state.value;

  @override
  void initState() {
    super.initState();
    if (widget.vm.startCommand.canRun.value) {
      widget.vm.startCommand();
    }
    // One-shot UI messages: convert the ViewModel's pendingMessage into a
    // SnackBar so transient statuses don't pollute long-lived state.
    widget.vm.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.vm.state.removeListener(_onStateChanged);
    super.dispose();
  }

  String? _lastShown;
  void _onStateChanged() {
    final message = _ui.pendingMessage;
    if (message == null) {
      _lastShown = null;
      return;
    }
    if (message == _lastShown) return;
    _lastShown = message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.vm.consumePendingMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: widget.vm.state,
      builder: (context, _) {
        if (_ui.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return DefaultTabController(
          length: 2,
          initialIndex: _ui.tabIndex,
          child: Column(
            children: [
              Container(
                color: palette.surface,
                child: TabBar(
                  tabs: _tabs,
                  onTap: widget.vm.setTabIndex,
                ),
              ),
              if (_ui.hasError && _ui.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _ui.errorMessage!,
                    style: TextStyle(color: palette.danger),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ResourceMetricsGrid(vm: widget.vm),
                          const SizedBox(height: 28),
                          ResourceHistorySection(vm: widget.vm),
                        ],
                      ),
                    ),
                    ProcessListPane(vm: widget.vm),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
