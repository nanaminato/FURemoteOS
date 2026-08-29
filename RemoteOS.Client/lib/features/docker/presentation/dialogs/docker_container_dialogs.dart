// Docker feature — container-related dialogs (presentation).
//
// Three dialogs bundled because they share a dependency on the container
// domain and common dialog primitives:
//   * CreateContainerDialog (Create new container)
//   * EditContainerDialog   (Rename existing container)
//   * ContainerDetailsDialog (Read-only structured container inspector)
//
// Mirrors Avalonia views: DockerContainerDialogView,
// DockerContainerEditDialogView, DockerContainerDetailsDialogView.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../application/docker_view_model.dart';
import '../../data/remote_docker_api.dart';
import '../components/docker_components.dart';

// ---------------------------------------------------------------------------
// Create-container dialog
// ---------------------------------------------------------------------------

class CreateContainerDialog extends ConsumerStatefulWidget {
  const CreateContainerDialog({super.key, required this.vm});

  final DockerViewModel vm;

  @override
  ConsumerState<CreateContainerDialog> createState() =>
      _CreateContainerDialogState();
}

class _CreateContainerDialogState extends ConsumerState<CreateContainerDialog> {
  final name = TextEditingController();
  final image = TextEditingController();
  final ports = TextEditingController();
  final mounts = TextEditingController();
  final environment = TextEditingController();
  final arguments = TextEditingController();
  String network = 'bridge';
  String restartPolicy = 'unless-stopped';

  @override
  void initState() {
    super.initState();
    network = widget.vm.availableNetworks.contains('bridge')
        ? 'bridge'
        : widget.vm.availableNetworks.firstOrNull ?? 'bridge';
  }

  @override
  void dispose() {
    name.dispose();
    image.dispose();
    ports.dispose();
    mounts.dispose();
    environment.dispose();
    arguments.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.vm.tryCreateContainer(
      name: name.text,
      image: image.text,
      arguments: splitLines(arguments),
      ports: splitLines(ports),
      environment: splitLines(environment),
      mounts: splitLines(mounts),
      network: network,
      restartPolicy: restartPolicy,
    );
    if (ok && mounted) {
      completeCurrentDialog(ref, context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final valid = name.text.trim().isNotEmpty && image.text.trim().isNotEmpty;
    return ValueListenableBuilder(
        valueListenable: widget.vm.state,
        builder: (context, _, __) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Expanded(
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    HintText('docker.containers_hint'.tr(), palette),
                    const SizedBox(height: 12),
                    DialogLabel(
                        'docker.container.section.identity'.tr(), palette),
                    const SizedBox(height: 6),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: TextField(
                                  controller: name,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                      labelText: 'docker.container.name'.tr(),
                                      isDense: true))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextField(
                                  controller: image,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                      hintText: 'nginx:latest',
                                      labelText: 'docker.container.image'.tr(),
                                      isDense: true))),
                        ]),
                    const SizedBox(height: 12),
                    DialogLabel(
                        'docker.container.section.runtime'.tr(), palette),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                          child: DropdownButtonFormField<String>(
                              initialValue:
                                  widget.vm.availableNetworks.contains(network)
                                      ? network
                                      : widget.vm.availableNetworks.firstOrNull,
                              items: [
                                for (final value in widget.vm.availableNetworks)
                                  DropdownMenuItem(
                                      value: value, child: Text(value))
                              ],
                              onChanged: (value) =>
                                  setState(() => network = value ?? 'bridge'),
                              decoration: InputDecoration(
                                  labelText: 'docker.container.network'.tr(),
                                  isDense: true))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: DropdownButtonFormField<String>(
                              initialValue: restartPolicy,
                              items: [
                                for (final value
                                    in DockerViewModel.restartPolicies)
                                  DropdownMenuItem(
                                      value: value, child: Text(value))
                              ],
                              onChanged: (value) =>
                                  setState(() => restartPolicy = value ?? 'no'),
                              decoration: InputDecoration(
                                  labelText: 'docker.container.restart'.tr(),
                                  isDense: true))),
                    ]),
                    const SizedBox(height: 12),
                    DialogLabel(
                        'docker.container.section.connectivity'.tr(), palette),
                    const SizedBox(height: 6),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: TextField(
                                  controller: ports,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                      hintText: '8080:80',
                                      labelText: 'docker.container.ports'.tr(),
                                      isDense: true))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextField(
                                  controller: mounts,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                      hintText: 'volume:/data',
                                      labelText: 'docker.container.mounts'.tr(),
                                      isDense: true))),
                        ]),
                    const SizedBox(height: 12),
                    DialogLabel(
                        'docker.container.section.configuration'.tr(), palette),
                    const SizedBox(height: 6),
                    DialogLabel('docker.container.environment'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: environment,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            hintText: 'KEY=value', isDense: true)),
                    const SizedBox(height: 10),
                    DialogLabel('docker.container.arguments'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: arguments,
                        maxLines: 3,
                        decoration: const InputDecoration(isDense: true)),
                  ]))),
              const SizedBox(height: 12),
              DialogFooter(actions: [
                OutlinedButton(
                    onPressed: () => dismissCurrentDialog(ref, context),
                    child: Text('common.cancel'.tr())),
                FilledButton(
                    onPressed: valid && !widget.vm.isLoading ? _submit : null,
                    child: Text('docker.container.create'.tr())),
              ]),
            ])));
  }
}

// ---------------------------------------------------------------------------
// Rename-container dialog
// ---------------------------------------------------------------------------

class EditContainerDialog extends ConsumerStatefulWidget {
  const EditContainerDialog({
    super.key,
    required this.vm,
    required this.container,
  });

  final DockerViewModel vm;
  final DockerContainer container;

  @override
  ConsumerState<EditContainerDialog> createState() =>
      _EditContainerDialogState();
}

class _EditContainerDialogState extends ConsumerState<EditContainerDialog> {
  late final name = TextEditingController(text: widget.container.name);

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.vm.tryUpdateContainer(widget.container, name.text);
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
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    HintText('docker.container.edit_hint'.tr(), palette),
                    const SizedBox(height: 10),
                    DialogLabel('docker.container.name'.tr(), palette),
                    const SizedBox(height: 4),
                    TextField(
                        controller: name,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(isDense: true)),
                    const SizedBox(height: 8),
                    DialogLabel(widget.container.image, palette),
                  ]))),
              const SizedBox(height: 12),
              DialogFooter(actions: [
                FilledButton(
                    onPressed: name.text.trim().isEmpty || widget.vm.isLoading
                        ? null
                        : _submit,
                    child: Text('docker.container.save'.tr())),
                OutlinedButton(
                    onPressed: () => dismissCurrentDialog(ref, context),
                    child: Text('common.cancel'.tr())),
              ]),
            ])));
  }
}

// ---------------------------------------------------------------------------
// Container details dialog
// ---------------------------------------------------------------------------

class ContainerDetailsDialog extends ConsumerWidget {
  const ContainerDetailsDialog({super.key, required this.vm});

  final DockerViewModel vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final details = vm.containerDetails;
    final windowId = currentModalWindowId(context);
    if (details == null) {
      return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Expanded(
                child: Center(
                    child: HintText('docker.problem.failed'.tr(), palette))),
            DialogFooter(actions: [
              OutlinedButton(
                  onPressed: () =>
                      ref.read(modalManagerProvider).dismiss(windowId),
                  child: Text('common.close'.tr())),
            ]),
          ]));
    }
    Widget field(String label, String value) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DialogLabel(label, palette),
          const SizedBox(height: 2),
          ReadOnlyBlock(text: value, palette: palette, minHeight: 30),
        ]);
    Widget section(String label, String value,
            {double minHeight = 44, bool mono = false}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: palette.textSecondary))),
          const SizedBox(height: 4),
          ReadOnlyBlock(
              text: value,
              palette: palette,
              minHeight: minHeight,
              maxHeight: 210,
              mono: mono),
        ]);
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          HintText('docker.container.details_copy_hint'.tr(), palette),
          const SizedBox(height: 12),
          Expanded(
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                field('docker.container.name'.tr(), details.name),
                const SizedBox(height: 6),
                field('docker.container.id'.tr(), details.id),
                const SizedBox(height: 6),
                field('docker.container.image'.tr(), details.image),
                const SizedBox(height: 6),
                field('docker.table.state'.tr(), details.state),
                const SizedBox(height: 6),
                field('docker.table.status'.tr(), details.status),
                const SizedBox(height: 6),
                field('docker.container.created_at'.tr(), details.created),
                const SizedBox(height: 6),
                field('docker.container.restart'.tr(), details.restartPolicy),
                const SizedBox(height: 6),
                field('docker.container.working_directory'.tr(),
                    details.workingDirectory),
                const SizedBox(height: 6),
                field('docker.container.command'.tr(), details.command),
                section(
                    'docker.container.ports'.tr(), details.ports.join('\n')),
                section('docker.container.networks'.tr(),
                    details.networks.join('\n')),
                section(
                    'docker.container.mounts'.tr(), details.mounts.join('\n'),
                    minHeight: 72),
                section('docker.container.environment'.tr(),
                    details.environment.join('\n'),
                    minHeight: 92, mono: true),
                section(
                    'docker.container.labels'.tr(),
                    details.labels.entries
                        .map((label) => '${label.key}=${label.value}')
                        .join('\n'),
                    minHeight: 92,
                    mono: true),
              ]))),
          const SizedBox(height: 12),
          DialogFooter(actions: [
            OutlinedButton(
                onPressed: () async => copyToClipboard(vm.containerDetailsText),
                child: Text('common.copy'.tr())),
            OutlinedButton(
                onPressed: () =>
                    ref.read(modalManagerProvider).dismiss(windowId),
                child: Text('common.close'.tr())),
          ]),
        ]));
  }
}
