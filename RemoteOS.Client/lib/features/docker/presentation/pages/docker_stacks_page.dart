// Docker feature — stacks page (presentation).
//
// Compose projects table, orchestration actions and services table.
// Mirrors the Avalonia `DockerManagerWorkspace` Stacks tab.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/docker_view_model.dart';
import '../../data/remote_docker_api.dart';
import '../components/docker_components.dart';

class StacksPage extends StatelessWidget {
  const StacksPage({
    super.key,
    required this.vm,
    required this.onDeploy,
    required this.palette,
  });

  final DockerViewModel vm;
  final VoidCallback onDeploy;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final busy = vm.isLoading;
    final hasSelection = vm.selectedStack != null && !busy;
    return PageCard(
        palette: palette,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PageTitle(
              text: 'docker.orchestration'.tr(),
              palette: palette,
              trailing: [
                OutlinedButton(
                    onPressed: busy ? null : () => vm.refresh(),
                    child: Text('common.refresh'.tr())),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: onDeploy,
                    child: Text('docker.stack.deploy'.tr())),
              ]),
          const SizedBox(height: 12),
          HintText('docker.orchestration_hint'.tr(), palette),
          const SizedBox(height: 12),
          Text('docker.stack.projects'.tr(),
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: palette.textSecondary)),
          const SizedBox(height: 8),
          DockerTable<DockerStack>(
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
                onPressed:
                    hasSelection ? () => vm.applyStackAction('start') : null,
                child: Text('docker.action.start'.tr())),
            OutlinedButton(
                onPressed:
                    hasSelection ? () => vm.applyStackAction('stop') : null,
                child: Text('docker.action.stop'.tr())),
            OutlinedButton(
                onPressed:
                    hasSelection ? () => vm.applyStackAction('restart') : null,
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
            dangerButton('common.delete'.tr(), palette,
                hasSelection ? vm.deleteStack : null),
          ]),
          const SizedBox(height: 12),
          Text('docker.stack.services'.tr(),
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: palette.textSecondary)),
          const SizedBox(height: 8),
          DockerTable<DockerStackService>(
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
