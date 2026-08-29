// Desktop background: gradient + subtle dot pattern paint.
//
// Pure visual composition.  Does not depend on any ViewModel or repository.

import 'package:flutter/material.dart';

import '../../../core/theme/theme_service.dart';

class DesktopBackground extends StatelessWidget {
  const DesktopBackground({
    super.key,
    required this.palette,
    this.wallpaperKey,
    this.serverUrl,
    this.workspaceId,
    this.accessToken,
  });

  final ThemePalette palette;
  final String? wallpaperKey;
  final String? serverUrl;
  final String? workspaceId;
  final String? accessToken;

  DecorationImage? get _wallpaperImage {
    final key = wallpaperKey;
    final server = serverUrl;
    final workspace = workspaceId;
    final token = accessToken;
    if (key == null ||
        !key.startsWith('custom:') ||
        server == null ||
        workspace == null ||
        token == null) {
      return null;
    }
    final blobId = key.substring('custom:'.length);
    if (blobId.isEmpty) return null;
    final uri = Uri.parse(server)
        .resolve('api/v1/workspaces/$workspace/wallpaper/$blobId');
    return DecorationImage(
      image: NetworkImage(uri.toString(),
          headers: {'Authorization': 'Bearer $token'}),
      fit: BoxFit.cover,
      onError: (_, __) {},
    );
  }

  List<Color> get _backgroundColors => switch (wallpaperKey) {
        'builtin:aurora' => const [Color(0xFF083344), Color(0xFF14532D)],
        'builtin:sand' => const [Color(0xFFB45309), Color(0xFF78350F)],
        'builtin:night' => const [Color(0xFF111827), Color(0xFF312E81)],
        'builtin:gradient' => const [Color(0xFF0F766E), Color(0xFF1D4ED8)],
        _ => [palette.appBackground, palette.shellBackground],
      };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: _wallpaperImage,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _backgroundColors,
        ),
      ),
      child: CustomPaint(painter: _DesktopPatternPainter(palette)),
    );
  }
}

class _DesktopPatternPainter extends CustomPainter {
  final ThemePalette palette;
  _DesktopPatternPainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.accent.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DesktopPatternPainter old) =>
      old.palette != palette;
}
