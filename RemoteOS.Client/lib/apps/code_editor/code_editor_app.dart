// Code Editor app shell (thin entry per AGENTS.md § 2).
//
// Builds the shared RemoteCodeEditorRepository using the riverpod-owned
// RemoteFileApi and composes the ViewModel/View pair.  All editor logic lives
// under the features/code_editor/ feature folder.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/dependency_injection.dart' as app_di;
import '../../core/network/remoteos_api.dart';
import '../../features/code_editor/application/code_editor_view_model.dart';
import '../../features/code_editor/data/code_editor_repository_impl.dart';
import '../../features/code_editor/presentation/code_editor_view.dart';
import '../../features/files/data/remote_file_api.dart';
import '../../features/files/text_file_encodings.dart';
import '../../features/workspace/application/workspace_sync_coordinator.dart';

class CodeEditorApp extends ConsumerStatefulWidget {
  const CodeEditorApp({
    super.key,
    this.remotePath,
    this.fileName,
  });

  final String? remotePath;
  final String? fileName;

  @override
  ConsumerState<CodeEditorApp> createState() => _CodeEditorAppState();
}

class _CodeEditorAppState extends ConsumerState<CodeEditorApp> {
  CodeEditorViewModel? _vm;

  @override
  void initState() {
    super.initState();
    final files = RemoteFileApi(ref.read(remoteOsApiProvider));
    final stored = app_di
        .getService<WorkspaceSyncCoordinator>()
        .debugPreferencesSnapshot()
        ?.codeEditorDefaultEncoding;
    final defaultEncoding = (stored != null &&
        stored.isNotEmpty &&
        TextFileEncodings.isSupported(stored))
        ? stored
        : 'UTF-8';
    _vm = CodeEditorViewModel(
      repository: RemoteCodeEditorRepository(files: files),
      initialPath: widget.remotePath,
      defaultEncodingName: defaultEncoding,
    )..saveDefaultEncodingAsync = _saveDefaultEncoding;
  }

  Future<void> _saveDefaultEncoding(String encoding) async {
    final sync = app_di.getService<WorkspaceSyncCoordinator>();
    final current = sync.debugPreferencesSnapshot();
    if (current == null) return;
    sync.queuePreferences(
        current.copyWith(codeEditorDefaultEncoding: encoding));
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
      return const Center(child: Text('Unable to start code editor.'));
    }
    return CodeEditorView(vm: vm);
  }
}