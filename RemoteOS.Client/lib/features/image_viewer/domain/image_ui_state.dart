// Image Viewer UI state.
//
// Contains canvas state (zoom, inspector toggle, loaded bytes, errors) plus
// metadata strings for the right-hand info column.

import 'package:flutter/foundation.dart';

@immutable
class ImageViewerUiState {
  const ImageViewerUiState({
    required this.zoom,
    required this.showInfo,
    required this.imageBytes,
    required this.errorMessage,
    required this.fileName,
    required this.isLoading,
  });

  factory ImageViewerUiState.initial({String? fileName}) => ImageViewerUiState(
        zoom: 1,
        showInfo: true,
        imageBytes: null,
        errorMessage: null,
        fileName: fileName,
        isLoading: false,
      );

  final double zoom;
  final bool showInfo;
  final Uint8List? imageBytes;
  final String? errorMessage;
  final String? fileName;
  final bool isLoading;

  String get zoomPercent => '${(zoom * 100).round()}%';

  ImageViewerUiState copyWith({
    double? zoom,
    bool? showInfo,
    Uint8List? imageBytes,
    bool clearImageBytes = false,
    String? errorMessage,
    bool clearError = false,
    String? fileName,
    bool? isLoading,
  }) {
    return ImageViewerUiState(
      zoom: zoom ?? this.zoom,
      showInfo: showInfo ?? this.showInfo,
      imageBytes: clearImageBytes ? null : (imageBytes ?? this.imageBytes),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fileName: fileName ?? this.fileName,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
