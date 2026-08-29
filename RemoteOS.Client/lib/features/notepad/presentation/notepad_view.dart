// Top-level Notepad view (ARCHITECTURE.md § 8).
//
// The View owns Flutter UI resources (TextEditingController, ScrollController,
// FocusNode, modal/dialog coordination) and maps user gestures to ViewModel
// commands / methods.  It does NOT call RemoteFileApi or read preferences
// directly; those stay behind the repository + WorkspaceSyncCoordinator.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watch_it/watch_it.dart' as watch_it;

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

  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  final _findFocusNode = FocusNode();

  bool _installedHooks = false;
  bool _syncingTextFromVm = false;

  @override
  void initState() {
    super.initState();
    _vm = widget.vm ?? app_di.di<NotepadViewModel>();
    _controller.addListener(_onTextChanged);
    _controller.addListener(_onSelectionChanged);
    // Initial status text translation.
    if (_vm.state.value.statusText.isEmpty) {
      _vm.state.value =
          _vm.state.value.copyWith(statusText: 'notepad.status.ready');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_installedHooks) {
      _installedHooks = true;
      _installHooks();
      // Seed an initial snapshot so Ctrl+Z on an untouched document behaves.
      _vm.seedInitialSnapshot(
          '', const TextSelection.collapsed(offset: 0));
      if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_vm.openPath(
              widget.initialPath!, _vm.state.value.defaultEncodingName));
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.removeListener(_onSelectionChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_syncingTextFromVm) return;
    _vm.onTextChanged(_controller.text);
  }

  void _onSelectionChanged() {
    if (_syncingTextFromVm) return;
    _vm.onSelectionChanged(
      baseOffset: _controller.selection.baseOffset,
      text: _controller.text,
    );
  }

  // ---- VM → View hooks ----

  void _installHooks() {
    _vm.requestFileAsync = _requestFile;
    _vm.requestSavePathAsync = _requestSavePath;
    _vm.requestDiscardChangesAsync = _confirmDiscard;
    _vm.requestSettingsAsync = _openSettings;
    _vm.requestEncodingActionAsync = _requestEncodingAction;
    _vm.requestEncodingAsync = _requestEncoding;
    _vm.saveDefaultEncodingAsync = (_) async {};

    // Re-apply external text updates coming from the VM (open / reload /
    // undo/redo from external source) into the Flutter controller.
    _vm.state.addListener(_onVmTextChanged);
  }

  void _onVmTextChanged() {
    final s = _vm.state.value;
    if (s.text != _controller.text) {
      _syncingTextFromVm = true;
      _controller.value = TextEditingValue(
        text: s.text,
        selection: _controller.selection,
      );
      _syncingTextFromVm = false;
    }
    // If the find toolbar just opened, focus the find input.
    if (s.showFindReplace) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_findFocusNode);
      });
    }
  }

  // ---- Dialog + picker wrappers ----

  Future<String?> _requestFile() {
    return showRemoteFilePicker(
      ref,
      context,
      filters: [
        ExplorerFileFilter(
          label: 'notepad.text_file_filter'.tr(),
          patterns: [
            for (final ext in notepadSupportedExtensions) '*$ext',
          ],
          includeExtensionlessFiles: true,
        ),
        ExplorerFileFilter.allFiles,
      ],
    );
  }

  Future<String?> _requestSavePath(String defaultName) {
    return ref.read(modalManagerProvider).open<String>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'notepad.save_remote_file'.tr(),
        icon: Icons.save_outlined,
        preferredSize: const Size(440, 230),
        child: NotepadSavePathDialog(
          prompt: 'notepad.remote_path_prompt'.tr(),
          initialValue: defaultName,
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard(String titleKey, String messageKey) {
    return ref
        .read(modalManagerProvider)
        .open<bool>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: titleKey.tr(),
            icon: Icons.warning_amber_rounded,
            preferredSize: const Size(440, 230),
            child: NotepadConfirmDialog(
              title: titleKey.tr(),
              message: messageKey.tr(),
              confirmLabel: 'notepad.discard_changes'.tr(),
            ),
          ),
        )
        .then((value) => value == true);
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
          fontSizes: notepadFontSizes,
          onFontSizeChanged: _vm.setFontSize,
          onDefaultEncodingChanged: _vm.setDefaultEncoding,
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

  Future<String?> _requestEncoding(String currentEncoding) {
    return ref.read(modalManagerProvider).open<String>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: 'common.file_encoding'.tr(),
            icon: Icons.translate_rounded,
            preferredSize: const Size(420, 360),
            child: NotepadEncodingDialog(currentEncoding: currentEncoding),
          ),
        );
  }

  // ---- Keyboard shortcuts ----

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;
    final s = _vm.state.value;

    if (key == LogicalKeyboardKey.f3) {
      if (shift) {
        _runFindPrev();
      } else {
        _runFindNext();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && s.showFindReplace) {
      _vm.closeFindReplace();
      return KeyEventResult.handled;
    }
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
    if (key == LogicalKeyboardKey.keyZ && !shift) {
      _runUndo();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyY ||
        (key == LogicalKeyboardKey.keyZ && shift)) {
      _runRedo();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX) {
      // Clipboard ops are handled by the Widgets binding too, but Avalonia's
      // ViewModel exposes them as commands so we mirror the shortcuts on the
      // Notepad-level focus node.  The TextField's own bindings still fire
      // when the editor is focused.
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyF) {
      _vm.openFind();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH) {
      _vm.openFind(replaceMode: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _runUndo() {
    final snap = _vm.undo();
    if (snap == null) return;
    _syncingTextFromVm = true;
    _controller.value = TextEditingValue(text: snap.text, selection: snap.selection);
    _syncingTextFromVm = false;
  }

  void _runRedo() {
    final snap = _vm.redo();
    if (snap == null) return;
    _syncingTextFromVm = true;
    _controller.value = TextEditingValue(text: snap.text, selection: snap.selection);
    _syncingTextFromVm = false;
  }

  void _runFindNext() {
    final match = _vm.findNext(
      _findController.text,
      _controller.text,
      _controller.selection.baseOffset.clamp(0, _controller.text.length),
    );
    if (match != null) _applySelection(match);
  }

  void _runFindPrev() {
    final match = _vm.findPrev(
      _findController.text,
      _controller.text,
      _controller.selection.baseOffset.clamp(0, _controller.text.length),
    );
    if (match != null) _applySelection(match);
  }

  void _applySelection(TextSelection match) {
    _syncingTextFromVm = true;
    _controller.selection = match;
    _syncingTextFromVm = false;
    _focusNode.requestFocus();
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return ValueListenableBuilder(
      valueListenable: _vm.state,
      builder: (context, NotepadUiState s, _) {
        // Synchronize external text update (e.g. open-path result) that
        // may have been queued before build.
        if (s.text != _controller.text) {
          _syncingTextFromVm = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && s.text == _vm.state.value.text) {
              _controller.value = TextEditingValue(
                text: s.text,
                selection: TextSelection.collapsed(
                    offset: s.text.length > _controller.selection.end
                        ? _controller.selection.end
                        : s.text.length),
              );
            }
            _syncingTextFromVm = false;
          });
        }

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: Column(
            children: [
              NotepadMenuBar(
                state: s,
                vm: _vm,
                findController: _findController,
                replaceController: _replaceController,
                editorFocus: _focusNode,
                editorController: _controller,
              ),
              if (s.showFindReplace)
                NotepadFindReplaceToolbar(
                  state: s,
                  vm: _vm,
                  findController: _findController,
                  findFocusNode: _findFocusNode,
                  replaceController: _replaceController,
                  editorController: _controller,
                  onSelectionApplied: _applySelection,
                ),
              Expanded(
                child: Container(
                  color: palette.surface,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (s.showLineNumbers)
                        _buildLineNumbersGutter(palette, s),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection:
                              s.wordWrap ? Axis.vertical : Axis.horizontal,
                          child: s.wordWrap
                              ? _buildTextField(palette, s)
                              : SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: _buildTextField(palette, s),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              NotepadStatusBar(
                state: s,
                onEncodingPressed: () => _vm.chooseEncodingCommand.runAsync(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineNumbersGutter(ThemePalette palette, NotepadUiState s) {
    return Container(
      width: 52,
      padding: const EdgeInsets.only(top: 14, right: 8),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        border: Border(right: BorderSide(color: palette.borderSubtle)),
      ),
      child: Text(
        List.generate(s.lineCount, (i) => '${i + 1}').join('\n'),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'Consolas',
          fontFamilyFallback: const ['Courier New', 'monospace'],
          fontSize: s.fontSize,
          height: 1.35,
          color: palette.textTertiary,
        ),
      ),
    );
  }

  Widget _buildTextField(ThemePalette palette, NotepadUiState s) {
    final contentPadding = EdgeInsets.only(
      left: s.showLineNumbers ? 8 : 14,
      right: 14,
      top: 14,
      bottom: 14,
    );
    final text = s.text;
    double? intrinsicWidth;
    if (!s.wordWrap && text.isNotEmpty) {
      final direction = Directionality.maybeOf(context);
      if (direction != null) {
        final painter = TextPainter(
          text: TextSpan(
            text: _longestLine(text),
            style: TextStyle(
              fontFamily: 'Consolas',
              fontFamilyFallback: const ['Courier New', 'monospace'],
              fontSize: s.fontSize,
              height: 1.35,
            ),
          ),
          maxLines: 1,
          textDirection: direction,
        )..layout();
        intrinsicWidth = painter.width + 28;
      }
    }
    return Container(
      width: intrinsicWidth,
      constraints: s.wordWrap
          ? null
          : BoxConstraints(minWidth: MediaQuery.of(context).size.width),
      child: TextField(
        controller: _controller,
        expands: false,
        maxLines: s.wordWrap ? null : s.lineCount,
        minLines: s.wordWrap ? null : s.lineCount,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          fontFamily: 'Consolas',
          fontFamilyFallback: const ['Courier New', 'monospace'],
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
          filled: true,
          fillColor: palette.surface,
          contentPadding: contentPadding,
          hintText: 'notepad.hint.start_typing'.tr(),
          hintStyle:
              TextStyle(color: palette.textTertiary, fontSize: s.fontSize),
          isCollapsed: true,
          isDense: false,
        ),
      ),
    );
  }

  static String _longestLine(String text) {
    if (text.isEmpty) return '';
    return text.split('\n').reduce((a, b) => a.length > b.length ? a : b);
  }
}
