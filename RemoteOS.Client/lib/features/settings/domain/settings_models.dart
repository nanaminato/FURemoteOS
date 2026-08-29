// Settings feature — domain models (ARCHITECTURE.md § 14).
//
// Pure Dart data classes shared between the UI and repository layers.
// UI-only convenience helpers (default association lookups, wallpaper
// presets, fake permission placeholders) live here because they encode
// domain-level configuration, not widget layout.

import 'package:flutter/painting.dart';

/// Parse a `#RRGGBB` / `#AARRGGBB` hex token into a [Color].
///
/// Mirrors Avalonia's color parsing convention used by the theme
/// preview strip in the Personalization page.  Malformed input falls
/// back to fully transparent black to keep the preview stable.
Color parseHexColor(String? raw) {
  var code = (raw ?? '').trim().toUpperCase();
  if (code.startsWith('#')) code = code.substring(1);
  if (code.length == 3) {
    code = code.split('').map((c) => c + c).join();
  }
  if (code.length == 6) {
    code = 'FF$code';
  }
  if (code.length != 8) return const Color(0x00000000);
  final n = int.tryParse(code, radix: 16);
  if (n == null) return const Color(0x00000000);
  return Color(n);
}

/// A selectable palette entry shown in the Personalization page.
class PaletteChoice {
  final String id; // e.g. 'builtin:remoteos-blue' or 'custom:xxx'
  final String name;
  final bool isCustom;
  const PaletteChoice(this.id, this.name, this.isCustom);
}

/// An application entry shown in the Default Apps and Applications pages.
class AppOptionUi {
  const AppOptionUi({
    required this.id,
    required this.displayName,
    required this.schemes,
    required this.extensions,
  });
  final String id;
  final String displayName;
  final List<String> schemes;
  final List<String> extensions;
}

/// A scheme -> app mapping shown in the Default Apps page.
class DefaultAppMappingUi {
  DefaultAppMappingUi({required this.scheme, required this.appId});
  String scheme;
  String appId;
}

/// A registry mirror shown in the Image Mirrors page.
class ImageMirrorUi {
  ImageMirrorUi({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.isDefault,
    required this.isSelected,
  });
  final String id;
  final String name;
  final String endpoint;
  final bool isDefault;
  bool isSelected;
}

/// Subpage selector used by the Applications view.
enum AppsSubpage { installedApps, appDetails }

/// Wallpaper preset used by the Personalization page.
List<({String key, String name})> wallpaperOptions() => const [
      (key: 'builtin:bloom', name: 'Bloom'),
      (key: 'builtin:aurora', name: 'Aurora'),
      (key: 'builtin:sand', name: 'Sand Dunes'),
      (key: 'builtin:night', name: 'Night City'),
      (key: 'builtin:gradient', name: 'Gradient Blue'),
    ];

/// Default scheme declarations per application id. Mirrors Avalonia baseline.
List<String> defaultSchemesFor(String id) => switch (id) {
      'explorer' => ['file'],
      'browser' => ['http', 'https', 'mailto', 'ftp'],
      'settings' => ['remoteos'],
      _ => const [],
    };

/// Default file-extension associations per application id. Mirrors Avalonia
/// baseline used by Explorer -> Open with list.
List<String> defaultExtensionsFor(String id) => switch (id) {
      'notepad' => const [
          '.txt',
          '.md',
          '.markdown',
          '.json',
          '.xml',
          '.yaml',
          '.yml',
          '.toml',
          '.ini',
          '.cfg',
          '.conf',
          '.config',
          '.log',
          '.csv',
        ],
      'code_editor' => const [
          '.dart',
          '.cs',
          '.py',
          '.ts',
          '.tsx',
          '.js',
          '.jsx',
          '.java',
          '.go',
          '.rs',
          '.c',
          '.cpp',
          '.h',
          '.hpp',
          '.sh',
          '.ps1',
          '.bat',
          '.sql',
          '.kt',
          '.swift',
        ],
      'terminal' => const ['.sh', '.ps1', '.bat', '.cmd'],
      'browser' => const ['.html', '.htm', '.xhtml', '.mht'],
      'docker_manager' => const ['.dockerfile', '.yaml', '.yml'],
      'image_viewer' => const [
          '.png',
          '.jpg',
          '.jpeg',
          '.gif',
          '.bmp',
          '.webp',
          '.svg',
        ],
      _ => const [],
    };

/// Fake permissions descriptor shown in the Applications details page. The
/// strings intentionally match Avalonia to keep UI parity; real permissions
/// live server side and are enumerated via the Apps client (MVP skips that).
List<String> fakePermissionsFor(String id) => switch (id) {
      'browser' => const [
          'Access to network (HTTP/HTTPS requests)',
          'Open external links on the host OS',
          'Read local HTML file associations',
        ],
      'explorer' => const [
          'Read and write workspace files',
          'Launch associated applications',
        ],
      'terminal' => const [
          'Execute shell commands in sessions',
          'Access current working directory',
        ],
      'code_editor' => const [
          'Open text files and source code',
          'Save files back to workspace storage',
        ],
      'docker_manager' => const [
          'Docker daemon access (list, pull, run, remove)',
          'Read image mirror registries',
        ],
      'settings' => const [
          'Read and modify workspace preferences',
          'Open developer mode and pairing',
        ],
      'task_manager' => const [
          'Enumerate server processes and network usage',
          'Request process termination',
        ],
      'firewall' => const [
          'Read and modify firewall rules',
        ],
      _ => const [],
    };
