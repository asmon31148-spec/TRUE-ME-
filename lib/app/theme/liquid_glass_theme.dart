import 'package:flutter/material.dart';
import 'colors.dart';

/// Soft Surface & Elevation Design Tokens aligned with True Me Editorial Ivory & Lavender.
class LiquidGlassTheme {
  LiquidGlassTheme._();

  // Canvas Backgrounds
  static const Color darkCanvas = AppColors.darkBackground;
  static const Color lightCanvas = AppColors.background;

  // Accent Signature Colors
  static const Color electricIndigo = AppColors.accent;
  static const Color emeraldFocus = AppColors.success;
  static const Color amberStreak = AppColors.warning;
  static const Color roseAlert = AppColors.error;

  // Text Hierarchy
  static const Color darkTextPrimary = AppColors.darkTextPrimary;
  static const Color darkTextSecondary = AppColors.darkTextSecondary;
  static const Color darkTextMuted = Color(0xFF706D8E);

  static const Color lightTextPrimary = AppColors.textPrimary;
  static const Color lightTextSecondary = AppColors.textSecondary;
  static const Color lightTextMuted = AppColors.textMuted;

  // Soft Surface Fill Colors (Restrained, calm card elevation — zero neon/excessive blur)
  static const Color darkGlassFill = Color(0xFF171A27);
  static const Color lightGlassFill = Color(0xFFFFFFFF);
  static const Color darkGlassFillElevated = Color(0xFF1F2335);
  static const Color lightGlassFillElevated = Color(0xFFFFFFFF);

  // Subtle Hairline Border Gradients
  static final LinearGradient darkSpecularBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.12),
      Colors.white.withValues(alpha: 0.04),
    ],
  );

  static const LinearGradient lightSpecularBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFE5E0F5),
    ],
  );

  static final LinearGradient indigoSpecularBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      electricIndigo.withValues(alpha: 0.45),
      electricIndigo.withValues(alpha: 0.14),
    ],
  );

  static final LinearGradient emeraldSpecularBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      emeraldFocus.withValues(alpha: 0.45),
      emeraldFocus.withValues(alpha: 0.14),
    ],
  );

  // Restrained Elevation Constants
  static const double standardBlurSigma = 8.0;
  static const double floatingNavBlurSigma = 10.0;

  static List<BoxShadow> darkGlassShadow({Color? glowColor}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.28),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withValues(alpha: 0.14),
          blurRadius: 18,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
    ];
  }

  static List<BoxShadow> lightGlassShadow({Color? glowColor}) {
    return [
      const BoxShadow(
        color: Color(0x0D2E2A5C),
        blurRadius: 18,
        offset: Offset(0, 6),
      ),
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withValues(alpha: 0.10),
          blurRadius: 16,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
    ];
  }

  static const double minTouchTarget = 44.0;
  static const double cardRadius = 18.0;
  static const double pillRadius = 999.0;
}

/// Context extensions for calm True Me tokens
extension LiquidGlassContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get liquidCanvas =>
      isDark ? LiquidGlassTheme.darkCanvas : LiquidGlassTheme.lightCanvas;

  Color get liquidGlassFill =>
      isDark ? LiquidGlassTheme.darkGlassFill : LiquidGlassTheme.lightGlassFill;

  Color get liquidGlassFillElevated => isDark
      ? LiquidGlassTheme.darkGlassFillElevated
      : LiquidGlassTheme.lightGlassFillElevated;

  LinearGradient get liquidSpecularBorder => isDark
      ? LiquidGlassTheme.darkSpecularBorder
      : LiquidGlassTheme.lightSpecularBorder;

  Color get liquidTextPrimary =>
      isDark ? LiquidGlassTheme.darkTextPrimary : LiquidGlassTheme.lightTextPrimary;

  Color get liquidTextSecondary =>
      isDark ? LiquidGlassTheme.darkTextSecondary : LiquidGlassTheme.lightTextSecondary;

  Color get liquidTextMuted =>
      isDark ? LiquidGlassTheme.darkTextMuted : LiquidGlassTheme.lightTextMuted;

  List<BoxShadow> liquidShadow({Color? glowColor}) => isDark
      ? LiquidGlassTheme.darkGlassShadow(glowColor: glowColor)
      : LiquidGlassTheme.lightGlassShadow(glowColor: glowColor);
}
