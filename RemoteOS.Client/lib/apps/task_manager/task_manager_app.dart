// Task Manager app shell (thin entry per AGENTS.md § 2).
//
// Composes the transient [TaskManagerViewModel] with the feature
// [TaskManagerView].  Dependencies are composed here because the
// PerformanceHub instance is riverpod-owned (it is obtained via ref.read).
// No business logic or stream wiring lives here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/network/remoteos_api.dart';
import '../../features/system_monitor/data/performance_hub.dart';
import '../../features/system_monitor/data/remote_system_monitor_api.dart';
import '../../features/task_manager/application/task_manager_view_model.dart';
import '../../features/task_manager/presentation/task_manager_view.dart';

class TaskManagerApp extends ConsumerStatefulWidget {
  const TaskManagerApp({super.key});

  @override
  ConsumerState<TaskManagerApp> createState() => _TaskManagerAppState();
}

class _TaskManagerAppState extends ConsumerState<TaskManagerApp> {
  TaskManagerViewModel? _vm;

  @override
  void initState() {
    super.initState();
    final session = ref.read(authProvider);
    if (session.isAuthenticated) {
      final api = RemoteSystemMonitorApi(ref.read(remoteOsApiProvider));
      final hub = ref.read(performanceHubProvider);
      _vm = createTaskManagerViewModel(api: api, hub: hub);
    }
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    // Keep the PerformanceHub alive for the lifetime of this window.
    // The hub is exposed as Provider.autoDispose, and ref.read in initState
    // does not establish a dependency, so riverpod would otherwise auto-
    // dispose the hub (closing the SignalR stream and the snapshot
    // StreamController) the moment initState returns — even though the
    // ViewModel is still listening on the stream.  Watching it here anchors
    // the provider to this widget's lifetime so realtime snapshots keep
    // flowing until the window closes.
    ref.watch(performanceHubProvider);
    final vm = _vm;
    if (!session.isAuthenticated || vm == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Authentication required.')),
      );
    }
    return TaskManagerView(vm: vm);
  }
}
