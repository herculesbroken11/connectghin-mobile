import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compact multicolor “G” mark (Google brand colors). Not an official asset; for UI affordance only.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GoogleMarkPainter(),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);
  static const _blue = Color(0xFF4285F4);
  static const _deg = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.shortestSide;
    const strokeFactor = 0.14;
    final stroke = w * strokeFactor;
    final oval = Rect.fromLTWH(w * 0.08, w * 0.08, w * 0.84, w * 0.84);

    Paint strokePaint(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Ring segments (approximate consumer “G” mark).
    canvas.drawArc(oval, -35 * _deg, 88 * _deg, false, strokePaint(_red));
    canvas.drawArc(oval, 58 * _deg, 72 * _deg, false, strokePaint(_yellow));
    canvas.drawArc(oval, 132 * _deg, 78 * _deg, false, strokePaint(_green));
    canvas.drawArc(oval, 210 * _deg, 105 * _deg, false, strokePaint(_blue));

    // Horizontal bar (blue).
    final barY = w * 0.52;
    canvas.drawLine(
      Offset(w * 0.52, barY),
      Offset(w * 0.86, barY),
      strokePaint(_blue),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
