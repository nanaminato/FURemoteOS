import '../../../core/network/remoteos_api.dart';

/// Typed Docker Manager REST boundary. Docker operations deliberately use the
/// server's structured payloads: the Flutter client never constructs CLI text.
class RemoteDockerApi {
  RemoteDockerApi(this._api);
  final RemoteOsApi _api;

  Future<DockerStatus> status() async =>
      DockerStatus.fromJson(_map(await _api.getJson('/api/v1/docker/status')));
  Future<List<DockerContainer>> containers() async =>
      _list(await _api.getJson('/api/v1/docker/containers'))
          .map((value) => DockerContainer.fromJson(_map(value)))
          .toList();
  Future<List<DockerImage>> images() async =>
      _list(await _api.getJson('/api/v1/docker/images'))
          .map((value) => DockerImage.fromJson(_map(value)))
          .toList();
  Future<List<DockerVolume>> volumes() async =>
      _list(await _api.getJson('/api/v1/docker/volumes'))
          .map((value) => DockerVolume.fromJson(_map(value)))
          .toList();
  Future<List<DockerNetwork>> networks() async =>
      _list(await _api.getJson('/api/v1/docker/networks'))
          .map((value) => DockerNetwork.fromJson(_map(value)))
          .toList();
  Future<List<DockerStack>> stacks() async =>
      _list(await _api.getJson('/api/v1/docker/stacks'))
          .map((value) => DockerStack.fromJson(_map(value)))
          .toList();

  Future<DockerOperationResult> containerAction(String id, String action,
          {bool force = false, bool confirmed = false}) async =>
      DockerOperationResult.fromJson(_map(await _api.sendJson(
          'POST', '/api/v1/docker/containers/$id/$action',
          body: {'force': force, 'confirmed': confirmed})));

  Future<DockerOperationResult> createContainer(
          DockerContainerCreate request) async =>
      DockerOperationResult.fromJson(_map(await _api.sendJson(
          'POST', '/api/v1/docker/containers',
          body: request.toJson())));

  Future<DockerOperationResult> renameContainer(String id, String name) async =>
      DockerOperationResult.fromJson(_map(await _api.sendJson(
          'PUT', '/api/v1/docker/containers/$id',
          body: {'name': name})));

  Future<DockerOperationResult> pullImage(String reference) async =>
      DockerOperationResult.fromJson(_map(await _api.sendJson(
          'POST', '/api/v1/docker/images/pull',
          body: {'imageReference': reference, 'confirmed': false})));

  Future<DockerOperationResult> deleteImage(String id) async =>
      DockerOperationResult.fromJson(_map(await _api.sendJson(
          'DELETE', '/api/v1/docker/images/$id',
          body: {'imageReference': id, 'confirmed': true})));

  Future<DockerOperationResult> buildImage(
          String contextDirectory, String imageReference,
          {String? dockerfile}) async =>
      DockerOperationResult.fromJson(_map(
          await _api.sendJson('POST', '/api/v1/docker/images/build', body: {
        'contextDirectory': contextDirectory,
        'imageReference': imageReference,
        if (dockerfile != null && dockerfile.isNotEmpty)
          'dockerfile': dockerfile
      })));

  Future<DockerOperationResult> deleteNetwork(String id) async =>
      DockerOperationResult.fromJson(_map(await _api.sendJson(
          'DELETE', '/api/v1/docker/networks/$id',
          query: {'confirmed': 'true'})));

  Future<DockerOperationResult> deleteVolume(String name) async =>
      DockerOperationResult.fromJson(_map(await _api.sendJson(
          'DELETE', '/api/v1/docker/volumes/$name',
          query: {'confirmed': 'true'})));

  Future<DockerOperationResult> createNetwork(String name,
          {String driver = 'bridge'}) async =>
      DockerOperationResult.fromJson(_map(await _api.sendJson(
          'POST', '/api/v1/docker/networks',
          body: {'name': name, 'driver': driver, 'confirmed': false})));
  Future<DockerOperationResult> createVolume(String name,
          {String driver = 'local'}) async =>
      DockerOperationResult.fromJson(_map(await _api.sendJson(
          'POST', '/api/v1/docker/volumes',
          body: {'name': name, 'driver': driver, 'confirmed': false})));
  Future<DockerStackOperationResult> validateStack(
          DockerStackDefinition definition) async =>
      DockerStackOperationResult.fromJson(_map(await _api.sendJson(
          'POST', '/api/v1/docker/stacks/validate',
          body: definition.toJson())));
  Future<DockerStackOperationResult> deployStack(
          DockerStackDefinition definition) async =>
      DockerStackOperationResult.fromJson(_map(await _api.sendJson(
          'POST', '/api/v1/docker/stacks/deploy',
          body: definition.toJson())));
  Future<DockerStackOperationResult> stackAction(String name, String action,
          {bool confirmed = false}) async =>
      DockerStackOperationResult.fromJson(_map(await _api.sendJson(
          'POST', '/api/v1/docker/stacks/$name/$action',
          body: {'confirmed': confirmed})));
  Future<DockerStackDefinition?> stackDefinition(String name) async {
    final value = await _api.getJson('/api/v1/docker/stacks/$name/definition');
    return value == null ? null : DockerStackDefinition.fromJson(_map(value));
  }

  Future<List<DockerStackService>> stackServices(String name) async =>
      _list(await _api.getJson('/api/v1/docker/stacks/$name/services'))
          .map((value) => DockerStackService.fromJson(_map(value)))
          .toList();

  Future<DockerNetworkDetails?> networkDetails(String id) async {
    final value = await _api.getJson('/api/v1/docker/networks/$id');
    return value == null ? null : DockerNetworkDetails.fromJson(_map(value));
  }

  Future<DockerVolumeDetails?> volumeDetails(String name) async {
    final value = await _api.getJson('/api/v1/docker/volumes/$name');
    return value == null ? null : DockerVolumeDetails.fromJson(_map(value));
  }

  Future<DockerContainerDetails?> containerDetails(String id) async {
    final value = await _api.getJson('/api/v1/docker/containers/$id');
    return value == null ? null : DockerContainerDetails.fromJson(_map(value));
  }

  Future<DockerContainerLogs?> containerLogs(String id,
      {int tail = 200}) async {
    final value = await _api.getJson('/api/v1/docker/containers/$id/logs',
        query: {'tail': '${tail.clamp(1, 1000)}'});
    return value == null ? null : DockerContainerLogs.fromJson(_map(value));
  }

  Future<DockerContainerStats?> containerStats(String id) async {
    final value = await _api.getJson('/api/v1/docker/containers/$id/stats');
    return value == null ? null : DockerContainerStats.fromJson(_map(value));
  }
}

class DockerOperationResult {
  const DockerOperationResult(
      {required this.success, required this.problemCode, this.logLines});
  final bool success;
  final String problemCode;
  final List<String>? logLines;
  factory DockerOperationResult.fromJson(Map<String, dynamic> json) =>
      DockerOperationResult(
          success: json['success'] == true,
          problemCode: json['problemCode']?.toString() ?? '',
          logLines: json['logLines'] is List
              ? (json['logLines'] as List).map((item) => '$item').toList()
              : null);
}

/// Compose operations return bounded diagnostic messages instead of raw logs.
class DockerStackOperationResult {
  const DockerStackOperationResult(
      {required this.success,
      required this.problemCode,
      this.messages = const []});
  final bool success;
  final String problemCode;
  final List<String> messages;
  factory DockerStackOperationResult.fromJson(Map<String, dynamic> json) =>
      DockerStackOperationResult(
          success: json['success'] == true,
          problemCode: json['problemCode']?.toString() ?? '',
          messages: json['messages'] is List
              ? (json['messages'] as List).map((item) => '$item').toList()
              : const []);
}

class DockerContainerCreate {
  const DockerContainerCreate(
      {required this.name,
      required this.image,
      this.arguments = const [],
      this.ports = const [],
      this.environment = const [],
      this.mounts = const [],
      this.network,
      this.restartPolicy});
  final String name, image;
  final List<String> arguments, ports, environment, mounts;
  final String? network, restartPolicy;
  Map<String, dynamic> toJson() => {
        'name': name,
        'image': image,
        'arguments': arguments,
        'ports': ports,
        'environment': environment,
        'mounts': mounts,
        if (network != null && network!.isNotEmpty) 'network': network,
        if (restartPolicy != null && restartPolicy!.isNotEmpty)
          'restartPolicy': restartPolicy
      };
}

class DockerStackDefinition {
  const DockerStackDefinition({required this.name, required this.composeYaml});
  final String name, composeYaml;
  factory DockerStackDefinition.fromJson(Map<String, dynamic> json) =>
      DockerStackDefinition(
          name: _text(json, 'name'), composeYaml: _text(json, 'composeYaml'));
  Map<String, String> toJson() => {'name': name, 'composeYaml': composeYaml};
}

class DockerStackService {
  const DockerStackService(
      {required this.service,
      required this.container,
      required this.image,
      required this.state,
      required this.status});
  final String service, container, image, state, status;
  factory DockerStackService.fromJson(Map<String, dynamic> json) =>
      DockerStackService(
          service: _text(json, 'service'),
          container: _text(json, 'container'),
          image: _text(json, 'image'),
          state: _text(json, 'state'),
          status: _text(json, 'status'));
}

class DockerNetworkDetails {
  const DockerNetworkDetails(
      {required this.id,
      required this.name,
      required this.driver,
      required this.scope,
      required this.containers});
  final String id, name, driver, scope;
  final List<String> containers;
  factory DockerNetworkDetails.fromJson(Map<String, dynamic> json) =>
      DockerNetworkDetails(
          id: _text(json, 'id'),
          name: _text(json, 'name'),
          driver: _text(json, 'driver'),
          scope: _text(json, 'scope'),
          containers: _strings(json['containers']));
}

class DockerVolumeDetails {
  const DockerVolumeDetails(
      {required this.name,
      required this.driver,
      required this.mountpoint,
      required this.labels});
  final String name, driver, mountpoint;
  final Map<String, String> labels;
  factory DockerVolumeDetails.fromJson(Map<String, dynamic> json) =>
      DockerVolumeDetails(
          name: _text(json, 'name'),
          driver: _text(json, 'driver'),
          mountpoint: _text(json, 'mountpoint'),
          labels: _map(json['labels'])
              .map((key, value) => MapEntry(key, '$value')));
}

class DockerContainerDetails {
  const DockerContainerDetails(
      {required this.id,
      required this.name,
      required this.image,
      required this.created,
      required this.state,
      required this.status,
      required this.command,
      required this.workingDirectory,
      required this.restartPolicy,
      required this.ports,
      required this.mounts,
      required this.networks,
      required this.environment,
      required this.labels});
  final String id, name, image, created, state, status;
  final String command, workingDirectory, restartPolicy;
  final List<String> ports, mounts, networks, environment;
  final Map<String, String> labels;
  factory DockerContainerDetails.fromJson(Map<String, dynamic> json) =>
      DockerContainerDetails(
          id: _text(json, 'id'),
          name: _text(json, 'name'),
          image: _text(json, 'image'),
          created: _text(json, 'created'),
          state: _text(json, 'state'),
          status: _text(json, 'status'),
          command: _text(json, 'command'),
          workingDirectory: _text(json, 'workingDirectory'),
          restartPolicy: _text(json, 'restartPolicy'),
          ports: _strings(json['ports']),
          mounts: _strings(json['mounts']),
          networks: _strings(json['networks']),
          environment: _strings(json['environment']),
          labels: _map(json['labels'])
              .map((key, value) => MapEntry(key, '$value')));
}

class DockerContainerLogs {
  const DockerContainerLogs({required this.lines, required this.truncated});
  final List<String> lines;
  final bool truncated;
  factory DockerContainerLogs.fromJson(Map<String, dynamic> json) =>
      DockerContainerLogs(
          lines: _strings(json['lines']), truncated: json['truncated'] == true);
}

class DockerContainerStats {
  const DockerContainerStats(
      {required this.cpu,
      required this.memory,
      required this.networkIo,
      required this.blockIo});
  final String cpu, memory, networkIo, blockIo;
  factory DockerContainerStats.fromJson(Map<String, dynamic> json) =>
      DockerContainerStats(
          cpu: _text(json, 'cpuPercent'),
          memory: _text(json, 'memoryUsage'),
          networkIo: _text(json, 'networkIo'),
          blockIo: _text(json, 'blockIo'));
}

class DockerStatus {
  const DockerStatus(
      {required this.available,
      required this.problemCode,
      this.version,
      this.operatingSystem,
      this.architecture});
  final bool available;
  final String problemCode;
  final String? version;
  final String? operatingSystem;
  final String? architecture;
  factory DockerStatus.fromJson(Map<String, dynamic> json) => DockerStatus(
      available: json['isAvailable'] == true,
      problemCode: json['problemCode']?.toString() ?? '',
      version: json['serverVersion']?.toString(),
      operatingSystem: json['operatingSystem']?.toString(),
      architecture: json['architecture']?.toString());
}

class DockerContainer {
  const DockerContainer(
      {required this.id,
      required this.name,
      required this.image,
      required this.state,
      required this.status});
  final String id, name, image, state, status;
  factory DockerContainer.fromJson(Map<String, dynamic> json) =>
      DockerContainer(
          id: _text(json, 'id'),
          name: _text(json, 'names'),
          image: _text(json, 'image'),
          state: _text(json, 'state'),
          status: _text(json, 'status'));
}

class DockerImage {
  const DockerImage(
      {required this.id,
      required this.repository,
      required this.tag,
      required this.size,
      required this.createdSince});
  final String id, repository, tag, size, createdSince;
  factory DockerImage.fromJson(Map<String, dynamic> json) => DockerImage(
      id: _text(json, 'id'),
      repository: _text(json, 'repository'),
      tag: _text(json, 'tag'),
      size: _text(json, 'size'),
      createdSince: _text(json, 'createdSince'));
}

class DockerVolume {
  const DockerVolume(
      {required this.name, required this.driver, required this.mountpoint});
  final String name, driver, mountpoint;
  factory DockerVolume.fromJson(Map<String, dynamic> json) => DockerVolume(
      name: _text(json, 'name'),
      driver: _text(json, 'driver'),
      mountpoint: _text(json, 'mountpoint'));
}

class DockerNetwork {
  const DockerNetwork(
      {required this.id,
      required this.name,
      required this.driver,
      required this.scope});
  final String id, name, driver, scope;
  factory DockerNetwork.fromJson(Map<String, dynamic> json) => DockerNetwork(
      id: _text(json, 'id'),
      name: _text(json, 'name'),
      driver: _text(json, 'driver'),
      scope: _text(json, 'scope'));
}

class DockerStack {
  const DockerStack(
      {required this.name,
      required this.status,
      required this.configFiles,
      required this.configDirectory});
  final String name, status, configFiles, configDirectory;
  factory DockerStack.fromJson(Map<String, dynamic> json) => DockerStack(
      name: _text(json, 'name'),
      status: _text(json, 'status'),
      configFiles: _text(json, 'configFiles'),
      configDirectory: _text(json, 'configDirectory'));
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : const {};
List<Object?> _list(Object? value) =>
    value is List ? value.cast<Object?>() : const [];
String _text(Map<String, dynamic> value, String key) =>
    value[key]?.toString() ?? '';
List<String> _strings(Object? value) =>
    value is List ? value.map((item) => '$item').toList() : const [];
