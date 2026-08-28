import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/window_manager/modal_manager.dart';
import '../../core/window_manager/window_manager.dart';
import 'explorer_app.dart';

/// Mirrors `Client.Apps.Explorer.ExplorerPickerMode`. Selecting a file
/// (OpenFile) returns the picked path; selecting a folder (SelectFolder)
/// returns the current address bar path or the highlighted folder.
enum ExplorerPickerMode { openFile, selectFolder }

/// Mirrors `Client.Apps.Explorer.ExplorerFileFilter`. Patterns use the
/// classic `*.txt` wildcard syntax and are matched case-insensitively
/// against the entry name.
class ExplorerFileFilter {
  const ExplorerFileFilter({
    required this.label,
    required this.patterns,
    this.includeExtensionlessFiles = false,
  });

  final String label;
  final List<String> patterns;
  final bool includeExtensionlessFiles;

  /// Matches every file, including names without an extension. Mirrors
  /// `ExplorerFileFilter.AllFiles` in the Avalonia client.
  static const allFiles = ExplorerFileFilter(
    label: 'All files (*.*)',
    patterns: ['*'],
    includeExtensionlessFiles: true,
  );

  bool matches(String name) {
    if (patterns.isEmpty) return false;
    for (final pattern in patterns) {
      if (_matchesSimpleExpression(pattern, name)) return true;
    }
    if (includeExtensionlessFiles) {
      final dot = name.lastIndexOf('.');
      if (dot <= 0 || dot == name.length - 1) return true;
    }
    return false;
  }

  /// Minimal case-insensitive wildcard matcher (`*` and `?`). Equivalent in
  /// behaviour to .NET's `FileSystemName.MatchesSimpleExpression` for the
  /// patterns used by Notepad's text-file filters.
  static bool _matchesSimpleExpression(String pattern, String name) {
    if (pattern == '*') return true;
    var p = 0;
    var n = 0;
    var star = -1;
    var match = 0;
    while (n < name.length) {
      if (p < pattern.length &&
          (pattern[p] == '?' ||
              pattern[p].toLowerCase() == name[n].toLowerCase())) {
        p++;
        n++;
      } else if (p < pattern.length && pattern[p] == '*') {
        star = p;
        match = n;
        p++;
      } else if (star != -1) {
        p = star + 1;
        match++;
        n = match;
      } else {
        return false;
      }
    }
    while (p < pattern.length && pattern[p] == '*') {
      p++;
    }
    return p == pattern.length;
  }
}

/// Mirrors `Client.Apps.Explorer.ExplorerPickerOptions`. Filters apply only
/// in [ExplorerPickerMode.openFile] mode; folder picker mode accepts every
/// directory.
class ExplorerPickerOptions {
  const ExplorerPickerOptions({
    this.mode = ExplorerPickerMode.openFile,
    this.allowMultiple = false,
    this.filters = const [ExplorerFileFilter.allFiles],
    required this.onConfirm,
    this.onCancel,
  });

  final ExplorerPickerMode mode;
  final bool allowMultiple;
  final List<ExplorerFileFilter> filters;

  /// Invoked with the picked paths (single path when [allowMultiple] is
  /// false). Wired to the surrounding modal by the host application.
  final void Function(List<String> paths) onConfirm;

  /// Invoked when the user cancels the picker (Esc or the cancel button).
  final void Function()? onCancel;
}

/// Opens the Explorer as a modal file picker and returns the selected path
/// (or `null` when cancelled). Mirrors the `RequestFileAsync` callback wired
/// up by `NotepadApp` on the Avalonia side.
Future<String?> showRemoteFilePicker(
  WidgetRef ref,
  BuildContext context, {
  String? title,
  List<ExplorerFileFilter> filters = const [ExplorerFileFilter.allFiles],
  Size preferredSize = const Size(760, 520),
}) {
  final ownerId = RemoteWindowScope.of(context).window.id;
  final modals = ref.read(modalManagerProvider);
  return modals.open<String>(
    ownerId: ownerId,
    spec: ModalSpec(
      title: title ?? 'notepad.open_remote_file'.tr(),
      icon: Icons.folder_open_outlined,
      preferredSize: preferredSize,
      child: Builder(
        builder: (modalContext) {
          final dialogId = RemoteModalScope.of(modalContext).windowId;
          return ExplorerApp(
            picker: ExplorerPickerOptions(
              mode: ExplorerPickerMode.openFile,
              filters: filters,
              onConfirm: (paths) =>
                  modals.complete(dialogId, paths.isEmpty ? null : paths.first),
              onCancel: () => modals.dismiss(dialogId),
            ),
          );
        },
      ),
    ),
  );
}

/// Opens the Explorer as a modal folder picker.
Future<String?> showRemoteFolderPicker(
  WidgetRef ref,
  BuildContext context, {
  String? title,
  Size preferredSize = const Size(760, 520),
}) {
  final ownerId = RemoteWindowScope.of(context).window.id;
  final modals = ref.read(modalManagerProvider);
  return modals.open<String>(
    ownerId: ownerId,
    spec: ModalSpec(
      title: title ?? 'explorer.picker.select_folder'.tr(),
      icon: Icons.folder_open_outlined,
      preferredSize: preferredSize,
      child: Builder(
        builder: (modalContext) {
          final dialogId = RemoteModalScope.of(modalContext).windowId;
          return ExplorerApp(
            picker: ExplorerPickerOptions(
              mode: ExplorerPickerMode.selectFolder,
              onConfirm: (paths) =>
                  modals.complete(dialogId, paths.isEmpty ? null : paths.first),
              onCancel: () => modals.dismiss(dialogId),
            ),
          );
        },
      ),
    ),
  );
}
