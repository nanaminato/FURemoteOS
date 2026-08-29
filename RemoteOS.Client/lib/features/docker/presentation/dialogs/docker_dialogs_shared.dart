// Docker feature — dialogs shared primitives + confirm-delete dialog.
//
// Destructive-action confirmation (shared across containers/stacks/images/
// networks/volumes) plus re-exports of the small dialog-footer and
// dialog-label components already in `docker_components.dart`.
//
// Using ConsumerWidget because dialogs need to read modalManagerProvider.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../../../core/window_manager/window_manager.dart';
import '../components/docker_components.dart';

/// Destructive-operation confirmation (Avalonia `ConfirmDialogView`).
class ConfirmDeleteDialog extends ConsumerWidget {
  const ConfirmDeleteDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final windowId = RemoteModalScope.of(context).windowId;
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(message,
                      style: TextStyle(color: palette.textPrimary)))),
          const SizedBox(height: 16),
          DialogFooter(actions: [
            OutlinedButton(
                onPressed: () =>
                    ref.read(modalManagerProvider).dismiss(windowId),
                child: Text('common.cancel'.tr())),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: palette.danger,
                    foregroundColor: palette.textOnDanger),
                onPressed: () =>
                    ref.read(modalManagerProvider).complete(windowId, true),
                child: Text('common.delete'.tr())),
          ]),
        ]));
  }
}
