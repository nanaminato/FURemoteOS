// Image Viewer main view.
//
// Composes the three chrome components (toolbar, canvas, inspector, status
// bar) and wires the ViewModel's initial load hook on first frame.

import 'package:flutter/material.dart';

import '../../../core/theme/theme_service.dart';
import '../application/image_viewer_view_model.dart';
import 'components/image_viewer_components.dart';

class ImageViewerView extends StatefulWidget {
  const ImageViewerView({super.key, required this.vm});

  final ImageViewerViewModel vm;

  @override
  State<ImageViewerView> createState() => _ImageViewerViewState();
}

class _ImageViewerViewState extends State<ImageViewerView> {
  @override
  void initState() {
    super.initState();
    widget.vm.scheduleInitialLoad();
  }

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
        const ImageStatusBar(label: 'No file selected'),
      ],
    );
  }
}
