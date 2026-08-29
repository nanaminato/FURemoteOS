// Task Manager repository interface (ARCHITECTURE.md § 11).
//
// Task Manager has two I/O channels:
//   * Low-frequency REST: performance info, history, process list paging,
//     kill operations.
//   * High-frequency WebSocket stream: realtime [PerformanceSnapshot]s
//     delivered via the application-scope performance hub.
//
// The repository abstracts these concerns so the ViewModel never wires a
// StreamSubscription directly against a WebSocket client.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../system_monitor/data/remote_system_monitor_api.dart';

/// Which resource tile is selected in the Performance tab.
enum PerformanceResource { cpu, memory, filesystem, disk, network }

/// Result wrapper for kill-process operations; carries the server elevation
/// and error fields without leaking raw HTTP DTOs to the ViewModel.
@immutable
class KillResult {
  const KillResult({
    required this.success,
    required this.requiresElevation,
    this.error,
  });
  final bool success;
  final bool requiresElevation;
  final String? error;
}

/// Canonical access point for Task Manager data + mutation operations.
abstract interface class TaskRepository {
  // ---- Static metadata (rarely changes) ----
  Future<PerformanceInfo> getInfo();

  // ---- Snapshots (REST recovery + realtime stream) ----
  Future<List<PerformanceSnapshot>> getHistory({int seconds = 60});
  Stream<PerformanceSnapshot> get snapshotStream;
  Stream<void> get reconnectedStream;
  Future<void> ensureMonitoringConnected();

  // ---- Processes (REST) ----
  Future<ProcessPage> queryProcesses({required String filter, String sort});
  Future<KillResult> killProcess(int id, {bool force = false});

  // ---- Formatting helpers (defined here to match the old Avalonia impl) ----
  static String formatBytes(int value) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var number = value.toDouble();
    var index = 0;
    while (number >= 1024 && index < units.length - 1) {
      number /= 1024;
      index++;
    }
    return '${number.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
  }

  static String formatRate(int bytesPerSecond) =>
      '${formatBytes(bytesPerSecond)}/s';
}
