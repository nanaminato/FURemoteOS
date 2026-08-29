// Image Viewer ViewModel.
//
// Toolbar actions (zoom + info) are modelled as Sync NoParam Commands to keep
// the toolbar buttons uniform.  Load is parameterised so it follows the same
// plain-async-method pattern used by the Docker ViewModel for 1-param ops.

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
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
  }

  final ImageRepository _repository;
  final String? _pendingPath;

  late final ValueNotifier<ImageViewerUiState> state;

  ImageViewerUiState get _s => state.value;
  void _mutate(ImageViewerUiState Function(ImageViewerUiState s) fn) =>
      state.value = fn(state.value);

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

  // ---- Load: parameterised operation → plain async method (command_it v9.x
  //      does not expose a 1-param factory; gate via state instead).

  bool get isLoading => _s.isLoading;

  Future<void> load(String path) async {
    if (isLoading) return;
    _mutate((s) => s.copyWith(isLoading: true, clearError: true));
    try {
      final bytes = await _repository.readBytes(path);
      _mutate((s) => s.copyWith(
            imageBytes: bytes,
            isLoading: false,
          ));
    } catch (error) {
      _mutate((s) => s.copyWith(
            errorMessage: '$error',
            isLoading: false,
          ));
    }
  }

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
}
