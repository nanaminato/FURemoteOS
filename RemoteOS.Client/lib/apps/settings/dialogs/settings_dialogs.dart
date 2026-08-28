// Dialog helpers used by the Settings app. Kept in a dedicated `dialogs/`
// folder in accordance with AGENTS.md rule 4.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/theme_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A confirmation dialog (OK/Cancel). Returns `true` when the user accepts.
Future<bool?> showConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  String title,
  String message,
) {
  final palette = watchPalette(ref, context);
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
  final palette = watchPalette(ref, context);
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
            onPressed: () => Navigator.pop(c),
            child: Text('common.ok'.tr())),
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
