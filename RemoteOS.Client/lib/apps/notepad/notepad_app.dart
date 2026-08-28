import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/network/remoteos_api.dart';
import '../../core/theme/theme_service.dart';
import '../../core/window_manager/modal_manager.dart';
import '../../core/window_manager/window_manager.dart';
import '../../features/files/data/remote_file_api.dart';
import '../../features/files/text_file_encodings.dart';
import '../../features/workspace/application/workspace_sync_coordinator.dart';
import '../explorer/explorer_picker.dart';

/// Mirrors `Client.Apps.Notepad.NotepadApp.SupportedExtensions`. The built-in
/// text editor accepts all of these extensions (and extension-less files)
/// when opened from Explorer or via the open-file picker.
const List<String> _supportedExtensions = [
  '.txt', '.text', '.md', '.markdown', '.mdx', '.rst', '.adoc', '.asciidoc',
  '.log', '.nfo', '.csv', '.tsv', '.tab', '.ini', '.cfg', '.conf', '.config',
  '.properties', '.yaml', '.yml', '.toml', '.xml', '.xsd', '.xsl', '.xslt',
  '.json', '.jsonc', '.json5', '.html', '.htm', '.xhtml', '.css', '.scss',
  '.sass', '.less', '.tex', '.bib', '.srt', '.vtt', '.ics', '.vcf', '.diff',
  '.patch', '.asc', '.pem', '.crt', '.cer', '.pub',
];

/// The Notepad application, migrated from the Avalonia
/// `Client.Apps.Notepad.NotepadApp` + `NotepadViewModel`. It edits remote
/// text files through the file API and supports reopen/save with an
/// explicit encoding, mirroring the original capabilities.
class NotepadApp extends ConsumerStatefulWidget {
  const NotepadApp({super.key, this.initialPath});

  /// Optional remote path opened directly at activation, mirroring the
  /// original `NotepadApp.OpenFile(context, path)` entry point.
  final String? initialPath;

  @override
  ConsumerState<NotepadApp> createState() => _NotepadAppState();
}

class _NotepadAppState extends ConsumerState<NotepadApp> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  // Document state — mirrors `NotepadViewModel` observable properties.
  String? _currentPath;
  String _encodingName = 'UTF-8';
  String _defaultEncodingName = 'UTF-8';
  bool _isDirty = false;
  bool _isLoading = false;
  String _statusText = '';
  double _fontSize = 14;

  static const List<double> _fontSizes = [12, 13, 14, 16, 18, 20];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _statusText = 'notepad.status.ready'.tr();
    final preferences = ref.read(workspaceSyncProvider).preferences;
    final stored = preferences?.notepadDefaultEncoding;
    _defaultEncodingName = TextFileEncodings.isSupported(stored)
        ? stored!
        : TextFileEncodings.defaultEncoding;
    _encodingName = _defaultEncodingName;
    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openPath(widget.initialPath!, _encodingName));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_isLoading) return;
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  int get _lineCount => '\n'.allMatches(_controller.text).length + 1;
  int get _charCount => _controller.text.length;
  bool get _hasOpenFile => _currentPath != null && _currentPath!.isNotEmpty;
  String get _documentName {
    if (_currentPath == null || _currentPath!.isEmpty) {
      return 'notepad.document.untitled'.tr();
    }
    final normalized = _currentPath!.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? _currentPath! : parts.last;
  }

  // ---- Document commands ----

  Future<void> _newDocument() async {
    if (_isDirty && !await _confirmDiscard(
        'notepad.reopen_dirty_title'.tr(),
        'notepad.reopen_dirty_message'.tr())) {
      return;
    }
    _isLoading = true;
    _controller.clear();
    setState(() {
      _currentPath = null;
      _encodingName = _defaultEncodingName;
      _isDirty = false;
      _statusText = 'notepad.status.new_document'.tr();
    });
    _isLoading = false;
  }

  Future<void> _openDocument() async {
    final path = await showRemoteFilePicker(
      ref,
      context,
      filters: [
        ExplorerFileFilter(
          label: 'notepad.text_file_filter'.tr(),
          patterns: [
            for (final extension in _supportedExtensions) '*$extension',
          ],
          includeExtensionlessFiles: true,
        ),
        ExplorerFileFilter.allFiles,
      ],
    );
    if (path == null || path.isEmpty) return;
    await _openPath(path, _defaultEncodingName);
  }

  Future<void> _openPath(String path, String requestedEncoding) async {
    if (!TextFileEncodings.isSupported(requestedEncoding)) return;
    try {
      final bytes = await RemoteFileApi(ref.read(remoteOsApiProvider))
          .readBytes(path);
      if (bytes.isEmpty) {
        setState(() {
          _statusText = 'notepad.status.file_missing'.tr();
        });
        return;
      }
      _isLoading = true;
      final decoded = TextFileEncodings.decode(bytes, requestedEncoding);
      _controller.text = decoded;
      setState(() {
        _currentPath = path;
        _encodingName = requestedEncoding;
        _isDirty = false;
        _statusText = 'notepad.status.opened'
            .tr(args: [_baseName(path), requestedEncoding]);
      });
    } catch (error) {
      setState(() {
        _statusText =
            'notepad.status.open_failed'.tr(args: [error.toString()]);
      });
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _save() async {
    var path = _currentPath;
    if (path == null || path.isEmpty) {
      path = await _requestSavePath('untitled.txt');
      if (path == null || path.isEmpty) return;
    }
    await _saveToPath(path);
  }

  Future<void> _saveAs() async {
    final suggested = (_currentPath == null || _currentPath!.isEmpty)
        ? 'untitled.txt'
        : _baseName(_currentPath!);
    final path = await _requestSavePath(suggested);
    if (path == null || path.isEmpty) return;
    await _saveToPath(path);
  }

  Future<void> _saveToPath(String path) async {
    try {
      final bytes =
          TextFileEncodings.encode(_controller.text, _encodingName);
      await RemoteFileApi(ref.read(remoteOsApiProvider))
          .writeBytes(path, bytes);
      setState(() {
        _currentPath = path;
        _isDirty = false;
        _statusText = 'notepad.status.saved'
            .tr(args: [_baseName(path), _encodingName]);
      });
    } catch (error) {
      setState(() {
        _statusText =
            'notepad.status.save_failed'.tr(args: [error.toString()]);
      });
    }
  }

  Future<String?> _requestSavePath(String defaultName) async {
    return ref.read(modalManagerProvider).open<String>(
      ownerId: RemoteWindowScope.of(context).window.id,
      spec: ModalSpec(
        title: 'notepad.save_remote_file'.tr(),
        icon: Icons.save_outlined,
        preferredSize: const Size(440, 230),
        child: _SavePathDialog(
          prompt: 'notepad.remote_path_prompt'.tr(),
          initialValue: defaultName,
        ),
      ),
    );
  }

  Future<void> _chooseEncoding() async {
    if (!_hasOpenFile) return;
    final action = await ref.read(modalManagerProvider).open<_EncodingAction>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: 'common.file_encoding'.tr(),
            icon: Icons.translate_rounded,
            preferredSize: const Size(420, 220),
            child: const _EncodingActionDialog(),
          ),
        );
    if (action == null) return;
    final encoding = await ref.read(modalManagerProvider).open<String>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: 'common.file_encoding'.tr(),
            icon: Icons.translate_rounded,
            preferredSize: const Size(420, 360),
            child: _EncodingDialog(currentEncoding: _encodingName),
          ),
        );
    if (encoding == null || encoding.trim().isEmpty) return;
    if (action == _EncodingAction.reopen) {
      await _reopenWithEncoding(encoding);
    } else {
      await _saveWithEncoding(encoding);
    }
  }

  Future<void> _reopenWithEncoding(String encodingName) async {
    if (!_hasOpenFile || !TextFileEncodings.isSupported(encodingName)) return;
    if (_isDirty && !await _confirmDiscard(
        'notepad.reopen_dirty_title'.tr(),
        'notepad.reopen_dirty_message'.tr())) {
      return;
    }
    setState(() => _encodingName = encodingName);
    await _openPath(_currentPath!, encodingName);
  }

  Future<void> _saveWithEncoding(String encodingName) async {
    if (!_hasOpenFile || !TextFileEncodings.isSupported(encodingName)) return;
    setState(() => _encodingName = encodingName);
    await _saveToPath(_currentPath!);
  }

  Future<bool> _confirmDiscard(String title, String message) {
    return ref
        .read(modalManagerProvider)
        .open<bool>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: title,
            icon: Icons.warning_amber_rounded,
            preferredSize: const Size(440, 230),
            child: _ConfirmDialog(
              title: title,
              message: message,
              confirmLabel: 'notepad.discard_changes'.tr(),
            ),
          ),
        )
        .then((value) => value == true);
  }

  Future<void> _openSettings() async {
    await ref.read(modalManagerProvider).open<void>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
            title: 'notepad.settings.title'.tr(),
            icon: Icons.tune_outlined,
            preferredSize: const Size(440, 320),
            child: _SettingsDialog(
              fontSize: _fontSize,
              defaultEncoding: _defaultEncodingName,
              onFontSizeChanged: (size) => setState(() => _fontSize = size),
              onDefaultEncodingChanged: (encoding) {
                setState(() => _defaultEncodingName = encoding);
                _saveDefaultEncoding(encoding);
              },
            ),
          ),
        );
  }

  void _saveDefaultEncoding(String encoding) {
    final current = ref.read(workspaceSyncProvider).preferences;
    if (current == null) return;
    ref
        .read(workspaceSyncProvider.notifier)
        .queuePreferences(current.copyWith(notepadDefaultEncoding: encoding));
  }

  String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? normalized : parts.last;
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Column(
        children: [
          _buildMenuBar(palette),
          Expanded(
            child: Container(
              color: palette.surface,
              child: TextField(
                controller: _controller,
                scrollController: _scrollController,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontFamilyFallback: const ['Courier New', 'monospace'],
                  fontSize: _fontSize,
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
                  contentPadding: const EdgeInsets.all(14),
                  hintText: 'Start typing...',
                  hintStyle:
                      TextStyle(color: palette.textTertiary, fontSize: _fontSize),
                  isCollapsed: true,
                  isDense: false,
                ),
              ),
            ),
          ),
          _buildStatusBar(palette),
        ],
      ),
    );
  }

  // ---- Keyboard shortcuts ----

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (!ctrl) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyN && !shift) {
      _newDocument();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyO && !shift) {
      _openDocument();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS && !shift) {
      _save();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS && shift) {
      _saveAs();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildMenuBar(ThemePalette palette) {
    return Container(
      height: 32,
      color: palette.windowTitleBarBackground,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          _menuButton(palette, Icons.description_outlined, 'common.file'.tr(), [
            MenuItemButton(
              onPressed: _newDocument,
              leadingIcon: const Icon(Icons.note_add_outlined, size: 16),
              child: Text(
                  '${'common.new'.tr()}    Ctrl+N',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _openDocument,
              leadingIcon: const Icon(Icons.folder_open_outlined, size: 16),
              child: Text(
                  '${'common.open_ellipsis'.tr()}    Ctrl+O',
                  style: const TextStyle(fontSize: 13)),
            ),
            const MenuItemButton(child: Divider(height: 1)),
            MenuItemButton(
              onPressed: _save,
              leadingIcon: const Icon(Icons.save_outlined, size: 16),
              child: Text(
                  '${'common.save'.tr()}    Ctrl+S',
                  style: const TextStyle(fontSize: 13)),
            ),
            MenuItemButton(
              onPressed: _saveAs,
              leadingIcon: const Icon(Icons.save_as_outlined, size: 16),
              child: Text('${'common.save_as_ellipsis'.tr()}    Ctrl+Shift+S',
                  style: const TextStyle(fontSize: 13)),
            ),
          ]),
          _menuButton(palette, Icons.tune_outlined, 'common.settings'.tr(), [
            MenuItemButton(
              onPressed: _openSettings,
              leadingIcon: const Icon(Icons.settings_outlined, size: 16),
              child: Text('common.preferences_ellipsis'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _documentName,
              style: TextStyle(
                fontSize: 12,
                color: palette.windowTitleForeground.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButton(ThemePalette palette, IconData icon, String label,
      List<Widget> children) {
    return MenuAnchor(
      builder: (context, controller, _) => InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, size: 14, color: palette.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: palette.windowTitleForeground)),
            ],
          ),
        ),
      ),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(palette.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: palette.borderSubtle)),
        ),
      ),
      menuChildren: children,
    );
  }

  Widget _buildStatusBar(ThemePalette palette) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _statusText,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textTertiary, fontSize: 11),
            ),
          ),
          if (_hasOpenFile) ...[
            TextButton(
              onPressed: _chooseEncoding,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: palette.textTertiary,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: Text(_encodingName),
            ),
            const SizedBox(width: 14),
          ],
          Text(
            'common.line_count_format'.tr(args: ['$_lineCount']),
            style: TextStyle(color: palette.textTertiary, fontSize: 11),
          ),
          const SizedBox(width: 14),
          Text(
            'common.character_count_format'.tr(args: ['$_charCount']),
            style: TextStyle(color: palette.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Save-as path input dialog. Mirrors Avalonia's `TextInputDialogView` used
/// by `NotepadApp.RequestSavePathAsync`.
class _SavePathDialog extends ConsumerStatefulWidget {
  const _SavePathDialog({required this.prompt, required this.initialValue});
  final String prompt;
  final String initialValue;

  @override
  ConsumerState<_SavePathDialog> createState() => _SavePathDialogState();
}

class _SavePathDialogState extends ConsumerState<_SavePathDialog> {
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

/// Confirmation dialog used for "discard unsaved changes?" prompts. Mirrors
/// `ConfirmDialogView`.
class _ConfirmDialog extends ConsumerWidget {
  const _ConfirmDialog({
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
/// with the new encoding. Mirrors `EncodingActionDialogView`.
enum _EncodingAction { reopen, save }

class _EncodingActionDialog extends ConsumerWidget {
  const _EncodingActionDialog();

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
              () => modals.complete(dialogId, _EncodingAction.reopen)),
          _actionTile(palette, 'common.save'.tr(),
              () => modals.complete(dialogId, _EncodingAction.save)),
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
/// the picked one. Mirrors `EncodingDialogView`.
class _EncodingDialog extends ConsumerStatefulWidget {
  const _EncodingDialog({required this.currentEncoding});
  final String currentEncoding;

  @override
  ConsumerState<_EncodingDialog> createState() => _EncodingDialogState();
}

class _EncodingDialogState extends ConsumerState<_EncodingDialog> {
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

/// Settings dialog with font-size + default-encoding selectors. Mirrors the
/// Avalonia `NotepadSettingsView` (kept on the same `NotepadViewModel`).
class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog({
    required this.fontSize,
    required this.defaultEncoding,
    required this.onFontSizeChanged,
    required this.onDefaultEncodingChanged,
  });
  final double fontSize;
  final String defaultEncoding;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<String> onDefaultEncodingChanged;

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
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
                  for (final size in _NotepadAppState._fontSizes)
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
              onPressed: () => modals.dismiss(dialogId),
              child: Text('common.done'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}


