import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/pikayun_theme.dart';

/// A quiet, static signal field shared by the primary app destinations.
///
/// It adds network-tool identity without competing with live data or adding
/// permanently running animation.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    required this.child,
    this.showSignalField = true,
    super.key,
  });

  final Widget child;
  final bool showSignalField;

  @override
  Widget build(BuildContext context) {
    final colors = context.pikayunColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.canvasStart, colors.canvasEnd],
            ),
          ),
        ),
        Positioned(
          top: -150,
          right: -130,
          width: 360,
          height: 360,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    colors.signalGlow.withValues(alpha: isDark ? .18 : .13),
                    colors.signalGlow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showSignalField)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SignalFieldPainter(
                    color: colors.signalGrid.withValues(
                      alpha: isDark ? .085 : .055,
                    ),
                  ),
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class _SignalFieldPainter extends CustomPainter {
  const _SignalFieldPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = color;
    const spacing = 28.0;
    for (double y = 14; y < size.height; y += spacing) {
      for (double x = 14; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), .7, dotPaint);
      }
    }

    final orbitPaint = Paint()
      ..color = color.withValues(alpha: color.a * 1.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width + 18, 28);
    for (final radius in <double>[84, 132, 188]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * .62,
        math.pi * .72,
        false,
        orbitPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalFieldPainter oldDelegate) =>
      oldDelegate.color != color;
}
