// Immutable presentation state for the File Manager feature.
//
// The View broadcasts selection back to the ViewModel via method calls; the
// ViewModel pushes the complete projection here so the View can rebuild with
// `ValueListenableBuilder`.

import 'package:flutter/foundation.dart';

import '../../../apps/explorer/explorer_picker.dart';
import 'file_manager_models.dart';

@immutable
class FileManagerUiState {
  const FileManagerUiState({
    required this.currentPath,
    required this.locationName,
    required this.searchText,
    required this.detailsView,
    required this.entries,
    required this.selectedPaths,
    required this.navigationNodes,
    required this.selectedNodePath,
    required this.isLoading,
    required this.isTransferActive,
    required this.transferText,
    required this.transferProgressPercent,
    required this.loadError,
    required this.statusText,
    required this.history,
    required this.historyIndex,
    required this.clipboardPaths,
    required this.clipboardIsCut,
    required this.pickerOptions,
    required this.pickerEntryName,
    required this.pickerFilters,
    required this.pickerSelectedFilter,
  });

  factory FileManagerUiState.initial({ExplorerPickerOptions? picker}) {
    final filters = (picker?.filters == null || picker!.filters.isEmpty)
        ? const <ExplorerFileFilter>[ExplorerFileFilter.allFiles]
        : picker.filters;
    return FileManagerUiState(
      currentPath: '',
      locationName: '',
      searchText: '',
      detailsView: true,
      entries: const [],
      selectedPaths: const <String>{},
      navigationNodes: const [],
      selectedNodePath: null,
      isLoading: false,
      isTransferActive: false,
      transferText: '',
      transferProgressPercent: 0,
      loadError: null,
      statusText: '',
      history: const [],
      historyIndex: -1,
      clipboardPaths: null,
      clipboardIsCut: false,
      pickerOptions: picker,
      pickerEntryName: picker?.suggestedFileName ?? '',
      pickerFilters: filters,
      pickerSelectedFilter: filters.first,
    );
  }

  // ---- Navigation ----
  final String currentPath;
  final String locationName;
  final String searchText;
  final bool detailsView;

  // ---- Directory contents ----
  final List<FileItem> entries;
  final Set<String> selectedPaths;

  // ---- Navigation rail ----
  final List<TreeNodeItem> navigationNodes;
  final String? selectedNodePath;

  // ---- Load state ----
  final bool isLoading;
  final bool isTransferActive;
  final String transferText;
  final double transferProgressPercent;
  final String? loadError;
  final String statusText;

  // ---- History ----
  final List<String> history;
  final int historyIndex;

  // ---- Clipboard ----
  final List<String>? clipboardPaths;
  final bool clipboardIsCut;

  // ---- Picker ----
  final ExplorerPickerOptions? pickerOptions;
  final String pickerEntryName;
  final List<ExplorerFileFilter> pickerFilters;
  final ExplorerFileFilter pickerSelectedFilter;

  // ---- Derived ----
  bool get isPickerMode => pickerOptions != null;

  ExplorerPickerMode? get pickerMode => pickerOptions?.mode;
  bool get isFolderPickerMode =>
      pickerMode == ExplorerPickerMode.selectFolder;
  bool get isFilePickerMode =>
      isPickerMode &&
      pickerMode != ExplorerPickerMode.selectFolder &&
      pickerMode != ExplorerPickerMode.saveFile;
  bool get isSaveFilePickerMode =>
      pickerMode == ExplorerPickerMode.saveFile;
  bool get isMultiFilePickerMode =>
      pickerMode == ExplorerPickerMode.openFiles;
  bool get allowMultipleFiles =>
      isMultiFilePickerMode ||
      (isFilePickerMode && (pickerOptions?.allowMultiple ?? false));

  bool get canGoBack => historyIndex > 0;
  bool get canGoForward => historyIndex < history.length - 1;
  bool get canGoUp => currentPath.isNotEmpty;
  bool get hasSelection => selectedPaths.isNotEmpty;
  bool get hasClipboard => clipboardPaths != null && clipboardPaths!.isNotEmpty;

  List<FileItem> selectedEntries({List<FileItem>? from}) {
    final pool = from ?? entries;
    return pool
        .where((entry) => selectedPaths.contains(entry.path))
        .toList(growable: false);
  }

  // ---- Copy-with ----

  FileManagerUiState copyWith({
    String? currentPath,
    String? locationName,
    String? searchText,
    bool? detailsView,
    List<FileItem>? entries,
    Set<String>? selectedPaths,
    List<TreeNodeItem>? navigationNodes,
    String? selectedNodePath,
    bool clearSelectedNodePath = false,
    bool? isLoading,
    bool? isTransferActive,
    String? transferText,
    double? transferProgressPercent,
    String? loadError,
    bool clearLoadError = false,
    String? statusText,
    List<String>? history,
    int? historyIndex,
    List<String>? clipboardPaths,
    bool clearClipboardPaths = false,
    bool? clipboardIsCut,
    ExplorerPickerOptions? pickerOptions,
    String? pickerEntryName,
    List<ExplorerFileFilter>? pickerFilters,
    ExplorerFileFilter? pickerSelectedFilter,
  }) {
    return FileManagerUiState(
      currentPath: currentPath ?? this.currentPath,
      locationName: locationName ?? this.locationName,
      searchText: searchText ?? this.searchText,
      detailsView: detailsView ?? this.detailsView,
      entries: entries ?? this.entries,
      selectedPaths: selectedPaths ?? this.selectedPaths,
      navigationNodes: navigationNodes ?? this.navigationNodes,
      selectedNodePath: clearSelectedNodePath
          ? null
          : (selectedNodePath ?? this.selectedNodePath),
      isLoading: isLoading ?? this.isLoading,
      isTransferActive: isTransferActive ?? this.isTransferActive,
      transferText: transferText ?? this.transferText,
      transferProgressPercent:
          transferProgressPercent ?? this.transferProgressPercent,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      statusText: statusText ?? this.statusText,
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
      clipboardPaths: clearClipboardPaths
          ? null
          : (clipboardPaths ?? this.clipboardPaths),
      clipboardIsCut: clipboardIsCut ?? this.clipboardIsCut,
      pickerOptions: pickerOptions ?? this.pickerOptions,
      pickerEntryName: pickerEntryName ?? this.pickerEntryName,
      pickerFilters: pickerFilters ?? this.pickerFilters,
      pickerSelectedFilter: pickerSelectedFilter ?? this.pickerSelectedFilter,
    );
  }
}
