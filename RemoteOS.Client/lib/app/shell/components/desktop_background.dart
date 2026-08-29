// Desktop background: gradient + subtle dot pattern paint.
//
// Pure visual composition.  Does not depend on any ViewModel or repository.

import 'package:flutter/material.dart';

import '../../../core/theme/theme_service.dart';

class DesktopBackground extends StatelessWidget {
  const DesktopBackground({super.key, required this.palette});

  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.appBackground, palette.shellBackground],
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
