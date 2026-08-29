// Image Viewer feature components.
//
// Split by semantic role:
//   * [ImageToolbar] — top chrome with file, zoom, info and navigation actions.
//   * [ImageCanvas] — the dark viewer surface with InteractiveViewer body.
//   * [ImageInspector] — right-hand info column with file metadata rows.
//   * [ImageStatusBar] — bottom chrome with the current file label.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/image_viewer_view_model.dart';

class ImageToolbar extends StatelessWidget {
  const ImageToolbar({super.key, required this.vm});
  final ImageViewerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: vm.state,
      builder: (context, _) {
        final s = vm.state.value;
        return Container(
          height: 46,
          color: palette.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: s.isLoading ? null : () => vm.openCommand.runAsync(),
                tooltip: 'image_viewer.open_image'.tr(),
                icon: const Icon(Icons.folder_open_outlined),
              ),
              IconButton(
                onPressed: s.isLoading || !s.canGoPrevious
                    ? null
                    : () => vm.previousCommand.runAsync(),
                tooltip: 'image_viewer.previous_image'.tr(),
                icon: const Icon(Icons.navigate_before_rounded),
              ),
              IconButton(
                onPressed: s.isLoading || !s.canGoNext
                    ? null
                    : () => vm.nextCommand.runAsync(),
                tooltip: 'image_viewer.next_image'.tr(),
                icon: const Icon(Icons.navigate_next_rounded),
              ),
              Container(
                width: 1,
                height: 22,
                color: palette.borderSubtle,
                margin: const EdgeInsets.symmetric(horizontal: 5),
              ),
              ListenableBuilder(
                listenable: vm.zoomOutCommand,
                builder: (_, __) => IconButton(
                  onPressed: vm.zoomOutCommand.canRun.value
                      ? () => vm.zoomOutCommand()
                      : null,
                  tooltip: 'image_viewer.zoom_out'.tr(),
                  icon: const Icon(Icons.zoom_out_rounded),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  s.zoomPercent,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: vm.zoomInCommand,
                builder: (_, __) => IconButton(
                  onPressed: vm.zoomInCommand.canRun.value
                      ? () => vm.zoomInCommand()
                      : null,
                  tooltip: 'image_viewer.zoom_in'.tr(),
                  icon: const Icon(Icons.zoom_in_rounded),
                ),
              ),
              ListenableBuilder(
                listenable: vm.zoomResetCommand,
                builder: (_, __) => TextButton(
                  onPressed: vm.zoomResetCommand.canRun.value
                      ? () => vm.zoomResetCommand()
                      : null,
                  child: Text('image_viewer.actual_size'.tr()),
                ),
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: vm.toggleInfoCommand,
                builder: (_, __) => IconButton(
                  onPressed: vm.toggleInfoCommand.canRun.value
                      ? () => vm.toggleInfoCommand()
                      : null,
                  tooltip: 'image_viewer.image_information'.tr(),
                  icon: Icon(
                    Icons.info_outline_rounded,
                    color: s.showInfo ? palette.accent : palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ImageCanvas extends StatefulWidget {
  const ImageCanvas({super.key, required this.vm});
  final ImageViewerViewModel vm;

  @override
  State<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends State<ImageCanvas> {
  static const _bg = Color(0xFF191919);
  final _transformationController = TransformationController();
  double _appliedZoom = 1;
  String? _displayedPath;

  ImageViewerViewModel get _vm => widget.vm;

  @override
  void initState() {
    super.initState();
    _vm.state.addListener(_applyState);
  }

  @override
  void dispose() {
    _vm.state.removeListener(_applyState);
    _transformationController.dispose();
    super.dispose();
  }

  void _applyState() {
    final state = _vm.state.value;
    if (state.remotePath != _displayedPath) {
      _displayedPath = state.remotePath;
      _appliedZoom = 1;
      _transformationController.value = Matrix4.identity();
    }
    if (state.zoom == _appliedZoom) return;
    _appliedZoom = state.zoom;
    _transformationController.value = Matrix4.diagonal3Values(
      state.zoom,
      state.zoom,
      1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Center(child: _body()),
    );
  }

  Widget _body() {
    return ListenableBuilder(
      listenable: _vm.state,
      builder: (context, _) {
        final s = _vm.state.value;
        if (s.imageBytes != null) {
          return LayoutBuilder(
            builder: (context, constraints) => InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.1,
              maxScale: 5,
              onInteractionEnd: (_) {
                final zoom =
                    _transformationController.value.getMaxScaleOnAxis();
                _appliedZoom = zoom;
                _vm.setZoom(zoom);
              },
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Image.memory(
                  s.imageBytes!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      'image_viewer.load_failed'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (s.errorMessage != null) {
          return Text(
            s.errorMessage!.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          );
        }
        if (s.isLoading) {
          return const CircularProgressIndicator();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: .45),
            ),
            const SizedBox(height: 14),
            Text(
              'image_viewer.no_image_open'.tr(),
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 5),
            Text(
              'image_viewer.open_image_prompt'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: .55),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ImageInspector extends StatelessWidget {
  const ImageInspector({super.key, required this.vm});
  final ImageViewerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: vm.state,
      builder: (context, _) {
        final s = vm.state.value;
        return Container(
          width: 220,
          color: palette.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'image_viewer.image_information'.tr().toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                  color: palette.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              for (final item in [
                ('image_viewer.name'.tr(), s.fileName ?? '—'),
                ('image_viewer.dimensions'.tr(), '—'),
                ('image_viewer.format'.tr(), '—'),
                ('image_viewer.size'.tr(), '—'),
                ('image_viewer.modified'.tr(), '—'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                )
            ],
          ),
        );
      },
    );
  }
}

class ImageStatusBar extends StatelessWidget {
  const ImageStatusBar({super.key, required this.vm});
  final ImageViewerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: vm.state,
      builder: (context, _) {
        final state = vm.state.value;
        return Container(
          height: 26,
          color: palette.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Text(
            state.fileName ?? 'image_viewer.no_file_selected'.tr(),
            style: TextStyle(fontSize: 11, color: palette.textTertiary),
          ),
        );
      },
    );
  }
}
