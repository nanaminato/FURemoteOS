// Docker feature — images page (presentation).
//
// Image list, pull action and deletion.
// Mirrors the Avalonia `DockerManagerWorkspace` Images tab.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/docker_view_model.dart';
import '../../data/remote_docker_api.dart';
import '../components/docker_components.dart';

class ImagesPage extends StatelessWidget {
  const ImagesPage({
    super.key,
    required this.vm,
    required this.onPull,
    required this.palette,
  });

  final DockerViewModel vm;
  final VoidCallback onPull;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => PageCard(
      palette: palette,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('docker.images'.tr(),
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary)),
        const SizedBox(height: 12),
        HintText('docker.images_hint'.tr(), palette),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: onPull, child: Text('docker.image.pull'.tr())),
        const SizedBox(height: 12),
        Divider(height: 1, color: palette.borderSubtle),
        const SizedBox(height: 12),
        DockerTable<DockerImage>(
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
        dangerButton('docker.image.delete'.tr(), palette,
            vm.selectedImage != null && !vm.isLoading ? vm.deleteImage : null),
      ]));
}
