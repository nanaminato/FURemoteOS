// Docker feature — resource creation + unavailable dialogs (presentation).
//
// Four small dialogs bundled together since each is <100 lines and they
// share the same simple form-plus-footer pattern:
//   * PullImageDialog        (Avalonia DockerPullImageDialogView)
//   * CreateNetworkDialog    (Avalonia DockerNetworkDialogView)
//   * CreateVolumeDialog     (Avalonia DockerVolumeDialogView)
//   * DockerUnavailableDialog (engine / install-hint alert)

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../application/docker_view_model.dart';
import '../components/docker_components.dart';

// ---------------------------------------------------------------------------
// Pull-image dialog
// ---------------------------------------------------------------------------

class PullImageDialog extends ConsumerStatefulWidget {
  const PullImageDialog({super.key, required this.vm});

  final DockerViewModel vm;

  @override
  ConsumerState<PullImageDialog> createState() => _PullImageDialogState();
}

class _PullImageDialogState extends ConsumerState<PullImageDialog> {
  final reference = TextEditingController();

  @override
  void dispose() {
    reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.vm.pullImage(reference.text);
    if (ok && mounted) {
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
                    DialogLabel('docker.image.reference'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: reference,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            hintText: 'nginx:latest', isDense: true)),
                  ])),
              const SizedBox(height: 16),
              DialogFooter(actions: [
                OutlinedButton(
                    onPressed: () => dismissCurrentDialog(ref, context),
                    child: Text('common.cancel'.tr())),
                FilledButton(
                    onPressed:
                        reference.text.trim().isEmpty || widget.vm.isLoading
                            ? null
                            : _submit,
                    child: Text('docker.image.pull'.tr())),
              ]),
            ])));
  }
}

// ---------------------------------------------------------------------------
// Create-network dialog
// ---------------------------------------------------------------------------

class CreateNetworkDialog extends ConsumerStatefulWidget {
  const CreateNetworkDialog({super.key, required this.vm});

  final DockerViewModel vm;

  @override
  ConsumerState<CreateNetworkDialog> createState() =>
      _CreateNetworkDialogState();
}

class _CreateNetworkDialogState extends ConsumerState<CreateNetworkDialog> {
  final name = TextEditingController();
  String driver = 'bridge';

  Future<void> _submit() async {
    final ok = await widget.vm.tryCreateNetwork(name.text, driver);
    if (ok && mounted) {
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
                    DialogLabel('common.name'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: name,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(isDense: true)),
                    const SizedBox(height: 12),
                    DialogLabel('docker.network.driver'.tr(), palette),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                        initialValue: driver,
                        items: [
                          for (final value in DockerViewModel.networkDrivers)
                            DropdownMenuItem(value: value, child: Text(value))
                        ],
                        onChanged: (value) =>
                            setState(() => driver = value ?? 'bridge'),
                        decoration: const InputDecoration(isDense: true)),
                  ])),
              const SizedBox(height: 16),
              DialogFooter(actions: [
                OutlinedButton(
                    onPressed: () => dismissCurrentDialog(ref, context),
                    child: Text('common.cancel'.tr())),
                FilledButton(
                    onPressed: name.text.trim().isEmpty || widget.vm.isLoading
                        ? null
                        : _submit,
                    child: Text('common.create'.tr())),
              ]),
            ])));
  }
}

// ---------------------------------------------------------------------------
// Create-volume dialog
// ---------------------------------------------------------------------------

class CreateVolumeDialog extends ConsumerStatefulWidget {
  const CreateVolumeDialog({super.key, required this.vm});

  final DockerViewModel vm;

  @override
  ConsumerState<CreateVolumeDialog> createState() => _CreateVolumeDialogState();
}

class _CreateVolumeDialogState extends ConsumerState<CreateVolumeDialog> {
  final name = TextEditingController();
  String driver = 'local';

  Future<void> _submit() async {
    final ok = await widget.vm.tryCreateVolume(name.text, driver);
    if (ok && mounted) {
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
                    DialogLabel('common.name'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: name,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(isDense: true)),
                    const SizedBox(height: 12),
                    DialogLabel('docker.volume.driver'.tr(), palette),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                        initialValue: driver,
                        items: [
                          for (final value in DockerViewModel.volumeDrivers)
                            DropdownMenuItem(value: value, child: Text(value))
                        ],
                        onChanged: (value) =>
                            setState(() => driver = value ?? 'local'),
                        decoration: const InputDecoration(isDense: true)),
                  ])),
              const SizedBox(height: 16),
              DialogFooter(actions: [
                OutlinedButton(
                    onPressed: () => dismissCurrentDialog(ref, context),
                    child: Text('common.cancel'.tr())),
                FilledButton(
                    onPressed: name.text.trim().isEmpty || widget.vm.isLoading
                        ? null
                        : _submit,
                    child: Text('common.create'.tr())),
              ]),
            ])));
  }
}

// ---------------------------------------------------------------------------
// Docker-unavailable dialog
// ---------------------------------------------------------------------------

class DockerUnavailableDialog extends ConsumerWidget {
  const DockerUnavailableDialog({super.key, required this.vm});

  final DockerViewModel vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final windowId = currentModalWindowId(context);
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: HintText(
                      'docker.unavailable_dialog.message'.tr(), palette))),
          const SizedBox(height: 16),
          DialogFooter(actions: [
            OutlinedButton(
                onPressed: vm.isLoading ? null : () => vm.refresh(),
                child: Text('common.refresh'.tr())),
            FilledButton(
                onPressed: () =>
                    ref.read(modalManagerProvider).dismiss(windowId),
                child: Text('common.ok'.tr())),
          ]),
        ]));
  }
}
