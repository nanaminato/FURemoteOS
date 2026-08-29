// Settings dialog helpers (AGENTS.md § 18: View owns dialog APIs,
// ViewModel owns dialog state / user choices).  These widgets intentionally
// remain lightweight wrappers around Flutter showDialog; the ViewModel
// receives their return values via closures passed from pages.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/settings_widgets.dart';

/// A confirmation dialog (OK/Cancel). Returns `true` when the user accepts.
Future<bool?> showConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  String title,
  String message,
) {
  final palette = WatchItExtension.readPalette(context);
  return showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: palette.surface,
      title: Text(title,
          style: TextStyle(color: palette.textPrimary, fontSize: 16)),
      content: Text(message,
          style: TextStyle(color: palette.textSecondary, fontSize: 13)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('common.cancel'.tr())),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('common.ok'.tr())),
      ],
    ),
  );
}

/// An informational dialog with a scrollable body and a single OK action.
Future<void> showInfoDialog(
  BuildContext context,
  WidgetRef ref,
  String title,
  String body,
) async {
  final palette = WatchItExtension.readPalette(context);
  await showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: palette.surface,
      title: Text(title,
          style: TextStyle(color: palette.textPrimary, fontSize: 16)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Text(body,
              style: TextStyle(color: palette.textSecondary, fontSize: 13)),
        ),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(c), child: Text('common.ok'.tr())),
      ],
    ),
  );
}

/// Shows a short snack bar message. Falls back gracefully when no
/// [ScaffoldMessenger] is mounted (e.g. inside a desktop window without a
/// Scaffold ancestor).
void showInfoSnack(
  BuildContext context,
  String msg, {
  VoidCallback? onFallback,
}) {
  final scaffold = ScaffoldMessenger.maybeOf(context);
  if (scaffold == null) {
    onFallback?.call();
    return;
  }
  scaffold.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}
