// Terminal View (xterm chrome + rendering host).
//
// Owns the xterm2 [Terminal] text buffer controller (because it is a
// rendering concern per ARCHITECTURE.md § 8 — VT/xterm parsing).  Pipes the
// inbound byte stream into it via a [TerminalOutputSink] installed on the
// ViewModel; user keystrokes / resizes / menu actions / context actions are
// routed back through the VM's typed methods and gating helpers.
//
// Performance (why output is batched): the SignalR hub can emit OnOutput
// dozens of times per frame during high-volume commands (`ls -laR /`, line
// noise, compiler output, etc).  Scheduling one addPostFrameCallback per
// chunk produced visible stutter because each enqueue forced a new
// microtask+frame for a single `_terminal.write()`.  The coalescing sink
// instead appends every chunk to a [StringBuffer] and schedules exactly one
// post-frame flush per frame, collapsing N SignalR events into one xterm
// buffer write.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm2/flutter.dart' as xterm;
import 'package:xterm2/xterm.dart';

import '../../../core/window_manager/modal_manager.dart';
import '../../../core/window_manager/window_manager.dart';
import '../application/terminal_view_model.dart';
import '../domain/terminal_repository.dart';
import '../domain/terminal_ui_state.dart';
import 'dialogs/terminal_settings_dialog.dart';
import 'terminal_output_queue.dart';

class TerminalView extends ConsumerStatefulWidget {
  const TerminalView({
    super.key,
    required this.vm,
    required this.serverUrl,
    required this.accessToken,
    this.workingDirectory,
    this.resumeSessionId,
  });

  final TerminalViewModel vm;
  final String serverUrl;
  final String accessToken;
  final String? workingDirectory;
  final String? resumeSessionId;

  @override
  ConsumerState<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends ConsumerState<TerminalView> {
  late final Terminal _terminal;
  late final xterm.TerminalController _terminalController;

  // ---- Appearance chrome ----
  // Option lists + default scheme live on [TerminalSettingsDialog] so the
  // dialog and view stay in sync without duplicating constants.
  String _colorScheme = TerminalSettingsDialog.defaultScheme;
  double _fontSize = 14;
  String _fontFamily = 'Cascadia Mono';

  // ---- Output coalescing ----
  static const _maxOutputCodeUnitsPerFrame = 32 * 1024;
  final TerminalOutputQueue _pendingOutput = TerminalOutputQueue();
  bool _outputFlushScheduled = false;

  // Resizing a desktop window can change the xterm grid dozens of times per
  // second. Coalescing the geometry before it crosses the SignalR boundary
  // prevents a slow Windows PTY resize from competing with typing and paint.
  static const _resizeDebounce = Duration(milliseconds: 80);
  Timer? _resizeDebounceTimer;
  ({int columns, int rows, int widthPixels, int heightPixels})? _pendingResize;

  // ---- Selection-aware menu state ----
  bool _hasSelection = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _terminalController = xterm.TerminalController();
    widget.vm.outputSink = _writeChunk;
    widget.vm.requestSettingsAsync = _showSettingsDialog;
    _terminal
      ..onOutput = _handleKeystroke
      ..onResize = _handleResize
      ..onTitleChange = widget.vm.setTitle;
    _terminalController.addListener(_onControllerChanged);
    // Kick off the PTY handshake once the xterm controller knows its size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.vm.prepareStartArgs((
        serverUrl: widget.serverUrl,
        accessToken: widget.accessToken,
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
        workingDirectory: widget.workingDirectory,
        resumeSessionId: widget.resumeSessionId,
      ));
      if (widget.vm.startCommand.canRun.value) {
        widget.vm.startCommand();
      }
    });
  }

  @override
  void dispose() {
    _terminalController.removeListener(_onControllerChanged);
    _resizeDebounceTimer?.cancel();
    _pendingResize = null;
    _pendingOutput.clear();
    widget.vm.requestSettingsAsync = null;
    widget.vm.outputSink = null;
    super.dispose();
  }

  void _onControllerChanged() {
    final sel = _terminalController.selection;
    final nowHasSel = sel != null;
    if (nowHasSel != _hasSelection) {
      setState(() => _hasSelection = nowHasSel);
    }
  }

  // ---- Coalesced output flush ----

  void _writeChunk(String chunk) {
    _pendingOutput.add(chunk);
    _scheduleOutputFlush();
  }

  void _scheduleOutputFlush() {
    if (_outputFlushScheduled || _pendingOutput.isEmpty) return;
    _outputFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _outputFlushScheduled = false;
      if (!mounted) {
        _pendingOutput.clear();
        return;
      }
      if (_pendingOutput.isEmpty) return;
      final chunk = _pendingOutput.takeUpTo(_maxOutputCodeUnitsPerFrame);
      _terminal.write(chunk);
      _scheduleOutputFlush();
    });
    // A post-frame callback is passive: when the terminal is otherwise idle,
    // registering one does not create a frame. SignalR output can therefore
    // remain queued until unrelated pointer/window activity schedules paint.
    // Requesting a frame is idempotent when one is already pending and keeps
    // the existing one-flush-per-frame backpressure policy intact.
    WidgetsBinding.instance.scheduleFrame();
  }

  // ---- Input / resize → VM ----

  void _handleKeystroke(String value) {
    if (widget.vm.canSendInput()) {
      // ignore: discarded_futures
      widget.vm.sendInput(value);
    }
  }

  void _handleResize(int cols, int rows, int wpx, int hpx) {
    if (!widget.vm.canResize()) return;
    _pendingResize = (
      columns: cols,
      rows: rows,
      widthPixels: wpx,
      heightPixels: hpx,
    );
    _resizeDebounceTimer?.cancel();
    _resizeDebounceTimer = Timer(_resizeDebounce, _flushPendingResize);
  }

  void _flushPendingResize() {
    final resize = _pendingResize;
    _pendingResize = null;
    if (!mounted || resize == null || !widget.vm.canResize()) return;
    // ignore: discarded_futures
    widget.vm.resize(
      resize.columns,
      resize.rows,
      widthPx: resize.widthPixels,
      heightPx: resize.heightPixels,
    );
  }

  // ---- Context-menu actions (copy/paste/select-all/clear) ----

  Future<void> _copySelection() async {
    final range = _terminalController.selection;
    if (range == null) return;
    final text = _terminal.buffer.getText(range);
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _terminal.paste(text);
  }

  void _selectAll() {
    final rows = _terminal.viewHeight;
    final cols = _terminal.viewWidth;
    if (rows <= 0 || cols <= 0) return;
    final buffer = _terminal.buffer;
    final lines = buffer.lines;
    if (lines.length == 0) return;
    // createAnchor(x, y) — column first, line second (matches xterm2 buffer API).
    final start = buffer.createAnchor(0, 0);
    final lastLine = (lines.length - 1).clamp(0, 1 << 31);
    final lastCols =
        lines.length > 0 ? (lines[lastLine].length - 1).clamp(0, 1 << 31) : 0;
    final end = buffer.createAnchor(
      lastCols > 0 ? lastCols : (cols - 1).clamp(0, 1 << 31),
      lastLine,
    );
    _terminalController.setSelection(start, end);
    setState(() => _hasSelection = true);
  }

  void _clearTerminal() {
    // Drop both the visible viewport rows and the scrollback history above
    // to match Avalonia's ClearHistory + ClearScrollback.
    _terminal.clear();
    _terminal.buffer.clearScrollback();
    _terminalController.clearSelection();
    setState(() => _hasSelection = false);
  }

  // ---- Settings dialog ----
  //
  // Hosted through [ModalManager] so the dialog is owned by this terminal
  // app's [RemoteWindowScope] — it only blocks the terminal window (Avalonia
  // ModalBlocker semantics) instead of the whole workspace window, and it
  // participates in desktop z-order + focus restoration.  Matches the
  // pattern used by NotepadView for `NotepadSettingsDialog`.

  Future<void> _showSettingsDialog() {
    final ownerId = RemoteWindowScope.of(context).window.id;
    return ref.read(modalManagerProvider).open<void>(
          ownerId: ownerId,
          spec: ModalSpec(
            title: 'terminal.settings'.tr(),
            icon: Icons.tune_outlined,
            preferredSize: const Size(440, 320),
            child: TerminalSettingsDialog(
              colorScheme: _colorScheme,
              fontSize: _fontSize,
              fontFamily: _fontFamily,
              onColorSchemeChanged: (value) {
                if (!mounted) return;
                setState(() => _colorScheme = value);
              },
              onFontSizeChanged: (value) {
                if (!mounted) return;
                setState(() => _fontSize = value);
              },
              onFontFamilyChanged: (value) {
                if (!mounted) return;
                setState(() => _fontFamily = value);
              },
            ),
          ),
        );
  }

  // ==========================================================================
  // Build
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final palette = _resolvePalette(_colorScheme);
    return ColoredBox(
      color: palette.background,
      child: Column(
        children: [
          // ---- Menu bar row (matches Avalonia TerminalView.axaml Grid[0]) ----
          _buildChrome(palette),
          ListenableBuilder(
            listenable: widget.vm.state,
            builder: (context, _) {
              final err = widget.vm.state.value.errorMessage;
              if (err == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(
                  'terminal.status.start_failed'.tr(args: [err]),
                  style: TextStyle(color: palette.bad, fontSize: 12),
                ),
              );
            },
          ),
          Expanded(
            child: _buildTerminalHost(palette),
          ),
        ],
      ),
    );
  }

  Widget _buildChrome(_TerminalPalette palette) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border:
            Border(bottom: BorderSide(color: palette.borderDefault, width: 1)),
      ),
      child: Row(
        children: [
          // ---- Terminal (menu) ----
          _TerminalMenuButton(
            label: 'terminal.menu'.tr(),
            items: [
              PopupMenuItem<void>(
                onTap: () {
                  if (widget.vm.openSettingsCommand.canRun.value) {
                    widget.vm.openSettingsCommand();
                  } else {
                    // ignore: discarded_futures
                    _showSettingsDialog();
                  }
                },
                child: Text('terminal.settings'.tr()),
              ),
            ],
          ),
          // ---- Status line (right of menu, matches Avalonia) ----
          const SizedBox(width: 8),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.vm.state,
              builder: (context, _) {
                final s = widget.vm.state.value;
                final text = _resolveStatusLabel(s, palette);
                return Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          // ---- Session id tail (subtle, matches previous chrome) ----
          ListenableBuilder(
            listenable: widget.vm.state,
            builder: (context, _) {
              final sessionId = widget.vm.state.value.sessionId;
              if (sessionId == null) return const SizedBox.shrink();
              final tail = sessionId.length > 8
                  ? sessionId.substring(sessionId.length - 8)
                  : sessionId;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  tail,
                  style: TextStyle(
                    color: palette.session,
                    fontSize: 11,
                    fontFamily: _fontFamily,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalHost(_TerminalPalette palette) {
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(details.globalPosition, palette),
      child: xterm.TerminalView(
        _terminal,
        controller: _terminalController,
        theme: palette.toTerminalTheme(),
        textStyle: xterm.TerminalStyle(
          fontSize: _fontSize,
          fontFamily: _fontFamily,
        ),
      ),
    );
  }

  // ---- Context menu ----

  void _showContextMenu(Offset globalPosition, _TerminalPalette palette) {
    final box = context.findRenderObject() as RenderBox?;
    final relative =
        box == null ? globalPosition : box.globalToLocal(globalPosition);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(relative, relative),
        box == null ? Offset.zero & const Size(1, 1) : Offset.zero & box.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          enabled: _hasSelection,
          child: Text('terminal.context.copy'.tr()),
        ),
        PopupMenuItem<String>(
          value: 'paste',
          child: Text('terminal.context.paste'.tr()),
        ),
        PopupMenuItem<String>(
          value: 'select_all',
          child: Text('terminal.context.select_all'.tr()),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'clear',
          child: Text('terminal.context.clear'.tr()),
        ),
      ],
      elevation: 8,
    ).then<void>((value) async {
      if (!mounted || value == null) return;
      switch (value) {
        case 'copy':
          await _copySelection();
          break;
        case 'paste':
          await _pasteFromClipboard();
          break;
        case 'select_all':
          _selectAll();
          break;
        case 'clear':
          _clearTerminal();
          break;
      }
    });
  }

  // ---- Status label (localized, View owns l10n per § 8) ----

  String _resolveStatusLabel(TerminalUiState s, _TerminalPalette _) {
    final title = s.title;
    if (title != null && title.isNotEmpty) return title;
    switch (s.connectionState) {
      case TerminalConnectionState.connecting:
        return 'terminal.status.connecting'.tr();
      case TerminalConnectionState.connected:
        return 'terminal.status.connected'.tr();
      case TerminalConnectionState.exited:
        final code = s.exitCode;
        if (code == null) return 'terminal.status.process_exited'.tr();
        return 'terminal.status.process_exited_with_code'
            .tr(args: [code.toString()]);
      case TerminalConnectionState.disconnected:
        return 'terminal.status.process_exited'.tr();
    }
  }

  // ---- Palette / theme helpers ----

  static _TerminalPalette _resolvePalette(String scheme) {
    switch (scheme) {
      case 'One Half Dark':
        return const _TerminalPalette(
          tag: 'One Half Dark',
          background: Color(0xFF282C34),
          foreground: Color(0xFFDCDFE4),
          cursor: Color(0xFFFFFFFF),
          surfaceRaised: Color(0xFF2E323C),
          borderDefault: Color(0xFF3E4451),
          ok: Color(0xFF98C379),
          bad: Color(0xFFE06C75),
          textSecondary: Color(0xFFDCDFE4),
          session: Color(0xFF61AFEF),
        );
      case 'Solarized Dark':
        return const _TerminalPalette(
          tag: 'Solarized Dark',
          background: Color(0xFF002B36),
          foreground: Color(0xFF839496),
          cursor: Color(0xFF93A1A1),
          surfaceRaised: Color(0xFF073642),
          borderDefault: Color(0xFF0A4554),
          ok: Color(0xFF859900),
          bad: Color(0xFFDC322F),
          textSecondary: Color(0xFF93A1A1),
          session: Color(0xFF268BD2),
        );
      case 'Light':
        return const _TerminalPalette(
          tag: 'Light',
          background: Color(0xFFFFFFFF),
          foreground: Color(0xFF1E1E1E),
          cursor: Color(0xFF000000),
          surfaceRaised: Color(0xFFF3F3F3),
          borderDefault: Color(0xFFE5E5E5),
          ok: Color(0xFF16A34A),
          bad: Color(0xFFDC2626),
          textSecondary: Color(0xFF4B5563),
          session: Color(0xFF2563EB),
        );
      case 'Campbell':
      default:
        return const _TerminalPalette(
          tag: 'Campbell',
          background: Color(0xFF0C0C0C),
          foreground: Color(0xFFCCCCCC),
          cursor: Color(0xFFFFFFFF),
          surfaceRaised: Color(0xFF1A1A1A),
          borderDefault: Color(0xFF2E2E2E),
          ok: Color(0xFF16A34A),
          bad: Color(0xFFC50F1F),
          textSecondary: Color(0xFFCCCCCC),
          session: Color(0xFF3B78FF),
        );
    }
  }
}

// ============================================================================
// Supporting types
// ============================================================================

/// Custom window-menu style button that anchors a Flutter popup menu like a
/// desktop menu bar item.  Keeps the Avalonia-like flat, compact, hoverable
/// menu head instead of Material's default PopupMenuButton icon button.
class _TerminalMenuButton extends StatefulWidget {
  const _TerminalMenuButton({
    required this.label,
    required this.items,
  });

  final String label;
  final List<PopupMenuEntry<void>> items;

  @override
  State<_TerminalMenuButton> createState() => _TerminalMenuButtonState();
}

class _TerminalMenuButtonState extends State<_TerminalMenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: _openMenu,
        onHover: (v) => setState(() => _hover = v),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _hover
                ? Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }

  void _openMenu() {
    final box = context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy + box.size.height,
      box.size.width,
      0,
    );
    showMenu<void>(
      context: context,
      position: RelativeRect.fromRect(
        rect,
        Offset.zero & MediaQuery.sizeOf(context),
      ),
      items: widget.items,
      elevation: 6,
    );
  }
}

/// Color abstraction shared by chrome + xterm theme.  Values align with
/// Avalonia's `TerminalAppearance.ApplyScheme` presets.
class _TerminalPalette {
  const _TerminalPalette({
    required this.tag,
    required this.background,
    required this.foreground,
    required this.cursor,
    required this.surfaceRaised,
    required this.borderDefault,
    required this.ok,
    required this.bad,
    required this.textSecondary,
    required this.session,
  });

  final String tag;
  final Color background;
  final Color foreground;
  final Color cursor;
  final Color surfaceRaised;
  final Color borderDefault;
  final Color ok;
  final Color bad;
  final Color textSecondary;
  final Color session;

  TerminalTheme toTerminalTheme() {
    return TerminalTheme(
      cursor: cursor,
      selection: cursor.withValues(alpha: 0.25),
      foreground: foreground,
      background: background,
      black: _shade(background, 0.1),
      red: bad,
      green: ok,
      yellow: const Color(0xFFE9B949),
      blue: session,
      magenta: const Color(0xFFB4009E),
      cyan: const Color(0xFF3A96DD),
      white: foreground,
      brightBlack: const Color(0xFF767676),
      brightRed: const Color(0xFFE74856),
      brightGreen: const Color(0xFF16C60C),
      brightYellow: const Color(0xFFF9F1A5),
      brightBlue: const Color(0xFF3B78FF),
      brightMagenta: const Color(0xFFB4009E),
      brightCyan: const Color(0xFF61D6D6),
      brightWhite: const Color(0xFFF2F2F2),
      searchHitBackground: cursor.withValues(alpha: 0.2),
      searchHitBackgroundCurrent: cursor.withValues(alpha: 0.5),
      searchHitForeground: background,
    );
  }

  static Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}
