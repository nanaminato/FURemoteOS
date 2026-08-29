// Terminal app shell (thin entry per AGENTS.md § 2).
//
// Composes the transient [TerminalViewModel] with the [TerminalView].
// Session credentials (server URL + access token) are resolved from the
// riverpod auth provider in this ConsumerState and forwarded.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../features/terminal/application/terminal_view_model.dart';
import '../../features/terminal/presentation/terminal_view.dart';

class TerminalApp extends ConsumerStatefulWidget {
  const TerminalApp({
    super.key,
    this.workingDirectory,
    this.sessionId,
  });

  final String? workingDirectory;
  final String? sessionId;

  @override
  ConsumerState<TerminalApp> createState() => _TerminalAppState();
}

class _TerminalAppState extends ConsumerState<TerminalApp> {
  TerminalViewModel? _vm;

  @override
  void initState() {
    super.initState();
    final session = ref.read(authProvider);
    if (session.isAuthenticated) {
      _vm = createTerminalViewModel();
    }
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    final vm = _vm;
    if (!session.isAuthenticated ||
        session.serverUrl == null ||
        session.accessToken == null ||
        vm == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Not signed in.')),
      );
    }
    return TerminalView(
      vm: vm,
      serverUrl: session.serverUrl!,
      accessToken: session.accessToken!,
      workingDirectory: widget.workingDirectory,
      resumeSessionId: widget.sessionId,
    );
  }
}
