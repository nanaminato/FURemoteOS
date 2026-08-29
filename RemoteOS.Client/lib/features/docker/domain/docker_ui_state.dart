// Docker feature — immutable presentation state.
//
// The previous ChangeNotifier _DockerVm stored state as public mutable
// fields.  Moving state into a dedicated immutable class and exposing it
// via a ValueNotifier in the ViewModel gives fine-grained reactivity
// (AGENTS.md § 9, § 30 — avoid whole-page rebuilds).

import 'package:flutter/foundation.dart';

import '../data/remote_docker_api.dart';

@immutable
class DockerUiState {
  const DockerUiState({
    required this.containers,
    required this.images,
    required this.networks,
    required this.volumes,
    required this.stacks,
    required this.stackServices,
    required this.availableNetworks,
    required this.statusText,
    required this.isLoading,
    required this.isOperationRunning,
    required this.operationTitle,
    required this.operationLog,
    required this.isDockerAvailable,
    required this.isDockerInstallRequired,
    required this.engineVersion,
    required this.enginePlatform,
    required this.selectedContainerId,
    required this.selectedStackName,
    required this.selectedImageId,
    required this.selectedNetworkId,
    required this.selectedVolumeName,
    required this.containerDetails,
    required this.containerDetailsText,
    required this.containerLogs,
    required this.containerStats,
  });

  final List<DockerContainer> containers;
  final List<DockerImage> images;
  final List<DockerNetwork> networks;
  final List<DockerVolume> volumes;
  final List<DockerStack> stacks;
  final List<DockerStackService> stackServices;
  final List<String> availableNetworks;

  final String statusText;
  final bool isLoading;
  final bool isOperationRunning;
  final String operationTitle;
  final String operationLog;

  final bool isDockerAvailable;
  final bool isDockerInstallRequired;
  final String engineVersion;
  final String enginePlatform;

  final String? selectedContainerId;
  final String? selectedStackName;
  final String? selectedImageId;
  final String? selectedNetworkId;
  final String? selectedVolumeName;

  final DockerContainerDetails? containerDetails;
  final String containerDetailsText;
  final String containerLogs;
  final String containerStats;

  factory DockerUiState.initial() => DockerUiState(
        containers: const [],
        images: const [],
        networks: const [],
        volumes: const [],
        stacks: const [],
        stackServices: const [],
        availableNetworks: const ['bridge'],
        statusText: 'docker.status.loading',
        isLoading: false,
        isOperationRunning: false,
        operationTitle: '',
        operationLog: '',
        isDockerAvailable: false,
        isDockerInstallRequired: false,
        engineVersion: '—',
        enginePlatform: '—',
        selectedContainerId: null,
        selectedStackName: null,
        selectedImageId: null,
        selectedNetworkId: null,
        selectedVolumeName: null,
        containerDetails: null,
        containerDetailsText: '',
        containerLogs: '',
        containerStats: '',
      );

  DockerContainer? findContainer(String? id) {
    if (id == null) return null;
    for (final c in containers) {
      if (c.id == id) return c;
    }
    return null;
  }

  DockerStack? findStack(String? name) {
    if (name == null) return null;
    for (final s in stacks) {
      if (s.name == name) return s;
    }
    return null;
  }

  DockerImage? findImage(String? id) {
    if (id == null) return null;
    for (final i in images) {
      if (i.id == id) return i;
    }
    return null;
  }

  DockerNetwork? findNetwork(String? id) {
    if (id == null) return null;
    for (final n in networks) {
      if (n.id == id) return n;
    }
    return null;
  }

  DockerVolume? findVolume(String? name) {
    if (name == null) return null;
    for (final v in volumes) {
      if (v.name == name) return v;
    }
    return null;
  }

  int get runningContainerCount =>
      containers.where((c) => c.state.toLowerCase() == 'running').length;

  bool get hasOperationActivity => operationTitle.trim().isNotEmpty;

  DockerUiState copyWith({
    List<DockerContainer>? containers,
    List<DockerImage>? images,
    List<DockerNetwork>? networks,
    List<DockerVolume>? volumes,
    List<DockerStack>? stacks,
    List<DockerStackService>? stackServices,
    List<String>? availableNetworks,
    String? statusText,
    bool? isLoading,
    bool? isOperationRunning,
    String? operationTitle,
    String? operationLog,
    bool? isDockerAvailable,
    bool? isDockerInstallRequired,
    String? engineVersion,
    String? enginePlatform,
    String? selectedContainerId,
    String? selectedStackName,
    String? selectedImageId,
    String? selectedNetworkId,
    String? selectedVolumeName,
    DockerContainerDetails? containerDetails,
    String? containerDetailsText,
    String? containerLogs,
    String? containerStats,
    bool clearSelectedContainerId = false,
    bool clearSelectedStackName = false,
    bool clearSelectedImageId = false,
    bool clearSelectedNetworkId = false,
    bool clearSelectedVolumeName = false,
    bool clearContainerDetails = false,
  }) {
    return DockerUiState(
      containers: containers ?? this.containers,
      images: images ?? this.images,
      networks: networks ?? this.networks,
      volumes: volumes ?? this.volumes,
      stacks: stacks ?? this.stacks,
      stackServices: stackServices ?? this.stackServices,
      availableNetworks: availableNetworks ?? this.availableNetworks,
      statusText: statusText ?? this.statusText,
      isLoading: isLoading ?? this.isLoading,
      isOperationRunning: isOperationRunning ?? this.isOperationRunning,
      operationTitle: operationTitle ?? this.operationTitle,
      operationLog: operationLog ?? this.operationLog,
      isDockerAvailable: isDockerAvailable ?? this.isDockerAvailable,
      isDockerInstallRequired:
          isDockerInstallRequired ?? this.isDockerInstallRequired,
      engineVersion: engineVersion ?? this.engineVersion,
      enginePlatform: enginePlatform ?? this.enginePlatform,
      selectedContainerId: clearSelectedContainerId
          ? null
          : (selectedContainerId ?? this.selectedContainerId),
      selectedStackName: clearSelectedStackName
          ? null
          : (selectedStackName ?? this.selectedStackName),
      selectedImageId:
          clearSelectedImageId ? null : (selectedImageId ?? this.selectedImageId),
      selectedNetworkId: clearSelectedNetworkId
          ? null
          : (selectedNetworkId ?? this.selectedNetworkId),
      selectedVolumeName: clearSelectedVolumeName
          ? null
          : (selectedVolumeName ?? this.selectedVolumeName),
      containerDetails:
          clearContainerDetails ? null : (containerDetails ?? this.containerDetails),
      containerDetailsText: containerDetailsText ?? this.containerDetailsText,
      containerLogs: containerLogs ?? this.containerLogs,
      containerStats: containerStats ?? this.containerStats,
    );
  }
}
