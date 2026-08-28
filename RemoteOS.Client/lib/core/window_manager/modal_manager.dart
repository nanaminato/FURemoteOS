import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'window_manager.dart';

/// Description of a dialog hosted by [ModalManager]. Dialogs are managed
/// windows, never route-level Material dialogs, so they remain inside their
/// owner chain and participate in desktop z-order and focus restoration.
class ModalSpec {
  const ModalSpec({
    required this.title,
    required this.icon,
    required this.child,
    this.preferredSize = const Size(460, 320),
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Size preferredSize;
}

class ModalManager {
  const ModalManager(this._windows);

  final WindowManagerNotifier _windows;

  Future<T?> open<T>({required String ownerId, required ModalSpec spec}) {
    final owner = _windows.state.where((item) => item.id == ownerId);
    if (owner.isEmpty) {
      throw StateError('Cannot open a modal for unknown owner $ownerId.');
    }
    return _windows.showDialog<T>(
      owner: owner.first,
      title: spec.title,
      icon: spec.icon,
      child: spec.child,
      preferredSize: spec.preferredSize,
    );
  }

  void complete<T>(String dialogId, [T? value]) =>
      _windows.completeDialog<T>(dialogId, value);

  void dismiss(String dialogId) => _windows.completeDialog(dialogId);
}

final modalManagerProvider = Provider<ModalManager>(
  (ref) => ModalManager(ref.read(windowManagerProvider.notifier)),
);
