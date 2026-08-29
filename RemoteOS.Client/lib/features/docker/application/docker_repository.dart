// Docker feature — repository interface + HTTP-API implementation.
//
// Per ARCHITECTURE.md § 11 the repository is the canonical data source for
// the ViewModel; it wraps [RemoteDockerApi], consolidates parallel refresh
// calls and maps raw problem codes / DTO shapes into presentation-facing
// aggregate results.  Tests can swap [DockerRepository] with a fake.

import '../data/remote_docker_api.dart';

abstract class DockerRepository {
  static const networkDrivers = ['bridge', 'ipvlan', 'macvlan', 'overlay'];
  static const volumeDrivers = ['local'];
  static const restartPolicies = [
    'no',
    'always',
    'unless-stopped',
    'on-failure'
  ];

  Future<DockerRefreshSnapshot> refresh();
  Future<DockerOperationResult> containerAction(
      String containerId, String action,
      {bool confirmed = false});
  Future<DockerContainerLogs?> containerLogs(String containerId);
  Future<DockerContainerStats?> containerStats(String containerId);
  Future<DockerContainerDetails?> containerDetails(String containerId);
  Future<DockerOperationResult> renameContainer(
      String containerId, String name);
  Future<DockerOperationResult> createContainer(DockerContainerCreate request);
  Future<DockerStackOperationResult> validateStack(
      DockerStackDefinition definition);
  Future<DockerStackOperationResult> deployStack(
      DockerStackDefinition definition);
  Future<DockerStackOperationResult> stackAction(
      String stackName, String action,
      {bool confirmed = false});
  Future<List<DockerStackService>> stackServices(String stackName);
  Future<DockerStackDefinition?> stackDefinition(String stackName);
  Future<DockerOperationResult> pullImage(String reference);
  Future<DockerOperationResult> deleteImage(String imageId);
  Future<DockerOperationResult> createNetwork(String name,
      {String driver = 'bridge'});
  Future<DockerOperationResult> deleteNetwork(String networkId);
  Future<DockerOperationResult> createVolume(String name,
      {String driver = 'local'});
  Future<DockerOperationResult> deleteVolume(String volumeName);
}

/// Aggregate snapshot produced by a single refresh() call.
class DockerRefreshSnapshot {
  const DockerRefreshSnapshot({
    required this.status,
    required this.containers,
    required this.images,
    required this.networks,
    required this.volumes,
    required this.stacks,
  });

  final DockerStatus status;
  final List<DockerContainer> containers;
  final List<DockerImage> images;
  final List<DockerNetwork> networks;
  final List<DockerVolume> volumes;
  final List<DockerStack> stacks;
}

class RemoteDockerRepository implements DockerRepository {
  RemoteDockerRepository(this.api);
  final RemoteDockerApi api;

  @override
  Future<DockerRefreshSnapshot> refresh() async {
    final results = await Future.wait([
      api.status(),
      api.containers(),
      api.images(),
      api.networks(),
      api.volumes(),
      api.stacks(),
    ]);
    return DockerRefreshSnapshot(
      status: results[0] as DockerStatus,
      containers: results[1] as List<DockerContainer>,
      images: results[2] as List<DockerImage>,
      networks: results[3] as List<DockerNetwork>,
      volumes: results[4] as List<DockerVolume>,
      stacks: results[5] as List<DockerStack>,
    );
  }

  @override
  Future<DockerOperationResult> containerAction(
          String containerId, String action,
          {bool confirmed = false}) =>
      api.containerAction(containerId, action, confirmed: confirmed);

  @override
  Future<DockerContainerLogs?> containerLogs(String containerId) =>
      api.containerLogs(containerId);

  @override
  Future<DockerContainerStats?> containerStats(String containerId) =>
      api.containerStats(containerId);

  @override
  Future<DockerContainerDetails?> containerDetails(String containerId) =>
      api.containerDetails(containerId);

  @override
  Future<DockerOperationResult> renameContainer(
          String containerId, String name) =>
      api.renameContainer(containerId, name);

  @override
  Future<DockerOperationResult> createContainer(
          DockerContainerCreate request) =>
      api.createContainer(request);

  @override
  Future<DockerStackOperationResult> validateStack(
          DockerStackDefinition definition) =>
      api.validateStack(definition);

  @override
  Future<DockerStackOperationResult> deployStack(
          DockerStackDefinition definition) =>
      api.deployStack(definition);

  @override
  Future<DockerStackOperationResult> stackAction(
          String stackName, String action,
          {bool confirmed = false}) =>
      api.stackAction(stackName, action, confirmed: confirmed);

  @override
  Future<List<DockerStackService>> stackServices(String stackName) =>
      api.stackServices(stackName);

  @override
  Future<DockerStackDefinition?> stackDefinition(String stackName) =>
      api.stackDefinition(stackName);

  @override
  Future<DockerOperationResult> pullImage(String reference) =>
      api.pullImage(reference);

  @override
  Future<DockerOperationResult> deleteImage(String imageId) =>
      api.deleteImage(imageId);

  @override
  Future<DockerOperationResult> createNetwork(String name,
          {String driver = 'bridge'}) =>
      api.createNetwork(name, driver: driver);

  @override
  Future<DockerOperationResult> deleteNetwork(String networkId) =>
      api.deleteNetwork(networkId);

  @override
  Future<DockerOperationResult> createVolume(String name,
          {String driver = 'local'}) =>
      api.createVolume(name, driver: driver);

  @override
  Future<DockerOperationResult> deleteVolume(String volumeName) =>
      api.deleteVolume(volumeName);
}
