// Code Editor app shell (thin entry per AGENTS.md § 2).
//
// Builds the shared TextFileRepository using the riverpod-owned RemoteFileApi
// and composes the ViewModel/View pair.  All editor logic lives under the
// features/code_editor/ feature folder.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/remoteos_api.dart';
import '../../features/code_editor/application/code_editor_view_model.dart';
import '../../features/code_editor/presentation/code_editor_view.dart';
import '../../features/files/data/remote_file_api.dart';
import '../../features/notepad/data/text_file_repository.dart';

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
    final textRepo = RemoteTextFileRepository(files);
    _vm = createCodeEditorViewModel(
      repository: textRepo,
      remotePath: widget.remotePath,
      fileName: widget.fileName,
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
      return const Center(child: Text('Unable to start code editor.'));
    }
    return CodeEditorView(vm: vm);
  }
}
