// Notepad dialogs (AGENTS.md § 18 — ModalHost / ModalCoordinator style).
//
// All dialogs here are stateless widgets driven by ModalSpec; they complete
// their owning modal via `RemoteModalScope` + `ModalManager`.  They mirror
// the inner dialog classes previously nested inside `_NotepadAppState`.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/theme_service.dart';
import '../../../../../core/window_manager/modal_manager.dart';
import '../../../../../core/window_manager/window_manager.dart';
import '../../../../features/files/text_file_encodings.dart';
import '../../domain/notepad_models.dart';

/// Save-as path input dialog. Mirrors Avalonia's `TextInputDialogView`.
class NotepadSavePathDialog extends ConsumerStatefulWidget {
  const NotepadSavePathDialog({
    super.key,
    required this.prompt,
    required this.initialValue,
  });

  final String prompt;
  final String initialValue;

  @override
  ConsumerState<NotepadSavePathDialog> createState() =>
      _NotepadSavePathDialogState();
}

class _NotepadSavePathDialogState extends ConsumerState<NotepadSavePathDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..selection = TextSelection(
          baseOffset: 0, extentOffset: widget.initialValue.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
          Text(widget.prompt,
              style: TextStyle(color: palette.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: (value) =>
                modals.complete(dialogId, value.trim().isEmpty ? null : value),
            style: TextStyle(color: palette.textPrimary),
            decoration: const InputDecoration(labelText: 'Path'),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => modals.dismiss(dialogId),
                child: Text('common.cancel'.tr()),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => modals.complete(
                    dialogId,
                    _controller.text.trim().isEmpty
                        ? null
                        : _controller.text.trim()),
                child: Text('common.save'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Confirmation dialog used for "discard unsaved changes?" prompts.
class NotepadConfirmDialog extends ConsumerWidget {
  const NotepadConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final dialogId = RemoteModalScope.of(context).windowId;
    final modals = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: palette.textPrimary)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => modals.dismiss(dialogId),
                child: Text('common.cancel'.tr()),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => modals.complete(dialogId, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Step 1 of the encoding chooser: asks the user whether to reopen or save
/// with the new encoding.  Returns an [EncodingDialogAction].
class NotepadEncodingActionDialog extends ConsumerWidget {
  const NotepadEncodingActionDialog({super.key});

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
            child: Text(
              'common.encoding_action_hint'.tr(),
              style: TextStyle(color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: 10),
          _actionTile(palette, 'common.reopen'.tr(),
              () => modals.complete(dialogId, EncodingDialogAction.reopen)),
          _actionTile(palette, 'common.save'.tr(),
              () => modals.complete(dialogId, EncodingDialogAction.save)),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => modals.dismiss(dialogId),
              child: Text('common.cancel'.tr()),
            ),
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
class NotepadEncodingDialog extends ConsumerStatefulWidget {
  const NotepadEncodingDialog({
    super.key,
    required this.currentEncoding,
  });

  final String currentEncoding;

  @override
  ConsumerState<NotepadEncodingDialog> createState() =>
      _NotepadEncodingDialogState();
}

class _NotepadEncodingDialogState extends ConsumerState<NotepadEncodingDialog> {
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
                    if (value != null) {
                      setState(() => _selected = value);
                    }
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
                child: Text('common.cancel'.tr()),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => modals.complete(dialogId, _selected),
                child: Text('common.ok'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settings dialog: font size + default-encoding selectors.  Mirrors the
/// Avalonia `NotepadSettingsView`.
class NotepadSettingsDialog extends ConsumerStatefulWidget {
  const NotepadSettingsDialog({
    super.key,
    required this.fontSize,
    required this.defaultEncoding,
    required this.onFontSizeChanged,
    required this.onDefaultEncodingChanged,
    required this.fontSizes,
    this.onClose,
  });

  final double fontSize;
  final String defaultEncoding;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<String> onDefaultEncodingChanged;
  final List<double> fontSizes;
  final VoidCallback? onClose;

  @override
  ConsumerState<NotepadSettingsDialog> createState() =>
      _NotepadSettingsDialogState();
}

class _NotepadSettingsDialogState extends ConsumerState<NotepadSettingsDialog> {
  late double _fontSize = widget.fontSize;
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
          Text('notepad.settings.title'.tr(),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary)),
          const SizedBox(height: 18),
          Row(children: [
            SizedBox(
                width: 150,
                child: Text('common.font_size'.tr(),
                    style: TextStyle(color: palette.textSecondary))),
            Expanded(
              child: DropdownButton<double>(
                value: _fontSize,
                isExpanded: true,
                items: [
                  for (final size in widget.fontSizes)
                    DropdownMenuItem(
                        value: size, child: Text('${size.toInt()} pt')),
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
                child: Text('notepad.settings.default_encoding'.tr(),
                    style: TextStyle(color: palette.textSecondary))),
            Expanded(
              child: DropdownButton<String>(
                value: _defaultEncoding,
                isExpanded: true,
                items: [
                  for (final encoding in TextFileEncodings.available)
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
