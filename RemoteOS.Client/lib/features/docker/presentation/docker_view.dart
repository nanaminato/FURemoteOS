// Docker feature — main View (presentation layer).
//
// Owns layout, page switching and modal coordination. The View installs
// UI-side hooks into [DockerViewModel] so the VM can request dialogs
// without knowing Flutter APIs (AGENTS.md § 18 — no showDialog in VM).
//
// Pages and dialogs are extracted into dedicated files to keep this file
// focused on layout glue only (~200 lines target per AGENTS.md § 7).

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_injection.dart' as app_di;
import '../../../apps/explorer/explorer_app.dart';
import '../../../core/apps/app_registry.dart';
import '../../../core/theme/theme_service.dart';
import '../../../core/window_manager/modal_manager.dart';
import '../../../core/window_manager/window_manager.dart';
import '../application/docker_view_model.dart';
import '../data/remote_docker_api.dart';
import 'components/docker_components.dart';
import 'dialogs/docker_container_dialogs.dart';
import 'dialogs/docker_dialogs_shared.dart';
import 'dialogs/docker_resource_dialogs.dart';
import 'dialogs/docker_stack_dialogs.dart';
import 'pages/docker_containers_page.dart';
import 'pages/docker_images_page.dart';
import 'pages/docker_networks_volumes_page.dart';
import 'pages/docker_overview_page.dart';
import 'pages/docker_stacks_page.dart';

class DockerView extends ConsumerStatefulWidget {
  const DockerView({super.key, this.vm});

  /// Optional injected VM (tests or legacy callers may supply one).
  final DockerViewModel? vm;

  @override
  ConsumerState<DockerView> createState() => _DockerViewState();
}

class _DockerViewState extends ConsumerState<DockerView> {
  late final DockerViewModel _vm;
  int _pageIndex = 0;

  static const _navItems = [
    ('overview', Icons.dashboard_outlined, 'docker.overview'),
    ('containers', Icons.view_in_ar_outlined, 'docker.containers'),
    ('stacks', Icons.account_tree_outlined, 'docker.orchestration'),
    ('images', Icons.layers_outlined, 'docker.images'),
    ('networks', Icons.hub_outlined, 'docker.networks'),
    ('volumes', Icons.storage_outlined, 'docker.volumes'),
  ];

  String get _ownerId => RemoteWindowScope.of(context).window.id;

  @override
  void initState() {
    super.initState();
    _vm = widget.vm ?? app_di.di<DockerViewModel>();
    _installHooks();
    // ignore: discarded_futures
    _vm.start();
  }

  @override
  void dispose() {
    // If the caller injected a VM, the caller owns disposal.
    if (widget.vm == null) _vm.dispose();
    super.dispose();
  }

  void _installHooks() {
    _vm.onDockerUnavailable = _showDockerUnavailable;
    _vm.onContainerDetails = _showContainerDetails;
    _vm.onEditStack = _showEditStack;
    _vm.onConfirmDelete = _confirmDeletion;
    _vm.onOpenPath = _openExplorerAt;
    _vm.onEditContainer = _showEditContainer;
  }

  // ---- Dialog plumbing ---------------------------------------------------

  Future<void> _openDialog(
          String title, IconData icon, Size size, Widget child) =>
      ref.read(modalManagerProvider).open<void>(
          ownerId: _ownerId,
          spec: ModalSpec(
              title: title, icon: icon, preferredSize: size, child: child));

  Future<void> _showCreateContainer() => _openDialog(
      'docker.container.create'.tr(),
      Icons.add_box_outlined,
      const Size(720, 690),
      CreateContainerDialog(vm: _vm));

  Future<void> _showDeployStack() => _openDialog('docker.stack.deploy'.tr(),
      Icons.account_tree_outlined, const Size(760, 550), StackDialog(vm: _vm));

  Future<void> _showEditStack(String name, String composeYaml) => _openDialog(
      'docker.stack.edit'.tr(),
      Icons.account_tree_outlined,
      const Size(760, 550),
      StackDialog(vm: _vm, initialName: name, initialYaml: composeYaml));

  Future<void> _showPullImage() => _openDialog('docker.image.pull'.tr(),
      Icons.download_outlined, const Size(470, 230), PullImageDialog(vm: _vm));

  Future<void> _showCreateNetwork() => _openDialog('common.create'.tr(),
      Icons.hub_outlined, const Size(470, 280), CreateNetworkDialog(vm: _vm));

  Future<void> _showCreateVolume() => _openDialog(
      'common.create'.tr(),
      Icons.storage_outlined,
      const Size(470, 280),
      CreateVolumeDialog(vm: _vm));

  Future<void> _showDockerUnavailable() => _openDialog(
      'docker.unavailable_dialog.title'.tr(),
      Icons.warning_amber_outlined,
      const Size(460, 220),
      DockerUnavailableDialog(vm: _vm));

  Future<void> _showContainerDetails() => _openDialog(
      'docker.container.details'.tr(),
      Icons.info_outline,
      const Size(720, 620),
      ContainerDetailsDialog(vm: _vm));

  Future<void> _showEditContainer(DockerContainer container) => _openDialog(
      'docker.container.edit'.tr(),
      Icons.edit_outlined,
      const Size(460, 320),
      EditContainerDialog(vm: _vm, container: container));

  Future<bool> _confirmDeletion(String message) async {
    final confirmed = await ref.read(modalManagerProvider).open<bool>(
        ownerId: _ownerId,
        spec: ModalSpec(
            title: 'common.delete'.tr(),
            icon: Icons.warning_amber_outlined,
            preferredSize: const Size(430, 220),
            child: ConfirmDeleteDialog(message: message)));
    return confirmed == true;
  }

  Future<void> _openExplorerAt(String path) async {
    final app = ref.read(appRegistryProvider).get('explorer');
    if (app == null) {
      _vm.statusNote('docker.stack.explorer_unavailable'.tr());
      return;
    }
    ref.read(windowManagerProvider.notifier).openApp(
        entry: app,
        title: app.nameKey.tr(),
        child: ExplorerApp(initialPath: path));
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return ValueListenableBuilder(
        valueListenable: _vm.state,
        builder: (context, _, __) => Column(children: [
              WorkspaceHeader(vm: _vm, palette: palette),
              if (_vm.hasOperationActivity)
                OperationActivity(vm: _vm, palette: palette),
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
                                for (var i = 0; i < _navItems.length; i++)
                                  NavItem(
                                      label: _navItems[i].$3.tr(),
                                      icon: _navItems[i].$2,
                                      selected: _pageIndex == i,
                                      palette: palette,
                                      onTap: () =>
                                          setState(() => _pageIndex = i)),
                              ]))),
                  VerticalDivider(
                      width: 1, thickness: 1, color: palette.borderSubtle),
                  Expanded(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: switch (_navItems[_pageIndex].$1) {
                            'containers' => ContainersPage(
                                vm: _vm,
                                onCreate: _showCreateContainer,
                                palette: palette),
                            'stacks' => StacksPage(
                                vm: _vm,
                                onDeploy: _showDeployStack,
                                palette: palette),
                            'images' => ImagesPage(
                                vm: _vm,
                                onPull: _showPullImage,
                                palette: palette),
                            'networks' => NetworksPage(
                                vm: _vm,
                                onCreate: _showCreateNetwork,
                                palette: palette),
                            'volumes' => VolumesPage(
                                vm: _vm,
                                onCreate: _showCreateVolume,
                                palette: palette),
                            _ => OverviewPage(vm: _vm, palette: palette),
                          })),
                ]),
              ),
            ]));
  }
}
