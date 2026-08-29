// Docker feature — ViewModel (ARCHITECTURE.md § 9).
//
// Presentation state is exposed as a single immutable [DockerUiState] via
// [ValueNotifier]; user intents are [Command]s.
// Repository I/O is delegated to [DockerRepository].
//
// Hooks that require Flutter UI (open dialogs, launch explorer) are exposed as
// callbacks set by the owning View (AGENTS.md § 18 — ViewModels must not call
// showDialog / Navigator / Widget APIs directly).

import 'package:command_it/command_it.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../core/commands/base_view_model.dart';
import '../data/remote_docker_api.dart';
import '../domain/docker_ui_state.dart';
import 'docker_repository.dart';

/// Signature used by [DockerViewModel] to request a confirmation dialog.
typedef ConfirmCallback = Future<bool> Function(String message);

/// Signature used by [DockerViewModel] to open the file explorer at a path.
typedef OpenPathCallback = Future<void> Function(String path);

/// Signature used by [DockerViewModel] to open a stack-edit dialog.
typedef EditStackCallback = Future<void> Function(
    String name, String composeYaml);

/// Empty callback placeholders (default no-ops, never null).
Future<bool> _noopConfirm(String _) async => false;
Future<void> _noopVoid(String _) async {}
Future<void> _noopStack(String a, String b) async {}
Future<void> _noop0() async {}
Future<void> _noopEdit(DockerContainer _) async {}

class DockerViewModel extends ViewModel {
  DockerViewModel(this._repository) {
    trackDisposable(state);
    trackDisposable(refreshCommand);
    trackDisposable(containerDetailsCommand);
    trackDisposable(containerLogsCommand);
    trackDisposable(containerStatsCommand);
    trackDisposable(stackServicesCommand);
    trackDisposable(editStackCommand);
    trackDisposable(deleteImageCommand);
    trackDisposable(deleteNetworkCommand);
    trackDisposable(deleteVolumeCommand);
  }

  final DockerRepository _repository;

  final ValueNotifier<DockerUiState> state =
      ValueNotifier<DockerUiState>(DockerUiState.initial());

  // ---- View-installed hooks (never call Flutter UI from VM directly) ----
  Future<void> Function()? onDockerUnavailable;
  Future<void> Function()? onContainerDetails;
  EditStackCallback onEditStack = _noopStack;
  ConfirmCallback onConfirmDelete = _noopConfirm;
  OpenPathCallback onOpenPath = _noopVoid;
  Future<void> Function(DockerContainer container) onEditContainer = _noopEdit;

  bool _dialogShowing = false;

  // ---- Static policy lists (mirror DockerRepository) ----
  static const networkDrivers = DockerRepository.networkDrivers;
  static const volumeDrivers = DockerRepository.volumeDrivers;
  static const restartPolicies = DockerRepository.restartPolicies;

  // ---- Convenience getters mirroring old _DockerVm API -------------
  String get statusText => state.value.statusText;
  bool get isLoading => state.value.isLoading;
  bool get isOperationRunning => state.value.isOperationRunning;
  String get operationTitle => state.value.operationTitle;
  String get operationLog => state.value.operationLog;
  bool get isDockerAvailable => state.value.isDockerAvailable;
  bool get isDockerInstallRequired => state.value.isDockerInstallRequired;
  String get engineVersion => state.value.engineVersion;
  String get enginePlatform => state.value.enginePlatform;

  List<DockerContainer> get containers => state.value.containers;
  List<DockerImage> get images => state.value.images;
  List<DockerNetwork> get networks => state.value.networks;
  List<DockerVolume> get volumes => state.value.volumes;
  List<DockerStack> get stacks => state.value.stacks;
  List<DockerStackService> get stackServices => state.value.stackServices;
  List<String> get availableNetworks => state.value.availableNetworks;

  DockerContainer? get selectedContainer =>
      state.value.findContainer(state.value.selectedContainerId);
  DockerStack? get selectedStack =>
      state.value.findStack(state.value.selectedStackName);
  DockerImage? get selectedImage =>
      state.value.findImage(state.value.selectedImageId);
  DockerNetwork? get selectedNetwork =>
      state.value.findNetwork(state.value.selectedNetworkId);
  DockerVolume? get selectedVolume =>
      state.value.findVolume(state.value.selectedVolumeName);

  DockerContainerDetails? get containerDetails => state.value.containerDetails;
  String get containerDetailsText => state.value.containerDetailsText;
  String get containerLogs => state.value.containerLogs;
  String get containerStats => state.value.containerStats;

  int get runningContainerCount => state.value.runningContainerCount;
  bool get hasOperationActivity => state.value.hasOperationActivity;

  // ---- Commands (command_it v9.x) ----------------------------------
  //
  // Parameterless commands that match the `NoParam` factory shape are
  // exposed.  Operations that take arguments (containerAction, pullImage,
  // createContainer, …) remain as plain async methods: the VM's
  // [state.isLoading] flag provides the same execution-state semantics
  // (command_it does not ship a 1-param factory in v9.x).

  late final refreshCommand = Command.createAsyncNoParamNoResult(refresh);
  late final containerDetailsCommand =
      Command.createAsyncNoParamNoResult(loadContainerDetails);
  late final containerLogsCommand =
      Command.createAsyncNoParamNoResult(loadContainerLogs);
  late final containerStatsCommand =
      Command.createAsyncNoParamNoResult(loadContainerStats);
  late final stackServicesCommand =
      Command.createAsyncNoParamNoResult(loadStackServices);
  late final editStackCommand = Command.createAsyncNoParamNoResult(editStack);
  late final deleteImageCommand =
      Command.createAsyncNoParamNoResult(deleteImage);
  late final deleteNetworkCommand =
      Command.createAsyncNoParamNoResult(deleteNetwork);
  late final deleteVolumeCommand =
      Command.createAsyncNoParamNoResult(deleteVolume);

  // ---- Selection ----------------------------------------------------

  void selectContainer(DockerContainer? value) {
    state.value = state.value.copyWith(
      selectedContainerId: value?.id,
      clearContainerDetails: true,
      containerDetailsText: '',
      containerLogs: '',
      containerStats: '',
    );
  }

  void selectStack(DockerStack? value) {
    state.value = state.value.copyWith(
      selectedStackName: value?.name,
      clearSelectedStackName: value == null,
      stackServices: const [],
    );
    if (value != null) {
      // ignore: discarded_futures
      loadStackServices();
    }
  }

  void selectImage(DockerImage? value) {
    state.value = state.value.copyWith(selectedImageId: value?.id);
  }

  void selectNetwork(DockerNetwork? value) {
    state.value = state.value.copyWith(selectedNetworkId: value?.id);
  }

  void selectVolume(DockerVolume? value) {
    state.value = state.value.copyWith(selectedVolumeName: value?.name);
  }

  void statusNote(String text) {
    state.value = state.value.copyWith(statusText: text);
  }

  Future<void> start() => refresh();

  // ---- Refresh ------------------------------------------------------

  Future<void> refresh() async {
    if (state.value.isLoading) return;
    state.value = state.value.copyWith(isLoading: true);
    try {
      final snap = await _repository.refresh();
      final status = snap.status;
      final available = status.available;
      final installRequired = _isInstallRequired(available, status.problemCode);
      final version = (status.version ?? '').isNotEmpty ? status.version! : '—';
      final platform = [
        status.operatingSystem ?? '',
        status.architecture ?? '',
      ].where((v) => v.isNotEmpty).join(' / ');
      final netNames = <String>{
        'bridge',
        ...snap.networks.map((n) => n.name),
      }.toList();
      state.value = state.value.copyWith(
        containers: snap.containers,
        images: snap.images,
        networks: snap.networks,
        volumes: snap.volumes,
        stacks: snap.stacks,
        availableNetworks: netNames,
        isDockerAvailable: available,
        isDockerInstallRequired: installRequired,
        engineVersion: version,
        enginePlatform: platform.isEmpty ? '—' : platform,
        statusText: available
            ? 'docker.status.available'.tr(namedArgs: {
                'version': status.version ?? '',
                'os': status.operatingSystem ?? '',
              })
            : 'docker.status.unavailable'
                .tr(namedArgs: {'code': status.problemCode}),
        isLoading: false,
      );
    } catch (error) {
      state.value = state.value.copyWith(
        isDockerInstallRequired: false,
        statusText:
            'docker.status.failed'.tr(namedArgs: {'error': '$error'}),
        isLoading: false,
      );
    }
  }

  // ---- Container operations ----------------------------------------

  Future<bool> applyContainerAction(String action,
      {bool confirmed = false}) async {
    final c = selectedContainer;
    if (c == null) return false;
    return _runOperation(
      () => _repository.containerAction(c.id, action, confirmed: confirmed),
      (result) => result.success
          ? 'docker.action.succeeded'.tr(namedArgs: {
              'action': _opText(action),
              'name': c.name,
            })
          : 'docker.action.failed'.tr(namedArgs: {
              'action': _opText(action),
              'reason': _problemText(result.problemCode),
            }),
      operationName: 'docker.operation.container_action'.tr(namedArgs: {
        'action': _opText(action),
        'name': c.name,
      }),
    );
  }

  Future<void> deleteContainer() async {
    final c = selectedContainer;
    if (c == null) return;
    final ok = await onConfirmDelete(
        'docker.container.delete_confirmation'
            .tr(namedArgs: {'name': c.name}));
    if (!ok) return;
    await applyContainerAction('delete', confirmed: true);
  }

  Future<void> loadContainerLogs() async {
    final c = selectedContainer;
    if (c == null) return;
    await _runRead(() async {
      final logs = await _repository.containerLogs(c.id);
      final joined = logs == null ? '' : logs.lines.join('\n');
      _appendLog(logs?.lines);
      state.value = state.value.copyWith(
        containerLogs: joined,
        statusText: logs == null
            ? 'docker.action.failed'.tr(namedArgs: {
                'action': _opText('logs'),
                'reason': _problemText('docker.operation_failed'),
              })
            : 'docker.action.succeeded'.tr(namedArgs: {
                'action': _opText('logs'),
                'name': c.name,
              }),
      );
    });
  }

  Future<void> loadContainerStats() async {
    final c = selectedContainer;
    if (c == null) return;
    await _runRead(() async {
      final stats = await _repository.containerStats(c.id);
      final text = stats == null
          ? ''
          : 'docker.stats.summary'.tr(
              args: [stats.cpu, stats.memory, stats.networkIo, stats.blockIo]);
      state.value = state.value.copyWith(
        containerStats: text,
        statusText: stats == null
            ? 'docker.action.failed'.tr(namedArgs: {
                'action': _opText('stats'),
                'reason': _problemText('docker.operation_failed'),
              })
            : 'docker.action.succeeded'.tr(namedArgs: {
                'action': _opText('stats'),
                'name': c.name,
              }),
      );
    });
  }

  Future<void> loadContainerDetails() async {
    final c = selectedContainer;
    if (c == null) return;
    await _runRead(() async {
      final details = await _repository.containerDetails(c.id);
      state.value = state.value.copyWith(
        containerDetails: details,
        containerDetailsText:
            details == null ? '' : _formatContainerDetails(details),
        statusText: details == null
            ? 'docker.action.failed'.tr(namedArgs: {
                'action': 'docker.container.details'.tr(),
                'reason': _problemText('docker.operation_failed'),
              })
            : 'docker.container.details_loaded'
                .tr(namedArgs: {'name': c.name}),
      );
    });
    if (state.value.containerDetails != null) {
      await onContainerDetails?.call();
    }
  }

  Future<void> editContainer() async {
    final c = selectedContainer;
    if (c == null) return;
    await onEditContainer.call(c);
  }

  Future<bool> tryUpdateContainer(DockerContainer c, String name) async {
    if (state.value.isLoading) return false;
    final t = name.trim();
    if (t.isEmpty) return false;
    if (t == c.name) return true;
    return _runOperation(
      () => _repository.renameContainer(c.id, t),
      (result) => result.success
          ? 'docker.container.updated'.tr(namedArgs: {'name': t})
          : 'docker.container.update_failed'.tr(namedArgs: {
              'error': _problemText(result.problemCode),
            }),
      operationName:
          'docker.operation.update_container'.tr(namedArgs: {'name': c.name}),
    );
  }

  Future<bool> tryCreateContainer({
    required String name,
    required String image,
    required List<String> arguments,
    required List<String> ports,
    required List<String> environment,
    required List<String> mounts,
    required String network,
    required String restartPolicy,
  }) async {
    if (state.value.isLoading) return false;
    if (name.trim().isEmpty || image.trim().isEmpty) {
      statusNote('docker.container.required'.tr());
      return false;
    }
    final trimmed = name.trim();
    return _runOperation(
      () => _repository.createContainer(DockerContainerCreate(
        name: trimmed,
        image: image.trim(),
        arguments: arguments,
        ports: ports,
        environment: environment,
        mounts: mounts,
        network: network,
        restartPolicy: restartPolicy,
      )),
      (result) => result.success
          ? 'docker.container.created'.tr(namedArgs: {'name': trimmed})
          : 'docker.container.create_failed'.tr(namedArgs: {
              'error': _problemText(result.problemCode),
            }),
      operationName:
          'docker.operation.create_container'.tr(namedArgs: {'name': trimmed}),
    );
  }

  // ---- Stack operations --------------------------------------------

  Future<bool> validateStack(
      {required String name, required String composeYaml}) async {
    if (state.value.isLoading) return false;
    if (name.trim().isEmpty || composeYaml.trim().isEmpty) {
      statusNote('docker.stack.required'.tr());
      return false;
    }
    return _runStackOp(
      () => _repository.validateStack(
          DockerStackDefinition(name: name.trim(), composeYaml: composeYaml)),
      name,
    );
  }

  Future<bool> deployStack(
      {required String name, required String composeYaml}) async {
    if (state.value.isLoading) return false;
    if (name.trim().isEmpty || composeYaml.trim().isEmpty) {
      statusNote('docker.stack.required'.tr());
      return false;
    }
    return _runStackOp(
      () => _repository.deployStack(
          DockerStackDefinition(name: name.trim(), composeYaml: composeYaml)),
      name,
    );
  }

  Future<bool> _runStackOp(
      Future<DockerStackOperationResult> Function() op, String name) {
    return _runOpRaw<DockerStackOperationResult>(
      op,
      (result) {
        final detail = result.messages.isNotEmpty
            ? result.messages.first
            : result.problemCode;
        return result.success
            ? 'docker.stack.succeeded'.tr(namedArgs: {
                'action': _opText('deploy'),
                'name': name,
              })
            : 'docker.stack.failed'.tr(namedArgs: {
                'action': _opText('deploy'),
                'reason': _problemText(detail),
              });
      },
      operationName: 'docker.operation.stack'.tr(namedArgs: {
        'action': _opText('deploy'),
        'name': name,
      }),
    );
  }

  Future<bool> applyStackAction(String action, {bool confirmed = false}) async {
    final s = selectedStack;
    if (s == null) return false;
    return _runOpRaw<DockerStackOperationResult>(
      () => _repository.stackAction(s.name, action, confirmed: confirmed),
      (result) => result.success
          ? 'docker.stack.succeeded'.tr(namedArgs: {
              'action': _opText(action),
              'name': s.name,
            })
          : 'docker.stack.failed'.tr(namedArgs: {
              'action': _opText(action),
              'reason': _problemText(result.problemCode),
            }),
      operationName: 'docker.operation.stack'.tr(namedArgs: {
        'action': _opText(action),
        'name': s.name,
      }),
    );
  }

  Future<void> deleteStack() async {
    final s = selectedStack;
    if (s == null) return;
    final ok = await onConfirmDelete(
        'docker.stack.delete_confirmation'.tr(namedArgs: {'name': s.name}));
    if (!ok) return;
    await applyStackAction('delete', confirmed: true);
  }

  Future<void> loadStackServices() async {
    final s = selectedStack;
    if (s == null) return;
    await _runRead(() async {
      final list = await _repository.stackServices(s.name);
      state.value = state.value.copyWith(
        stackServices: list,
        statusText: 'docker.stack.services_loaded'.tr(namedArgs: {
          'name': s.name,
          'count': '${list.length}',
        }),
      );
    });
  }

  Future<void> editStack() async {
    final s = selectedStack;
    if (s == null) return;
    DockerStackDefinition? def;
    await _runRead(() async {
      def = await _repository.stackDefinition(s.name);
      state.value = state.value.copyWith(
        statusText: def == null
            ? 'docker.stack.source_unavailable'.tr()
            : 'docker.stack.source_loaded'.tr(namedArgs: {'name': s.name}),
      );
    });
    final d = def;
    if (d == null) return;
    await onEditStack(d.name, d.composeYaml);
  }

  Future<void> openStackSource() async {
    final s = selectedStack;
    if (s == null || s.configDirectory.isEmpty) return;
    await onOpenPath(s.configDirectory);
  }

  // ---- Image operations --------------------------------------------

  Future<bool> pullImage(String reference) async {
    if (state.value.isLoading) return false;
    if (reference.trim().isEmpty) {
      statusNote('docker.image.required'.tr());
      return false;
    }
    final t = reference.trim();
    return _runOperation(
      () => _repository.pullImage(t),
      (result) => result.success
          ? 'docker.image.pull_succeeded'.tr(namedArgs: {'name': t})
          : 'docker.image.pull_failed'
              .tr(namedArgs: {'error': _problemText(result.problemCode)}),
      operationName: 'docker.operation.pull'.tr(namedArgs: {'name': t}),
    );
  }

  Future<void> deleteImage() async {
    final img = selectedImage;
    if (img == null) return;
    final ok = await onConfirmDelete(
        'docker.image.delete_confirmation'
            .tr(namedArgs: {'name': img.repository}));
    if (!ok) return;
    await _runOperation(
      () => _repository.deleteImage(img.id),
      (result) => result.success
          ? 'docker.image.deleted'.tr(namedArgs: {'name': img.repository})
          : 'docker.image.delete_failed'
              .tr(namedArgs: {'error': _problemText(result.problemCode)}),
      operationName:
          'docker.operation.delete_image'.tr(namedArgs: {'name': img.repository}),
    );
  }

  // ---- Network operations ------------------------------------------

  Future<bool> tryCreateNetwork(String name, String driver) async {
    if (state.value.isLoading) return false;
    if (name.trim().isEmpty) {
      statusNote('docker.network.required'.tr());
      return false;
    }
    final t = name.trim();
    return _runOperation(
      () => _repository.createNetwork(t, driver: driver),
      (result) => result.success
          ? 'docker.network.created'.tr(namedArgs: {'name': t})
          : 'docker.network.create_failed'
              .tr(namedArgs: {'error': _problemText(result.problemCode)}),
      operationName: 'docker.operation.create_network'.tr(namedArgs: {'name': t}),
    );
  }

  Future<void> deleteNetwork() async {
    final n = selectedNetwork;
    if (n == null) return;
    final ok = await onConfirmDelete(
        'docker.network.delete_confirmation'.tr(namedArgs: {'name': n.name}));
    if (!ok) return;
    await _runOperation(
      () => _repository.deleteNetwork(n.id),
      (result) => result.success
          ? 'docker.network.deleted'.tr(namedArgs: {'name': n.name})
          : 'docker.network.delete_failed'
              .tr(namedArgs: {'error': _problemText(result.problemCode)}),
      operationName: 'docker.operation.delete_network'.tr(namedArgs: {'name': n.name}),
    );
  }

  // ---- Volume operations -------------------------------------------

  Future<bool> tryCreateVolume(String name, String driver) async {
    if (state.value.isLoading) return false;
    if (name.trim().isEmpty) {
      statusNote('docker.volume.required'.tr());
      return false;
    }
    final t = name.trim();
    return _runOperation(
      () => _repository.createVolume(t, driver: driver),
      (result) => result.success
          ? 'docker.volume.created'.tr(namedArgs: {'name': t})
          : 'docker.volume.create_failed'
              .tr(namedArgs: {'error': _problemText(result.problemCode)}),
      operationName: 'docker.operation.create_volume'.tr(namedArgs: {'name': t}),
    );
  }

  Future<void> deleteVolume() async {
    final v = selectedVolume;
    if (v == null) return;
    final ok = await onConfirmDelete(
        'docker.volume.delete_confirmation'.tr(namedArgs: {'name': v.name}));
    if (!ok) return;
    await _runOperation(
      () => _repository.deleteVolume(v.name),
      (result) => result.success
          ? 'docker.volume.deleted'.tr(namedArgs: {'name': v.name})
          : 'docker.volume.delete_failed'
              .tr(namedArgs: {'error': _problemText(result.problemCode)}),
      operationName: 'docker.operation.delete_volume'.tr(namedArgs: {'name': v.name}),
    );
  }

  // ---- Operation plumbing ------------------------------------------

  Future<bool> _runOperation(
    Future<DockerOperationResult> Function() op,
    String Function(DockerOperationResult) statusFn, {
    String? operationName,
  }) =>
      _runOpRaw<DockerOperationResult>(op, statusFn,
          operationName: operationName);

  Future<bool> _runOpRaw<T extends Object>(
    Future<T> Function() op,
    String Function(T) statusFn, {
    String? operationName,
  }) async {
    if (state.value.isLoading || !await _ensureAvailable()) return false;
    _beginOp(operationName);
    try {
      final result = await op();
      final st = statusFn(result);
      state.value = state.value.copyWith(statusText: st);
      if (result is DockerOperationResult) _appendLog(result.logLines);
      if (result is DockerStackOperationResult) _appendLog(result.messages);
      _completeOp(st);
      var failed = false;
      String? prob;
      if (result is DockerOperationResult && !result.success) {
        failed = true;
        prob = result.problemCode;
      }
      if (result is DockerStackOperationResult && !result.success) {
        failed = true;
        prob = result.problemCode;
      }
      if (failed && prob != null) {
        await _showUnavailableForProblem(prob);
      }
    } catch (error) {
      final st =
          'docker.status.failed'.tr(namedArgs: {'error': '$error'});
      state.value = state.value.copyWith(statusText: st);
      _appendLog(['$error']);
      _completeOp(st);
      await _showUnavailableForException();
    } finally {
      state.value = state.value.copyWith(
        isOperationRunning: false,
        isLoading: false,
      );
      await refresh();
    }
    return true;
  }

  Future<void> _runRead(Future<void> Function() op) async {
    if (!await _ensureAvailable()) return;
    _beginOp('docker.operation.reading'.tr());
    state.value = state.value.copyWith(isLoading: true);
    try {
      await op();
      _completeOp(state.value.statusText);
    } catch (error) {
      final st =
          'docker.status.failed'.tr(namedArgs: {'error': '$error'});
      state.value = state.value.copyWith(statusText: st);
      _appendLog(['$error']);
      _completeOp(st);
      await _showUnavailableForException();
    } finally {
      state.value = state.value.copyWith(
        isOperationRunning: false,
        isLoading: false,
      );
    }
  }

  Future<bool> _ensureAvailable() async {
    if (state.value.isDockerAvailable) return true;
    state.value = state.value
        .copyWith(statusText: 'docker.status.unavailable_operation'.tr());
    await _showUnavailableDialog();
    return false;
  }

  Future<void> _showUnavailableForProblem(String problemCode) async {
    if (problemCode != 'docker.unavailable' &&
        problemCode != 'docker.not_installed' &&
        problemCode != 'docker.api_incompatible') {
      return;
    }
    state.value = state.value.copyWith(
      isDockerAvailable: false,
      isDockerInstallRequired: _isInstallRequired(false, problemCode),
      statusText:
          'docker.status.unavailable'.tr(namedArgs: {'code': problemCode}),
    );
    await _showUnavailableDialog();
  }

  Future<void> _showUnavailableForException() async {
    try {
      final snap = await _repository.refresh();
      final status = snap.status;
      if (status.available) return;
      state.value = state.value.copyWith(
        isDockerAvailable: false,
        isDockerInstallRequired: _isInstallRequired(false, status.problemCode),
        statusText: 'docker.status.unavailable'
            .tr(namedArgs: {'code': status.problemCode}),
        containers: snap.containers,
        images: snap.images,
        networks: snap.networks,
        volumes: snap.volumes,
        stacks: snap.stacks,
      );
    } catch (_) {
      state.value = state.value.copyWith(
        isDockerAvailable: false,
        isDockerInstallRequired: false,
        statusText: 'docker.status.unavailable_operation'.tr(),
      );
    }
    await _showUnavailableDialog();
  }

  Future<void> _showUnavailableDialog() async {
    if (_dialogShowing) return;
    _dialogShowing = true;
    try {
      await (onDockerUnavailable ?? _noop0)();
    } finally {
      _dialogShowing = false;
    }
  }

  void _beginOp(String? name) {
    final title = (name ?? '').trim().isEmpty
        ? 'docker.operation.running_label'.tr()
        : name!;
    state.value = state.value.copyWith(
      operationTitle: title,
      operationLog:
          'docker.operation.started'.tr(namedArgs: {'title': title}),
      isOperationRunning: true,
      statusText: 'docker.operation.running'.tr(namedArgs: {'title': title}),
      isLoading: true,
    );
  }

  void _appendLog(List<String>? lines) {
    if (lines == null) return;
    final values = lines.where((l) => l.trim().isNotEmpty).toList();
    if (values.isEmpty) return;
    final cur = state.value.operationLog;
    state.value = state.value.copyWith(
      operationLog: [cur, ...values].join('\n'),
    );
  }

  void _completeOp(String outcome) {
    final cur = state.value.operationLog;
    state.value = state.value.copyWith(
      operationLog: [
        cur,
        'docker.operation.finished'.tr(namedArgs: {'outcome': outcome})
      ].join('\n'),
    );
  }

  static bool _isInstallRequired(bool available, String problemCode) =>
      !available && problemCode.toLowerCase() == 'docker.not_installed';

  static String _opText(String operation) => switch (operation) {
        'validate' => 'docker.stack.validate'.tr(),
        'deploy' => 'docker.stack.deploy'.tr(),
        'logs' => 'docker.container.logs'.tr(),
        'stats' => 'docker.container.stats'.tr(),
        'delete' => 'common.delete'.tr(),
        'start' => 'docker.action.start'.tr(),
        'stop' => 'docker.action.stop'.tr(),
        'restart' => 'docker.action.restart'.tr(),
        'pause' => 'docker.action.pause'.tr(),
        'unpause' => 'docker.action.unpause'.tr(),
        _ => operation,
      };

  static String _problemText(String problemCode) => switch (problemCode) {
        'docker.operation_timeout' => 'docker.problem.timeout'.tr(),
        'docker.operation_failed' => 'docker.problem.failed'.tr(),
        'docker.stack_no_services' => 'docker.problem.stack_no_services'.tr(),
        'docker.stack_source_unavailable' =>
          'docker.stack.source_unavailable'.tr(),
        _ => problemCode,
      };

  static String _formatContainerDetails(DockerContainerDetails d) => [
        'Name: ${d.name}',
        'ID: ${d.id}',
        'Image: ${d.image}',
        'State: ${d.state}',
        'Status: ${d.status}',
        'Created: ${d.created}',
        'Restart policy: ${d.restartPolicy}',
        'Working directory: ${d.workingDirectory}',
        'Command: ${d.command}',
        'Ports:\n${d.ports.join('\n')}',
        'Mounts:\n${d.mounts.join('\n')}',
        'Networks:\n${d.networks.join('\n')}',
        'Environment:\n${d.environment.join('\n')}',
        'Labels:\n${d.labels.entries.map((l) => '${l.key}=${l.value}').join('\n')}',
      ].join('\n');
}

/// Factory used by get_it `registerFactory` (see dependency_injection.dart).
DockerViewModel createDockerViewModel() {
  final g = GetIt.instance;
  return DockerViewModel(g<DockerRepository>());
}

// Helper alias used by the view's ValueListenableBuilder typing.
// ignore: camel_case_types
typedef DockerUiState2 = DockerUiState;
