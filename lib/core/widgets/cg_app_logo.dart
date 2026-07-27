import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../generated/brand_logo_bytes.dart';

enum CgAppLogoVariant {
  /// Full logo art (clubs + wordmark). Use large on light plates.
  full,

  /// Icon-only mark for small headers next to the word “Connectghin”.
  mark,
}

/// Connectghin brand logo.
///
/// Prefer [CgAppLogoVariant.mark] under ~80px — the full PNG wordmark becomes muddy.
class CgAppLogo extends StatelessWidget {
  const CgAppLogo({
    super.key,
    this.height = 88,
    this.variant = CgAppLogoVariant.full,
    this.plate = false,
  });

  final double height;
  final CgAppLogoVariant variant;

  /// White rounded plate — use on dark green headers so the logo stays crisp.
  final bool plate;

  @override
  Widget build(BuildContext context) {
    final child = variant == CgAppLogoVariant.mark
        ? _BrandMarkIcon(size: height)
        : Image.memory(
            kBrandLogoPngBytes,
            height: height,
            width: height,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _BrandMarkIcon(size: height),
          );

    if (!plate) return child;

    final pad = height < 72 ? 6.0 : 10.0;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(height < 72 ? 14 : 18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Crisp vector mark: crossed clubs + ball (scales cleanly at any size).
class _BrandMarkIcon extends StatelessWidget {
  const _BrandMarkIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BrandMarkPainter()),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = (w * 0.075).clamp(2.0, 5.5);

    final green = Paint()
      ..color = CgColors.green700
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final charcoal = Paint()
      ..color = CgColors.charcoal
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final gold = Paint()
      ..color = CgColors.premiumGold
      ..style = PaintingStyle.fill;

    // Left→right club (charcoal)
    final p1 = Path()
      ..moveTo(w * 0.22, h * 0.78)
      ..lineTo(w * 0.72, h * 0.18);
    canvas.drawPath(p1, charcoal);
    // Club head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.18, h * 0.82), width: w * 0.16, height: h * 0.1),
      Paint()..color = CgColors.charcoal,
    );

    // Right→left club (green)
    final p2 = Path()
      ..moveTo(w * 0.78, h * 0.78)
      ..lineTo(w * 0.28, h * 0.18);
    canvas.drawPath(p2, green);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.82, h * 0.82), width: w * 0.16, height: h * 0.1),
      Paint()..color = CgColors.green700,
    );

    // Link at intersection
    final linkR = w * 0.11;
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.42),
      linkR,
      Paint()
        ..color = CgColors.premiumGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.85,
    );

    // Golf ball
    final ballC = Offset(w * 0.5, h * 0.62);
    final ballR = w * 0.11;
    canvas.drawCircle(ballC, ballR, Paint()..color = CgColors.white);
    canvas.drawCircle(
      ballC,
      ballR,
      Paint()
        ..color = CgColors.gray300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Dimples
    final dimple = Paint()..color = CgColors.gray400;
    for (final o in [
      Offset(-0.03, -0.02),
      Offset(0.025, -0.015),
      Offset(0.0, 0.03),
      Offset(-0.02, 0.025),
      Offset(0.03, 0.02),
    ]) {
      canvas.drawCircle(ballC + Offset(w * o.dx, h * o.dy), w * 0.012, dimple);
    }

    // Small motion arcs
    final arc = Paint()
      ..color = CgColors.green600.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final rect = Rect.fromCenter(
        center: Offset(w * (0.28 - i * 0.04), h * 0.58),
        width: w * 0.12,
        height: h * 0.1,
      );
      canvas.drawArc(rect, 1.2, 1.2, false, arc);
    }

    // Accent tee tip
    canvas.drawCircle(Offset(w * 0.5, h * 0.42), w * 0.028, gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
