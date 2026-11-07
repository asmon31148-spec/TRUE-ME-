import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/liquid_glass_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? surfaceColor;
  final Gradient? surfaceGradient;
  final Gradient? borderGradient;
  final double borderWidth;
  final VoidCallback? onTap;
  final bool showShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = LiquidGlassTheme.radiusMedium,
    this.blur = LiquidGlassTheme.blurStandard,
    this.surfaceColor,
    this.surfaceGradient,
    this.borderGradient,
    this.borderWidth = 1.0,
    this.onTap,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceGradient == null
            ? (surfaceColor ?? AppColors.glassSurface)
            : null,
        gradient: surfaceGradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.08),
          highlightColor: Colors.white.withOpacity(0.04),
          child: cardContent,
        ),
      );
    }

    final cardWithBorder = CustomPaint(
      painter: _GlassBorderPainter(
        borderRadius: borderRadius,
        borderWidth: borderWidth,
        gradient: borderGradient ?? AppColors.glassBorderGradient,
      ),
      child: cardContent,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                const BoxShadow(
                  color: AppColors.glassShadow,
                  blurRadius: 28,
                  spreadRadius: -6,
                  offset: Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: cardWithBorder,
        ),
      ),
    );
  }
}

class _GlassBorderPainter extends CustomPainter {
  final double borderRadius;
  final double borderWidth;
  final Gradient gradient;

  _GlassBorderPainter({
    required this.borderRadius,
    required this.borderWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      borderWidth / 2,
      borderWidth / 2,
      size.width - borderWidth,
      size.height - borderWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = gradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.gradient != gradient;
  }
}
