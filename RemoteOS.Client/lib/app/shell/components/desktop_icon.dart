// Selectable desktop icon: double-tap / double-click opens the associated
// registered app.  Keeps its own hover/selection state locally because
// this is pure UI state (ARCHITECTURE.md § 8 + § 10).

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/apps/app_registry.dart';
import '../../../core/theme/theme_service.dart';

class DesktopIcon extends StatefulWidget {
  const DesktopIcon({
    super.key,
    required this.entry,
    required this.palette,
    required this.onOpen,
  });

  final AppRegistryEntry entry;
  final ThemePalette palette;
  final VoidCallback onOpen;

  @override
  State<DesktopIcon> createState() => _DesktopIconState();
}

class _DesktopIconState extends State<DesktopIcon> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _selected = true),
      onDoubleTap: widget.onOpen,
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color:
              _selected ? widget.palette.desktopIconSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _selected
                ? widget.palette.accent.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(widget.entry.icon,
                  size: 36, color: widget.palette.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              widget.entry.nameKey.tr(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.palette.textPrimary,
                fontSize: 11,
                height: 1.2,
                shadows: [
                  Shadow(
                    color: widget.palette.shellBackground.withValues(alpha: 0.9),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
