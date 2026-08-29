// Image Viewer ViewModel.
//
// Toolbar actions (zoom + info) are modelled as Sync NoParam Commands to keep
// the toolbar buttons uniform.  Load is parameterised so it follows the same
// plain-async-method pattern used by the Docker ViewModel for 1-param ops.

import 'package:command_it/command_it.dart';
import 'package:flutter/widgets.dart';

import '../../../core/commands/base_view_model.dart';
import '../domain/image_repository.dart';
import '../domain/image_ui_state.dart';

/// Transient factory.  Uses the app-shell-provided repository.
ImageViewerViewModel createImageViewerViewModel({
  required ImageRepository repository,
  String? fileName,
  String? remotePath,
}) =>
    ImageViewerViewModel(
      repository: repository,
      initialFileName: fileName,
      initialRemotePath: remotePath,
    );

class ImageViewerViewModel extends ViewModel {
  ImageViewerViewModel({
    required ImageRepository repository,
    String? initialFileName,
    String? initialRemotePath,
  })  : _repository = repository,
        _pendingPath = initialRemotePath {
    state = ValueNotifier<ImageViewerUiState>(
      ImageViewerUiState.initial(fileName: initialFileName),
    );
    trackDisposable(state);
    trackDisposable(zoomInCommand);
    trackDisposable(zoomOutCommand);
    trackDisposable(zoomResetCommand);
    trackDisposable(toggleInfoCommand);
    trackDisposable(openCommand);
    trackDisposable(previousCommand);
    trackDisposable(nextCommand);
  }

  final ImageRepository _repository;
  final String? _pendingPath;

  late final ValueNotifier<ImageViewerUiState> state;

  ImageViewerUiState get _s => state.value;
  void _mutate(ImageViewerUiState Function(ImageViewerUiState s) fn) =>
      state.value = fn(state.value);

  /// Installed by the View because the Explorer picker is a window-owned
  /// modal and must not be created by this ViewModel.
  Future<String?> Function()? requestImagePath;

  // ---- Zoom & info toggles are pure UI actions, modelled as Commands so
  //      the toolbar buttons can stay uniform with the async load flow.

  late final zoomInCommand = Command.createSyncNoParamNoResult(
    () => _mutate((s) => s.copyWith(zoom: (s.zoom + 0.1).clamp(0.1, 5.0))),
  );

  late final zoomOutCommand = Command.createSyncNoParamNoResult(
    () => _mutate((s) => s.copyWith(zoom: (s.zoom - 0.1).clamp(0.1, 5.0))),
  );

  late final zoomResetCommand = Command.createSyncNoParamNoResult(
    () => _mutate((s) => s.copyWith(zoom: 1)),
  );

  late final toggleInfoCommand = Command.createSyncNoParamNoResult(
    () => _mutate((s) => s.copyWith(showInfo: !s.showInfo)),
  );

  late final openCommand = Command.createAsyncNoParamNoResult(open);
  late final previousCommand = Command.createAsyncNoParamNoResult(goPrevious);
  late final nextCommand = Command.createAsyncNoParamNoResult(goNext);

  // ---- Load: parameterised operation → plain async method (command_it v9.x
  //      does not expose a 1-param factory; gate via state instead).

  bool get isLoading => _s.isLoading;

  Future<void> open() async {
    final path = await requestImagePath?.call();
    if (path == null || path.isEmpty) return;
    await load(path);
  }

  Future<void> load(String path) async {
    if (isLoading) return;
    _mutate((s) => s.copyWith(isLoading: true, clearError: true));
    try {
      final bytes = await _repository.readBytes(path);
      final images = await _repository.listImages(_directoryOf(path));
      final imageIndex = images.indexWhere((image) => image.path == path);
      _mutate((s) => s.copyWith(
            imageBytes: bytes,
            isLoading: false,
            fileName: _fileNameOf(path),
            remotePath: path,
            directoryImages: images,
            imageIndex: imageIndex,
            zoom: 1,
          ));
    } catch (error) {
      debugPrint('Image viewer failed to load "$path": $error');
      _mutate((s) => s.copyWith(
            errorMessage: 'image_viewer.load_failed',
            isLoading: false,
          ));
    }
  }

  Future<void> goPrevious() => _navigateBy(-1);

  Future<void> goNext() => _navigateBy(1);

  Future<void> _navigateBy(int offset) async {
    final s = _s;
    if (s.isLoading) return;
    final nextIndex = s.imageIndex + offset;
    if (s.imageIndex < 0 ||
        nextIndex < 0 ||
        nextIndex >= s.directoryImages.length) {
      return;
    }
    await load(s.directoryImages[nextIndex].path);
  }

  /// Records zooming performed with touchpad or pointer gestures in the View.
  void setZoom(double zoom) =>
      _mutate((s) => s.copyWith(zoom: zoom.clamp(0.1, 5.0)));

  /// Invoked by the View once its build context is ready.  This avoids
  /// touching the build tree from initState which has no mounted guarantee.
  void scheduleInitialLoad() {
    final path = _pendingPath;
    if (path == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      load(path);
    });
  }

  static String _directoryOf(String path) {
    final slash = path.lastIndexOf('/');
    final backslash = path.lastIndexOf('\\');
    final separator = slash > backslash ? slash : backslash;
    if (separator < 0) return '';
    if (separator == 0) return path.substring(0, 1);
    // Preserve a Windows drive root (for example C:\\) rather than passing
    // the invalid path C: to the remote file API.
    if (separator == 2 && path.length > 1 && path[1] == ':') {
      return path.substring(0, 3);
    }
    return path.substring(0, separator);
  }

  static String _fileNameOf(String path) {
    final slash = path.lastIndexOf('/');
    final backslash = path.lastIndexOf('\\');
    final separator = slash > backslash ? slash : backslash;
    return separator < 0 ? path : path.substring(separator + 1);
  }
}
