// Code Editor dialogs (AGENTS.md §18 — ModalHost / ModalCoordinator style).
//
// All dialogs are stateless/stateful widgets driven by ModalSpec; they
// complete their owning modal via `RemoteModalScope` + `ModalManager`. They
// mirror the Avalonia `EncodingActionDialogView` / `EncodingDialogView` /
// `CodeEditorSettingsView` trio.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../../../core/window_manager/window_manager.dart';
import '../../../files/text_file_encodings.dart';
import '../../domain/code_editor_models.dart';

/// Step 1 of the encoding chooser: asks whether to reopen or save with the
/// new encoding. Returns a [CodeEditorEncodingAction].
class CodeEditorEncodingActionDialog extends ConsumerWidget {
  const CodeEditorEncodingActionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('common.encoding_action_hint'.tr(),
                style: TextStyle(color: palette.textPrimary)),
          ),
          const SizedBox(height: 10),
          _actionTile(palette, 'common.reopen'.tr(),
                  () => modals.complete(dialogId, CodeEditorEncodingAction.reopen)),
          _actionTile(palette, 'common.save'.tr(),
                  () => modals.complete(dialogId, CodeEditorEncodingAction.save)),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: () => modals.dismiss(dialogId),
                child: Text('common.cancel'.tr())),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(ThemePalette palette, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: TextStyle(color: palette.textPrimary, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

/// Step 2 of the encoding chooser: lists all supported encodings and returns
/// the picked one.
class CodeEditorEncodingDialog extends ConsumerStatefulWidget {
  const CodeEditorEncodingDialog({super.key, required this.currentEncoding});

  final String currentEncoding;

  @override
  ConsumerState<CodeEditorEncodingDialog> createState() =>
      _CodeEditorEncodingDialogState();
}

class _CodeEditorEncodingDialogState
    extends ConsumerState<CodeEditorEncodingDialog> {
  late String _selected = TextFileEncodings.isSupported(widget.currentEncoding)
      ? widget.currentEncoding
      : TextFileEncodings.available.first;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('common.encoding_selection_hint'.tr(),
              style: TextStyle(color: palette.textPrimary)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: TextFileEncodings.available.length,
              itemBuilder: (context, index) {
                final encoding = TextFileEncodings.available[index];
                return RadioListTile<String>(
                  value: encoding,
                  groupValue: _selected,
                  title: Text(encoding),
                  dense: true,
                  onChanged: (value) {
                    if (value != null) setState(() => _selected = value);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () => modals.dismiss(dialogId),
                  child: Text('common.cancel'.tr())),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: () => modals.complete(dialogId, _selected),
                  child: Text('common.ok'.tr())),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settings dialog: font size + word wrap + default encoding + syntax note.
/// Mirrors the Avalonia `CodeEditorSettingsView`.
class CodeEditorSettingsDialog extends ConsumerStatefulWidget {
  const CodeEditorSettingsDialog({
    super.key,
    required this.fontSize,
    required this.wordWrap,
    required this.defaultEncoding,
    required this.fontSizes,
    required this.availableEncodings,
    required this.onFontSizeChanged,
    required this.onWordWrapChanged,
    required this.onDefaultEncodingChanged,
    this.onClose,
  });

  final double fontSize;
  final bool wordWrap;
  final String defaultEncoding;
  final List<double> fontSizes;
  final List<String> availableEncodings;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<bool> onWordWrapChanged;
  final ValueChanged<String> onDefaultEncodingChanged;
  final VoidCallback? onClose;

  @override
  ConsumerState<CodeEditorSettingsDialog> createState() =>
      _CodeEditorSettingsDialogState();
}

class _CodeEditorSettingsDialogState
    extends ConsumerState<CodeEditorSettingsDialog> {
  late double _fontSize = widget.fontSize;
  late bool _wordWrap = widget.wordWrap;
  late String _defaultEncoding = widget.defaultEncoding;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('code_editor.settings.title'.tr(),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary)),
          const SizedBox(height: 18),
          Row(children: [
            SizedBox(
                width: 150,
                child: Text('code_editor.settings.font_size'.tr(),
                    style: TextStyle(color: palette.textSecondary))),
            Expanded(
              child: DropdownButton<double>(
                value: _fontSize,
                isExpanded: true,
                items: [
                  for (final size in widget.fontSizes)
                    DropdownMenuItem(value: size, child: Text('${size.toInt()} pt')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _fontSize = value);
                  widget.onFontSizeChanged(value);
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            SizedBox(
                width: 150,
                child: Text('code_editor.settings.word_wrap'.tr(),
                    style: TextStyle(color: palette.textSecondary))),
            Align(
              alignment: Alignment.centerLeft,
              child: Checkbox(
                value: _wordWrap,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _wordWrap = value);
                  widget.onWordWrapChanged(value);
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            SizedBox(
                width: 150,
                child: Text('code_editor.settings.default_encoding'.tr(),
                    style: TextStyle(color: palette.textSecondary))),
            Expanded(
              child: DropdownButton<String>(
                value: _defaultEncoding,
                isExpanded: true,
                items: [
                  for (final encoding in widget.availableEncodings)
                    DropdownMenuItem(value: encoding, child: Text(encoding)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _defaultEncoding = value);
                  widget.onDefaultEncodingChanged(value);
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Text('code_editor.settings.syntax_note'.tr(),
              style: TextStyle(color: palette.textSecondary, fontSize: 12)),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                widget.onClose?.call();
                modals.dismiss(dialogId);
              },
              child: Text('common.done'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}