import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/remoteos_api.dart';
import '../../core/window_manager/modal_manager.dart';
import '../../core/window_manager/window_manager.dart';
import '../../features/docker/data/remote_docker_api.dart';
import '../common/workspace_scaffold.dart';

class DockerManagerApp extends ConsumerWidget {
  const DockerManagerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = RemoteDockerApi(ref.read(remoteOsApiProvider));
    return WorkspaceScaffold(
        title: 'Docker Manager',
        icon: Icons.integration_instructions_outlined,
        actions: [
          IconButton(
              tooltip: 'Create container',
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () => _create(context, ref, api))
        ],
        pages: [
          WorkspacePage(
              id: 'overview',
              title: 'Overview',
              icon: Icons.dashboard_outlined,
              builder: (_) => _StatusPage(load: api.status)),
          WorkspacePage(
              id: 'containers',
              title: 'Containers',
              icon: Icons.view_in_ar_outlined,
              builder: (_) => _ContainersPage(api: api)),
          WorkspacePage(
              id: 'images',
              title: 'Images',
              icon: Icons.layers_outlined,
              builder: (_) => _ListPage<DockerImage>(
                  load: api.images,
                  empty: 'No images found.',
                  title: (item) => '${item.repository}:${item.tag}',
                  detail: (item) => '${item.size} · ${item.createdSince}')),
          WorkspacePage(
              id: 'volumes',
              title: 'Volumes',
              icon: Icons.storage_outlined,
              builder: (_) => _ListPage<DockerVolume>(
                  load: api.volumes,
                  empty: 'No volumes found.',
                  title: (item) => item.name,
                  detail: (item) => '${item.driver} · ${item.mountpoint}')),
          WorkspacePage(
              id: 'networks',
              title: 'Networks',
              icon: Icons.hub_outlined,
              builder: (_) => _ListPage<DockerNetwork>(
                  load: api.networks,
                  empty: 'No networks found.',
                  title: (item) => item.name,
                  detail: (item) => '${item.driver} · ${item.scope}')),
          WorkspacePage(
              id: 'stacks',
              title: 'Stacks',
              icon: Icons.account_tree_outlined,
              builder: (_) => _ListPage<DockerStack>(
                  load: api.stacks,
                  empty: 'No Compose stacks found.',
                  title: (item) => item.name,
                  detail: (item) =>
                      '${item.status} · ${item.configDirectory}')),
        ]);
  }

  Future<void> _create(
      BuildContext context, WidgetRef ref, RemoteDockerApi api) async {
    final request = await ref
        .read(modalManagerProvider)
        .open<DockerContainerCreate>(
            ownerId: RemoteWindowScope.of(context).window.id,
            spec: const ModalSpec(
                title: 'Create container',
                icon: Icons.add_box_outlined,
                preferredSize: Size(720, 690),
                child: _CreateContainerDialog()));
    if (request == null || !context.mounted) return;
    try {
      final result = await api.createContainer(request);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                result.success ? 'Container created.' : result.problemCode)));
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _CreateContainerDialog extends ConsumerStatefulWidget {
  const _CreateContainerDialog();
  @override
  ConsumerState<_CreateContainerDialog> createState() =>
      _CreateContainerDialogState();
}

class _CreateContainerDialogState
    extends ConsumerState<_CreateContainerDialog> {
  final name = TextEditingController(),
      image = TextEditingController(),
      args = TextEditingController(),
      ports = TextEditingController(),
      environment = TextEditingController(),
      mounts = TextEditingController(),
      network = TextEditingController();
  String restart = '';
  List<String> _lines(TextEditingController value) => value.text
      .split('\n')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();
  @override
  void dispose() {
    name.dispose();
    image.dispose();
    args.dispose();
    ports.dispose();
    environment.dispose();
    mounts.dispose();
    network.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = RemoteModalScope.of(context).windowId;
    final modal = ref.read(modalManagerProvider);
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(
              controller: name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Name')),
          TextField(
              controller: image,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Image')),
          Expanded(
              child: ListView(children: [
            TextField(
                controller: args,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Arguments (one per line)')),
            TextField(
                controller: ports,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Ports (one per line)')),
            TextField(
                controller: environment,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Environment (one per line)')),
            TextField(
                controller: mounts,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Mounts (one per line)')),
            TextField(
                controller: network,
                decoration: const InputDecoration(labelText: 'Network')),
            DropdownButtonFormField<String>(
                value: restart,
                decoration: const InputDecoration(labelText: 'Restart policy'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('None')),
                  DropdownMenuItem(value: 'no', child: Text('No')),
                  DropdownMenuItem(value: 'always', child: Text('Always')),
                  DropdownMenuItem(
                      value: 'unless-stopped', child: Text('Unless stopped')),
                  DropdownMenuItem(
                      value: 'on-failure', child: Text('On failure'))
                ],
                onChanged: (value) => setState(() => restart = value ?? ''))
          ])),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
                onPressed: () => modal.dismiss(id),
                child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: name.text.trim().isEmpty || image.text.trim().isEmpty
                    ? null
                    : () => modal.complete(
                        id,
                        DockerContainerCreate(
                            name: name.text.trim(),
                            image: image.text.trim(),
                            arguments: _lines(args),
                            ports: _lines(ports),
                            environment: _lines(environment),
                            mounts: _lines(mounts),
                            network: network.text.trim(),
                            restartPolicy: restart)),
                child: const Text('Create'))
          ])
        ]));
  }
}

class _StatusPage extends StatefulWidget {
  const _StatusPage({required this.load});
  final Future<DockerStatus> Function() load;
  @override
  State<_StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<_StatusPage> {
  late Future<DockerStatus> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DockerStatus>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _Error(
              error: snapshot.error!,
              retry: () => setState(() => future = widget.load()));
        final value = snapshot.requireData;
        return Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  value.available
                      ? 'Docker Engine is available'
                      : 'Docker Engine is unavailable',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Version: ${value.version ?? '—'}'),
              Text('Operating system: ${value.operatingSystem ?? '—'}'),
              Text('Architecture: ${value.architecture ?? '—'}'),
              if (!value.available && value.problemCode.isNotEmpty)
                Text('Server status: ${value.problemCode}')
            ]));
      });
}

class _ListPage<T> extends StatefulWidget {
  const _ListPage(
      {required this.load,
      required this.empty,
      required this.title,
      required this.detail});
  final Future<List<T>> Function() load;
  final String empty;
  final String Function(T) title, detail;
  @override
  State<_ListPage<T>> createState() => _ListPageState<T>();
}

class _ListPageState<T> extends State<_ListPage<T>> {
  late Future<List<T>> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _Error(
              error: snapshot.error!,
              retry: () => setState(() => future = widget.load()));
        final values = snapshot.requireData;
        if (values.isEmpty) return Center(child: Text(widget.empty));
        return RefreshIndicator(
            onRefresh: () async => setState(() => future = widget.load()),
            child: ListView.builder(
                itemCount: values.length,
                itemBuilder: (_, index) {
                  final item = values[index];
                  return ListTile(
                      title: Text(widget.title(item)),
                      subtitle: Text(widget.detail(item)),
                      dense: true);
                }));
      });
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Unable to load Docker data: $error'),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: retry, child: const Text('Retry'))
      ]));
}

class _ContainersPage extends ConsumerStatefulWidget {
  const _ContainersPage({required this.api});
  final RemoteDockerApi api;
  @override
  ConsumerState<_ContainersPage> createState() => _ContainersPageState();
}

class _ContainersPageState extends ConsumerState<_ContainersPage> {
  late Future<List<DockerContainer>> future;
  @override
  void initState() {
    super.initState();
    future = widget.api.containers();
  }

  Future<void> _act(DockerContainer item, String action) async {
    final destructive = action != 'start';
    if (destructive) {
      final ok = await ref.read(modalManagerProvider).open<bool>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
              title: '${action == 'delete' ? 'Delete' : 'Stop'} container',
              icon: Icons.warning_amber_outlined,
              preferredSize: const Size(430, 230),
              child: _ConfirmDockerAction(
                  message:
                      '${action == 'delete' ? 'Delete' : 'Stop'} ${item.name}?')));
      if (ok != true) return;
    }
    try {
      final result = await widget.api
          .containerAction(item.id, action, confirmed: destructive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.success
              ? 'Container action completed.'
              : result.problemCode)));
      if (result.success) setState(() => future = widget.api.containers());
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _details(DockerContainer item) async {
    try {
      final responses = await Future.wait([
        widget.api.containerDetails(item.id),
        widget.api.containerLogs(item.id),
        widget.api.containerStats(item.id)
      ]);
      final details = responses[0] as DockerContainerDetails?;
      if (!mounted || details == null) return;
      await ref.read(modalManagerProvider).open<void>(
          ownerId: RemoteWindowScope.of(context).window.id,
          spec: ModalSpec(
              title: 'Container details',
              icon: Icons.info_outline,
              preferredSize: const Size(720, 620),
              child: _ContainerDetailsDialog(
                  details: details,
                  logs: responses[1] as DockerContainerLogs?,
                  stats: responses[2] as DockerContainerStats?)));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DockerContainer>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _Error(
              error: snapshot.error!,
              retry: () => setState(() => future = widget.api.containers()));
        final items = snapshot.requireData;
        if (items.isEmpty)
          return const Center(child: Text('No containers found.'));
        return ListView(children: [
          for (final item in items)
            ListTile(
                onTap: () => _details(item),
                title: Text(item.name),
                subtitle:
                    Text('${item.image} · ${item.state} · ${item.status}'),
                trailing: Wrap(children: [
                  IconButton(
                      tooltip: 'Start',
                      icon: const Icon(Icons.play_arrow),
                      onPressed: item.state == 'running'
                          ? null
                          : () => _act(item, 'start')),
                  IconButton(
                      tooltip: 'Stop',
                      icon: const Icon(Icons.stop),
                      onPressed: item.state == 'running'
                          ? () => _act(item, 'stop')
                          : null),
                  IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _act(item, 'delete'))
                ]))
        ]);
      });
}

class _ContainerDetailsDialog extends ConsumerWidget {
  const _ContainerDetailsDialog({required this.details, this.logs, this.stats});
  final DockerContainerDetails details;
  final DockerContainerLogs? logs;
  final DockerContainerStats? stats;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = RemoteModalScope.of(context).windowId;
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(details.name, style: Theme.of(context).textTheme.titleLarge),
          Text('${details.image} · ${details.state} · ${details.status}'),
          const SizedBox(height: 16),
          if (details.ports.isNotEmpty)
            Text('Ports: ${details.ports.join(', ')}'),
          if (details.mounts.isNotEmpty)
            Text('Mounts: ${details.mounts.join(', ')}'),
          if (details.networks.isNotEmpty)
            Text('Networks: ${details.networks.join(', ')}'),
          if (stats != null) ...[
            const SizedBox(height: 12),
            Text('CPU ${stats!.cpu} · Memory ${stats!.memory}'),
            Text('Network ${stats!.networkIo} · Block I/O ${stats!.blockIo}')
          ],
          const SizedBox(height: 12),
          const Text('Logs'),
          Expanded(
              child: SingleChildScrollView(
                  child: SelectableText(
                      logs?.lines.join('\n') ?? 'No logs returned.'))),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => ref.read(modalManagerProvider).dismiss(id),
                  child: const Text('Close')))
        ]));
  }
}

class _ConfirmDockerAction extends ConsumerWidget {
  const _ConfirmDockerAction({required this.message});
  final String message;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = RemoteModalScope.of(context).windowId;
    final modal = ref.read(modalManagerProvider);
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
                onPressed: () => modal.dismiss(id),
                child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: () => modal.complete(id, true),
                child: const Text('Confirm'))
          ])
        ]));
  }
}
