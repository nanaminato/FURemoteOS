// Compatibility shim preserving the `apps/explorer/explorer_app.dart` public
// entry point used by `app_registry.dart`, `explorer_picker.dart` and the
// Docker manager's "open in Explorer" action.
//
// The actual feature-first implementation lives under `features/file_manager/`.
// This wrapper forwards the existing [ExplorerApp] constructor signature to
// [FileManagerView] so callers are unaffected by the migration.

import 'package:flutter/material.dart';

import '../../features/file_manager/presentation/file_manager_view.dart';
import 'explorer_picker.dart';

/// RemoteOS file explorer.  See [FileManagerView] for the migrated
/// feature-first ViewModel-driven implementation.
class ExplorerApp extends StatelessWidget {
  const ExplorerApp({super.key, this.initialPath, this.picker});

  /// Optional server path opened directly at activation, mirroring the
  /// original Avalonia client's path activation.
  final String? initialPath;

  /// Optional picker configuration (file-open / folder-select / save-file).
  final ExplorerPickerOptions? picker;

  @override
  Widget build(BuildContext context) {
    return FileManagerView(
      initialPath: initialPath,
      picker: picker,
    );
  }
}
