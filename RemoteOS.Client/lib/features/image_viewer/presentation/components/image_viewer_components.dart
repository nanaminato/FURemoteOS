// Image Viewer feature components.
//
// Split by semantic role:
//   * [ImageToolbar] — top chrome with zoom + info toggle + navigation
//     (placeholder buttons until workspace activation lands).
//   * [ImageCanvas] — the dark viewer surface with InteractiveViewer body.
//   * [ImageInspector] — right-hand info column with file metadata rows.
//   * [ImageStatusBar] — bottom chrome with the current file label.

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
                onPressed: () {},
                tooltip: 'Open image',
                icon: const Icon(Icons.folder_open_outlined),
              ),
              IconButton(
                onPressed: () {},
                tooltip: 'Previous image',
                icon: const Icon(Icons.navigate_before_rounded),
              ),
              IconButton(
                onPressed: () {},
                tooltip: 'Next image',
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
                  tooltip: 'Zoom out',
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
                  tooltip: 'Zoom in',
                  icon: const Icon(Icons.zoom_in_rounded),
                ),
              ),
              ListenableBuilder(
                listenable: vm.zoomResetCommand,
                builder: (_, __) => TextButton(
                  onPressed: vm.zoomResetCommand.canRun.value
                      ? () => vm.zoomResetCommand()
                      : null,
                  child: const Text('Actual size'),
                ),
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: vm.toggleInfoCommand,
                builder: (_, __) => IconButton(
                  onPressed: vm.toggleInfoCommand.canRun.value
                      ? () => vm.toggleInfoCommand()
                      : null,
                  tooltip: 'Image information',
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

class ImageCanvas extends StatelessWidget {
  const ImageCanvas({super.key, required this.vm});
  final ImageViewerViewModel vm;

  static const _bg = Color(0xFF191919);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Center(child: _body()),
    );
  }

  Widget _body() {
    return ListenableBuilder(
      listenable: vm.state,
      builder: (context, _) {
        final s = vm.state.value;
        if (s.imageBytes != null) {
          return InteractiveViewer(
            minScale: 0.1,
            maxScale: 5,
            child: Image.memory(s.imageBytes!, fit: BoxFit.contain),
          );
        }
        if (s.errorMessage != null) {
          return Text(
            s.errorMessage!,
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
            const Text(
              'No image open',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 5),
            Text(
              'Open an image from File Explorer to view it here.',
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
                'IMAGE INFORMATION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                  color: palette.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              for (final item in [
                ('Name', s.fileName ?? '—'),
                ('Dimensions', '—'),
                ('Format', '—'),
                ('Size', '—'),
                ('Modified', '—'),
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
  const ImageStatusBar({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 26,
      color: palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: palette.textTertiary),
      ),
    );
  }
}
