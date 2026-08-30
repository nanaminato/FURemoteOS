import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../apps/explorer/explorer_picker.dart';
import '../../../core/window_manager/modal_manager.dart';
import '../../../core/window_manager/window_manager.dart';
import '../application/code_editor_view_model.dart';
import '../domain/code_editor_models.dart';
import 'components/code_editor_components.dart';
import 'dialogs/code_editor_dialogs.dart';

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
    final vm = widget.vm;
    vm.requestFilePath = () => showRemoteFilePicker(ref, context,
        title: 'code_editor.open_remote_file');
    vm.requestFolderPath = () => showRemoteFolderPicker(ref, context,
        title: 'code_editor.open_remote_folder');
    vm.requestSavePath = (name) => showRemoteSaveFilePicker(ref, context,
        title: 'code_editor.save_remote_file', suggestedFileName: name);
    vm.requestDiscardDocument = _confirmDiscard;
    vm.requestEncodingActionAsync = _requestEncodingAction;
    vm.requestEncodingAsync = _requestEncoding;
    vm.requestSettingsAsync = _openSettings;
    unawaited(vm.loadInitialDocument());
  }

  Future<bool> _confirmDiscard(CodeEditorDocument document) async {
    final result = await ref.read(modalManagerProvider).open<bool>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'code_editor.close_dirty_title'.tr(),
        icon: Icons.warning_amber_rounded,
        preferredSize: const Size(420, 220),
        child: CodeEditorDiscardDialog(document: document),
      ),
    );
    return result == true;
  }

  Future<void> _openSettings() {
    final s = widget.vm.state.value;
    return ref.read(modalManagerProvider).open<void>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'code_editor.settings.title'.tr(),
        icon: Icons.tune_outlined,
        preferredSize: const Size(440, 360),
        child: CodeEditorSettingsDialog(
          fontSize: s.fontSize,
          wordWrap: s.wordWrap,
          defaultEncoding: s.defaultEncodingName,
          fontSizes: widget.vm.fontSizes,
          availableEncodings: widget.vm.availableEncodings,
          onFontSizeChanged: widget.vm.setFontSize,
          onWordWrapChanged: widget.vm.toggleWordWrap,
          onDefaultEncodingChanged: widget.vm.setDefaultEncoding,
          onClose: widget.vm.closeSettings,
        ),
      ),
    );
  }

  Future<CodeEditorEncodingAction?> _requestEncodingAction() {
    return ref.read(modalManagerProvider).open<CodeEditorEncodingAction>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'common.file_encoding'.tr(),
        icon: Icons.translate_rounded,
        preferredSize: const Size(420, 220),
        child: const CodeEditorEncodingActionDialog(),
      ),
    );
  }

  Future<String?> _requestEncoding([String? currentEncoding]) {
    final fallback = widget.vm.state.value.activeDocument?.encodingName ??
        widget.vm.state.value.defaultEncodingName;
    return ref.read(modalManagerProvider).open<String>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'common.file_encoding'.tr(),
        icon: Icons.translate_rounded,
        preferredSize: const Size(420, 360),
        child: CodeEditorEncodingDialog(
            currentEncoding: currentEncoding ?? fallback),
      ),
    );
  }

  /// StatusBar 编码按钮入口。无打开文件时 VM 会直接返回；有打开文件时走
  /// Avalonia ChooseEncoding 两步式（reopen / save with encoding）。
  Future<void> _chooseEncodingPressed() async {
    await widget.vm.chooseEncodingCommand.runAsync();
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
            CodeEditorStatusBar(
                state: state, onEncodingPressed: _chooseEncodingPressed),
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