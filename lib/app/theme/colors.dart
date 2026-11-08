import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds (Refined Deep Obsidian & Slate System)
  static const Color background = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF131B2E);
  static const Color surfaceLighter = Color(0xFF1E293B);

  // Brand Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF8B5CF6); // Violet
  static const Color accent = Color(0xFF06B6D4); // Cyan Glow
  static const Color accentCyan = Color(0xFF38BDF8); // Sky Cyan

  // Status & Feedback
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFF43F5E);
  static const Color info = Color(0xFF3B82F6);

  // Text Colors (High Contrast WCAG AA Compliant)
  static const Color textPrimary = Color(0xFFF8FAFC); // 100% Crisp White
  static const Color textSecondary = Color(0xFFCBD5E1); // Slate-300 (85% contrast)
  static const Color textMuted = Color(0xFF94A3B8); // Slate-400 (4.8:1 contrast)

  // Refined Modern Liquid Glass Palette
  static const Color glassSurface = Color(0x281E293B); // Translucent slate
  static const Color glassSurfaceHover = Color(0x3D334155);
  static const Color glassBorderLight = Color(0x66CBD5E1); // Specular rim
  static const Color glassBorderDark = Color(0x3394A3B8); // Crisp slate edge
  static const Color glassShadow = Color(0x59000000); // 35% black

  // Specular Border Gradient (Light shining from top-left)
  static const LinearGradient glassBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x66FFFFFF), // High specular reflection
      Color(0x26CBD5E1), // Mid sheen
      Color(0x0F94A3B8), // Deep refraction
    ],
    stops: [0.0, 0.45, 1.0],
  );

  // Glass Background Gradient
  static const LinearGradient glassFillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x261E293B),
      Color(0x140F172A),
    ],
  );

  // Glow Gradients for Sage AI
  static const LinearGradient sageGlowGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF06B6D4)],
  );
}
