import 'package:flutter/material.dart';

import '../common/workspace_scaffold.dart';

/// Configurations for the Avalonia applications whose interaction model is a
/// server-backed, multi-page administration workspace.  Each page is a real
/// independently selectable widget (rather than a temporary placeholder), so
/// the API migration can replace its sample rows without changing navigation.
class ServerAdminApp extends StatelessWidget {
  const ServerAdminApp({super.key, required this.kind});

  final ServerAdminKind kind;

  @override
  Widget build(BuildContext context) {
    final spec = kind.spec;
    return WorkspaceScaffold(
      title: spec.title,
      icon: spec.icon,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {},
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
        const SizedBox(width: 4),
      ],
      pages: [
        for (final page in spec.pages)
          WorkspacePage(
            id: page.title.toLowerCase().replaceAll(' ', '-'),
            title: page.title,
            icon: page.icon,
            builder: (_) => WorkspaceOverview(
              title: page.title,
              description: page.description,
              metrics: page.metrics,
              columns: page.columns,
              rows: page.rows,
              primaryAction: page.primaryAction,
              onPrimaryAction: () {},
              emptyMessage: page.emptyMessage,
            ),
          ),
      ],
    );
  }
}

enum ServerAdminKind {
  taskManager,
  docker,
  firewall,
  certificates,
  webServers,
  tunnels,
  git,
  portForwarding,
  guardian,
  installer;

  ServerAdminWorkspaceSpec get spec => switch (this) {
        ServerAdminKind.taskManager => ServerAdminWorkspaceSpec(
            'Task Manager',
            Icons.monitor_heart_outlined,
            [
              ServerAdminPageSpec(
                  'Processes',
                  Icons.list_alt_outlined,
                  'Inspect server processes and stop a process when required.',
                  'End process',
                  ['Name', 'PID', 'CPU', 'Memory', 'User'],
                  [
                    ['RemoteOS.Server', '2418', '1.2%', '142 MB', 'remoteos'],
                    ['Process Guardian', '2471', '0.1%', '46 MB', 'remoteos']
                  ],
                  _processMetrics),
              ServerAdminPageSpec(
                  'Performance',
                  Icons.speed_outlined,
                  'Live CPU, memory, disk and network usage from the RemoteOS performance hub.',
                  null,
                  ['Metric', 'Current', 'Trend'],
                  [
                    ['CPU', '—', 'Waiting for server'],
                    ['Memory', '—', 'Waiting for server'],
                    ['Network', '—', 'Waiting for server']
                  ],
                  _performanceMetrics),
              ServerAdminPageSpec(
                  'Startup',
                  Icons.rocket_launch_outlined,
                  'Review startup workloads registered on the host.',
                  null,
                  ['Name', 'Status', 'Impact'],
                  const [],
                  _startupMetrics,
                  emptyMessage: 'No startup workloads were reported.'),
            ],
          ),
        ServerAdminKind.docker => ServerAdminWorkspaceSpec(
            'Docker Manager',
            Icons.integration_instructions_outlined,
            [
              ServerAdminPageSpec(
                  'Overview',
                  Icons.dashboard_outlined,
                  'Manage the Docker Engine installed on this RemoteOS server.',
                  null,
                  ['Service', 'State', 'Version'],
                  [
                    ['Docker Engine', 'Checking…', '—']
                  ],
                  _dockerMetrics),
              ServerAdminPageSpec(
                  'Containers',
                  Icons.view_in_ar_outlined,
                  'Start, stop, inspect and remove containers.',
                  'Run container',
                  ['Name', 'Image', 'Status', 'Ports'],
                  const [],
                  _containerMetrics,
                  emptyMessage: 'No containers found.'),
              ServerAdminPageSpec(
                  'Images',
                  Icons.layers_outlined,
                  'Browse locally available images or pull a new image.',
                  'Pull image',
                  ['Repository', 'Tag', 'Size'],
                  const [],
                  _imageMetrics,
                  emptyMessage: 'No images found.'),
              ServerAdminPageSpec(
                  'Volumes',
                  Icons.storage_outlined,
                  'Inspect persistent Docker volumes.',
                  'Create volume',
                  ['Name', 'Driver', 'Mount point'],
                  const [],
                  _volumeMetrics,
                  emptyMessage: 'No volumes found.'),
              ServerAdminPageSpec(
                  'Networks',
                  Icons.hub_outlined,
                  'View and manage Docker networks.',
                  'Create network',
                  ['Name', 'Driver', 'Scope'],
                  const [],
                  _networkMetrics,
                  emptyMessage: 'No networks found.'),
              ServerAdminPageSpec(
                  'Stacks',
                  Icons.account_tree_outlined,
                  'Deploy and monitor Compose stacks.',
                  'Deploy stack',
                  ['Stack', 'Status', 'Services'],
                  const [],
                  _stackMetrics,
                  emptyMessage: 'No stacks found.'),
            ],
          ),
        ServerAdminKind.firewall => ServerAdminWorkspaceSpec(
            'Firewall',
            Icons.shield_outlined,
            [
              ServerAdminPageSpec(
                  'Rules',
                  Icons.rule_outlined,
                  'Manage UFW firewall rules on the Linux host.',
                  'Add rule',
                  ['Rule', 'Action', 'Protocol', 'Source'],
                  const [],
                  _firewallMetrics,
                  emptyMessage: 'No firewall rules loaded.'),
              ServerAdminPageSpec(
                  'Status',
                  Icons.verified_user_outlined,
                  'Review the active firewall state before making changes.',
                  null,
                  ['Property', 'Value'],
                  [
                    ['Firewall', 'Checking…'],
                    ['Default incoming', '—'],
                    ['Default outgoing', '—']
                  ],
                  _firewallMetrics),
            ],
          ),
        ServerAdminKind.certificates => ServerAdminWorkspaceSpec(
            'Certificate Manager',
            Icons.verified_user_outlined,
            [
              ServerAdminPageSpec(
                  'Overview',
                  Icons.dashboard_outlined,
                  'Request, deploy and renew TLS certificates for managed services.',
                  'Request certificate',
                  ['Certificate', 'Domains', 'Expires', 'Status'],
                  const [],
                  _certificateMetrics,
                  emptyMessage: 'No certificates have been requested.'),
              ServerAdminPageSpec(
                  'Certificates',
                  Icons.workspace_premium_outlined,
                  'Inspect certificate metadata and renewal history.',
                  'Request certificate',
                  ['Name', 'Issuer', 'Expiry', 'Renewal'],
                  const [],
                  _certificateMetrics,
                  emptyMessage: 'No certificates found.'),
              ServerAdminPageSpec(
                  'Operations',
                  Icons.history_outlined,
                  'Review recent deployment and renewal operations.',
                  null,
                  ['Operation', 'Started', 'Result'],
                  const [],
                  _operationMetrics,
                  emptyMessage: 'No certificate operations recorded.'),
            ],
          ),
        ServerAdminKind.webServers => ServerAdminWorkspaceSpec(
            'Web Server Manager',
            Icons.http_outlined,
            [
              ServerAdminPageSpec(
                  'Overview',
                  Icons.dashboard_outlined,
                  'Configure managed Nginx installations and hosted sites.',
                  null,
                  ['Service', 'State', 'Version'],
                  [
                    ['Nginx', 'Checking…', '—']
                  ],
                  _webMetrics),
              ServerAdminPageSpec(
                  'Instances',
                  Icons.dns_outlined,
                  'Manage Nginx instances on the server.',
                  'Add instance',
                  ['Instance', 'State', 'Address'],
                  const [],
                  _webMetrics,
                  emptyMessage: 'No managed web-server instances.'),
              ServerAdminPageSpec(
                  'Sites',
                  Icons.language_outlined,
                  'Create virtual hosts, routes and TLS bindings.',
                  'Add site',
                  ['Site', 'Host name', 'State'],
                  const [],
                  _siteMetrics,
                  emptyMessage: 'No sites configured.'),
            ],
          ),
        ServerAdminKind.tunnels => ServerAdminWorkspaceSpec(
            'Tunnel Manager',
            Icons.route_outlined,
            [
              ServerAdminPageSpec(
                  'Overview',
                  Icons.dashboard_outlined,
                  'Manage FRP tunnel desired state and runtime status.',
                  null,
                  ['Runtime', 'Status', 'Version'],
                  [
                    ['FRP', 'Checking…', '—']
                  ],
                  _tunnelMetrics),
              ServerAdminPageSpec(
                  'Definitions',
                  Icons.alt_route_outlined,
                  'Create TCP, UDP, HTTP and HTTPS tunnel definitions.',
                  'Add tunnel',
                  ['Name', 'Type', 'Local target', 'Status'],
                  const [],
                  _tunnelMetrics,
                  emptyMessage: 'No tunnel definitions.'),
              ServerAdminPageSpec(
                  'Servers',
                  Icons.storage_outlined,
                  'Configure FRP server profiles.',
                  'Add server',
                  ['Name', 'Host', 'Port', 'Default'],
                  const [],
                  _serverMetrics,
                  emptyMessage: 'No tunnel servers configured.'),
              ServerAdminPageSpec(
                  'Managed FRPS',
                  Icons.settings_ethernet_outlined,
                  'Inspect the managed FRPS service and diagnostics.',
                  null,
                  ['Check', 'Value'],
                  [
                    ['Service', 'Checking…'],
                    ['Configuration', '—']
                  ],
                  _frpsMetrics),
            ],
          ),
        ServerAdminKind.git => ServerAdminWorkspaceSpec(
            'Git Client',
            Icons.source_outlined,
            [
              ServerAdminPageSpec(
                  'Overview',
                  Icons.dashboard_outlined,
                  'Open a repository to inspect changes, history and remotes.',
                  'Open repository',
                  ['Repository', 'Branch', 'Changes'],
                  const [],
                  _gitMetrics,
                  emptyMessage: 'Select a repository to begin.'),
              ServerAdminPageSpec(
                  'Changes',
                  Icons.edit_note_outlined,
                  'Stage files and prepare a commit.',
                  'Commit',
                  ['File', 'Status', 'Staged'],
                  const [],
                  _changeMetrics,
                  emptyMessage: 'No repository is open.'),
              ServerAdminPageSpec(
                  'History',
                  Icons.history_outlined,
                  'Browse commits and compare revisions.',
                  null,
                  ['Message', 'Author', 'Date'],
                  const [],
                  _historyMetrics,
                  emptyMessage: 'No repository is open.'),
              ServerAdminPageSpec(
                  'Branches',
                  Icons.account_tree_outlined,
                  'Create, switch and merge branches.',
                  'New branch',
                  ['Branch', 'Upstream', 'Current'],
                  const [],
                  _branchMetrics,
                  emptyMessage: 'No repository is open.'),
              ServerAdminPageSpec(
                  'Remotes',
                  Icons.cloud_outlined,
                  'Manage fetch and push remote endpoints.',
                  'Add remote',
                  ['Name', 'URL', 'Fetch'],
                  const [],
                  _remoteMetrics,
                  emptyMessage: 'No repository is open.'),
            ],
          ),
        ServerAdminKind.portForwarding => ServerAdminWorkspaceSpec(
            'Port Forwarding',
            Icons.alt_route_outlined,
            [
              ServerAdminPageSpec(
                  'Forwards',
                  Icons.swap_horiz_outlined,
                  'Create and manage local-to-remote port forwards.',
                  'Add forward',
                  ['Name', 'Local', 'Remote', 'State'],
                  const [],
                  _forwardMetrics,
                  emptyMessage: 'No port forwards configured.'),
              ServerAdminPageSpec(
                  'Connection',
                  Icons.link_outlined,
                  'Review the SSH or tunnel connection used by forwards.',
                  null,
                  ['Property', 'Value'],
                  [
                    ['Connection', 'Not configured'],
                    ['Keep alive', 'Enabled']
                  ],
                  _connectionMetrics),
            ],
          ),
        ServerAdminKind.guardian => ServerAdminWorkspaceSpec(
            'Process Guardian',
            Icons.health_and_safety_outlined,
            [
              ServerAdminPageSpec(
                  'Workloads',
                  Icons.health_and_safety_outlined,
                  'Monitor and manage workloads supervised by the RemoteOS Guardian Agent.',
                  'Start workload',
                  ['Workload', 'State', 'PID', 'Restarts'],
                  const [],
                  _guardianMetrics,
                  emptyMessage: 'No managed workloads were reported.'),
              ServerAdminPageSpec(
                  'Logs',
                  Icons.article_outlined,
                  'Inspect live Guardian Agent logs.',
                  null,
                  ['Time', 'Level', 'Message'],
                  const [],
                  _logMetrics,
                  emptyMessage: 'No logs received yet.'),
            ],
          ),
        ServerAdminKind.installer => ServerAdminWorkspaceSpec(
            'App Installer',
            Icons.get_app_outlined,
            [
              ServerAdminPageSpec(
                  'Packages',
                  Icons.inventory_2_outlined,
                  'Install RemoteOS application packages and inspect installed applications.',
                  'Install package',
                  ['Application', 'Version', 'Publisher', 'State'],
                  const [],
                  _packageMetrics,
                  emptyMessage: 'No installed packages to show.'),
              ServerAdminPageSpec(
                  'Permissions',
                  Icons.admin_panel_settings_outlined,
                  'Review permissions requested by installed applications.',
                  null,
                  ['Application', 'Permission', 'Access'],
                  const [],
                  _permissionMetrics,
                  emptyMessage: 'No application permissions to show.'),
            ],
          ),
      };
}

class ServerAdminWorkspaceSpec {
  const ServerAdminWorkspaceSpec(this.title, this.icon, this.pages);
  final String title;
  final IconData icon;
  final List<ServerAdminPageSpec> pages;
}

class ServerAdminPageSpec {
  const ServerAdminPageSpec(this.title, this.icon, this.description,
      this.primaryAction, this.columns, this.rows, this.metrics,
      {this.emptyMessage});
  final String title;
  final IconData icon;
  final String description;
  final String? primaryAction;
  final List<String> columns;
  final List<List<String>> rows;
  final List<WorkspaceMetric> metrics;
  final String? emptyMessage;
}

const _blue = Color(0xFF2174D9);
const _green = Color(0xFF2E9D61);
const _amber = Color(0xFFE6A000);
const _red = Color(0xFFD95050);

const _processMetrics = [
  WorkspaceMetric('Processes', '—', Icons.memory_outlined, _blue),
  WorkspaceMetric('CPU usage', '—', Icons.speed_outlined, _green),
  WorkspaceMetric('Memory', '—', Icons.storage_outlined, _amber)
];
const _performanceMetrics = [
  WorkspaceMetric('CPU', '—', Icons.speed_outlined, _blue),
  WorkspaceMetric('Memory', '—', Icons.memory_outlined, _green),
  WorkspaceMetric('Network', '—', Icons.network_check_outlined, _amber)
];
const _startupMetrics = [
  WorkspaceMetric('Workloads', '—', Icons.rocket_launch_outlined, _blue),
  WorkspaceMetric('Enabled', '—', Icons.check_circle_outline, _green)
];
const _dockerMetrics = [
  WorkspaceMetric('Engine', '—', Icons.settings_outlined, _blue),
  WorkspaceMetric('Containers', '—', Icons.view_in_ar_outlined, _green),
  WorkspaceMetric('Images', '—', Icons.layers_outlined, _amber)
];
const _containerMetrics = [
  WorkspaceMetric('Running', '—', Icons.play_circle_outline, _green),
  WorkspaceMetric('Stopped', '—', Icons.stop_circle_outlined, _amber),
  WorkspaceMetric('Total', '—', Icons.view_in_ar_outlined, _blue)
];
const _imageMetrics = [
  WorkspaceMetric('Images', '—', Icons.layers_outlined, _blue),
  WorkspaceMetric('Storage', '—', Icons.storage_outlined, _amber)
];
const _volumeMetrics = [
  WorkspaceMetric('Volumes', '—', Icons.storage_outlined, _blue),
  WorkspaceMetric('In use', '—', Icons.link_outlined, _green)
];
const _networkMetrics = [
  WorkspaceMetric('Networks', '—', Icons.hub_outlined, _blue),
  WorkspaceMetric('Connected', '—', Icons.device_hub_outlined, _green)
];
const _stackMetrics = [
  WorkspaceMetric('Stacks', '—', Icons.account_tree_outlined, _blue),
  WorkspaceMetric('Services', '—', Icons.widgets_outlined, _green)
];
const _firewallMetrics = [
  WorkspaceMetric('Firewall', '—', Icons.shield_outlined, _blue),
  WorkspaceMetric('Rules', '—', Icons.rule_outlined, _green),
  WorkspaceMetric('Blocked', '—', Icons.block_outlined, _red)
];
const _certificateMetrics = [
  WorkspaceMetric('Certificates', '—', Icons.verified_user_outlined, _blue),
  WorkspaceMetric('Valid', '—', Icons.check_circle_outline, _green),
  WorkspaceMetric('Expiring', '—', Icons.warning_amber_outlined, _amber)
];
const _operationMetrics = [
  WorkspaceMetric('Recent operations', '—', Icons.history_outlined, _blue),
  WorkspaceMetric('Succeeded', '—', Icons.check_circle_outline, _green)
];
const _webMetrics = [
  WorkspaceMetric('Instances', '—', Icons.dns_outlined, _blue),
  WorkspaceMetric('Sites', '—', Icons.language_outlined, _green),
  WorkspaceMetric('Online', '—', Icons.check_circle_outline, _amber)
];
const _siteMetrics = [
  WorkspaceMetric('Sites', '—', Icons.language_outlined, _blue),
  WorkspaceMetric('Enabled', '—', Icons.check_circle_outline, _green)
];
const _tunnelMetrics = [
  WorkspaceMetric('Tunnels', '—', Icons.route_outlined, _blue),
  WorkspaceMetric('Online', '—', Icons.check_circle_outline, _green),
  WorkspaceMetric('Errors', '—', Icons.error_outline, _red)
];
const _serverMetrics = [
  WorkspaceMetric('Servers', '—', Icons.storage_outlined, _blue),
  WorkspaceMetric('Reachable', '—', Icons.link_outlined, _green)
];
const _frpsMetrics = [
  WorkspaceMetric('FRPS', '—', Icons.settings_ethernet_outlined, _blue),
  WorkspaceMetric('Diagnostics', '—', Icons.health_and_safety_outlined, _green)
];
const _gitMetrics = [
  WorkspaceMetric('Repository', '—', Icons.folder_outlined, _blue),
  WorkspaceMetric('Branch', '—', Icons.account_tree_outlined, _green),
  WorkspaceMetric('Changes', '—', Icons.edit_note_outlined, _amber)
];
const _changeMetrics = [
  WorkspaceMetric('Changed files', '—', Icons.edit_note_outlined, _blue),
  WorkspaceMetric('Staged', '—', Icons.check_circle_outline, _green)
];
const _historyMetrics = [
  WorkspaceMetric('Commits', '—', Icons.history_outlined, _blue),
  WorkspaceMetric('Ahead', '—', Icons.arrow_upward_outlined, _green)
];
const _branchMetrics = [
  WorkspaceMetric('Branches', '—', Icons.account_tree_outlined, _blue),
  WorkspaceMetric('Current', '—', Icons.check_circle_outline, _green)
];
const _remoteMetrics = [
  WorkspaceMetric('Remotes', '—', Icons.cloud_outlined, _blue),
  WorkspaceMetric('Tracking', '—', Icons.sync_outlined, _green)
];
const _forwardMetrics = [
  WorkspaceMetric('Forwards', '—', Icons.swap_horiz_outlined, _blue),
  WorkspaceMetric('Active', '—', Icons.play_circle_outline, _green)
];
const _connectionMetrics = [
  WorkspaceMetric('Connection', '—', Icons.link_outlined, _blue),
  WorkspaceMetric('Latency', '—', Icons.speed_outlined, _green)
];
const _guardianMetrics = [
  WorkspaceMetric('Workloads', '—', Icons.health_and_safety_outlined, _blue),
  WorkspaceMetric('Healthy', '—', Icons.check_circle_outline, _green),
  WorkspaceMetric('Restarting', '—', Icons.refresh_outlined, _amber)
];
const _logMetrics = [
  WorkspaceMetric('Log stream', '—', Icons.article_outlined, _blue),
  WorkspaceMetric('Warnings', '—', Icons.warning_amber_outlined, _amber)
];
const _packageMetrics = [
  WorkspaceMetric('Installed', '—', Icons.inventory_2_outlined, _blue),
  WorkspaceMetric('Updates', '—', Icons.system_update_outlined, _amber)
];
const _permissionMetrics = [
  WorkspaceMetric('Applications', '—', Icons.apps_outlined, _blue),
  WorkspaceMetric('Granted', '—', Icons.check_circle_outline, _green)
];
