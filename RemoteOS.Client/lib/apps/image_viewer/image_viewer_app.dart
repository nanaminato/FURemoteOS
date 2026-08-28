import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_service.dart';
import '../../features/files/data/remote_file_api.dart';
import '../../core/network/remoteos_api.dart';

/// Image Viewer window.  The toolbar and inspector are preserved from the
/// Avalonia app; file activation supplies the image bytes in a later file API
/// migration, and this empty state remains useful when launched directly.
class ImageViewerApp extends ConsumerStatefulWidget {
  const ImageViewerApp({super.key, this.remotePath, this.fileName});
  final String? remotePath;
  final String? fileName;

  @override
  ConsumerState<ImageViewerApp> createState() => _ImageViewerAppState();
}

class _ImageViewerAppState extends ConsumerState<ImageViewerApp> {
  double _zoom = 1;
  bool _showInfo = true;
  Uint8List? _imageBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.remotePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemoteImage());
    }
  }

  Future<void> _loadRemoteImage() async {
    try {
      final bytes = await RemoteFileApi(ref.read(remoteOsApiProvider))
          .readBytes(widget.remotePath!);
      if (mounted) setState(() => _imageBytes = Uint8List.fromList(bytes));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return Column(children: [
      Container(
          height: 46,
          color: palette.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton(
                onPressed: () {},
                tooltip: 'Open image',
                icon: const Icon(Icons.folder_open_outlined)),
            IconButton(
                onPressed: () {},
                tooltip: 'Previous image',
                icon: const Icon(Icons.navigate_before_rounded)),
            IconButton(
                onPressed: () {},
                tooltip: 'Next image',
                icon: const Icon(Icons.navigate_next_rounded)),
            Container(
                width: 1,
                height: 22,
                color: palette.borderSubtle,
                margin: const EdgeInsets.symmetric(horizontal: 5)),
            IconButton(
                onPressed: () =>
                    setState(() => _zoom = (_zoom - .1).clamp(.1, 5)),
                tooltip: 'Zoom out',
                icon: const Icon(Icons.zoom_out_rounded)),
            SizedBox(
                width: 52,
                child: Text('${(_zoom * 100).round()}%',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: palette.textPrimary))),
            IconButton(
                onPressed: () =>
                    setState(() => _zoom = (_zoom + .1).clamp(.1, 5)),
                tooltip: 'Zoom in',
                icon: const Icon(Icons.zoom_in_rounded)),
            TextButton(
                onPressed: () => setState(() => _zoom = 1),
                child: const Text('Actual size')),
            const Spacer(),
            IconButton(
                onPressed: () => setState(() => _showInfo = !_showInfo),
                tooltip: 'Image information',
                icon: Icon(Icons.info_outline_rounded,
                    color: _showInfo ? palette.accent : palette.textSecondary)),
          ])),
      Expanded(
          child: Row(children: [
        Expanded(
            child: Container(
                color: const Color(0xFF191919),
                child: Center(child: _imageBody()))),
        if (_showInfo)
          VerticalDivider(width: 1, thickness: 1, color: palette.borderSubtle),
        if (_showInfo) SizedBox(width: 220, child: _inspector(palette)),
      ])),
      Container(
          height: 26,
          color: palette.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Text('No file selected',
              style: TextStyle(fontSize: 11, color: palette.textTertiary))),
    ]);
  }

  Widget _inspector(ThemePalette palette) => Container(
      color: palette.surface,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('IMAGE INFORMATION',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
                color: palette.textTertiary)),
        const SizedBox(height: 16),
        for (final item in [
          ('Name', widget.fileName ?? '—'),
          ('Dimensions', '—'),
          ('Format', '—'),
          ('Size', '—'),
          ('Modified', '—')
        ])
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1,
                        style: TextStyle(
                            fontSize: 11, color: palette.textTertiary)),
                    const SizedBox(height: 2),
                    Text(item.$2,
                        style:
                            TextStyle(fontSize: 13, color: palette.textPrimary))
                  ])),
      ]));

  Widget _imageBody() {
    if (_imageBytes != null) {
      return InteractiveViewer(
          minScale: .1,
          maxScale: 5,
          child: Image.memory(_imageBytes!, fit: BoxFit.contain));
    }
    if (_error != null) {
      return Text(_error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white));
    }
    if (widget.remotePath != null) {
      return const CircularProgressIndicator();
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.image_outlined,
          size: 64, color: Colors.white.withOpacity(.45)),
      const SizedBox(height: 14),
      const Text('No image open',
          style: TextStyle(fontSize: 16, color: Colors.white)),
      const SizedBox(height: 5),
      Text('Open an image from File Explorer to view it here.',
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.55))),
    ]);
  }
}
