import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme/colors.dart';

/// Draws a delicate 4-point sparkle star on [canvas].
void _drawSparkleStar(Canvas canvas, Offset center, double radius, Paint paint) {
  final path = Path()
    ..moveTo(center.dx, center.dy - radius)
    ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
    ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
    ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
    ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
    ..close();
  canvas.drawPath(path, paint);
}

/// Layered translucent silk wave ribbons + ambient sparkles over the warm ivory canvas.
class SilkRibbonBackgroundPainter extends CustomPainter {
  final bool isDark;
  final bool intense;

  const SilkRibbonBackgroundPainter({required this.isDark, this.intense = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Soft atmospheric corner blooms
    final bloomAlpha = isDark ? (intense ? 0.14 : 0.08) : (intense ? 0.48 : 0.30);
    canvas.drawCircle(
      Offset(w * 0.92, h * 0.08),
      w * 0.68,
      Paint()
        ..shader = RadialGradient(
          colors: [
            (isDark ? const Color(0xFF4F46E5) : const Color(0xFFDDD7FC)).withValues(alpha: bloomAlpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.92, h * 0.08), radius: w * 0.68)),
    );

    canvas.drawCircle(
      Offset(w * 0.05, h * 0.86),
      w * 0.72,
      Paint()
        ..shader = RadialGradient(
          colors: [
            (isDark ? const Color(0xFF3730A3) : const Color(0xFFE5DFFC)).withValues(alpha: bloomAlpha * 0.9),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.05, h * 0.86), radius: w * 0.72)),
    );

    // 2. Sweeping top flowing silk ribbon (matches upper wave drapes in ref screenshots)
    final topWave1 = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.82, 0)
      ..cubicTo(w * 0.70, h * 0.07, w * 0.42, h * 0.05, w * 0.28, h * 0.12)
      ..cubicTo(w * 0.16, h * 0.18, w * 0.06, h * 0.11, 0, h * 0.15)
      ..close();

    canvas.drawPath(
      topWave1,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF6366F1).withValues(alpha: 0.12), const Color(0xFF8B5CF6).withValues(alpha: 0.02)]
              : [
                  const Color(0xFFD5CEF9).withValues(alpha: intense ? 0.55 : 0.36),
                  const Color(0xFFEEEAFC).withValues(alpha: 0.08),
                ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.2)),
    );

    final topWave2 = Path()
      ..moveTo(w * 0.36, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.14)
      ..cubicTo(w * 0.80, h * 0.09, w * 0.64, h * 0.13, w * 0.50, h * 0.06)
      ..cubicTo(w * 0.42, h * 0.03, w * 0.38, h * 0.01, w * 0.36, 0)
      ..close();

    canvas.drawPath(
      topWave2,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? [const Color(0xFF818CF8).withValues(alpha: 0.10), Colors.transparent]
              : [
                  const Color(0xFFBDB4F4).withValues(alpha: intense ? 0.40 : 0.25),
                  const Color(0xFFE7E2FC).withValues(alpha: 0.05),
                ],
        ).createShader(Rect.fromLTWH(w * 0.3, 0, w * 0.7, h * 0.18)),
    );

    // 3. Flowing translucent bottom ribbon veil
    final bottomWave = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w, h * 0.78)
      ..cubicTo(w * 0.78, h * 0.87, w * 0.55, h * 0.80, w * 0.30, h * 0.88)
      ..cubicTo(w * 0.16, h * 0.92, w * 0.06, h * 0.84, 0, h * 0.88)
      ..close();

    canvas.drawPath(
      bottomWave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: isDark
              ? [const Color(0xFF4F46E5).withValues(alpha: 0.12), Colors.transparent]
              : [
                  const Color(0xFFDAD3FA).withValues(alpha: intense ? 0.46 : 0.28),
                  const Color(0xFFF3F0FC).withValues(alpha: 0.02),
                ],
        ).createShader(Rect.fromLTWH(0, h * 0.74, w, h * 0.26)),
    );

    if (intense) {
      // Extra diagonal silk fold behind Sage Orb & Splash
      final midRibbon = Path()
        ..moveTo(w, h * 0.28)
        ..cubicTo(w * 0.68, h * 0.34, w * 0.42, h * 0.50, 0, h * 0.62)
        ..lineTo(0, h * 0.74)
        ..cubicTo(w * 0.44, h * 0.64, w * 0.74, h * 0.48, w, h * 0.46)
        ..close();
      canvas.drawPath(
        midRibbon,
        Paint()
          ..color = (isDark ? const Color(0xFF6366F1) : const Color(0xFFD6CFF9))
              .withValues(alpha: isDark ? 0.07 : 0.26),
      );
    }

    // 4. Delicate diamond sparkles
    final starPaint = Paint()
      ..color = (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF7D78EA))
          .withValues(alpha: isDark ? 0.28 : 0.22);
    _drawSparkleStar(canvas, Offset(w * 0.88, h * 0.17), 5.5, starPaint);
    _drawSparkleStar(canvas, Offset(w * 0.12, h * 0.36), 4.0, starPaint);
    _drawSparkleStar(canvas, Offset(w * 0.85, h * 0.78), 5.0, starPaint);
  }

  @override
  bool shouldRepaint(covariant SilkRibbonBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.intense != intense;
}

/// 3D Luminous Glassmorphic Sage Sphere with orbiting ellipses & twinkling diamond stars.
class TrueMeOrbPainter extends CustomPainter {
  final double breath; // 0.0 .. 1.0
  final bool isDark;
  final bool showCenterStar;

  const TrueMeOrbPainter({
    required this.breath,
    required this.isDark,
    this.showCenterStar = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = (math.min(size.width, size.height) * 0.285) + (breath * 3.0);

    // Outer ambient aura halo
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF818CF8).withValues(alpha: isDark ? 0.34 : 0.32),
          const Color(0xFFC4B5FD).withValues(alpha: isDark ? 0.12 : 0.16),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseR * 2.2));
    canvas.drawCircle(center, baseR * 2.2, haloPaint);

    // Subtle frosted outer ring halo
    canvas.drawCircle(
      center,
      baseR * (1.28 + breath * 0.05),
      Paint()
        ..color = (isDark ? Colors.white : const Color(0xFF9F9AF8))
            .withValues(alpha: isDark ? 0.10 : 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Back half of inclined orbital rings
    final ringPaint = Paint()
      ..color = (isDark ? const Color(0xFFC7D2FE) : const Color(0xFF8783F2))
          .withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 7.5 + (breath * 0.10));
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: baseR * 3.1, height: baseR * 1.12), ringPaint);
    canvas.rotate(math.pi / 3.2);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: baseR * 2.85, height: baseR * 0.96), ringPaint);
    canvas.restore();

    // Rich 3D Spherical Body with radial illumination
    final spherePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.38),
        radius: 0.98,
        colors: [
          Color(0xFFECEAFE),
          Color(0xFF908FF6),
          Color(0xFF554FE0),
          Color(0xFF423BC6),
        ],
        stops: [0.0, 0.32, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseR));
    canvas.drawCircle(center, baseR, spherePaint);

    // Soft internal crescent rim light (bottom-right reflection)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: baseR * 0.86),
      0.15,
      math.pi * 0.65,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.0,
    );

    // Diagonal glass light ribbon across sphere
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: baseR)));
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 5);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, -baseR * 0.22), width: baseR * 2.4, height: baseR * 0.22),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.restore();

    // Glossy specular catchlight top-left
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - baseR * 0.34, center.dy - baseR * 0.36),
        width: baseR * 0.42,
        height: baseR * 0.24,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.48),
    );

    // Optional centered 4-point luminous star (great for Splash emblem)
    if (showCenterStar) {
      _drawSparkleStar(
        canvas,
        center,
        baseR * 0.46,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
    }

    // Orbiting satellite sparkle stars
    final sparklePaint = Paint()..color = const Color(0xFF9A97F7).withValues(alpha: 0.85);
    _drawSparkleStar(
      canvas,
      Offset(center.dx + baseR * 1.48, center.dy - baseR * 0.42),
      5.5,
      sparklePaint,
    );
    _drawSparkleStar(
      canvas,
      Offset(center.dx - baseR * 1.42, center.dy + baseR * 0.54),
      4.5,
      sparklePaint,
    );
    canvas.drawCircle(
      Offset(center.dx + baseR * 1.12, center.dy + baseR * 0.82),
      2.6,
      Paint()..color = const Color(0xFFB5B2FA),
    );
  }

  @override
  bool shouldRepaint(covariant TrueMeOrbPainter oldDelegate) =>
      oldDelegate.breath != breath || oldDelegate.isDark != isDark || oldDelegate.showCenterStar != showCenterStar;
}

/// Crisp white 4-point star + thin orbital ring for the Centered Bottom Dock Orb.
class SageDockStarPainter extends CustomPainter {
  const SageDockStarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.40;

    canvas.drawCircle(
      center,
      r * 0.96,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2.15, height: r * 0.82),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();

    _drawSparkleStar(
      canvas,
      center,
      r * 0.72,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant SageDockStarPainter oldDelegate) => false;
}

/// Painterly twilight portal arch & hills for Home "Today's Focus" Hero Card.
class HeroFocusArchPainter extends CustomPainter {
  final bool isDark;

  const HeroFocusArchPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Warm sunlit sky glow behind the arch
    canvas.drawCircle(
      Offset(w * 0.62, h * 0.42),
      w * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            (isDark ? const Color(0xFF818CF8) : const Color(0xFFFAF1E6)).withValues(alpha: isDark ? 0.25 : 0.75),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.62, h * 0.42), radius: w * 0.42)),
    );

    // Distant hazy blue-lavender mountain range
    final backHill = Path()
      ..moveTo(0, h)
      ..moveTo(w * 0.05, h)
      ..cubicTo(w * 0.28, h * 0.62, w * 0.48, h * 0.60, w * 0.75, h * 0.46)
      ..quadraticBezierTo(w * 0.90, h * 0.38, w, h * 0.48)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      backHill,
      Paint()..color = (isDark ? const Color(0xFF28294A) : const Color(0xFFB5B7DE)).withValues(alpha: 0.48),
    );

    // Mid emerald-sage hill
    final midHill = Path()
      ..moveTo(w * 0.16, h)
      ..cubicTo(w * 0.36, h * 0.72, w * 0.64, h * 0.72, w, h * 0.56)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      midHill,
      Paint()..color = (isDark ? const Color(0xFF313362) : const Color(0xFF9EA2D8)).withValues(alpha: 0.56),
    );

    // Serene 3D-shaded stone gateway arch
    final archOuter = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.45, h * 0.33, 52, 74),
      topLeft: const Radius.circular(26),
      topRight: const Radius.circular(26),
    );
    canvas.drawRRect(
      archOuter,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF6366F1), const Color(0xFF3730A3)]
              : [const Color(0xFF7B85C9), const Color(0xFF5D65AD)],
        ).createShader(archOuter.outerRect),
    );

    // Glowing sky inside portal arch
    final archInner = archOuter.deflate(9);
    canvas.drawRRect(
      archInner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC7D2FE), Color(0xFFFEF3C7)],
        ).createShader(archInner.outerRect),
    );

    // Steps leading into portal
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.41, h * 0.72, 60, 8), const Radius.circular(3)),
      Paint()..color = (isDark ? const Color(0xFF4F46E5) : const Color(0xFF9196D2)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.37, h * 0.77, 68, 9), const Radius.circular(3)),
      Paint()..color = (isDark ? const Color(0xFF3730A3) : const Color(0xFF7D82C4)),
    );

    // Botanical tree foliage framing the right corner
    final treeColor = (isDark ? const Color(0xFF1F3B36) : const Color(0xFF5C8A6E)).withValues(alpha: 0.72);
    canvas.drawCircle(Offset(w * 0.90, h * 0.25), 26, Paint()..color = treeColor);
    canvas.drawCircle(Offset(w * 0.98, h * 0.38), 22, Paint()..color = treeColor.withValues(alpha: 0.65));
    canvas.drawCircle(Offset(w * 0.80, h * 0.32), 18, Paint()..color = treeColor.withValues(alpha: 0.55));

    // Ambient twilight stars
    final starP = Paint()..color = Colors.white.withValues(alpha: 0.75);
    _drawSparkleStar(canvas, Offset(w * 0.32, h * 0.22), 5.0, starP);
    _drawSparkleStar(canvas, Offset(w * 0.66, h * 0.16), 3.8, starP);
  }

  @override
  bool shouldRepaint(covariant HeroFocusArchPainter oldDelegate) => oldDelegate.isDark != isDark;
}

/// Painterly sunrise horizon & pathway for the bottom Home Insight / Quote Banner.
class CalmHorizonBannerPainter extends CustomPainter {
  final bool isDark;

  const CalmHorizonBannerPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft rising sun glow
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.42),
      h * 0.56,
      Paint()
        ..shader = RadialGradient(
          colors: [
            (isDark ? const Color(0xFF818CF8) : const Color(0xFFFEF0DC)).withValues(alpha: isDark ? 0.25 : 0.85),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.78, h * 0.42), radius: h * 0.56)),
    );

    // Back lavender ridge
    final p1 = Path()
      ..moveTo(0, h)
      ..moveTo(0, h * 0.72)
      ..cubicTo(w * 0.35, h * 0.42, w * 0.62, h * 0.24, w, h * 0.48)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      p1,
      Paint()..color = (isDark ? const Color(0xFF2B2C52) : const Color(0xFFC5BFEF)).withValues(alpha: 0.52),
    );

    // Foreground meadow hill
    final p2 = Path()
      ..moveTo(w * 0.32, h)
      ..cubicTo(w * 0.56, h * 0.62, w * 0.80, h * 0.58, w, h * 0.72)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      p2,
      Paint()..color = (isDark ? const Color(0xFF393A6B) : const Color(0xFFAFA8EB)).withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant CalmHorizonBannerPainter oldDelegate) => oldDelegate.isDark != isDark;
}

/// Delicate translucent lavender leaf stems framing Profile Hero & Word Outline cards.
class BotanicalCornerPainter extends CustomPainter {
  final bool isDark;

  const BotanicalCornerPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final leafColor = (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF8B84E8))
        .withValues(alpha: isDark ? 0.16 : 0.22);
    final paint = Paint()..color = leafColor;
    final stemPaint = Paint()
      ..color = leafColor.withValues(alpha: (isDark ? 0.20 : 0.28))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    final stem = Path()
      ..moveTo(w * 0.86, h)
      ..quadraticBezierTo(w * 0.78, h * 0.56, w * 0.90, h * 0.16);
    canvas.drawPath(stem, stemPaint);

    void leaf(Offset base, double angle, double rx, double ry) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle);
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(rx * 0.6, -ry, rx * 1.4, -ry * 0.2)
        ..quadraticBezierTo(rx * 0.7, ry * 0.6, 0, 0)
        ..close();
      canvas.drawPath(p, paint);
      canvas.restore();
    }

    leaf(Offset(w * 0.82, h * 0.78), -2.4, 24, 10);
    leaf(Offset(w * 0.82, h * 0.74), -0.5, 22, 9);
    leaf(Offset(w * 0.81, h * 0.54), -2.3, 28, 11);
    leaf(Offset(w * 0.83, h * 0.48), -0.4, 24, 9);
    leaf(Offset(w * 0.86, h * 0.32), -2.1, 20, 8);
    leaf(Offset(w * 0.89, h * 0.18), -1.3, 18, 7);
  }

  @override
  bool shouldRepaint(covariant BotanicalCornerPainter oldDelegate) => oldDelegate.isDark != isDark;
}

/// Custom domain artwork for each Library Subject Card (replaces plain square Material icons).
class SubjectCardArtworkPainter extends CustomPainter {
  final String subject;
  final Color accent;
  final bool isDark;

  const SubjectCardArtworkPainter({
    required this.subject,
    required this.accent,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = subject.trim().toLowerCase();
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.52;

    final strokeP = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final softFill = Paint()..color = accent.withValues(alpha: isDark ? 0.24 : 0.16);
    final midFill = Paint()..color = accent.withValues(alpha: isDark ? 0.36 : 0.26);

    // Subtle light shimmer behind artwork
    canvas.drawCircle(
      Offset(cx, cy),
      math.min(w, h) * 0.44,
      Paint()..color = Colors.white.withValues(alpha: isDark ? 0.05 : 0.38),
    );

    if (s.contains('math') || s.contains('calc') || s.contains('alg') || s.contains('stat') || s.contains('geom')) {
      // Geometric Triangular Prism + Cone + Sparkles
      final cone = Path()
        ..moveTo(cx - 24, cy + 16)
        ..lineTo(cx - 10, cy - 16)
        ..lineTo(cx + 4, cy + 16)
        ..close();
      canvas.drawPath(cone, midFill);
      canvas.drawPath(cone, strokeP);

      final tri = Path()
        ..moveTo(cx + 2, cy - 22)
        ..lineTo(cx + 30, cy + 12)
        ..lineTo(cx - 2, cy + 12)
        ..close();
      canvas.drawPath(tri, softFill);
      canvas.drawPath(tri, strokeP);
      _drawSparkleStar(canvas, Offset(cx + 24, cy - 16), 5, Paint()..color = accent);
      return;
    }

    if (s.contains('phys') || s.contains('astro') || s.contains('mech') || s.contains('elec')) {
      // Bohr Atom Orbital Rings + Glowing Nucleus
      for (final ang in [0.0, math.pi / 3, -math.pi / 3]) {
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(ang);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 58, height: 22), strokeP);
        canvas.restore();
      }
      canvas.drawCircle(Offset(cx, cy), 6.5, Paint()..color = accent);
      canvas.drawCircle(Offset(cx + 22, cy - 10), 3.2, Paint()..color = accent);
      return;
    }

    if (s.contains('chem') || s.contains('pharm') || s.contains('food')) {
      // Conical Flask with Liquid + Bubbles
      final flask = Path()
        ..moveTo(cx - 7, cy - 22)
        ..lineTo(cx + 7, cy - 22)
        ..lineTo(cx + 7, cy - 10)
        ..lineTo(cx + 22, cy + 18)
        ..quadraticBezierTo(cx + 23, cy + 23, cx + 17, cy + 23)
        ..lineTo(cx - 17, cy + 23)
        ..quadraticBezierTo(cx - 23, cy + 23, cx - 22, cy + 18)
        ..lineTo(cx - 7, cy - 10)
        ..close();
      canvas.drawPath(flask, softFill);

      final liquid = Path()
        ..moveTo(cx - 14, cy + 4)
        ..lineTo(cx + 14, cy + 4)
        ..lineTo(cx + 21, cy + 18)
        ..quadraticBezierTo(cx + 22, cy + 22, cx + 17, cy + 22)
        ..lineTo(cx - 17, cy + 22)
        ..quadraticBezierTo(cx - 22, cy + 22, cx - 21, cy + 18)
        ..close();
      canvas.drawPath(liquid, midFill);
      canvas.drawPath(flask, strokeP);
      canvas.drawCircle(Offset(cx - 4, cy + 12), 2.5, Paint()..color = accent);
      canvas.drawCircle(Offset(cx + 5, cy + 9), 2.0, Paint()..color = accent);
      return;
    }

    if (s.contains('micro') || s.contains('bio') || s.contains('anat') || s.contains('med') || s.contains('ecol')) {
      // Lush Dual Botanical Leaf & Cellular Vein Artwork
      final bigLeaf = Path()
        ..moveTo(cx - 4, cy + 22)
        ..cubicTo(cx - 22, cy + 4, cx - 12, cy - 22, cx + 16, cy - 24)
        ..cubicTo(cx + 24, cy - 4, cx + 14, cy + 16, cx - 4, cy + 22)
        ..close();
      canvas.drawPath(bigLeaf, midFill);
      canvas.drawPath(bigLeaf, strokeP);

      // Center leaf vein
      canvas.drawLine(Offset(cx - 4, cy + 24), Offset(cx + 12, cy - 18), strokeP);

      // Second smaller leaf sprouting left
      final sideLeaf = Path()
        ..moveTo(cx - 6, cy + 14)
        ..cubicTo(cx - 26, cy + 8, cx - 28, cy - 10, cx - 12, cy - 10)
        ..cubicTo(cx - 4, cy - 4, cx - 4, cy + 8, cx - 6, cy + 14)
        ..close();
      canvas.drawPath(sideLeaf, softFill);
      canvas.drawPath(sideLeaf, strokeP);
      _drawSparkleStar(canvas, Offset(cx + 22, cy - 16), 4.5, Paint()..color = accent);
      return;
    }

    // Default Open Notebook + Floating Constellation Sparkles
    final leftPage = Path()
      ..moveTo(cx, cy - 14)
      ..quadraticBezierTo(cx - 14, cy - 18, cx - 26, cy - 12)
      ..lineTo(cx - 26, cy + 16)
      ..quadraticBezierTo(cx - 14, cy + 10, cx, cy + 16)
      ..close();
    final rightPage = Path()
      ..moveTo(cx, cy - 14)
      ..quadraticBezierTo(cx + 14, cy - 18, cx + 26, cy - 12)
      ..lineTo(cx + 26, cy + 16)
      ..quadraticBezierTo(cx + 14, cy + 10, cx, cy + 16)
      ..close();
    canvas.drawPath(leftPage, midFill);
    canvas.drawPath(rightPage, softFill);
    canvas.drawPath(leftPage, strokeP);
    canvas.drawPath(rightPage, strokeP);
    _drawSparkleStar(canvas, Offset(cx + 22, cy - 22), 5.0, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant SubjectCardArtworkPainter oldDelegate) =>
      oldDelegate.subject != subject || oldDelegate.accent != accent || oldDelegate.isDark != isDark;
}

/// Illustrated Microscope & Petri Dish Stage Card for Audio Explainer Studio.
class ExplainerMicroscopePainter extends CustomPainter {
  final bool isDark;
  final double pulse; // 0..1 animation wave

  const ExplainerMicroscopePainter({required this.isDark, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft mint-to-lavender painted bokeh backdrop
    canvas.drawCircle(
      Offset(w * 0.16, h * 0.72),
      56,
      Paint()..color = (isDark ? const Color(0xFF134E4A) : const Color(0xFFC9F2DE)).withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.28),
      68,
      Paint()..color = (isDark ? const Color(0xFF3730A3) : const Color(0xFFCBC4FB)).withValues(alpha: 0.55),
    );

    // Delicate botanical lavender leaves framing left & right
    final leafP = Paint()..color = (isDark ? const Color(0xFF6366F1) : const Color(0xFFA29CF5)).withValues(alpha: 0.45);
    void sprig(Offset origin, bool flip) {
      final sign = flip ? -1.0 : 1.0;
      for (int i = 0; i < 4; i++) {
        canvas.save();
        canvas.translate(origin.dx + sign * i * 7.0, origin.dy - i * 18.0);
        canvas.rotate(sign * (0.45 + i * 0.12));
        canvas.drawOval(const Rect.fromLTWH(-7, -14, 14, 24), leafP);
        canvas.restore();
      }
    }

    sprig(Offset(w * 0.14, h * 0.88), false);
    sprig(Offset(w * 0.86, h * 0.84), true);

    // Desk horizon shelf
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.80, w, h * 0.20),
      Paint()..color = (isDark ? const Color(0xFF1F223A) : Colors.white).withValues(alpha: 0.42),
    );

    // Petri dish bottom-left-center
    final dishCenter = Offset(w * 0.36, h * 0.77);
    canvas.drawOval(
      Rect.fromCenter(center: dishCenter, width: 62, height: 18),
      Paint()..color = isDark ? const Color(0xFF2D3256) : const Color(0xFFD6F4E7),
    );
    canvas.drawOval(
      Rect.fromCenter(center: dishCenter, width: 62, height: 18),
      Paint()
        ..color = isDark ? const Color(0xFF818CF8) : const Color(0xFF5FA392)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(Offset(dishCenter.dx - 10, dishCenter.dy - 1), 3, Paint()..color = AppColors.accent);
    canvas.drawCircle(Offset(dishCenter.dx + 12, dishCenter.dy + 1), 2.5, Paint()..color = AppColors.success);

    // Microscope Silhouette on the right-center
    final mx = w * 0.67;
    final my = h * 0.79;
    final scopeDark = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF39427B);
    final scopeMid = isDark ? const Color(0xFF6366F1) : const Color(0xFF6A70BC);

    // Base stand
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(mx - 26, my - 10, 52, 12), const Radius.circular(6)),
      Paint()..color = scopeDark,
    );
    // Curved C-arm
    canvas.drawArc(
      Rect.fromCenter(center: Offset(mx + 4, my - 40), width: 42, height: 60),
      -math.pi * 0.48,
      math.pi * 0.96,
      false,
      Paint()
        ..color = scopeDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    // Stage platform
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(mx - 22, my - 30, 30, 5), const Radius.circular(2.5)),
      Paint()..color = scopeMid,
    );
    // Tilted Eyepiece Barrel
    canvas.save();
    canvas.translate(mx - 2, my - 64);
    canvas.rotate(0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -26, 14, 42), const Radius.circular(5)),
      Paint()..color = scopeMid,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -31, 18, 9), const Radius.circular(3)),
      Paint()..color = scopeDark,
    );
    canvas.restore();

    // Animated pulse halo around center play trigger
    if (pulse > 0.01) {
      canvas.drawCircle(
        Offset(w / 2, h / 2),
        34 + pulse * 14,
        Paint()
          ..color = AppColors.accent.withValues(alpha: (1 - pulse) * 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ExplainerMicroscopePainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.pulse != pulse;
}

/// Bespoke 3D-shaded squircle Quick Access icon medallions matching Reference Image 3 Left.
class QuickAccessEmblem extends StatelessWidget {
  final String kind; // 'sage', 'library', 'planner', 'quiz'
  final bool isDark;

  const QuickAccessEmblem({super.key, required this.kind, required this.isDark});

  @override
  Widget build(BuildContext context) {
    List<Color> colors;
    Widget child;

    switch (kind) {
      case 'sage':
        colors = isDark
            ? [const Color(0xFF28265E), const Color(0xFF1D1B44)]
            : [const Color(0xFFEDE9FE), const Color(0xFFDCD6FE)];
        child = CustomPaint(
          size: const Size(34, 34),
          painter: TrueMeOrbPainter(breath: 0.3, isDark: isDark),
        );
        break;
      case 'library':
        colors = isDark
            ? [const Color(0xFF0E303D), const Color(0xFF132638)]
            : [const Color(0xFFE0F7FA), const Color(0xFFC8EBF5)];
        child = Icon(
          Icons.menu_book_rounded,
          size: 24,
          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0E7490),
        );
        break;
      case 'planner':
        colors = isDark
            ? [const Color(0xFF382714), const Color(0xFF291D0F)]
            : [const Color(0xFFFFF3E0), const Color(0xFFFDE0B8)];
        child = Icon(
          Icons.calendar_today_rounded,
          size: 23,
          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        );
        break;
      case 'quiz':
      default:
        colors = isDark
            ? [const Color(0xFF1E224A), const Color(0xFF171A38)]
            : [const Color(0xFFEDE9FE), const Color(0xFFDCD8FD)];
        child = Icon(
          Icons.verified_user_rounded,
          size: 24,
          color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
        );
        break;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// 3D-shaded layered notebook/deck emblem for Flashcards selector & Quiz Setup selector.
class StackedDeckEmblem extends StatelessWidget {
  final Color? accentColor;
  final double size;

  const StackedDeckEmblem({super.key, this.accentColor, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = accentColor ?? AppColors.accent;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(3, 3),
            child: Container(
              width: size * 0.72,
              height: size * 0.82,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          Container(
            width: size * 0.74,
            height: size * 0.84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.withValues(alpha: 0.85), c],
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.menu_book_rounded, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Miniature rendered document style preview thumbnails for Export Studio PDF/PPTX.
class ExportStyleMiniPreview extends StatelessWidget {
  final String kind; // 'cornell', 'minimalCute', 'zenInk', 'modernHighYield', 'cuteDeck', 'chartDeck'

  const ExportStyleMiniPreview({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ExportPreviewPainter(kind),
      child: const SizedBox.expand(),
    );
  }
}

class _ExportPreviewPainter extends CustomPainter {
  final String kind;
  _ExportPreviewPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (kind == 'cornell') {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFDF7));
      // Spiral rings on left
      for (double y = 12; y < h - 8; y += 14) {
        canvas.drawCircle(Offset(7, y), 2.2, Paint()..color = const Color(0xFFD6D3D1));
      }
      // Red vertical Cornell margin
      canvas.drawLine(
        Offset(w * 0.24, 0),
        Offset(w * 0.24, h),
        Paint()
          ..color = const Color(0xFFFCA5A5)
          ..strokeWidth = 1.4,
      );
      // Horizontal lined paper rows + miniature note lines
      for (double y = 16; y < h - 6; y += 12) {
        canvas.drawLine(
          Offset(12, y),
          Offset(w - 10, y),
          Paint()
            ..color = const Color(0xFFDBEAFE)
            ..strokeWidth = 1.0,
        );
        if (y < h * 0.72) {
          canvas.drawLine(
            Offset(w * 0.28, y - 3),
            Offset(w * 0.72, y - 3),
            Paint()
              ..color = const Color(0xFF94A3B8).withValues(alpha: 0.45)
              ..strokeWidth = 1.6,
          );
        }
      }
      return;
    }

    if (kind == 'minimalCute') {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF5F8), Color(0xFFF3F0FF)],
          ).createShader(Offset.zero & size),
      );
      // Cute floating doodle pill box
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.14, h * 0.16, w * 0.72, h * 0.68), const Radius.circular(10)),
        Paint()..color = Colors.white.withValues(alpha: 0.90),
      );
      // Pastel bullet dots + wavy bars
      final colors = [const Color(0xFFF472B6), const Color(0xFF818CF8), const Color(0xFF34D399)];
      for (int i = 0; i < 3; i++) {
        final y = h * 0.30 + i * 16;
        canvas.drawCircle(Offset(w * 0.25, y), 3.2, Paint()..color = colors[i]);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.34, y - 2.5, w * (0.42 - i * 0.06), 5), const Radius.circular(3)),
          Paint()..color = const Color(0xFFCBD5E1),
        );
      }
      _drawSparkleStar(canvas, Offset(w * 0.78, h * 0.22), 5.0, Paint()..color = const Color(0xFFA78BFA));
      return;
    }

    if (kind == 'zenInk') {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9F4EC), Color(0xFFEDE2D3)],
          ).createShader(Offset.zero & size),
      );
      // Sumi-ink misty mountains
      final mtn = Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.72)
        ..quadraticBezierTo(w * 0.26, h * 0.42, w * 0.55, h * 0.68)
        ..quadraticBezierTo(w * 0.78, h * 0.34, w, h * 0.56)
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(mtn, Paint()..color = const Color(0xFF78716C).withValues(alpha: 0.32));
      // Bamboo / blossom branch top-left
      canvas.drawLine(
        const Offset(6, 18),
        Offset(w * 0.48, h * 0.34),
        Paint()
          ..color = const Color(0xFF57534E)
          ..strokeWidth = 1.6,
      );
      canvas.drawCircle(Offset(w * 0.30, h * 0.22), 4.2, Paint()..color = const Color(0xFFE11D48).withValues(alpha: 0.45));
      canvas.drawCircle(Offset(w * 0.45, h * 0.31), 3.5, Paint()..color = const Color(0xFFE11D48).withValues(alpha: 0.45));
      // Red hankō square seal bottom-right
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w - 20, h - 20, 11, 11), const Radius.circular(2.5)),
        Paint()..color = const Color(0xFFDC2626),
      );
      return;
    }

    if (kind == 'cuteDeck') {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEDE9FE), Color(0xFFE0F2FE)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.14, h * 0.18, w * 0.72, h * 0.64), const Radius.circular(12)),
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      // Graduation cap icon silhouette in indigo
      final cap = Path()
        ..moveTo(w * 0.50, h * 0.34)
        ..lineTo(w * 0.68, h * 0.44)
        ..lineTo(w * 0.50, h * 0.54)
        ..lineTo(w * 0.32, h * 0.44)
        ..close();
      canvas.drawPath(cap, Paint()..color = AppColors.accent);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.40, h * 0.52, w * 0.20, 8), const Radius.circular(3)),
        Paint()..color = AppColors.accentLight,
      );
      return;
    }

    // Modern High-Yield bento / chart layout
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF2FF), Color(0xFFE5EAFF)],
        ).createShader(Offset.zero & size),
    );
    if (kind == 'chartDeck') {
      final bars = [0.28, 0.42, 0.58, 0.74, 0.90];
      for (int i = 0; i < bars.length; i++) {
        final bh = h * 0.54 * bars[i];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.18 + i * (w * 0.13), h * 0.78 - bh, w * 0.09, bh),
            const Radius.circular(3),
          ),
          Paint()..color = AppColors.accent.withValues(alpha: 0.45 + i * 0.11),
        );
      }
    } else {
      // Modern grid cards
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(10, 10, w - 20, h * 0.20), const Radius.circular(6)),
        Paint()..color = AppColors.accent.withValues(alpha: 0.75),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(10, h * 0.36, w * 0.42, h * 0.50), const Radius.circular(7)),
        Paint()..color = Colors.white,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.54, h * 0.36, w * 0.36, h * 0.50), const Radius.circular(7)),
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ExportPreviewPainter oldDelegate) => oldDelegate.kind != kind;
}
