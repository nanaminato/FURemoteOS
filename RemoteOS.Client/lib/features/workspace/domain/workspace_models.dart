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
  });

  final String wallpaperKey;
  final ThemeKind theme;
  final String timeFormat;
  final String dateFormat;
  final String language;
  final String region;
  final ThemePreferencesDto themePreferences;

  WorkspacePreferences copyWith({
    String? wallpaperKey,
    ThemeKind? theme,
    String? timeFormat,
    String? dateFormat,
    String? language,
    String? region,
    ThemePreferencesDto? themePreferences,
  }) =>
      WorkspacePreferences(
        wallpaperKey: wallpaperKey ?? this.wallpaperKey,
        theme: theme ?? this.theme,
        timeFormat: timeFormat ?? this.timeFormat,
        dateFormat: dateFormat ?? this.dateFormat,
        language: language ?? this.language,
        region: region ?? this.region,
        themePreferences: themePreferences ?? this.themePreferences,
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
      );

  Map<String, dynamic> toJson() => {
        'wallpaperKey': wallpaperKey,
        'theme': theme.name,
        'timeFormat': timeFormat,
        'dateFormat': dateFormat,
        'language': language,
        'region': region,
        'themePreferences': themePreferences.toJson(),
      };
}
