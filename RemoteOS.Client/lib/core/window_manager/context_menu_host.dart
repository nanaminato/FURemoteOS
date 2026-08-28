import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controller shared by a [ContextMenuHost] and any [ContextMenuRegion] below
/// it. Menus are overlay content rather than Material route popups, keeping
/// them in the managed desktop's focus and z-order model.
class RemoteContextMenuController {
  _ContextMenuHostState? _host;

  bool get isOpen => _host?._entry != null;

  void show(Offset position, List<ContextMenuEntry> entries) =>
      _host?._show(position, entries);

  void dismiss() => _host?._dismiss();
}

sealed class ContextMenuEntry {
  const ContextMenuEntry();
}

class ContextMenuAction extends ContextMenuEntry {
  const ContextMenuAction({
    required this.label,
    required this.onSelected,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onSelected;
}

class ContextMenuDivider extends ContextMenuEntry {
  const ContextMenuDivider();
}

class ContextMenuSubmenu extends ContextMenuEntry {
  const ContextMenuSubmenu({
    required this.label,
    required this.entries,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final bool enabled;
  final List<ContextMenuEntry> entries;
}

class ContextMenuHost extends StatefulWidget {
  const ContextMenuHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final RemoteContextMenuController controller;
  final Widget child;

  @override
  State<ContextMenuHost> createState() => _ContextMenuHostState();
}

class _ContextMenuHostState extends State<ContextMenuHost> {
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    widget.controller._host = this;
  }

  @override
  void didUpdateWidget(covariant ContextMenuHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._host = null;
      widget.controller._host = this;
    }
  }

  @override
  void dispose() {
    widget.controller._host = null;
    _dismiss();
    super.dispose();
  }

  void _show(Offset position, List<ContextMenuEntry> entries) {
    _dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (context) => _ContextMenuOverlay(
        position: position,
        entries: entries,
        onDismiss: _dismiss,
      ),
    );
    overlay.insert(_entry!);
  }

  void _dismiss() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Attaches a context-menu request to arbitrary desktop content.
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({
    super.key,
    required this.controller,
    required this.entries,
    required this.child,
  });

  final RemoteContextMenuController controller;
  final List<ContextMenuEntry> entries;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) =>
            controller.show(details.globalPosition, entries),
        child: child,
      );
}

class _ContextMenuOverlay extends StatefulWidget {
  const _ContextMenuOverlay({
    required this.position,
    required this.entries,
    required this.onDismiss,
  });

  final Offset position;
  final List<ContextMenuEntry> entries;
  final VoidCallback onDismiss;

  @override
  State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay> {
  static const _menuWidth = 240.0;
  static const _edgeMargin = 6.0;
  ContextMenuSubmenu? _openSubmenu;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'Remote context menu');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final estimatedHeight = widget.entries.fold<double>(
      16,
      (height, entry) => height + (entry is ContextMenuDivider ? 9 : 36),
    );
    final left = widget.position.dx
        .clamp(_edgeMargin, screen.width - _menuWidth - _edgeMargin)
        .toDouble();
    final top = widget.position.dy
        .clamp(_edgeMargin, screen.height - estimatedHeight - _edgeMargin)
        .toDouble();
    final opensLeft = left + _menuWidth * 2 + _edgeMargin > screen.width;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onDismiss();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: _ContextMenuPanel(
              entries: widget.entries,
              onDismiss: widget.onDismiss,
              onSubmenu: (submenu) => setState(() => _openSubmenu = submenu),
            ),
          ),
          if (_openSubmenu != null)
            Positioned(
              left: opensLeft ? left - _menuWidth + 4 : left + _menuWidth - 4,
              top: top,
              child: _ContextMenuPanel(
                entries: _openSubmenu!.entries,
                onDismiss: widget.onDismiss,
                onSubmenu: (_) {},
              ),
            ),
        ],
      ),
    );
  }
}

class _ContextMenuPanel extends StatelessWidget {
  const _ContextMenuPanel({
    required this.entries,
    required this.onDismiss,
    required this.onSubmenu,
  });

  final List<ContextMenuEntry> entries;
  final VoidCallback onDismiss;
  final ValueChanged<ContextMenuSubmenu> onSubmenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SizedBox(
        width: 240,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in entries)
                switch (entry) {
                  ContextMenuDivider() => const Divider(height: 9),
                  ContextMenuAction() => _MenuActionTile(
                      entry: entry,
                      onDismiss: onDismiss,
                    ),
                  ContextMenuSubmenu() => _MenuSubmenuTile(
                      entry: entry,
                      onHover: () => onSubmenu(entry),
                    ),
                },
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuActionTile extends StatelessWidget {
  const _MenuActionTile({required this.entry, required this.onDismiss});
  final ContextMenuAction entry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: entry.enabled
            ? () {
                onDismiss();
                entry.onSelected();
              }
            : null,
        child: SizedBox(
          height: 36,
          child: Row(
            children: [
              const SizedBox(width: 12),
              SizedBox(
                width: 22,
                child: entry.icon == null ? null : Icon(entry.icon, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(entry.label)),
              const SizedBox(width: 12),
            ],
          ),
        ),
      );
}

class _MenuSubmenuTile extends StatelessWidget {
  const _MenuSubmenuTile({required this.entry, required this.onHover});
  final ContextMenuSubmenu entry;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => onHover(),
        child: InkWell(
          onTap: entry.enabled ? onHover : null,
          child: SizedBox(
            height: 36,
            child: Row(
              children: [
                const SizedBox(width: 12),
                SizedBox(
                  width: 22,
                  child: entry.icon == null ? null : Icon(entry.icon, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.label)),
                const Icon(Icons.chevron_right_rounded, size: 18),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      );
}
