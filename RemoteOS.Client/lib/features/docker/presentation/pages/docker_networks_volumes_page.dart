// Docker feature — networks + volumes pages (presentation).
//
// Both pages are small so they share one file (AGENTS.md § 7 — small
// semantically-related widgets may share a file).
// Mirrors the Avalonia `DockerManagerWorkspace` Networks/Volumes tabs.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/docker_view_model.dart';
import '../../data/remote_docker_api.dart';
import '../components/docker_components.dart';

class NetworksPage extends StatelessWidget {
  const NetworksPage({
    super.key,
    required this.vm,
    required this.onCreate,
    required this.palette,
  });

  final DockerViewModel vm;
  final VoidCallback onCreate;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => PageCard(
      palette: palette,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('docker.networks'.tr(),
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary)),
        const SizedBox(height: 12),
        HintText('docker.networks_hint'.tr(), palette),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: onCreate, child: Text('common.create'.tr())),
        const SizedBox(height: 12),
        Divider(height: 1, color: palette.borderSubtle),
        const SizedBox(height: 12),
        DockerTable<DockerNetwork>(
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
        dangerButton(
            'common.delete'.tr(),
            palette,
            vm.selectedNetwork != null && !vm.isLoading
                ? vm.deleteNetwork
                : null),
      ]));
}

class VolumesPage extends StatelessWidget {
  const VolumesPage({
    super.key,
    required this.vm,
    required this.onCreate,
    required this.palette,
  });

  final DockerViewModel vm;
  final VoidCallback onCreate;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => PageCard(
      palette: palette,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('docker.volumes'.tr(),
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary)),
        const SizedBox(height: 12),
        HintText('docker.volumes_hint'.tr(), palette),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: onCreate, child: Text('common.create'.tr())),
        const SizedBox(height: 12),
        Divider(height: 1, color: palette.borderSubtle),
        const SizedBox(height: 12),
        DockerTable<DockerVolume>(
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
        dangerButton(
            'common.delete'.tr(),
            palette,
            vm.selectedVolume != null && !vm.isLoading
                ? vm.deleteVolume
                : null),
      ]));
}
