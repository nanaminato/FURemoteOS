import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/workspace_scaffold.dart';
import '../../../core/network/remoteos_api.dart';

/// Binds the migrated administration pages to the same v1 REST routes used by
/// the Avalonia client.  JSON remains deliberately tolerant so a newer server
/// can add DTO properties without breaking the desktop shell.
class RemoteAdminPage extends ConsumerStatefulWidget {
  const RemoteAdminPage(
      {super.key,
      required this.application,
      required this.title,
      required this.description,
      required this.columns,
      required this.metrics,
      this.primaryAction,
      this.emptyMessage});
  final String application;
  final String title;
  final String description;
  final List<String> columns;
  final List<WorkspaceMetric> metrics;
  final String? primaryAction;
  final String? emptyMessage;

  @override
  ConsumerState<RemoteAdminPage> createState() => _RemoteAdminPageState();
}

class _RemoteAdminPageState extends ConsumerState<RemoteAdminPage> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(RemoteAdminPage old) {
    super.didUpdateWidget(old);
    if (old.application != widget.application || old.title != widget.title)
      _future = _load();
  }

  Future<dynamic> _load() => ref
      .read(remoteOsApiProvider)
      .getJson(_routeFor(widget.application, widget.title));
  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return WorkspaceOverview(
                title: widget.title,
                description: widget.description,
                metrics: widget.metrics,
                columns: widget.columns,
                rows: const [],
                emptyMessage: 'Unable to load server data: ${snapshot.error}',
                primaryAction: 'Retry',
                onPrimaryAction: _refresh);
          }
          final rows = _rows(snapshot.data, widget.columns);
          final metrics = _metrics(widget.metrics, rows, snapshot.data);
          return WorkspaceOverview(
              title: widget.title,
              description: widget.description,
              metrics: metrics,
              columns: widget.columns,
              rows: rows,
              emptyMessage: widget.emptyMessage,
              primaryAction: widget.primaryAction,
              onPrimaryAction: _refresh);
        },
      );
}

String _routeFor(String app, String page) {
  final key = '$app/$page';
  return switch (key) {
    'task_manager/Processes' => '/api/v1/system/processes',
    'task_manager/Performance' => '/api/v1/system/metrics',
    'docker_manager/Overview' => '/api/v1/docker/status',
    'docker_manager/Containers' => '/api/v1/docker/containers',
    'docker_manager/Images' => '/api/v1/docker/images',
    'docker_manager/Volumes' => '/api/v1/docker/volumes',
    'docker_manager/Networks' => '/api/v1/docker/networks',
    'docker_manager/Stacks' => '/api/v1/docker/stacks',
    'firewall/Rules' => '/api/v1/firewall/rules',
    'firewall/Status' => '/api/v1/firewall/status',
    'certificates/Overview' ||
    'certificates/Certificates' =>
      '/api/v1/certificates',
    'web_servers/Overview' || 'web_servers/Instances' => '/api/v1/webservers',
    'tunnels/Overview' || 'tunnels/Definitions' => '/api/v1/tunnels',
    'tunnels/Servers' => '/api/v1/tunnels/profiles',
    'process_guardian/Workloads' => '/api/v1/guardian/workloads',
    'process_guardian/Logs' => '/api/v1/guardian/audit',
    _ =>
      '/api/v1/${app.replaceAll('_manager', '').replaceAll('_', '-')}/status',
  };
}

List<List<String>> _rows(dynamic body, List<String> columns) {
  final records = body is List
      ? body
      : body is Map
          ? _firstList(body) ?? [body]
          : const [];
  return records.whereType<Map>().map((raw) {
    final item = Map<String, dynamic>.from(raw);
    return columns.map((column) => _value(item, column)).toList();
  }).toList();
}

List<dynamic>? _firstList(Map body) {
  for (final value in body.values) {
    if (value is List) return value;
  }
  return null;
}

String _value(Map<String, dynamic> item, String column) {
  final normalized = column.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  for (final entry in item.entries) {
    if (entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ==
        normalized) return _display(entry.value);
  }
  const aliases = {
    'name': ['displayName', 'containerName', 'repository'],
    'state': ['status'],
    'status': ['state'],
    'memory': ['memoryUsage'],
    'cpu': ['cpuUsage'],
    'pid': ['processId'],
    'address': ['url', 'listenAddress']
  };
  for (final candidate in aliases[normalized] ?? const <String>[]) {
    if (item.containsKey(candidate)) return _display(item[candidate]);
  }
  return '—';
}

String _display(dynamic value) => value == null
    ? '—'
    : value is Map || value is List
        ? value.toString()
        : value.toString();

List<WorkspaceMetric> _metrics(
    List<WorkspaceMetric> base, List<List<String>> rows, dynamic body) {
  return [
    for (var index = 0; index < base.length; index++)
      WorkspaceMetric(
          base[index].label,
          index == 0 ? '${rows.length}' : _metricValue(body, base[index].label),
          base[index].icon,
          base[index].color)
  ];
}

String _metricValue(dynamic body, String label) {
  if (body is Map) return _value(Map<String, dynamic>.from(body), label);
  return '—';
}
