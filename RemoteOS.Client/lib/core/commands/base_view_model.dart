// Base mixin for ViewModels (ARCHITECTURE.md § 7).
//
// ViewModels own presentation state via ValueNotifier / Listenable and expose
// user intents as Command objects.  ViewModels must never reference Flutter
// UI types (BuildContext, Widget, Navigator, showDialog, Theme.of, …).

/// Contract for any object that owns `ValueNotifier`, `StreamSubscription`,
/// `Command` or similar resources that need explicit cleanup.
abstract class Disposable {
  void dispose();
}

/// Mixin that tracks subscriptions and ValueNotifier-style objects.  A
/// ViewModel should call [trackDisposable] on every owned object so a single
/// [dispose] call cleans everything up.
mixin ViewModelLifecycle implements Disposable {
  final List<Object> _owned = [];
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Register a child object for disposal with this ViewModel.
  T trackDisposable<T extends Object>(T disposable) {
    if (_disposed) {
      _disposeOne(disposable);
    } else {
      _owned.add(disposable);
    }
    return disposable;
  }

  static void _disposeOne(Object o) {
    if (o is Disposable) o.dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final o in _owned.reversed) {
      // A disposal bug in one object must not prevent cleanup of the rest.
      // Individual services/loggers record their own diagnostic details.
      try {
        _disposeOne(o);
      } catch (_) {}
    }
    _owned.clear();
  }
}

/// Generic dialog state base.  ViewModels expose a
/// `ValueNotifier<DialogState>`; Views watch it and mount/unmount dialogs
/// via RemoteOS's ModalManager.  This keeps `showDialog()` out of
/// ViewModels (AGENTS.md rule 18 / ARCHITECTURE.md § 17).
sealed class DialogState {
  const DialogState();
}

final class NoDialog extends DialogState {
  const NoDialog();
}

/// Base class for feature ViewModels.  Exposes no Flutter UI types.
abstract class ViewModel with ViewModelLifecycle {}
