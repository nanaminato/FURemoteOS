import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/apps/app_registry.dart';
import '../../core/network/remoteos_api.dart';
import '../../core/theme/theme_service.dart';
import '../../core/window_manager/modal_manager.dart';
import '../../core/window_manager/window_manager.dart';
import '../../features/docker/data/remote_docker_api.dart';
import '../explorer/explorer_app.dart';

/// Docker Manager, migrated from the Avalonia `DockerManagerWorkspace`.
/// All state and safe typed operations live in [_DockerVm]; the widget tree
/// only renders that state and opens the managed modal dialogs.
class DockerManagerApp extends ConsumerStatefulWidget {
  const DockerManagerApp({super.key});

  @override
  ConsumerState<DockerManagerApp> createState() => _DockerManagerAppState();
}

class _DockerManagerAppState extends ConsumerState<DockerManagerApp> {
  late final _DockerVm vm;
  int _pageIndex = 0;

  static const _navItems = [
    ('overview', Icons.dashboard_outlined, 'docker.overview'),
    ('containers', Icons.view_in_ar_outlined, 'docker.containers'),
    ('stacks', Icons.account_tree_outlined, 'docker.orchestration'),
    ('images', Icons.layers_outlined, 'docker.images'),
    ('networks', Icons.hub_outlined, 'docker.networks'),
    ('volumes', Icons.storage_outlined, 'docker.volumes'),
  ];

  @override
  void initState() {
    super.initState();
    vm = _DockerVm(RemoteDockerApi(ref.read(remoteOsApiProvider)));
    vm.showDockerUnavailable = _showDockerUnavailable;
    vm.showContainerDetails = _showContainerDetails;
    vm.showEditStack = _showEditStack;
    vm.requestDeletionConfirmation = _confirmDeletion;
    vm.openFileBrowserAtPath = _openExplorerAt;
    vm.start();
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  String get _ownerId => RemoteWindowScope.of(context).window.id;

  Future<void> _openDialog(String title, IconData icon, Size size,
          Widget child) =>
      ref.read(modalManagerProvider).open<void>(
          ownerId: _ownerId,
          spec: ModalSpec(
              title: title, icon: icon, preferredSize: size, child: child));

  Future<void> _showCreateContainer() => _openDialog('docker.container.create'.tr(),
      Icons.add_box_outlined, const Size(720, 690), _CreateContainerDialog(vm: vm));

  Future<void> _showDeployStack() => _openDialog('docker.stack.deploy'.tr(),
      Icons.account_tree_outlined, const Size(760, 550), _StackDialog(vm: vm));

  Future<void> _showEditStack(String name, String composeYaml) =>
      _openDialog('docker.stack.edit'.tr(), Icons.account_tree_outlined,
          const Size(760, 550),
          _StackDialog(vm: vm, initialName: name, initialYaml: composeYaml));

  Future<void> _showPullImage() => _openDialog('docker.image.pull'.tr(),
      Icons.download_outlined, const Size(470, 230), _PullImageDialog(vm: vm));

  Future<void> _showCreateNetwork() => _openDialog('common.create'.tr(),
      Icons.hub_outlined, const Size(470, 280), _CreateNetworkDialog(vm: vm));

  Future<void> _showCreateVolume() => _openDialog('common.create'.tr(),
      Icons.storage_outlined, const Size(470, 280), _CreateVolumeDialog(vm: vm));

  Future<void> _showDockerUnavailable() => _openDialog(
      'docker.unavailable_dialog.title'.tr(),
      Icons.warning_amber_outlined,
      const Size(460, 220),
      _DockerUnavailableDialog(vm: vm));

  Future<void> _showContainerDetails() => _openDialog(
      'docker.container.details'.tr(),
      Icons.info_outline,
      const Size(720, 620),
      _ContainerDetailsDialog(vm: vm));

  Future<bool> _confirmDeletion(String message) async {
    final confirmed = await ref.read(modalManagerProvider).open<bool>(
        ownerId: _ownerId,
        spec: ModalSpec(
            title: 'common.delete'.tr(),
            icon: Icons.warning_amber_outlined,
            preferredSize: const Size(430, 220),
            child: _ConfirmDeleteDialog(message: message)));
    return confirmed == true;
  }

  Future<void> _openExplorerAt(String path) async {
    final app = ref.read(appRegistryProvider).get('explorer');
    if (app == null) {
      vm.statusNote('docker.stack.explorer_unavailable'.tr());
      return;
    }
    ref.read(windowManagerProvider.notifier).openApp(
        entry: app,
        title: app.nameKey.tr(),
        child: ExplorerApp(initialPath: path));
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return AnimatedBuilder(
        animation: vm,
        builder: (context, _) => Column(children: [
              _WorkspaceHeader(vm: vm, palette: palette),
              if (vm.hasOperationActivity)
                _OperationActivity(vm: vm, palette: palette),
              Expanded(
                child: Row(children: [
                  SizedBox(
                      width: 190,
                      child: Container(
                          color: palette.surfaceSunken,
                          padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                    padding: const EdgeInsets.only(
                                        left: 10, bottom: 6),
                                    child: Text('docker.workspace'.tr(),
                                        style: TextStyle(
                                            color: palette.textTertiary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600))),
                                for (var index = 0;
                                    index < _navItems.length;
                                    index++)
                                  _NavItem(
                                      label: _navItems[index].$3.tr(),
                                      icon: _navItems[index].$2,
                                      selected: _pageIndex == index,
                                      palette: palette,
                                      onTap: () => setState(
                                          () => _pageIndex = index)),
                              ]))),
                  VerticalDivider(
                      width: 1, thickness: 1, color: palette.borderSubtle),
                  Expanded(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: switch (_navItems[_pageIndex].$1) {
                            'containers' => _ContainersPage(
                                vm: vm,
                                onCreate: _showCreateContainer,
                                palette: palette),
                            'stacks' => _StacksPage(
                                vm: vm,
                                onDeploy: _showDeployStack,
                                palette: palette),
                            'images' => _ImagesPage(
                                vm: vm,
                                onPull: _showPullImage,
                                palette: palette),
                            'networks' => _NetworksPage(
                                vm: vm,
                                onCreate: _showCreateNetwork,
                                palette: palette),
                            'volumes' => _VolumesPage(
                                vm: vm,
                                onCreate: _showCreateVolume,
                                palette: palette),
                            _ => _OverviewPage(vm: vm, palette: palette),
                          })),
                ]),
              ),
            ]));
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.palette,
      required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final ThemePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: selected ? palette.accentMuted : Colors.transparent,
                  borderRadius: BorderRadius.circular(5)),
              child: Row(children: [
                Icon(icon,
                    size: 17,
                    color:
                        selected ? palette.accent : palette.textSecondary),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: palette.textPrimary)))
              ]))));
}

/// Header mirroring the Avalonia workspace banner: icon, title, subtitle and
/// the engine status chip.
class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.vm, required this.palette});

  final _DockerVm vm;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
          color: palette.surfaceSunken,
          border: Border(bottom: BorderSide(color: palette.borderSubtle))),
      child: Row(children: [
        Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: palette.accent, borderRadius: BorderRadius.circular(14)),
            child: const Center(
                child: Text('🐳', style: TextStyle(fontSize: 25)))),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('app.docker_manager'.tr(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary)),
              Text('docker.subtitle'.tr(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: palette.textTertiary)),
            ])),
        const SizedBox(width: 16),
        Tooltip(
            message: 'docker.status.open_install_guide'.tr(),
            child: Material(
                color: palette.accentMuted,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                    // No Help Center app exists in this client; tapping mirrors
                    // the Avalonia activation failure path.
                    onTap: vm.isDockerInstallRequired
                        ? () => vm.statusNote(
                            'docker.status.install_guide_unavailable'.tr())
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.accent)),
                        constraints:
                            const BoxConstraints(maxWidth: 360),
                        child: Text(vm.statusText,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: palette.textPrimary)))))),
      ]));
}

/// The collapsible operation log strip below the header.
class _OperationActivity extends StatelessWidget {
  const _OperationActivity({required this.vm, required this.palette});

  final _DockerVm vm;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
          color: palette.accentMuted,
          border: Border(bottom: BorderSide(color: palette.borderStrong))),
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: palette.accentMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.borderStrong)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(vm.operationTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary))),
              if (vm.isOperationRunning)
                Text('docker.operation.running_label'.tr(),
                    style: TextStyle(color: palette.info, fontSize: 12)),
            ]),
            if (vm.isOperationRunning)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: palette.borderSubtle,
                      color: palette.accent)),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text('docker.operation.logs'.tr(),
                    style: TextStyle(fontSize: 13, color: palette.textSecondary)),
                children: [
                  Container(
                      constraints:
                          const BoxConstraints(minHeight: 88, maxHeight: 180),
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: palette.borderSubtle)),
                      child: SingleChildScrollView(
                          child: SelectableText(vm.operationLog.isEmpty ? ' ' : vm.operationLog,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: palette.textPrimary)))),
                ]),
          ])));
}

/// Card wrapper matching the Avalonia page surface.
class _PageCard extends StatelessWidget {
  const _PageCard({required this.palette, required this.child});

  final ThemePalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.borderSubtle)),
      child: child);
}

class _PageTitle extends StatelessWidget {
  const _PageTitle(
      {required this.text, required this.palette, this.trailing});

  final String text;
  final ThemePalette palette;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary))),
        if (trailing != null) ...trailing!,
      ]);
}

class _HintText extends StatelessWidget {
  const _HintText(this.text, this.palette);

  final String text;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: palette.textSecondary, height: 1.4));
}

/// Read-only bordered text block, the Avalonia read-only TextBox shape.
class _ReadOnlyBlock extends StatelessWidget {
  const _ReadOnlyBlock(
      {required this.text,
      required this.palette,
      this.minHeight = 32,
      this.maxHeight = 160,
      this.mono = false});

  final String text;
  final ThemePalette palette;
  final double minHeight;
  final double maxHeight;
  final bool mono;

  @override
  Widget build(BuildContext context) => Container(
      constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: palette.surfaceSunken,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: palette.borderSubtle)),
      child: SingleChildScrollView(
          child: SelectableText(text.isEmpty ? ' ' : text,
              style: TextStyle(
                  fontSize: mono ? 12 : 13,
                  fontFamily: mono ? 'monospace' : null,
                  color: palette.textPrimary))));
}

/// DataGrid equivalent: a horizontally scrollable single-selection table.
class _DockerTable<T> extends StatelessWidget {
  const _DockerTable(
      {required this.rows,
      required this.columns,
      required this.cell,
      required this.selected,
      required this.onSelected,
      required this.palette,
      this.minWidth = 700,
      this.height,
      this.onDoubleTap});

  final List<T> rows;
  final List<(String, double)> columns;
  final String Function(T, int) cell;
  final T? selected;
  final ValueChanged<T?> onSelected;
  final ThemePalette palette;
  final double minWidth;
  final double? height;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: height,
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: GestureDetector(
              onDoubleTap: selected == null ? null : onDoubleTap,
              child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minWidth),
                  child: DataTable(
                      headingRowColor:
                          WidgetStatePropertyAll(palette.surfaceSunken),
                      headingRowHeight: 34,
                      dataRowMinHeight: 34,
                      dataRowMaxHeight: 34,
                      columnSpacing: 18,
                      columns: [
                        for (var index = 0; index < columns.length; index++)
                          DataColumn(
                              label: SizedBox(
                                  width: columns[index].$2,
                                  child: Text(columns[index].$1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: palette.textSecondary))))
                      ],
                      rows: [
                        for (final row in rows)
                          DataRow(
                              selected: identical(row, selected),
                              onSelectChanged: (value) =>
                                  onSelected(value == true ? row : null),
                              cells: [
                                for (var index = 0;
                                    index < columns.length;
                                    index++)
                                  DataCell(SizedBox(
                                      width: columns[index].$2,
                                      child: Text(cell(row, index),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: palette.textPrimary))))
                              ])
                      ])))));
}

Widget _dangerButton(String label, ThemePalette palette, VoidCallback? onPressed,
        {double? width}) =>
    SizedBox(
        width: width,
        child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(foregroundColor: palette.danger),
            child: Text(label)));

/// Overview page: engine card, running containers, resource counts, safety hint.
class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.vm, required this.palette});

  final _DockerVm vm;
  final ThemePalette palette;

  Widget _card(Widget child) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.borderSubtle)),
      child: child);

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
              child: _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('docker.engine'.tr(),
                    style: TextStyle(
                        fontSize: 12, color: palette.textSecondary)),
                const SizedBox(height: 6),
                Text(vm.engineVersion,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary)),
                const SizedBox(height: 6),
                Text(vm.enginePlatform,
                    style: TextStyle(
                        fontSize: 13, color: palette.textSecondary)),
              ]))),
          const SizedBox(width: 18),
          Expanded(
              child: _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('docker.running_containers'.tr(),
                    style: TextStyle(
                        fontSize: 12, color: palette.textSecondary)),
                const SizedBox(height: 6),
                Text('${vm.runningContainerCount}',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary)),
                const SizedBox(height: 6),
                Text('docker.running_hint'.tr(),
                    style: TextStyle(
                        fontSize: 13, color: palette.textSecondary)),
              ]))),
        ]),
        const SizedBox(height: 18),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('docker.overview'.tr(),
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary)),
          const SizedBox(height: 12),
          _HintText('docker.overview_hint'.tr(), palette),
          const SizedBox(height: 16),
          Row(children: [
            _OverviewMetric('docker.containers'.tr(),
                '${vm.containers.length}', palette),
            _OverviewMetric('docker.stacks'.tr(), '${vm.stacks.length}', palette),
            _OverviewMetric('docker.images'.tr(), '${vm.images.length}', palette),
            _OverviewMetric(
                'docker.networks'.tr(), '${vm.networks.length}', palette),
            _OverviewMetric('docker.volumes'.tr(), '${vm.volumes.length}', palette),
          ]),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: vm.isLoading ? null : vm.refresh,
              child: Text('common.refresh'.tr())),
        ])),
        const SizedBox(height: 18),
        Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: palette.accentMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.borderStrong)),
            child: _HintText('docker.safety_hint'.tr(), palette)),
      ]);
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric(this.label, this.value, this.palette);

  final String label;
  final String value;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: palette.textSecondary)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary)),
      ]));
}

/// Containers page with lifecycle actions, logs and stats panels.
class _ContainersPage extends StatelessWidget {
  const _ContainersPage(
      {required this.vm, required this.onCreate, required this.palette});

  final _DockerVm vm;
  final VoidCallback onCreate;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final busy = vm.isLoading;
    final hasSelection = vm.selectedContainer != null && !busy;
    return _PageCard(
        palette: palette,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageTitle(
                  text: 'docker.containers'.tr(),
                  palette: palette,
                  trailing: [
                    OutlinedButton(
                        onPressed: busy ? null : vm.refresh,
                        child: Text('common.refresh'.tr())),
                  ]),
              const SizedBox(height: 12),
              _HintText('docker.containers_hint'.tr(), palette),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: onCreate, child: Text('docker.container.create'.tr())),
              const SizedBox(height: 12),
              Divider(height: 1, color: palette.borderSubtle),
              const SizedBox(height: 12),
              _DockerTable<DockerContainer>(
                  rows: vm.containers,
                  columns: const [
                    ('docker.table.name', 180),
                    ('docker.table.image', 210),
                    ('docker.table.status', 360),
                    ('docker.table.state', 120),
                  ],
                  cell: (item, index) => switch (index) {
                        0 => item.name,
                        1 => item.image,
                        2 => item.status,
                        _ => item.state
                      },
                  selected: vm.selectedContainer,
                  onSelected: vm.selectContainer,
                  palette: palette,
                  minWidth: 900,
                  height: 230,
                  onDoubleTap: vm.selectedContainer == null
                      ? null
                      : () => vm.loadContainerDetails()),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(
                    onPressed: hasSelection
                        ? () => vm.applyContainerAction('start')
                        : null,
                    child: Text('docker.action.start'.tr())),
                OutlinedButton(
                    onPressed: hasSelection
                        ? () => vm.applyContainerAction('stop')
                        : null,
                    child: Text('docker.action.stop'.tr())),
                OutlinedButton(
                    onPressed: hasSelection
                        ? () => vm.applyContainerAction('restart')
                        : null,
                    child: Text('docker.action.restart'.tr())),
                OutlinedButton(
                    onPressed: hasSelection
                        ? () => vm.applyContainerAction('pause')
                        : null,
                    child: Text('docker.action.pause'.tr())),
                OutlinedButton(
                    onPressed: hasSelection
                        ? () => vm.applyContainerAction('unpause')
                        : null,
                    child: Text('docker.action.unpause'.tr())),
                OutlinedButton(
                    onPressed: hasSelection ? vm.editContainer : null,
                    child: Text('docker.container.edit'.tr())),
                OutlinedButton(
                    onPressed: hasSelection ? vm.loadContainerLogs : null,
                    child: Text('docker.container.logs'.tr())),
                OutlinedButton(
                    onPressed: hasSelection ? vm.loadContainerStats : null,
                    child: Text('docker.container.stats'.tr())),
                _dangerButton('common.delete'.tr(), palette,
                    hasSelection ? vm.deleteContainer : null),
              ]),
              const SizedBox(height: 12),
              _ReadOnlyBlock(
                  text: vm.containerStats, palette: palette, minHeight: 32),
              const SizedBox(height: 8),
              _ReadOnlyBlock(
                  text: vm.containerLogs,
                  palette: palette,
                  minHeight: 140,
                  maxHeight: 140),
            ]));
  }
}

/// Compose orchestration page: projects, actions and services tables.
class _StacksPage extends StatelessWidget {
  const _StacksPage(
      {required this.vm, required this.onDeploy, required this.palette});

  final _DockerVm vm;
  final VoidCallback onDeploy;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final busy = vm.isLoading;
    final hasSelection = vm.selectedStack != null && !busy;
    return _PageCard(
        palette: palette,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageTitle(
                  text: 'docker.orchestration'.tr(),
                  palette: palette,
                  trailing: [
                    OutlinedButton(
                        onPressed: busy ? null : vm.refresh,
                        child: Text('common.refresh'.tr())),
                    const SizedBox(width: 8),
                    FilledButton(
                        onPressed: onDeploy,
                        child: Text('docker.stack.deploy'.tr())),
                  ]),
              const SizedBox(height: 12),
              _HintText('docker.orchestration_hint'.tr(), palette),
              const SizedBox(height: 12),
              Text('docker.stack.projects'.tr(),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary)),
              const SizedBox(height: 8),
              _DockerTable<DockerStack>(
                  rows: vm.stacks,
                  columns: const [
                    ('docker.table.name', 200),
                    ('docker.table.status', 250),
                    ('docker.table.config_files', 500),
                  ],
                  cell: (item, index) => switch (index) {
                        0 => item.name,
                        1 => item.status,
                        _ => item.configFiles
                      },
                  selected: vm.selectedStack,
                  onSelected: vm.selectStack,
                  palette: palette,
                  minWidth: 980),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(
                    onPressed: hasSelection
                        ? () => vm.applyStackAction('start')
                        : null,
                    child: Text('docker.action.start'.tr())),
                OutlinedButton(
                    onPressed: hasSelection
                        ? () => vm.applyStackAction('stop')
                        : null,
                    child: Text('docker.action.stop'.tr())),
                OutlinedButton(
                    onPressed: hasSelection
                        ? () => vm.applyStackAction('restart')
                        : null,
                    child: Text('docker.action.restart'.tr())),
                OutlinedButton(
                    onPressed: hasSelection ? vm.editStack : null,
                    child: Text('docker.stack.edit'.tr())),
                OutlinedButton(
                    onPressed:
                        hasSelection && vm.selectedStack!.configDirectory.isNotEmpty
                            ? vm.openStackSource
                            : null,
                    child: Text('docker.stack.open_source'.tr())),
                OutlinedButton(
                    onPressed: hasSelection ? vm.loadStackServices : null,
                    child: Text('docker.stack.refresh_services'.tr())),
                _dangerButton('common.delete'.tr(), palette,
                    hasSelection ? vm.deleteStack : null),
              ]),
              const SizedBox(height: 12),
              Text('docker.stack.services'.tr(),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary)),
              const SizedBox(height: 8),
              _DockerTable<DockerStackService>(
                  rows: vm.stackServices,
                  columns: const [
                    ('docker.table.service', 170),
                    ('docker.table.container', 230),
                    ('docker.table.image', 240),
                    ('docker.table.state', 130),
                    ('docker.table.status', 300),
                  ],
                  cell: (item, index) => switch (index) {
                        0 => item.service,
                        1 => item.container,
                        2 => item.image,
                        3 => item.state,
                        _ => item.status
                      },
                  selected: null,
                  onSelected: (_) {},
                  palette: palette,
                  minWidth: 1100),
            ]));
  }
}

/// Images page with pull and delete actions.
class _ImagesPage extends StatelessWidget {
  const _ImagesPage(
      {required this.vm, required this.onPull, required this.palette});

  final _DockerVm vm;
  final VoidCallback onPull;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => _PageCard(
      palette: palette,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('docker.images'.tr(),
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary)),
            const SizedBox(height: 12),
            _HintText('docker.images_hint'.tr(), palette),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: onPull, child: Text('docker.image.pull'.tr())),
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.borderSubtle),
            const SizedBox(height: 12),
            _DockerTable<DockerImage>(
                rows: vm.images,
                columns: const [
                  ('docker.table.repository', 300),
                  ('docker.table.tag', 160),
                  ('docker.table.size', 120),
                  ('docker.table.created', 200),
                ],
                cell: (item, index) => switch (index) {
                      0 => item.repository,
                      1 => item.tag,
                      2 => item.size,
                      _ => item.createdSince
                    },
                selected: vm.selectedImage,
                onSelected: vm.selectImage,
                palette: palette,
                minWidth: 800,
                height: 230),
            const SizedBox(height: 12),
            _dangerButton('docker.image.delete'.tr(), palette,
                vm.selectedImage != null && !vm.isLoading ? vm.deleteImage : null),
          ]));
}

/// Networks page with create and delete actions.
class _NetworksPage extends StatelessWidget {
  const _NetworksPage(
      {required this.vm, required this.onCreate, required this.palette});

  final _DockerVm vm;
  final VoidCallback onCreate;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => _PageCard(
      palette: palette,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('docker.networks'.tr(),
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary)),
            const SizedBox(height: 12),
            _HintText('docker.networks_hint'.tr(), palette),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: onCreate, child: Text('common.create'.tr())),
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.borderSubtle),
            const SizedBox(height: 12),
            _DockerTable<DockerNetwork>(
                rows: vm.networks,
                columns: const [
                  ('docker.table.name', 300),
                  ('docker.table.driver', 200),
                  ('docker.table.scope', 160),
                ],
                cell: (item, index) => switch (index) {
                      0 => item.name,
                      1 => item.driver,
                      _ => item.scope
                    },
                selected: vm.selectedNetwork,
                onSelected: vm.selectNetwork,
                palette: palette,
                minWidth: 700,
                height: 230),
            const SizedBox(height: 12),
            _dangerButton('common.delete'.tr(), palette,
                vm.selectedNetwork != null && !vm.isLoading ? vm.deleteNetwork : null),
          ]));
}

/// Volumes page with create and delete actions.
class _VolumesPage extends StatelessWidget {
  const _VolumesPage(
      {required this.vm, required this.onCreate, required this.palette});

  final _DockerVm vm;
  final VoidCallback onCreate;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => _PageCard(
      palette: palette,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('docker.volumes'.tr(),
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary)),
            const SizedBox(height: 12),
            _HintText('docker.volumes_hint'.tr(), palette),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: onCreate, child: Text('common.create'.tr())),
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.borderSubtle),
            const SizedBox(height: 12),
            _DockerTable<DockerVolume>(
                rows: vm.volumes,
                columns: const [
                  ('docker.table.name', 250),
                  ('docker.table.driver', 180),
                  ('docker.table.mount_point', 400),
                ],
                cell: (item, index) => switch (index) {
                      0 => item.name,
                      1 => item.driver,
                      _ => item.mountpoint
                    },
                selected: vm.selectedVolume,
                onSelected: vm.selectVolume,
                palette: palette,
                minWidth: 850,
                height: 230),
            const SizedBox(height: 12),
            _dangerButton('common.delete'.tr(), palette,
                vm.selectedVolume != null && !vm.isLoading ? vm.deleteVolume : null),
          ]));
}

/// ---------------------------------------------------------------------------
/// Dialogs (all owner-bound managed windows).
/// ---------------------------------------------------------------------------

class _DialogFooter extends ConsumerWidget {
  const _DialogFooter({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          actions[index],
        ],
      ]);
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text, this.palette);

  final String text;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 13, color: palette.textSecondary));
}

/// Create-container dialog (Avalonia `DockerContainerDialogView`).
class _CreateContainerDialog extends ConsumerStatefulWidget {
  const _CreateContainerDialog({required this.vm});

  final _DockerVm vm;

  @override
  ConsumerState<_CreateContainerDialog> createState() =>
      _CreateContainerDialogState();
}

class _CreateContainerDialogState
    extends ConsumerState<_CreateContainerDialog> {
  final name = TextEditingController();
  final image = TextEditingController();
  final ports = TextEditingController();
  final mounts = TextEditingController();
  final environment = TextEditingController();
  final arguments = TextEditingController();
  String network = 'bridge';
  String restartPolicy = 'unless-stopped';

  @override
  void initState() {
    super.initState();
    network = widget.vm.availableNetworks.contains('bridge')
        ? 'bridge'
        : widget.vm.availableNetworks.firstOrNull ?? 'bridge';
  }

  @override
  void dispose() {
    name.dispose();
    image.dispose();
    ports.dispose();
    mounts.dispose();
    environment.dispose();
    arguments.dispose();
    super.dispose();
  }

  List<String> _lines(TextEditingController value) => value.text
      .split('\n')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    final ok = await widget.vm.tryCreateContainer(
        name: name.text,
        image: image.text,
        arguments: _lines(arguments),
        ports: _lines(ports),
        environment: _lines(environment),
        mounts: _lines(mounts),
        network: network,
        restartPolicy: restartPolicy);
    if (ok && mounted) {
      ref.read(modalManagerProvider).complete(RemoteModalScope.of(context).windowId, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final valid =
        name.text.trim().isNotEmpty && image.text.trim().isNotEmpty;
    return AnimatedBuilder(
        animation: widget.vm,
        builder: (context, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Expanded(
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    _HintText('docker.containers_hint'.tr(), palette),
                    const SizedBox(height: 12),
                    _DialogLabel(
                        'docker.container.section.identity'.tr(), palette),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                          child: TextField(
                              controller: name,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                  labelText:
                                      'docker.container.name'.tr(),
                                  isDense: true))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: image,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                  hintText: 'nginx:latest',
                                  labelText:
                                      'docker.container.image'.tr(),
                                  isDense: true))),
                    ]),
                    const SizedBox(height: 12),
                    _DialogLabel(
                        'docker.container.section.runtime'.tr(), palette),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                          child: DropdownButtonFormField<String>(
                              value: widget.vm.availableNetworks
                                      .contains(network)
                                  ? network
                                  : widget.vm.availableNetworks.firstOrNull,
                              items: [
                                for (final value in widget.vm.availableNetworks)
                                  DropdownMenuItem(
                                      value: value, child: Text(value))
                              ],
                              onChanged: (value) =>
                                  setState(() => network = value ?? 'bridge'),
                              decoration: InputDecoration(
                                  labelText: 'docker.container.network'.tr(),
                                  isDense: true))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: DropdownButtonFormField<String>(
                              value: restartPolicy,
                              items: [
                                for (final value in _DockerVm.restartPolicies)
                                  DropdownMenuItem(
                                      value: value, child: Text(value))
                              ],
                              onChanged: (value) => setState(
                                  () => restartPolicy = value ?? 'no'),
                              decoration: InputDecoration(
                                  labelText:
                                      'docker.container.restart'.tr(),
                                  isDense: true))),
                    ]),
                    const SizedBox(height: 12),
                    _DialogLabel(
                        'docker.container.section.connectivity'.tr(),
                        palette),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                          child: TextField(
                              controller: ports,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                  hintText: '8080:80',
                                  labelText: 'docker.container.ports'.tr(),
                                  isDense: true))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: mounts,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                  hintText: 'volume:/data',
                                  labelText: 'docker.container.mounts'.tr(),
                                  isDense: true))),
                    ]),
                    const SizedBox(height: 12),
                    _DialogLabel(
                        'docker.container.section.configuration'.tr(),
                        palette),
                    const SizedBox(height: 6),
                    _DialogLabel('docker.container.environment'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: environment,
                        maxLines: 3,
                        decoration: InputDecoration(
                            hintText: 'KEY=value', isDense: true)),
                    const SizedBox(height: 10),
                    _DialogLabel('docker.container.arguments'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: arguments,
                        maxLines: 3,
                        decoration: const InputDecoration(isDense: true)),
                  ]))),
              const SizedBox(height: 12),
              _DialogFooter(actions: [
                OutlinedButton(
                    onPressed: () => ref
                        .read(modalManagerProvider)
                        .dismiss(RemoteModalScope.of(context).windowId),
                    child: Text('common.cancel'.tr())),
                FilledButton(
                    onPressed:
                        valid && !widget.vm.isLoading ? _submit : null,
                    child: Text('docker.container.create'.tr())),
              ]),
            ])));
  }
}

/// Rename-container dialog (Avalonia `DockerContainerEditDialogView`).
class _EditContainerDialog extends ConsumerStatefulWidget {
  const _EditContainerDialog({required this.vm, required this.container});

  final _DockerVm vm;
  final DockerContainer container;

  @override
  ConsumerState<_EditContainerDialog> createState() =>
      _EditContainerDialogState();
}

class _EditContainerDialogState extends ConsumerState<_EditContainerDialog> {
  late final name = TextEditingController(text: widget.container.name);

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.vm.tryUpdateContainer(widget.container, name.text);
    if (ok && mounted) {
      ref
          .read(modalManagerProvider)
          .complete(RemoteModalScope.of(context).windowId, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return AnimatedBuilder(
        animation: widget.vm,
        builder: (context, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Expanded(
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        _HintText('docker.container.edit_hint'.tr(), palette),
                        const SizedBox(height: 10),
                        _DialogLabel('docker.container.name'.tr(), palette),
                        const SizedBox(height: 4),
                        TextField(
                            controller: name,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(isDense: true)),
                        const SizedBox(height: 8),
                        _DialogLabel(widget.container.image, palette),
                      ]))),
              const SizedBox(height: 12),
              _DialogFooter(actions: [
                FilledButton(
                    onPressed: name.text.trim().isEmpty || widget.vm.isLoading
                        ? null
                        : _submit,
                    child: Text('docker.container.save'.tr())),
                OutlinedButton(
                    onPressed: () => ref
                        .read(modalManagerProvider)
                        .dismiss(RemoteModalScope.of(context).windowId),
                    child: Text('common.cancel'.tr())),
              ]),
            ])));
  }
}

/// Container details dialog (Avalonia `DockerContainerDetailsDialogView`).
class _ContainerDetailsDialog extends ConsumerWidget {
  const _ContainerDetailsDialog({required this.vm});

  final _DockerVm vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final details = vm.containerDetails;
    final windowId = RemoteModalScope.of(context).windowId;
    if (details == null) {
      return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Expanded(child: Center(child: _HintText('docker.not_found', palette))),
            _DialogFooter(actions: [
              OutlinedButton(
                  onPressed: () =>
                      ref.read(modalManagerProvider).dismiss(windowId),
                  child: Text('common.close'.tr())),
            ]),
          ]));
    }
    Widget field(String label, String value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogLabel(label, palette),
              const SizedBox(height: 2),
              _ReadOnlyBlock(text: value, palette: palette, minHeight: 30),
            ]);
    Widget section(String label, String value,
            {double minHeight = 44, bool mono = false}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: palette.textSecondary))),
          const SizedBox(height: 4),
          _ReadOnlyBlock(
              text: value,
              palette: palette,
              minHeight: minHeight,
              maxHeight: 210,
              mono: mono),
        ]);
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _HintText('docker.container.details_copy_hint'.tr(), palette),
          const SizedBox(height: 12),
          Expanded(
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    field('docker.container.name'.tr(), details.name),
                    const SizedBox(height: 6),
                    field('docker.container.id'.tr(), details.id),
                    const SizedBox(height: 6),
                    field('docker.container.image'.tr(), details.image),
                    const SizedBox(height: 6),
                    field('docker.table.state'.tr(), details.state),
                    const SizedBox(height: 6),
                    field('docker.table.status'.tr(), details.status),
                    const SizedBox(height: 6),
                    field('docker.container.created_at'.tr(), details.created),
                    const SizedBox(height: 6),
                    field('docker.container.restart'.tr(), details.restartPolicy),
                    const SizedBox(height: 6),
                    field('docker.container.working_directory'.tr(),
                        details.workingDirectory),
                    const SizedBox(height: 6),
                    field('docker.container.command'.tr(), details.command),
                    section('docker.container.ports'.tr(),
                        details.ports.join('\n')),
                    section('docker.container.networks'.tr(),
                        details.networks.join('\n')),
                    section('docker.container.mounts'.tr(),
                        details.mounts.join('\n'),
                        minHeight: 72),
                    section('docker.container.environment'.tr(),
                        details.environment.join('\n'),
                        minHeight: 92, mono: true),
                    section(
                        'docker.container.labels'.tr(),
                        details.labels.entries
                            .map((label) => '${label.key}=${label.value}')
                            .join('\n'),
                        minHeight: 92,
                        mono: true),
                  ]))),
          const SizedBox(height: 12),
          _DialogFooter(actions: [
            OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: vm.containerDetailsText));
                },
                child: Text('common.copy'.tr())),
            OutlinedButton(
                onPressed: () =>
                    ref.read(modalManagerProvider).dismiss(windowId),
                child: Text('common.close'.tr())),
          ]),
        ]));
  }
}

/// Compose stack deploy/edit dialog (Avalonia `DockerStackDialogView`).
class _StackDialog extends ConsumerStatefulWidget {
  const _StackDialog({required this.vm, this.initialName = '', this.initialYaml = ''});

  final _DockerVm vm;
  final String initialName;
  final String initialYaml;

  @override
  ConsumerState<_StackDialog> createState() => _StackDialogState();
}

class _StackDialogState extends ConsumerState<_StackDialog> {
  late final name = TextEditingController(text: widget.initialName);
  late final yaml = TextEditingController(text: widget.initialYaml);

  @override
  void dispose() {
    name.dispose();
    yaml.dispose();
    super.dispose();
  }

  Future<void> _submit(bool deploy) async {
    final ok = deploy
        ? await widget.vm
            .deployStack(name: name.text, composeYaml: yaml.text)
        : await widget.vm
            .validateStack(name: name.text, composeYaml: yaml.text);
    if (ok && deploy && mounted) {
      ref
          .read(modalManagerProvider)
          .complete(RemoteModalScope.of(context).windowId, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return AnimatedBuilder(
        animation: widget.vm,
        builder: (context, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _HintText('docker.stacks_hint'.tr(), palette),
                    const SizedBox(height: 12),
                    _DialogLabel('docker.stack.name'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: name,
                        decoration: const InputDecoration(
                            hintText: 'my-stack', isDense: true)),
                    const SizedBox(height: 12),
                    _DialogLabel('docker.stack.compose'.tr(), palette),
                    const SizedBox(height: 4),
                    Expanded(
                        child: TextField(
                            controller: yaml,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(fontFamily: 'monospace'),
                            decoration: const InputDecoration(
                                hintText:
                                    'services:\n  web:\n    image: nginx:latest',
                                isDense: true))),
                  ])),
              const SizedBox(height: 12),
              _DialogFooter(actions: [
                OutlinedButton(
                    onPressed: widget.vm.isLoading
                        ? null
                        : () => _submit(false),
                    child: Text('docker.stack.validate'.tr())),
                FilledButton(
                    onPressed: widget.vm.isLoading
                        ? null
                        : () => _submit(true),
                    child: Text('docker.stack.deploy'.tr())),
                OutlinedButton(
                    onPressed: () => ref
                        .read(modalManagerProvider)
                        .dismiss(RemoteModalScope.of(context).windowId),
                    child: Text('common.cancel'.tr())),
              ]),
            ])));
  }
}

/// Pull-image dialog (Avalonia `DockerPullImageDialogView`).
class _PullImageDialog extends ConsumerStatefulWidget {
  const _PullImageDialog({required this.vm});

  final _DockerVm vm;

  @override
  ConsumerState<_PullImageDialog> createState() => _PullImageDialogState();
}

class _PullImageDialogState extends ConsumerState<_PullImageDialog> {
  final reference = TextEditingController();

  @override
  void dispose() {
    reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.vm.pullImage(reference.text);
    if (ok && mounted) {
      ref
          .read(modalManagerProvider)
          .complete(RemoteModalScope.of(context).windowId, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return AnimatedBuilder(
        animation: widget.vm,
        builder: (context, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _DialogLabel('docker.image.reference'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: reference,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            hintText: 'nginx:latest', isDense: true)),
                  ])),
              const SizedBox(height: 16),
              _DialogFooter(actions: [
                OutlinedButton(
                    onPressed: () => ref
                        .read(modalManagerProvider)
                        .dismiss(RemoteModalScope.of(context).windowId),
                    child: Text('common.cancel'.tr())),
                FilledButton(
                    onPressed: reference.text.trim().isEmpty ||
                            widget.vm.isLoading
                        ? null
                        : _submit,
                    child: Text('docker.image.pull'.tr())),
              ]),
            ])));
  }
}

/// Create-network dialog (Avalonia `DockerNetworkDialogView`).
class _CreateNetworkDialog extends ConsumerStatefulWidget {
  const _CreateNetworkDialog({required this.vm});

  final _DockerVm vm;

  @override
  ConsumerState<_CreateNetworkDialog> createState() =>
      _CreateNetworkDialogState();
}

class _CreateNetworkDialogState extends ConsumerState<_CreateNetworkDialog> {
  final name = TextEditingController();
  String driver = 'bridge';

  Future<void> _submit() async {
    final ok = await widget.vm.tryCreateNetwork(name.text, driver);
    if (ok && mounted) {
      ref
          .read(modalManagerProvider)
          .complete(RemoteModalScope.of(context).windowId, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return AnimatedBuilder(
        animation: widget.vm,
        builder: (context, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _DialogLabel('common.name'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: name,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(isDense: true)),
                    const SizedBox(height: 12),
                    _DialogLabel('docker.network.driver'.tr(), palette),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                        value: driver,
                        items: [
                          for (final value in _DockerVm.networkDrivers)
                            DropdownMenuItem(value: value, child: Text(value))
                        ],
                        onChanged: (value) =>
                            setState(() => driver = value ?? 'bridge'),
                        decoration: const InputDecoration(isDense: true)),
                  ])),
              const SizedBox(height: 16),
              _DialogFooter(actions: [
                OutlinedButton(
                    onPressed: () => ref
                        .read(modalManagerProvider)
                        .dismiss(RemoteModalScope.of(context).windowId),
                    child: Text('common.cancel'.tr())),
                FilledButton(
                    onPressed: name.text.trim().isEmpty || widget.vm.isLoading
                        ? null
                        : _submit,
                    child: Text('common.create'.tr())),
              ]),
            ])));
  }
}

/// Create-volume dialog (Avalonia `DockerVolumeDialogView`).
class _CreateVolumeDialog extends ConsumerStatefulWidget {
  const _CreateVolumeDialog({required this.vm});

  final _DockerVm vm;

  @override
  ConsumerState<_CreateVolumeDialog> createState() =>
      _CreateVolumeDialogState();
}

class _CreateVolumeDialogState extends ConsumerState<_CreateVolumeDialog> {
  final name = TextEditingController();
  String driver = 'local';

  Future<void> _submit() async {
    final ok = await widget.vm.tryCreateVolume(name.text, driver);
    if (ok && mounted) {
      ref
          .read(modalManagerProvider)
          .complete(RemoteModalScope.of(context).windowId, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return AnimatedBuilder(
        animation: widget.vm,
        builder: (context, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _DialogLabel('common.name'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: name,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(isDense: true)),
                    const SizedBox(height: 12),
                    _DialogLabel('docker.volume.driver'.tr(), palette),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                        value: driver,
                        items: [
                          for (final value in _DockerVm.volumeDrivers)
                            DropdownMenuItem(value: value, child: Text(value))
                        ],
                        onChanged: (value) =>
                            setState(() => driver = value ?? 'local'),
                        decoration: const InputDecoration(isDense: true)),
                  ])),
              const SizedBox(height: 16),
              _DialogFooter(actions: [
                OutlinedButton(
                    onPressed: () => ref
                        .read(modalManagerProvider)
                        .dismiss(RemoteModalScope.of(context).windowId),
                    child: Text('common.cancel'.tr())),
                FilledButton(
                    onPressed: name.text.trim().isEmpty || widget.vm.isLoading
                        ? null
                        : _submit,
                    child: Text('common.create'.tr())),
              ]),
            ])));
  }
}

/// Docker-unavailable dialog with refresh and acknowledge actions.
class _DockerUnavailableDialog extends ConsumerWidget {
  const _DockerUnavailableDialog({required this.vm});

  final _DockerVm vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final windowId = RemoteModalScope.of(context).windowId;
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: _HintText('docker.unavailable_dialog.message'.tr(), palette))),
          const SizedBox(height: 16),
          _DialogFooter(actions: [
            OutlinedButton(
                onPressed: vm.isLoading ? null : vm.refresh,
                child: Text('common.refresh'.tr())),
            FilledButton(
                onPressed: () =>
                    ref.read(modalManagerProvider).dismiss(windowId),
                child: Text('common.ok'.tr())),
          ]),
        ]));
  }
}

/// Destructive-operation confirmation (Avalonia `ConfirmDialogView`).
class _ConfirmDeleteDialog extends ConsumerWidget {
  const _ConfirmDeleteDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final windowId = RemoteModalScope.of(context).windowId;
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(message,
                      style: TextStyle(color: palette.textPrimary)))),
          const SizedBox(height: 16),
          _DialogFooter(actions: [
            OutlinedButton(
                onPressed: () =>
                    ref.read(modalManagerProvider).dismiss(windowId),
                child: Text('common.cancel'.tr())),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: palette.danger,
                    foregroundColor: palette.textOnDanger),
                onPressed: () =>
                    ref.read(modalManagerProvider).complete(windowId, true),
                child: Text('common.delete'.tr())),
          ]),
        ]));
  }
}

/// ---------------------------------------------------------------------------
/// View model: state + safe typed Docker operations.
/// ---------------------------------------------------------------------------

class _DockerVm extends ChangeNotifier {
  _DockerVm(this.api);

  final RemoteDockerApi api;

  static const networkDrivers = ['bridge', 'ipvlan', 'macvlan', 'overlay'];
  static const volumeDrivers = ['local'];
  static const restartPolicies = ['no', 'always', 'unless-stopped', 'on-failure'];

  final containers = <DockerContainer>[];
  final images = <DockerImage>[];
  final networks = <DockerNetwork>[];
  final volumes = <DockerVolume>[];
  final stacks = <DockerStack>[];
  final stackServices = <DockerStackService>[];
  List<String> availableNetworks = ['bridge'];

  String statusText = 'docker.status.loading'.tr();
  bool isLoading = false;
  bool isOperationRunning = false;
  String operationTitle = '';
  String operationLog = '';
  bool isDockerAvailable = false;
  bool isDockerInstallRequired = false;
  String engineVersion = '—';
  String enginePlatform = '—';

  DockerContainer? selectedContainer;
  DockerContainerDetails? containerDetails;
  String containerDetailsText = '';
  String containerLogs = '';
  String containerStats = '';
  DockerStack? selectedStack;
  DockerImage? selectedImage;
  DockerNetwork? selectedNetwork;
  DockerVolume? selectedVolume;

  // Assigned by the app shell, mirroring the Avalonia VM hooks.
  Future<void> Function()? showDockerUnavailable;
  Future<void> Function()? showContainerDetails;
  Future<void> Function(String name, String composeYaml)? showEditStack;
  Future<bool> Function(String message)? requestDeletionConfirmation;
  Future<void> Function(String path)? openFileBrowserAtPath;

  bool _isUnavailableDialogShowing = false;

  int get runningContainerCount => containers
      .where((container) => container.state.toLowerCase() == 'running')
      .length;
  bool get hasOperationActivity => operationTitle.trim().isNotEmpty;

  void statusNote(String text) {
    statusText = text;
    notifyListeners();
  }

  Future<void> start() => refresh();

  Future<void> refresh() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        api.status(),
        api.containers(),
        api.images(),
        api.networks(),
        api.volumes(),
        api.stacks(),
      ]);
      final status = results[0] as DockerStatus;
      isDockerAvailable = status.available;
      isDockerInstallRequired =
          _isInstallRequired(status.available, status.problemCode);
      engineVersion = (status.version ?? '').isNotEmpty ? status.version! : '—';
      final platform = [
        status.operatingSystem ?? '',
        status.architecture ?? ''
      ].where((value) => value.isNotEmpty).join(' / ');
      enginePlatform = platform.isEmpty ? '—' : platform;
      statusText = status.available
          ? 'docker.status.available'
              .tr(args: [status.version ?? '', status.operatingSystem ?? ''])
          : 'docker.status.unavailable'.tr(args: [status.problemCode]);
      containers
        ..clear()
        ..addAll(results[1] as List<DockerContainer>);
      images
        ..clear()
        ..addAll(results[2] as List<DockerImage>);
      final networkValues = results[3] as List<DockerNetwork>;
      networks
        ..clear()
        ..addAll(networkValues);
      volumes
        ..clear()
        ..addAll(results[4] as List<DockerVolume>);
      stacks
        ..clear()
        ..addAll(results[5] as List<DockerStack>);
      final seen = <String>{};
      availableNetworks = ['bridge', ...networkValues.map((value) => value.name)]
          .where((value) => seen.add(value))
          .toList();
    } catch (error) {
      isDockerInstallRequired = false;
      statusText = 'docker.status.failed'.tr(args: ['$error']);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // -- selection ------------------------------------------------------------

  void selectContainer(DockerContainer? value) {
    selectedContainer = value;
    containerDetails = null;
    containerDetailsText = '';
    containerLogs = '';
    containerStats = '';
    notifyListeners();
  }

  void selectStack(DockerStack? value) {
    selectedStack = value;
    stackServices.clear();
    notifyListeners();
    if (value != null) loadStackServices();
  }

  void selectImage(DockerImage? value) {
    selectedImage = value;
    notifyListeners();
  }

  void selectNetwork(DockerNetwork? value) {
    selectedNetwork = value;
    notifyListeners();
  }

  void selectVolume(DockerVolume? value) {
    selectedVolume = value;
    notifyListeners();
  }

  // -- container operations --------------------------------------------------

  Future<bool> applyContainerAction(String action, {bool confirmed = false}) {
    final container = selectedContainer;
    if (container == null) return Future.value(false);
    return _runOperation(
        () => api.containerAction(container.id, action, confirmed: confirmed),
        (result) => result.success
            ? 'docker.action.succeeded'
                .tr(args: [_operationText(action), container.name])
            : 'docker.action.failed'
                .tr(args: [_operationText(action), _problemText(result.problemCode)]),
        operationName: 'docker.operation.container_action'
            .tr(args: [_operationText(action), container.name]));
  }

  Future<void> deleteContainer() async {
    final container = selectedContainer;
    if (container == null) return;
    final confirmed = await _confirmDeletion(
        'docker.container.delete_confirmation'.tr(args: [container.name]));
    if (!confirmed) return;
    await applyContainerAction('delete', confirmed: true);
  }

  Future<void> loadContainerLogs() async {
    final container = selectedContainer;
    if (container == null) return;
    await _runRead(() async {
      final logs = await api.containerLogs(container.id);
      containerLogs = logs == null ? '' : logs.lines.join('\n');
      _appendLog(logs?.lines);
      statusText = logs == null
          ? 'docker.action.failed'
              .tr(args: [_operationText('logs'), 'docker.not_found'])
          : 'docker.action.succeeded'
              .tr(args: [_operationText('logs'), container.name]);
    });
  }

  Future<void> loadContainerStats() async {
    final container = selectedContainer;
    if (container == null) return;
    await _runRead(() async {
      final stats = await api.containerStats(container.id);
      containerStats = stats == null
          ? ''
          : 'docker.stats.summary'.tr(
              args: [stats.cpu, stats.memory, stats.networkIo, stats.blockIo]);
      statusText = stats == null
          ? 'docker.action.failed'
              .tr(args: [_operationText('stats'), 'docker.not_found'])
          : 'docker.action.succeeded'
              .tr(args: [_operationText('stats'), container.name]);
    });
  }

  Future<void> loadContainerDetails() async {
    final container = selectedContainer;
    if (container == null) return;
    await _runRead(() async {
      containerDetails = await api.containerDetails(container.id);
      containerDetailsText = containerDetails == null
          ? ''
          : _formatContainerDetails(containerDetails!);
      statusText = containerDetails == null
          ? 'docker.action.failed'.tr(
              args: ['docker.container.details'.tr(), 'docker.not_found'])
          : 'docker.container.details_loaded'.tr(args: [container.name]);
    });
    if (containerDetails != null) await showContainerDetails?.call();
  }

  Future<void> editContainer() async {
    final container = selectedContainer;
    if (container == null) return;
    // Handled by the app shell: opens the rename dialog.
    await _editContainerHook?.call(container);
  }

  /// Set by the app shell to open the rename dialog for a container.
  Future<void> Function(DockerContainer container)? _editContainerHook;

  Future<bool> tryUpdateContainer(DockerContainer container, String name) async {
    if (isLoading) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == container.name) return true;
    return _runOperation(
        () => api.renameContainer(container.id, trimmed),
        (result) => result.success
            ? 'docker.container.updated'.tr(args: [trimmed])
            : 'docker.container.update_failed'
                .tr(args: [_problemText(result.problemCode)]),
        operationName:
            'docker.operation.update_container'.tr(args: [container.name]));
  }

  Future<bool> tryCreateContainer(
      {required String name,
      required String image,
      required List<String> arguments,
      required List<String> ports,
      required List<String> environment,
      required List<String> mounts,
      required String network,
      required String restartPolicy}) async {
    if (isLoading) return false;
    if (name.trim().isEmpty || image.trim().isEmpty) {
      statusNote('docker.container.required'.tr());
      return false;
    }
    final trimmed = name.trim();
    return _runOperation(
        () => api.createContainer(DockerContainerCreate(
            name: trimmed,
            image: image.trim(),
            arguments: arguments,
            ports: ports,
            environment: environment,
            mounts: mounts,
            network: network,
            restartPolicy: restartPolicy)),
        (result) => result.success
            ? 'docker.container.created'.tr(args: [trimmed])
            : 'docker.container.create_failed'
                .tr(args: [_problemText(result.problemCode)]),
        operationName: 'docker.operation.create_container'.tr(args: [trimmed]));
  }

  // -- stack operations ------------------------------------------------------

  Future<bool> validateStack(
      {required String name, required String composeYaml}) async {
    if (isLoading) return false;
    if (name.trim().isEmpty || composeYaml.trim().isEmpty) {
      statusNote('docker.stack.required'.tr());
      return false;
    }
    return _runStackOperation(
        () => api.validateStack(
            DockerStackDefinition(name: name.trim(), composeYaml: composeYaml)),
        name);
  }

  Future<bool> deployStack(
      {required String name, required String composeYaml}) async {
    if (isLoading) return false;
    if (name.trim().isEmpty || composeYaml.trim().isEmpty) {
      statusNote('docker.stack.required'.tr());
      return false;
    }
    return _runStackOperation(
        () => api.deployStack(
            DockerStackDefinition(name: name.trim(), composeYaml: composeYaml)),
        name);
  }

  Future<bool> _runStackOperation(
      Future<DockerStackOperationResult> Function() operation, String name) {
    return _runOperationRaw(
        operation,
        (result) {
          final detail =
              result.messages.isNotEmpty ? result.messages.first : result.problemCode;
          return result.success
              ? 'docker.stack.succeeded'
                  .tr(args: [_operationText('deploy'), name])
              : 'docker.stack.failed'
                  .tr(args: [_operationText('deploy'), _problemText(detail)]);
        },
        operationName: 'docker.operation.stack'
            .tr(args: [_operationText('deploy'), name]));
  }

  Future<bool> applyStackAction(String action, {bool confirmed = false}) {
    final stack = selectedStack;
    if (stack == null) return Future.value(false);
    return _runOperationRaw(
        () => api.stackAction(stack.name, action, confirmed: confirmed),
        (result) => result.success
            ? 'docker.stack.succeeded'
                .tr(args: [_operationText(action), stack.name])
            : 'docker.stack.failed'.tr(
                args: [_operationText(action), _problemText(result.problemCode)]),
        operationName:
            'docker.operation.stack'.tr(args: [_operationText(action), stack.name]));
  }

  Future<void> deleteStack() async {
    final stack = selectedStack;
    if (stack == null) return;
    final confirmed = await _confirmDeletion(
        'docker.stack.delete_confirmation'.tr(args: [stack.name]));
    if (!confirmed) return;
    await applyStackAction('delete', confirmed: true);
  }

  Future<void> loadStackServices() async {
    final stack = selectedStack;
    if (stack == null) return;
    await _runRead(() async {
      stackServices
        ..clear()
        ..addAll(await api.stackServices(stack.name));
      statusText =
          'docker.stack.services_loaded'.tr(args: [stack.name, '${stackServices.length}']);
    });
  }

  Future<void> editStack() async {
    final stack = selectedStack;
    if (stack == null) return;
    DockerStackDefinition? definition;
    await _runRead(() async {
      definition = await api.stackDefinition(stack.name);
      statusText = definition == null
          ? 'docker.stack.source_unavailable'.tr()
          : 'docker.stack.source_loaded'.tr(args: [stack.name]);
    });
    final value = definition;
    if (value == null) return;
    await showEditStack?.call(value.name, value.composeYaml);
  }

  Future<void> openStackSource() async {
    final stack = selectedStack;
    if (stack == null || stack.configDirectory.isEmpty) return;
    await openFileBrowserAtPath?.call(stack.configDirectory);
  }

  // -- image operations ------------------------------------------------------

  Future<bool> pullImage(String reference) async {
    if (isLoading) return false;
    if (reference.trim().isEmpty) {
      statusNote('docker.image.required'.tr());
      return false;
    }
    final trimmed = reference.trim();
    return _runOperation(
        () => api.pullImage(trimmed),
        (result) => result.success
            ? 'docker.image.pull_succeeded'.tr(args: [trimmed])
            : 'docker.image.pull_failed'
                .tr(args: [_problemText(result.problemCode)]),
        operationName: 'docker.operation.pull'.tr(args: [trimmed]));
  }

  Future<void> deleteImage() async {
    final image = selectedImage;
    if (image == null) return;
    final confirmed = await _confirmDeletion(
        'docker.image.delete_confirmation'.tr(args: [image.repository]));
    if (!confirmed) return;
    await _runOperation(
        () => api.deleteImage(image.id),
        (result) => result.success
            ? 'docker.image.deleted'.tr(args: [image.repository])
            : 'docker.image.delete_failed'
                .tr(args: [_problemText(result.problemCode)]),
        operationName:
            'docker.operation.delete_image'.tr(args: [image.repository]));
  }

  // -- network operations ----------------------------------------------------

  Future<bool> tryCreateNetwork(String name, String driver) async {
    if (isLoading) return false;
    if (name.trim().isEmpty) {
      statusNote('docker.network.required'.tr());
      return false;
    }
    final trimmed = name.trim();
    return _runOperation(
        () => api.createNetwork(trimmed, driver: driver),
        (result) => result.success
            ? 'docker.network.created'.tr(args: [trimmed])
            : 'docker.network.create_failed'
                .tr(args: [_problemText(result.problemCode)]),
        operationName: 'docker.operation.create_network'.tr(args: [trimmed]));
  }

  Future<void> deleteNetwork() async {
    final network = selectedNetwork;
    if (network == null) return;
    final confirmed = await _confirmDeletion(
        'docker.network.delete_confirmation'.tr(args: [network.name]));
    if (!confirmed) return;
    await _runOperation(
        () => api.deleteNetwork(network.id),
        (result) => result.success
            ? 'docker.network.deleted'.tr(args: [network.name])
            : 'docker.network.delete_failed'
                .tr(args: [_problemText(result.problemCode)]),
        operationName:
            'docker.operation.delete_network'.tr(args: [network.name]));
  }

  // -- volume operations -----------------------------------------------------

  Future<bool> tryCreateVolume(String name, String driver) async {
    if (isLoading) return false;
    if (name.trim().isEmpty) {
      statusNote('docker.volume.required'.tr());
      return false;
    }
    final trimmed = name.trim();
    return _runOperation(
        () => api.createVolume(trimmed, driver: driver),
        (result) => result.success
            ? 'docker.volume.created'.tr(args: [trimmed])
            : 'docker.volume.create_failed'
                .tr(args: [_problemText(result.problemCode)]),
        operationName: 'docker.operation.create_volume'.tr(args: [trimmed]));
  }

  Future<void> deleteVolume() async {
    final volume = selectedVolume;
    if (volume == null) return;
    final confirmed = await _confirmDeletion(
        'docker.volume.delete_confirmation'.tr(args: [volume.name]));
    if (!confirmed) return;
    await _runOperation(
        () => api.deleteVolume(volume.name),
        (result) => result.success
            ? 'docker.volume.deleted'.tr(args: [volume.name])
            : 'docker.volume.delete_failed'
                .tr(args: [_problemText(result.problemCode)]),
        operationName:
            'docker.operation.delete_volume'.tr(args: [volume.name]));
  }

  // -- operation plumbing -----------------------------------------------------

  Future<bool> _confirmDeletion(String message) async =>
      await requestDeletionConfirmation?.call(message) ?? false;

  Future<bool> _runOperation(
      Future<DockerOperationResult> Function() operation,
      String Function(DockerOperationResult) status,
      {String? operationName}) {
    return _runOperationRaw<DockerOperationResult>(operation, status,
        operationName: operationName);
  }

  Future<bool> _runOperationRaw<T extends Object>(
      Future<T> Function() operation,
      String Function(T) status,
      {String? operationName}) async {
    if (isLoading || !await _ensureDockerAvailable()) return false;
    isLoading = true;
    _beginOperation(operationName);
    try {
      final result = await operation();
      statusText = status(result);
      if (result is DockerOperationResult) _appendLog(result.logLines);
      if (result is DockerStackOperationResult) _appendLog(result.messages);
      _completeOperation(statusText);
      if (result is DockerOperationResult && !result.success) {
        await _showUnavailableForProblem(result.problemCode);
      } else if (result is DockerStackOperationResult && !result.success) {
        await _showUnavailableForProblem(result.problemCode);
      }
    } catch (error) {
      statusText = 'docker.status.failed'.tr(args: ['$error']);
      _appendLog(['$error']);
      _completeOperation(statusText);
      await _showUnavailableForException();
    } finally {
      isOperationRunning = false;
      isLoading = false;
      notifyListeners();
      await refresh();
    }
    return true;
  }

  Future<void> _runRead(Future<void> Function() operation) async {
    if (!await _ensureDockerAvailable()) return;
    isLoading = true;
    _beginOperation('docker.operation.reading'.tr());
    notifyListeners();
    try {
      await operation();
      _completeOperation(statusText);
    } catch (error) {
      statusText = 'docker.status.failed'.tr(args: ['$error']);
      _appendLog(['$error']);
      _completeOperation(statusText);
      await _showUnavailableForException();
    } finally {
      isOperationRunning = false;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _ensureDockerAvailable() async {
    if (isDockerAvailable) return true;
    statusText = 'docker.status.unavailable_operation'.tr();
    notifyListeners();
    await _showDockerUnavailableDialog();
    return false;
  }

  Future<void> _showUnavailableForProblem(String problemCode) async {
    if (problemCode != 'docker.unavailable' &&
        problemCode != 'docker.not_installed' &&
        problemCode != 'docker.api_incompatible') {
      return;
    }
    isDockerAvailable = false;
    isDockerInstallRequired = _isInstallRequired(false, problemCode);
    statusText = 'docker.status.unavailable'.tr(args: [problemCode]);
    notifyListeners();
    await _showDockerUnavailableDialog();
  }

  Future<void> _showUnavailableForException() async {
    try {
      final status = await api.status();
      if (status.available) return;
      isDockerAvailable = false;
      isDockerInstallRequired =
          _isInstallRequired(false, status.problemCode);
      statusText = 'docker.status.unavailable'.tr(args: [status.problemCode]);
    } catch (_) {
      isDockerAvailable = false;
      isDockerInstallRequired = false;
      statusText = 'docker.status.unavailable_operation'.tr();
    }
    notifyListeners();
    await _showDockerUnavailableDialog();
  }

  Future<void> _showDockerUnavailableDialog() async {
    if (_isUnavailableDialogShowing) return;
    _isUnavailableDialogShowing = true;
    try {
      await showDockerUnavailable?.call();
    } finally {
      _isUnavailableDialogShowing = false;
    }
  }

  void _beginOperation(String? operationName) {
    operationTitle = (operationName ?? '').trim().isEmpty
        ? 'docker.operation.running_label'.tr()
        : operationName!;
    operationLog = 'docker.operation.started'.tr(args: [operationTitle]);
    isOperationRunning = true;
    statusText = 'docker.operation.running'.tr(args: [operationTitle]);
    notifyListeners();
  }

  void _appendLog(List<String>? lines) {
    if (lines == null) return;
    final values =
        lines.where((line) => line.trim().isNotEmpty).toList();
    if (values.isEmpty) return;
    operationLog = [operationLog, ...values].join('\n');
  }

  void _completeOperation(String outcome) {
    operationLog = [operationLog, 'docker.operation.finished'.tr(args: [outcome])]
        .join('\n');
  }

  static bool _isInstallRequired(bool available, String problemCode) =>
      !available && problemCode.toLowerCase() == 'docker.not_installed';

  static String _operationText(String operation) => switch (operation) {
        'validate' => 'docker.stack.validate'.tr(),
        'deploy' => 'docker.stack.deploy'.tr(),
        'logs' => 'docker.container.logs'.tr(),
        'stats' => 'docker.container.stats'.tr(),
        'delete' => 'common.delete'.tr(),
        _ => 'docker.action.$operation'.tr(),
      };

  static String _problemText(String problemCode) => switch (problemCode) {
        'docker.operation_timeout' => 'docker.problem.timeout'.tr(),
        'docker.operation_failed' => 'docker.problem.failed'.tr(),
        'docker.stack_no_services' => 'docker.problem.stack_no_services'.tr(),
        'docker.stack_source_unavailable' =>
          'docker.stack.source_unavailable'.tr(),
        _ => problemCode,
      };

  static String _formatContainerDetails(DockerContainerDetails details) =>
      [
        'Name: ${details.name}',
        'ID: ${details.id}',
        'Image: ${details.image}',
        'State: ${details.state}',
        'Status: ${details.status}',
        'Created: ${details.created}',
        'Restart policy: ${details.restartPolicy}',
        'Working directory: ${details.workingDirectory}',
        'Command: ${details.command}',
        'Ports:\n${details.ports.join('\n')}',
        'Mounts:\n${details.mounts.join('\n')}',
        'Networks:\n${details.networks.join('\n')}',
        'Environment:\n${details.environment.join('\n')}',
        'Labels:\n${details.labels.entries.map((label) => '${label.key}=${label.value}').join('\n')}',
      ].join('\n');
}
