// Docker feature — containers page (presentation).
//
// Container table, lifecycle action buttons, logs and stats panels.
// Mirrors the Avalonia `DockerManagerWorkspace` Containers tab.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/docker_view_model.dart';
import '../../data/remote_docker_api.dart';
import '../components/docker_components.dart';

class ContainersPage extends StatelessWidget {
  const ContainersPage({
    super.key,
    required this.vm,
    required this.onCreate,
    required this.palette,
  });

  final DockerViewModel vm;
  final VoidCallback onCreate;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final busy = vm.isLoading;
    final hasSelection = vm.selectedContainer != null && !busy;
    return PageCard(
        palette: palette,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PageTitle(
              text: 'docker.containers'.tr(),
              palette: palette,
              trailing: [
                OutlinedButton(
                    onPressed: busy ? null : () => vm.refresh(),
                    child: Text('common.refresh'.tr())),
              ]),
          const SizedBox(height: 12),
          HintText('docker.containers_hint'.tr(), palette),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: onCreate, child: Text('docker.container.create'.tr())),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.borderSubtle),
          const SizedBox(height: 12),
          DockerTable<DockerContainer>(
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
                onPressed:
                    hasSelection ? () => vm.applyContainerAction('stop') : null,
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
            dangerButton('common.delete'.tr(), palette,
                hasSelection ? vm.deleteContainer : null),
          ]),
          const SizedBox(height: 12),
          ReadOnlyBlock(
              text: vm.containerStats, palette: palette, minHeight: 32),
          const SizedBox(height: 8),
          ReadOnlyBlock(
              text: vm.containerLogs,
              palette: palette,
              minHeight: 140,
              maxHeight: 140),
        ]));
  }
}
