// Settings feature — immutable presentation state (ARCHITECTURE.md § 9).
//
// The SettingsViewModel exposes a single instance of this class via a
// ValueNotifier.  Pages read the value reactively and call commands/methods
// on the ViewModel when they need to mutate it.  Keeping this file <300
// lines is part of the AGENTS.md file-size guidance.

import 'package:flutter/material.dart';

import 'settings_models.dart';

@immutable
class SettingsState {
  const SettingsState({
    required this.defaultMappings,
    required this.appOptions,
    required this.availableSchemes,
    required this.imageMirrors,
    required this.imageMirrorStatus,
    required this.imageMirrorsLoading,
    required this.networkTesting,
    required this.networkLatencyText,
    required this.networkAddrLoading,
    required this.networkAddrStatus,
    required this.networkAddresses,
    required this.appsSubpage,
    required this.selectedAppId,
    required this.appsActionStatus,
    required this.browserLinkTargetSaving,
    required this.browserLinkTargetStatus,
    required this.browserLinkTarget,
    required this.devModeEnabled,
    required this.devPairingToken,
    required this.networkInspectorStatus,
    required this.accentError,
    required this.sampleClock,
  });

  final List<DefaultAppMappingUi> defaultMappings;
  final List<AppOptionUi> appOptions;
  final List<String> availableSchemes;
  final List<ImageMirrorUi> imageMirrors;
  final String imageMirrorStatus;
  final bool imageMirrorsLoading;
  final bool networkTesting;
  final String networkLatencyText;
  final bool networkAddrLoading;
  final String networkAddrStatus;
  final List<({String iface, String address})> networkAddresses;
  final AppsSubpage appsSubpage;
  final String? selectedAppId;
  final String appsActionStatus;
  final bool browserLinkTargetSaving;
  final String browserLinkTargetStatus;
  final int browserLinkTarget;
  final bool devModeEnabled;
  final String devPairingToken;
  final String networkInspectorStatus;
  final String? accentError;
  final DateTime sampleClock;

  static SettingsState initial() => SettingsState(
        defaultMappings: const [],
        appOptions: const [],
        availableSchemes: const [],
        imageMirrors: const [],
        imageMirrorStatus: '',
        imageMirrorsLoading: false,
        networkTesting: false,
        networkLatencyText: '',
        networkAddrLoading: false,
        networkAddrStatus: '',
        networkAddresses: const [],
        appsSubpage: AppsSubpage.installedApps,
        selectedAppId: null,
        appsActionStatus: '',
        browserLinkTargetSaving: false,
        browserLinkTargetStatus: '',
        browserLinkTarget: 0,
        devModeEnabled: false,
        devPairingToken: 'R0-A1B2C3D4-E5F6',
        networkInspectorStatus: '',
        accentError: null,
        sampleClock: DateTime.now(),
      );

  SettingsState copyWith({
    List<DefaultAppMappingUi>? defaultMappings,
    List<AppOptionUi>? appOptions,
    List<String>? availableSchemes,
    List<ImageMirrorUi>? imageMirrors,
    String? imageMirrorStatus,
    bool? imageMirrorsLoading,
    bool? networkTesting,
    String? networkLatencyText,
    bool? networkAddrLoading,
    String? networkAddrStatus,
    List<({String iface, String address})>? networkAddresses,
    AppsSubpage? appsSubpage,
    String? selectedAppId,
    String? appsActionStatus,
    bool? browserLinkTargetSaving,
    String? browserLinkTargetStatus,
    int? browserLinkTarget,
    bool? devModeEnabled,
    String? devPairingToken,
    String? networkInspectorStatus,
    String? accentError,
    DateTime? sampleClock,
    bool clearSelectedAppId = false,
  }) {
    return SettingsState(
      defaultMappings: defaultMappings ?? this.defaultMappings,
      appOptions: appOptions ?? this.appOptions,
      availableSchemes: availableSchemes ?? this.availableSchemes,
      imageMirrors: imageMirrors ?? this.imageMirrors,
      imageMirrorStatus: imageMirrorStatus ?? this.imageMirrorStatus,
      imageMirrorsLoading: imageMirrorsLoading ?? this.imageMirrorsLoading,
      networkTesting: networkTesting ?? this.networkTesting,
      networkLatencyText: networkLatencyText ?? this.networkLatencyText,
      networkAddrLoading: networkAddrLoading ?? this.networkAddrLoading,
      networkAddrStatus: networkAddrStatus ?? this.networkAddrStatus,
      networkAddresses: networkAddresses ?? this.networkAddresses,
      appsSubpage: appsSubpage ?? this.appsSubpage,
      selectedAppId:
          clearSelectedAppId ? null : (selectedAppId ?? this.selectedAppId),
      appsActionStatus: appsActionStatus ?? this.appsActionStatus,
      browserLinkTargetSaving:
          browserLinkTargetSaving ?? this.browserLinkTargetSaving,
      browserLinkTargetStatus:
          browserLinkTargetStatus ?? this.browserLinkTargetStatus,
      browserLinkTarget: browserLinkTarget ?? this.browserLinkTarget,
      devModeEnabled: devModeEnabled ?? this.devModeEnabled,
      devPairingToken: devPairingToken ?? this.devPairingToken,
      networkInspectorStatus:
          networkInspectorStatus ?? this.networkInspectorStatus,
      accentError: accentError ?? this.accentError,
      sampleClock: sampleClock ?? this.sampleClock,
    );
  }
}
