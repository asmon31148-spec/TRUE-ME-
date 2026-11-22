import 'package:flutter/material.dart';

/// Zen Paper & Ink Design System Tokens (The Mindful Scholar)
class ZenColors {
  ZenColors._();

  // Light Mode ("Morning Porcelain")
  static const Color washiCanvas = Color(0xFFF8FAFC);      // Clean modern soft slate canvas
  static const Color washiSurface = Color(0xFFFFFFFF);     // Pure clean white card surface
  static const Color washiBorder = Color(0xFFE2E8F0);      // Soft subtle hairline divider
  static const Color sumiInk = Color(0xFF0F172A);          // Deep modern slate black
  static const Color stoneMist = Color(0xFF64748B);        // Clean neutral secondary text
  
  // Signature Accent: Smart Indigo (Calming & Focused)
  static const Color vermilionSeal = Color(0xFF4F46E5);    // Smart Indigo (Focus, Clarity & Intellect)
  static const Color vermilionSoft = Color(0xFFEEF2FF);    // Soft indigo wash for chips & highlights

  // Dark Mode ("Midnight Scholar")
  static const Color darkCanvas = Color(0xFF0B0F19);       // Deep midnight slate canvas
  static const Color darkSurface = Color(0xFF151B28);      // Elevated obsidian slate card surface
  static const Color darkBorder = Color(0xFF222B3D);       // Soft hairline border
  static const Color darkInk = Color(0xFFF8FAFC);          // Bright clean text
  static const Color darkMist = Color(0xFF94A3B8);         // Muted slate text
  static const Color darkVermilion = Color(0xFF818CF8);    // Glowing indigo iris accent

  // Subject Ink Tags (Pastel Washes)
  static const Color csInk = Color(0xFF7C3AED);           // Violet ink
  static const Color csWash = Color(0xFFEDE9FE);
  static const Color microbioInk = Color(0xFF15803D);     // Forest ink
  static const Color microbioWash = Color(0xFFDCFCE7);
  static const Color calculusInk = Color(0xFFB45309);     // Amber ink
  static const Color calculusWash = Color(0xFFFEF3C7);
}

/// Unified App Colors — powered by the Zen Paper & Ink Design System.
class AppColors {
  AppColors._();

  // Light Mode Tokens ("Morning Parchment")
  static const Color background = ZenColors.washiCanvas;
  static const Color surface = ZenColors.washiSurface;
  static const Color border = ZenColors.washiBorder;
  static const Color textPrimary = ZenColors.sumiInk;
  static const Color textSecondary = ZenColors.stoneMist;
  static const Color textMuted = ZenColors.stoneMist;

  // Signature Vermilion Seal Accent
  static const Color accent = ZenColors.vermilionSeal;
  static const Color primary = ZenColors.vermilionSeal;
  static const Color primaryLight = Color(0xFFEF4444);
  static const Color accentCyan = ZenColors.vermilionSeal;
  static const Color secondary = ZenColors.sumiInk;

  // Status & Feedback
  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFB45309);
  static const Color error = ZenColors.vermilionSeal;
  static const Color info = Color(0xFF0284C7);

  // Dark Mode Tokens ("Midnight Scholar")
  static const Color darkBackground = ZenColors.darkCanvas;
  static const Color darkSurface = ZenColors.darkSurface;
  static const Color darkBorder = ZenColors.darkBorder;
  static const Color darkTextPrimary = ZenColors.darkInk;
  static const Color darkTextSecondary = ZenColors.darkMist;
  static const Color darkAccent = ZenColors.darkVermilion;
  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkError = ZenColors.darkVermilion;

  // Neutral Aliases
  static const Color cardSurface = surface;
  static const Color cardBorder = border;

  // Zero gradient fallbacks for backwards compatibility
  static const LinearGradient sageGlowGradient = LinearGradient(
    colors: [ZenColors.vermilionSeal, ZenColors.vermilionSeal],
  );
  static const LinearGradient glassFillGradient = LinearGradient(
    colors: [ZenColors.washiSurface, ZenColors.washiSurface],
  );
  static const LinearGradient glassBorderGradient = LinearGradient(
    colors: [ZenColors.washiBorder, ZenColors.washiBorder],
  );
}
