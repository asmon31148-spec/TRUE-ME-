import 'dart:ui';
import 'package:flutter/material.dart';
import 'colors.dart';

class LiquidGlassTheme {
  LiquidGlassTheme._();

  static const double blurStandard = 18.0;
  static const double blurDense = 28.0;
  static const double blurSubtle = 10.0;

  static const double radiusSmall = 12.0;
  static const double radiusMedium = 20.0;
  static const double radiusLarge = 28.0;
  static const double radiusPill = 999.0;

  static BoxDecoration glassDecoration({
    double borderRadius = radiusMedium,
    Color? surfaceColor,
    Gradient? surfaceGradient,
    Gradient? borderGradient,
    double borderWidth = 1.0,
    bool showShadow = true,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: surfaceGradient == null
          ? (surfaceColor ?? AppColors.glassSurface)
          : null,
      gradient: surfaceGradient,
      border: Border.all(
        color: Colors.transparent,
        width: 0,
      ),
      boxShadow: showShadow
          ? [
              const BoxShadow(
                color: AppColors.glassShadow,
                blurRadius: 24,
                spreadRadius: -4,
                offset: Offset(0, 12),
              ),
            ]
          : null,
    );
  }

  static Widget glassBackdrop({
    required Widget child,
    double blur = blurStandard,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(radiusMedium),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      ),
    );
  }
}
