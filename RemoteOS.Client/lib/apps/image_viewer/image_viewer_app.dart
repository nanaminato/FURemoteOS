// Image Viewer app shell (thin entry per AGENTS.md § 2).
//
// Resolves the RemoteFileApi via riverpod and composes the repository,
// ViewModel, and feature View.  Real business logic lives in the feature
// layer under features/image_viewer/.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/remoteos_api.dart';
import '../../features/files/data/remote_file_api.dart';
import '../../features/image_viewer/application/image_viewer_view_model.dart';
import '../../features/image_viewer/data/repositories/remote_image_repository.dart';
import '../../features/image_viewer/presentation/image_viewer_view.dart';

class ImageViewerApp extends ConsumerStatefulWidget {
  const ImageViewerApp({
    super.key,
    this.remotePath,
    this.fileName,
  });

  final String? remotePath;
  final String? fileName;

  @override
  ConsumerState<ImageViewerApp> createState() => _ImageViewerAppState();
}

class _ImageViewerAppState extends ConsumerState<ImageViewerApp> {
  ImageViewerViewModel? _vm;

  @override
  void initState() {
    super.initState();
    final files = RemoteFileApi(ref.read(remoteOsApiProvider));
    final repo = RemoteImageRepository(files);
    _vm = createImageViewerViewModel(
      repository: repo,
      fileName: widget.fileName,
      remotePath: widget.remotePath,
    );
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) {
      return const Center(child: Text('Unable to start image viewer.'));
    }
    return ImageViewerView(vm: vm);
  }
}
