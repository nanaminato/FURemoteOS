// Code Editor main view.
//
// Assembles the chrome pieces (menu bar, tab bar, explorer, editor area,
// status bar) and triggers the remote-load hook on first paint.

import 'package:flutter/material.dart';

import '../application/code_editor_view_model.dart';
import 'components/code_editor_components.dart';

class CodeEditorView extends StatefulWidget {
  const CodeEditorView({super.key, required this.vm});

  final CodeEditorViewModel vm;

  @override
  State<CodeEditorView> createState() => _CodeEditorViewState();
}

class _CodeEditorViewState extends State<CodeEditorView> {
  @override
  void initState() {
    super.initState();
    widget.vm.scheduleInitialLoad();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CodeEditorMenuBar(vm: widget.vm),
        ListenableBuilder(
          listenable: widget.vm.state,
          builder: (_, __) => CodeEditorTabBar(state: widget.vm.state.value),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.vm.state,
            builder: (_, __) => Row(
              children: [
                if (widget.vm.state.value.showExplorer)
                  CodeEditorExplorer(vm: widget.vm),
                Expanded(child: CodeEditorTextField(vm: widget.vm)),
              ],
            ),
          ),
        ),
        CodeEditorStatusBar(vm: widget.vm),
      ],
    );
  }
}
