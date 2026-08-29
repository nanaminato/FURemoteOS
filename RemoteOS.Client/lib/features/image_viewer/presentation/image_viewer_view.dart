// Image Viewer main view.
//
// Composes the three chrome components (toolbar, canvas, inspector, status
// bar) and owns the Explorer modal binding used by the ViewModel's Open
// command.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../apps/explorer/explorer_picker.dart';
import '../../../core/theme/theme_service.dart';
import '../application/image_viewer_view_model.dart';
import '../domain/image_repository.dart';
import 'components/image_viewer_components.dart';

class ImageViewerView extends ConsumerStatefulWidget {
  const ImageViewerView({super.key, required this.vm});

  final ImageViewerViewModel vm;

  @override
  ConsumerState<ImageViewerView> createState() => _ImageViewerViewState();
}

class _ImageViewerViewState extends ConsumerState<ImageViewerView> {
  @override
  void initState() {
    super.initState();
    widget.vm.requestImagePath = _requestImagePath;
    widget.vm.scheduleInitialLoad();
  }

  @override
  void dispose() {
    widget.vm.requestImagePath = null;
    super.dispose();
  }

  Future<String?> _requestImagePath() => showRemoteFilePicker(
        ref,
        context,
        title: 'image_viewer.open_image'.tr(),
        filters: [
          ExplorerFileFilter(
            label: 'image_viewer.image_files'.tr(),
            patterns: [
              for (final extension in imageViewerExtensions) '*$extension',
            ],
          ),
          ExplorerFileFilter.allFiles,
        ],
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        ImageToolbar(vm: widget.vm),
        Expanded(
          child: Row(
            children: [
              Expanded(child: ImageCanvas(vm: widget.vm)),
              ListenableBuilder(
                listenable: widget.vm.state,
                builder: (context, _) {
                  if (!widget.vm.state.value.showInfo) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: palette.borderSubtle,
                      ),
                      ImageInspector(vm: widget.vm),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        ImageStatusBar(vm: widget.vm),
      ],
    );
  }
}
