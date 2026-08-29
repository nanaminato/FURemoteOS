import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../apps/explorer/explorer_picker.dart';
import '../../../core/window_manager/modal_manager.dart';
import '../../../core/window_manager/window_manager.dart';
import '../domain/code_editor_models.dart';
import '../application/code_editor_view_model.dart';
import 'components/code_editor_components.dart';

/// Rendering and lifecycle owner for a Code Editor window. Keyboard focus,
/// text controllers and post-frame startup remain here; the ViewModel stays
/// independent of Flutter widget APIs.
class CodeEditorView extends ConsumerStatefulWidget {
  const CodeEditorView({super.key, required this.vm});
  final CodeEditorViewModel vm;

  @override
  ConsumerState<CodeEditorView> createState() => _CodeEditorViewState();
}

class _CodeEditorViewState extends ConsumerState<CodeEditorView> {
  @override
  void initState() {
    super.initState();
    widget.vm.requestFilePath = () => showRemoteFilePicker(ref, context,
        title: 'code_editor.open_remote_file');
    widget.vm.requestFolderPath = () => showRemoteFolderPicker(ref, context,
        title: 'code_editor.open_remote_folder');
    widget.vm.requestSavePath = (name) => showRemoteSaveFilePicker(ref, context,
        title: 'code_editor.save_remote_file', suggestedFileName: name);
    widget.vm.requestDiscardDocument = _confirmDiscard;
    unawaited(widget.vm.loadInitialDocument());
  }

  Future<bool> _confirmDiscard(CodeEditorDocument document) async {
    final result = await ref.read(modalManagerProvider).open<bool>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: 'Discard unsaved changes?',
            icon: Icons.warning_amber_rounded,
            preferredSize: const Size(420, 220),
            child: CodeEditorDiscardDialog(document: document),
          ),
        );
    return result == true;
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.keyN, control: true): _NewIntent(),
          SingleActivator(LogicalKeyboardKey.keyO, control: true):
              _OpenIntent(),
          SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _SaveIntent(),
          SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
              _SaveAsIntent(),
          SingleActivator(LogicalKeyboardKey.keyW, control: true):
              _CloseIntent(),
        },
        child: Actions(
          actions: {
            _NewIntent: CallbackAction<_NewIntent>(
                onInvoke: (_) => widget.vm.newDocument()),
            _OpenIntent: CallbackAction<_OpenIntent>(
                onInvoke: (_) => widget.vm.openDocumentCommand.runAsync()),
            _SaveIntent: CallbackAction<_SaveIntent>(
                onInvoke: (_) => widget.vm.saveCommand.runAsync()),
            _SaveAsIntent: CallbackAction<_SaveAsIntent>(
                onInvoke: (_) => widget.vm.saveAsCommand.runAsync()),
            _CloseIntent: CallbackAction<_CloseIntent>(
                onInvoke: (_) => widget.vm.closeDocumentCommand.runAsync()),
          },
          child: Focus(
            autofocus: true,
            child: ValueListenableBuilder(
              valueListenable: widget.vm.state,
              builder: (context, state, _) => Column(children: [
                CodeEditorMenuBar(vm: widget.vm),
                Expanded(
                    child: CodeEditorWorkspace(vm: widget.vm, state: state)),
                CodeEditorStatusBar(state: state),
              ]),
            ),
          ),
        ),
      );
}

class _NewIntent extends Intent {
  const _NewIntent();
}

class _OpenIntent extends Intent {
  const _OpenIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _SaveAsIntent extends Intent {
  const _SaveAsIntent();
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}
