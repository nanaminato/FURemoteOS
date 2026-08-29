// Docker feature — overview page (presentation).
//
// Engine status card, running containers and aggregate resource metrics.
// Mirrors the Avalonia `DockerManagerWorkspace` Overview tab.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/docker_view_model.dart';
import '../components/docker_components.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.vm,
    required this.palette,
  });

  final DockerViewModel vm;
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
          HintText('docker.overview_hint'.tr(), palette),
          const SizedBox(height: 16),
          Row(children: [
            OverviewMetric(
                'docker.containers'.tr(), '${vm.containers.length}', palette),
            OverviewMetric(
                'docker.stacks'.tr(), '${vm.stacks.length}', palette),
            OverviewMetric(
                'docker.images'.tr(), '${vm.images.length}', palette),
            OverviewMetric(
                'docker.networks'.tr(), '${vm.networks.length}', palette),
            OverviewMetric(
                'docker.volumes'.tr(), '${vm.volumes.length}', palette),
          ]),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: vm.isLoading ? null : () => vm.refresh(),
              child: Text('common.refresh'.tr())),
        ])),
        const SizedBox(height: 18),
        Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: palette.accentMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.borderStrong)),
            child: HintText('docker.safety_hint'.tr(), palette)),
      ]);
}
