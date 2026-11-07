import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds (Dark Space Canvas)
  static const Color background = Color(0xFF070B14);
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceLighter = Color(0xFF1E293B);

  // Brand Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF8B5CF6); // Violet
  static const Color accent = Color(0xFF06B6D4); // Cyan Glow
  static const Color accentCyan = Color(0xFF38BDF8);

  // Status & Feedback
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFF43F5E);
  static const Color info = Color(0xFF3B82F6);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Apple Liquid Glass Palette
  static const Color glassSurface = Color(0x14FFFFFF); // ~8% white
  static const Color glassSurfaceHover = Color(0x24FFFFFF); // ~14% white
  static const Color glassBorderLight = Color(0x4DFFFFFF); // ~30% white specular rim
  static const Color glassBorderDark = Color(0x0FFFFFFF); // ~6% white subtle edge
  static const Color glassShadow = Color(0x40000000); // 25% black

  // Specular Border Gradient (Light shining from top-left)
  static const LinearGradient glassBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x66FFFFFF), // High specular reflection
      Color(0x1AFFFFFF), // Mid sheen
      Color(0x05FFFFFF), // Deep refraction
    ],
    stops: [0.0, 0.45, 1.0],
  );

  // Glass Background Gradient
  static const LinearGradient glassFillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1AFFFFFF),
      Color(0x0DFFFFFF),
    ],
  );

  // Glow Gradients for Sage AI
  static const LinearGradient sageGlowGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF06B6D4)],
  );
}
