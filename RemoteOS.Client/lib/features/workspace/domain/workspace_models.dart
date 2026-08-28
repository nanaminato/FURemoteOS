import '../../../core/theme/theme_models.dart';

class WorkspaceWindowSize {
  const WorkspaceWindowSize(
      {required this.key, required this.width, required this.height});

  final String key;
  final double width;
  final double height;

  factory WorkspaceWindowSize.fromJson(Map<String, dynamic> json) =>
      WorkspaceWindowSize(
        key: json['key'] as String,
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() =>
      {'key': key, 'width': width, 'height': height};
}

class WorkspaceWindowLayouts {
  const WorkspaceWindowLayouts({this.windows = const []});

  final List<WorkspaceWindowSize> windows;

  factory WorkspaceWindowLayouts.fromJson(Map<String, dynamic> json) {
    final source = json['windows'];
    return WorkspaceWindowLayouts(
      windows: source is List
          ? source
              .whereType<Map<String, dynamic>>()
              .map(WorkspaceWindowSize.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() =>
      {'windows': windows.map((item) => item.toJson()).toList()};
}

class WorkspacePreferences {
  const WorkspacePreferences({
    required this.wallpaperKey,
    required this.theme,
    required this.timeFormat,
    required this.dateFormat,
    required this.language,
    required this.region,
    required this.themePreferences,
    this.defaultApps = const [],
    this.notepadDefaultEncoding = 'UTF-8',
    this.codeEditorDefaultEncoding = 'UTF-8',
  });

  final String wallpaperKey;
  final ThemeKind theme;
  final String timeFormat;
  final String dateFormat;
  final String language;
  final String region;
  final ThemePreferencesDto themePreferences;
  final List<WorkspaceDefaultAppMapping> defaultApps;
  final String notepadDefaultEncoding;
  final String codeEditorDefaultEncoding;

  WorkspacePreferences copyWith({
    String? wallpaperKey,
    ThemeKind? theme,
    String? timeFormat,
    String? dateFormat,
    String? language,
    String? region,
    ThemePreferencesDto? themePreferences,
    List<WorkspaceDefaultAppMapping>? defaultApps,
    String? notepadDefaultEncoding,
    String? codeEditorDefaultEncoding,
  }) =>
      WorkspacePreferences(
        wallpaperKey: wallpaperKey ?? this.wallpaperKey,
        theme: theme ?? this.theme,
        timeFormat: timeFormat ?? this.timeFormat,
        dateFormat: dateFormat ?? this.dateFormat,
        language: language ?? this.language,
        region: region ?? this.region,
        themePreferences: themePreferences ?? this.themePreferences,
        defaultApps: defaultApps ?? this.defaultApps,
        notepadDefaultEncoding:
            notepadDefaultEncoding ?? this.notepadDefaultEncoding,
        codeEditorDefaultEncoding:
            codeEditorDefaultEncoding ?? this.codeEditorDefaultEncoding,
      );

  factory WorkspacePreferences.fromJson(Map<String, dynamic> json) =>
      WorkspacePreferences(
        wallpaperKey: json['wallpaperKey'] as String? ?? 'builtin:bloom',
        theme: switch (json['theme']) {
          'dark' => ThemeKind.dark,
          'system' => ThemeKind.system,
          _ => ThemeKind.light,
        },
        timeFormat: json['timeFormat'] as String? ?? '24h',
        dateFormat: json['dateFormat'] as String? ?? 'yyyy/M/d',
        language: json['language'] as String? ?? 'en-US',
        region: json['region'] as String? ?? 'en-US',
        themePreferences: json['themePreferences'] is Map<String, dynamic>
            ? ThemePreferencesDto.fromJson(
                json['themePreferences'] as Map<String, dynamic>)
            : ThemePreferencesDto.defaults,
        defaultApps: (json['defaultApps'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => WorkspaceDefaultAppMapping.fromJson(
                Map<String, dynamic>.from(item)))
            .toList(growable: false),
        notepadDefaultEncoding:
            (json['notepadDefaultEncoding']?.toString().trim().isNotEmpty ==
                    true)
                ? json['notepadDefaultEncoding'].toString().trim()
                : 'UTF-8',
        codeEditorDefaultEncoding:
            (json['codeEditorDefaultEncoding']?.toString().trim().isNotEmpty ==
                    true)
                ? json['codeEditorDefaultEncoding'].toString().trim()
                : 'UTF-8',
      );

  Map<String, dynamic> toJson() => {
        'wallpaperKey': wallpaperKey,
        'theme': theme.name,
        'timeFormat': timeFormat,
        'dateFormat': dateFormat,
        'language': language,
        'region': region,
        'themePreferences': themePreferences.toJson(),
        'defaultApps': defaultApps.map((item) => item.toJson()).toList(),
        'notepadDefaultEncoding': notepadDefaultEncoding,
        'codeEditorDefaultEncoding': codeEditorDefaultEncoding,
      };
}

class WorkspaceDefaultAppMapping {
  const WorkspaceDefaultAppMapping({required this.scheme, required this.appId});
  final String scheme;
  final String appId;

  factory WorkspaceDefaultAppMapping.fromJson(Map<String, dynamic> json) =>
      WorkspaceDefaultAppMapping(
        scheme: (json['scheme'] ?? '').toString(),
        appId: (json['appId'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'scheme': scheme, 'appId': appId};
}
