// Compatibility shim for the existing `apps/notepad/notepad_app.dart` import
// path.  The actual Notepad implementation lives under `features/notepad/`
// (feature-first MVVM layout).  This wrapper keeps the public entry point
// `NotepadApp` used by `app_registry.dart` and file-open flows intact.

import 'package:flutter/material.dart';

import '../../features/notepad/presentation/notepad_view.dart';

/// RemoteOS built-in text editor.  See [NotepadView] for the migrated
/// feature-first implementation; this widget exists purely to preserve the
/// existing public import path and constructor name.
class NotepadApp extends StatelessWidget {
  const NotepadApp({super.key, this.initialPath});

  /// Optional remote path to open directly on window creation.
  final String? initialPath;

  @override
  Widget build(BuildContext context) {
    return NotepadView(initialPath: initialPath);
  }
}
