import 'dart:ui';
import 'package:flutter/material.dart';

/// Liquid Glass Design System Tokens
/// Apple-grade glassmorphism with high-performance 60fps rendering,
/// specular light refraction, and tactile micro-interactions.
class LiquidGlassTheme {
  LiquidGlassTheme._();

  // ---------------------------------------------------------------------------
  // CANVAS BACKGROUNDS
  // ---------------------------------------------------------------------------
  /// Deep Space Obsidian canvas background for Dark Mode
  static const Color darkCanvas = Color(0xFF0B0E14);

  /// Warm Silk White canvas background for Light Mode
  static const Color lightCanvas = Color(0xFFF7F9FC);

  // ---------------------------------------------------------------------------
  // ACCENT SIGNATURE COLORS
  // ---------------------------------------------------------------------------
  /// Electric Indigo — Primary intellect, Sage AI, and focus flow
  static const Color electricIndigo = Color(0xFF6366F1);

  /// Emerald Focus — Study streaks, active milestones, and masteries
  static const Color emeraldFocus = Color(0xFF10B981);

  /// Amber Streak — Spaced repetition alerts, countdowns, and highlights
  static const Color amberStreak = Color(0xFFF59E0B);

  /// Rose Alert — Critical error, decay warning, and reset actions
  static const Color roseAlert = Color(0xFFF43F5E);

  // ---------------------------------------------------------------------------
  // TEXT HIERARCHY
  // ---------------------------------------------------------------------------
  // Dark Mode Text
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Light Mode Text
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // ---------------------------------------------------------------------------
  // GLASS FILL COLORS
  // ---------------------------------------------------------------------------
  /// Dark glass card fill: 6% white opacity
  static final Color darkGlassFill = Colors.white.withOpacity(0.06);

  /// Light glass card fill: 70% white opacity
  static final Color lightGlassFill = Colors.white.withOpacity(0.70);

  /// Dark elevated glass card fill: 9% white opacity
  static final Color darkGlassFillElevated = Colors.white.withOpacity(0.09);

  /// Light elevated glass card fill: 85% white opacity
  static final Color lightGlassFillElevated = Colors.white.withOpacity(0.85);

  // ---------------------------------------------------------------------------
  // SPECULAR BORDER GRADIENTS (1px Light Refraction)
  // ---------------------------------------------------------------------------
  /// 1px specular highlight for Dark Mode: 20% white top-left -> 3% white bottom-right
  static final LinearGradient darkSpecularBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withOpacity(0.20),
      Colors.white.withOpacity(0.03),
    ],
  );

  /// 1px specular highlight for Light Mode: crisp white highlight top-left -> subtle tint bottom-right
  static final LinearGradient lightSpecularBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withOpacity(0.95),
      Colors.black.withOpacity(0.07),
    ],
  );

  /// Active Indigo Specular Border for focused/highlighted cards
  static final LinearGradient indigoSpecularBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      electricIndigo.withOpacity(0.75),
      electricIndigo.withOpacity(0.15),
    ],
  );

  /// Active Emerald Specular Border for mastery/completed cards
  static final LinearGradient emeraldSpecularBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      emeraldFocus.withOpacity(0.75),
      emeraldFocus.withOpacity(0.15),
    ],
  );

  // ---------------------------------------------------------------------------
  // BLUR PRESETS (Strictly on floating panels to preserve 60fps)
  // ---------------------------------------------------------------------------
  static const double standardBlurSigma = 12.0;
  static const double floatingNavBlurSigma = 16.0;

  // ---------------------------------------------------------------------------
  // ELEVATION SHADOWS
  // ---------------------------------------------------------------------------
  static List<BoxShadow> darkGlassShadow({Color? glowColor}) {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.35),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withOpacity(0.20),
          blurRadius: 24,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
    ];
  }

  static List<BoxShadow> lightGlassShadow({Color? glowColor}) {
    return [
      BoxShadow(
        color: const Color(0xFF64748B).withOpacity(0.08),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withOpacity(0.15),
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // ERGONOMIC TOUCH TARGETS & RADII
  // ---------------------------------------------------------------------------
  static const double minTouchTarget = 44.0;
  static const double cardRadius = 16.0;
  static const double pillRadius = 999.0;
}

/// Context extensions for seamless ergonomic access to Liquid Glass tokens
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

  Color get liquidTextSecondary => isDark
      ? LiquidGlassTheme.darkTextSecondary
      : LiquidGlassTheme.lightTextSecondary;

  Color get liquidTextMuted =>
      isDark ? LiquidGlassTheme.darkTextMuted : LiquidGlassTheme.lightTextMuted;

  List<BoxShadow> liquidShadow({Color? glowColor}) => isDark
      ? LiquidGlassTheme.darkGlassShadow(glowColor: glowColor)
      : LiquidGlassTheme.lightGlassShadow(glowColor: glowColor);
}
