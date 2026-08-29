// Docker feature — stack dialog (presentation).
//
// Compose stack deploy + edit dialog (two modes controlled by optional
// `initialName` / `initialYaml` parameters).  Mirrors Avalonia
// DockerStackDialogView.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_service.dart';
import '../../application/docker_view_model.dart';
import '../components/docker_components.dart';

class StackDialog extends ConsumerStatefulWidget {
  const StackDialog({
    super.key,
    required this.vm,
    this.initialName = '',
    this.initialYaml = '',
  });

  final DockerViewModel vm;
  final String initialName;
  final String initialYaml;

  @override
  ConsumerState<StackDialog> createState() => _StackDialogState();
}

class _StackDialogState extends ConsumerState<StackDialog> {
  late final name = TextEditingController(text: widget.initialName);
  late final yaml = TextEditingController(text: widget.initialYaml);

  @override
  void dispose() {
    name.dispose();
    yaml.dispose();
    super.dispose();
  }

  Future<void> _submit(bool deploy) async {
    final ok = deploy
        ? await widget.vm
            .deployStack(name: name.text, composeYaml: yaml.text)
        : await widget.vm
            .validateStack(name: name.text, composeYaml: yaml.text);
    if (ok && deploy && mounted) {
      completeCurrentDialog(ref, context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return ValueListenableBuilder(
        valueListenable: widget.vm.state,
        builder: (context, _, __) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    HintText('docker.stacks_hint'.tr(), palette),
                    const SizedBox(height: 12),
                    DialogLabel('docker.stack.name'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: name,
                        decoration: const InputDecoration(
                            hintText: 'my-stack', isDense: true)),
                    const SizedBox(height: 12),
                    DialogLabel('docker.stack.compose'.tr(), palette),
                    const SizedBox(height: 4),
                    Expanded(
                        child: TextField(
                            controller: yaml,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(fontFamily: 'monospace'),
                            decoration: const InputDecoration(
                                hintText:
                                    'services:\n  web:\n    image: nginx:latest',
                                isDense: true))),
                  ])),
              const SizedBox(height: 12),
              DialogFooter(actions: [
                OutlinedButton(
                    onPressed:
                        widget.vm.isLoading ? null : () => _submit(false),
                    child: Text('docker.stack.validate'.tr())),
                FilledButton(
                    onPressed:
                        widget.vm.isLoading ? null : () => _submit(true),
                    child: Text('docker.stack.deploy'.tr())),
                OutlinedButton(
                    onPressed: () => dismissCurrentDialog(ref, context),
                    child: Text('common.cancel'.tr())),
              ]),
            ])));
  }
}
