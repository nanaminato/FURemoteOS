// Top-level Notepad view (Avalonia parity).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/dependency_injection.dart' as app_di;
import '../../../../apps/explorer/explorer_picker.dart';
import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../../../core/window_manager/window_manager.dart';
import '../application/notepad_view_model.dart';
import '../domain/notepad_models.dart';
import '../domain/notepad_ui_state.dart';
import 'components/notepad_components.dart';
import 'dialogs/notepad_dialogs.dart';

class NotepadView extends ConsumerStatefulWidget {
  const NotepadView({super.key, this.vm, this.initialPath});
  final NotepadViewModel? vm;
  final String? initialPath;
  @override
  ConsumerState<NotepadView> createState() => _NotepadViewState();
}

class _NotepadViewState extends ConsumerState<NotepadView> {
  late final NotepadViewModel _vm;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _shortcutsFocusNode = FocusNode();
  bool _installedHooks = false;
  bool _syncingTextFromVm = false;

  @override
  void initState() {
    super.initState();
    _vm = widget.vm ?? app_di.di<NotepadViewModel>();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_installedHooks) {
      _installedHooks = true;
      _installHooks();
      if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_vm.openPath(widget.initialPath!, null));
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _shortcutsFocusNode.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_syncingTextFromVm) return;
    _vm.onTextChanged(_controller.text);
  }

  void _installHooks() {
    _vm.requestFileAsync = _requestFile;
    _vm.requestSavePathAsync = _requestSavePath;
    _vm.requestDiscardChangesAsync = _confirmDiscard;
    _vm.requestSettingsAsync = _openSettings;
    _vm.requestEncodingActionAsync = _requestEncodingAction;
    _vm.requestEncodingAsync = _requestEncoding;
    _vm.saveDefaultEncodingAsync = (_) async {};
    _vm.state.addListener(_onVmTextChanged);
  }

  void _onVmTextChanged() {
    final s = _vm.state.value;
    if (s.text != _controller.text) {
      _syncingTextFromVm = true;
      _controller.value = TextEditingValue(text: s.text, selection: _controller.selection);
      _syncingTextFromVm = false;
    }
  }

  Future<String?> _requestFile() {
    return showRemoteFilePicker(ref, context, filters: [
      ExplorerFileFilter(
        label: 'notepad.text_file_filter'.tr(),
        patterns: [for (final ext in notepadSupportedExtensions) "*$ext"],
        includeExtensionlessFiles: true,
      ),
      ExplorerFileFilter.allFiles,
    ]);
  }

  Future<String?> _requestSavePath(String defaultName) {
    return showRemoteSaveFilePicker(
      ref,
      context,
      title: 'notepad.save_remote_file'.tr(),
      suggestedFileName: defaultName,
      filters: [
        ExplorerFileFilter(
          label: 'notepad.text_file_filter'.tr(),
          patterns: [for (final ext in notepadSupportedExtensions) "*$ext"],
          includeExtensionlessFiles: true,
        ),
        ExplorerFileFilter.allFiles,
      ],
    );
  }

  Future<bool> _confirmDiscard() {
    return ref.read(modalManagerProvider).open<bool>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'notepad.reopen_dirty_title'.tr(),
        icon: Icons.warning_amber_rounded,
        preferredSize: const Size(440, 230),
        child: NotepadConfirmDialog(
          title: 'notepad.reopen_dirty_title'.tr(),
          message: 'notepad.reopen_dirty_message'.tr(),
          confirmLabel: 'notepad.discard_changes'.tr(),
        ),
      ),
    ).then((value) => value == true);
  }

  Future<void> _openSettings() {
    final s = _vm.state.value;
    return ref.read(modalManagerProvider).open<void>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'notepad.settings.title'.tr(),
        icon: Icons.tune_outlined,
        preferredSize: const Size(440, 320),
        child: NotepadSettingsDialog(
          fontSize: s.fontSize,
          defaultEncoding: s.defaultEncodingName,
          fontSizes: _vm.fontSizes,
          onFontSizeChanged: _vm.setFontSize,
          onDefaultEncodingChanged: _vm.setDefaultEncoding,
          onClose: _vm.closeSettings,
        ),
      ),
    );
  }

  Future<EncodingDialogAction?> _requestEncodingAction() {
    return ref.read(modalManagerProvider).open<EncodingDialogAction>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'common.file_encoding'.tr(),
        icon: Icons.translate_rounded,
        preferredSize: const Size(420, 220),
        child: const NotepadEncodingActionDialog(),
      ),
    );
  }

  Future<String?> _requestEncoding([String? currentEncoding]) {
    return ref.read(modalManagerProvider).open<String>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'common.file_encoding'.tr(),
        icon: Icons.translate_rounded,
        preferredSize: const Size(420, 360),
        child: NotepadEncodingDialog(
            currentEncoding: currentEncoding ?? _vm.state.value.encodingName),
      ),
    );
  }

  /// StatusBar 编码按钮入口。有打开文件时走 Avalonia ChooseEncoding 两步式，
  /// 无打开文件时直接更新当前工作编码（用于后续新建/保存）。
  Future<void> _chooseEncodingPressed() async {
    final s = _vm.state.value;
    if (!s.hasOpenFile) {
      final encoding = await _requestEncoding();
      if (encoding == null || encoding.trim().isEmpty) return;
      _vm.setWorkingEncoding(encoding);
      return;
    }
    await _vm.chooseEncodingCommand.runAsync();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;
    if (!ctrl) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.keyN && !shift) {
      unawaited(_vm.newDocumentCommand.runAsync());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyO && !shift) {
      unawaited(_vm.openDocumentCommand.runAsync());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS && !shift) {
      unawaited(_vm.saveCommand.runAsync());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS && shift) {
      unawaited(_vm.saveAsCommand.runAsync());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return ValueListenableBuilder(
      valueListenable: _vm.state,
      builder: (context, NotepadUiState s, _) {
        if (s.text != _controller.text) {
          _syncingTextFromVm = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && s.text == _vm.state.value.text) {
              final end = _controller.selection.end;
              _controller.value = TextEditingValue(
                text: s.text,
                selection: TextSelection.collapsed(
                  offset: s.text.length > end ? end : s.text.length,
                ),
              );
            }
            _syncingTextFromVm = false;
          });
        }
        return Focus(
          focusNode: _shortcutsFocusNode,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: Column(
            children: [
              NotepadMenuBar(state: s, vm: _vm),
              Expanded(child: _buildTextField(palette, s)),
              NotepadStatusBar(
                state: s,
                onEncodingPressed: _chooseEncodingPressed,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(ThemePalette palette, NotepadUiState s) {
    // Mirrors Avalonia NotepadView.axaml TextBox:
    //   TextWrapping = Wrap, Padding = "12,10", BorderThickness = 0,
    //   CornerRadius = 0, FontSize = FontSize, AcceptsReturn = True.
    return TextField(
      controller: _controller,
      scrollController: _scrollController,
      focusNode: _focusNode,
      expands: true,
      maxLines: null,
      minLines: null,
      enableInteractiveSelection: true,
      textAlign: TextAlign.start,
      textAlignVertical: TextAlignVertical.top,
      style: TextStyle(
        fontFamily: 'Consolas',
        fontFamilyFallback: const ['Cascadia Mono', 'Courier New', 'monospace'],
        fontSize: s.fontSize,
        height: 1.35,
        color: palette.textPrimary,
      ),
      cursorColor: palette.accent,
      cursorWidth: 2,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: true,
        fillColor: palette.surface,
        contentPadding:
            const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 10),
      ),
    );
  }
}

