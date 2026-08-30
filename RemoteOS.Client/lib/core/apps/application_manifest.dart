/// Runtime metadata for a built-in RemoteOS application.
enum ApplicationInstancePolicy {
  multiWindow,
  singleWindow,
  singleWindowPerActivationKey,
}

enum ApplicationPlatform { windows, linux, macos, unknown }

extension ApplicationPlatformName on ApplicationPlatform {
  String get wireName => switch (this) {
        ApplicationPlatform.windows => 'windows',
        ApplicationPlatform.linux => 'linux',
        ApplicationPlatform.macos => 'macos',
        ApplicationPlatform.unknown => 'unknown',
      };

  static ApplicationPlatform parse(Object? value) =>
      switch (value?.toString().trim().toLowerCase()) {
        'windows' => ApplicationPlatform.windows,
        'linux' => ApplicationPlatform.linux,
        'macos' || 'macosx' || 'darwin' => ApplicationPlatform.macos,
        _ => ApplicationPlatform.unknown,
      };
}

class ApplicationServerRequirements {
  const ApplicationServerRequirements({
    this.platforms = const [],
    this.capabilities = const [],
  });

  final List<ApplicationPlatform> platforms;
  final List<String> capabilities;

  bool get isEmpty => platforms.isEmpty && capabilities.isEmpty;
}

/// Declarative package metadata. Keep it free of widgets and network clients.
class ApplicationManifest {
  ApplicationManifest({
    required this.id,
    required this.version,
    this.descriptionKey,
    this.requestedPermissions = const [],
    this.clientPlatforms = const [],
    this.server = const ApplicationServerRequirements(),
    this.instancePolicy = ApplicationInstancePolicy.multiWindow,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9.-]{1,127}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'must be a stable package id');
    }
  }

  final String id;
  final String version;
  final String? descriptionKey;
  final List<String> requestedPermissions;
  final List<ApplicationPlatform> clientPlatforms;
  final ApplicationServerRequirements server;
  final ApplicationInstancePolicy instancePolicy;
}

class RemoteServerDescriptor {
  const RemoteServerDescriptor({
    required this.platform,
    this.capabilities = const [],
  });

  final ApplicationPlatform platform;
  final List<String> capabilities;

  factory RemoteServerDescriptor.fromJson(Map<String, dynamic> json) =>
      RemoteServerDescriptor(
        platform: ApplicationPlatformName.parse(json['platform']),
        capabilities: (json['capabilities'] as List? ?? const [])
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false),
      );
}

enum ApplicationCompatibilityStatus {
  compatible,
  clientPlatformMismatch,
  serverPlatformMismatch,
  missingServerCapability,
  serverUnavailable,
}

class ApplicationCompatibilityResult {
  const ApplicationCompatibilityResult(this.status,
      {this.expected, this.actual});

  const ApplicationCompatibilityResult.compatible()
      : this(ApplicationCompatibilityStatus.compatible);

  final ApplicationCompatibilityStatus status;
  final String? expected;
  final String? actual;

  bool get isCompatible => status == ApplicationCompatibilityStatus.compatible;
}
