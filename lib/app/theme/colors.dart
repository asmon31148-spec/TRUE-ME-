import 'package:flutter/material.dart';

/// Calm, plain design system tokens matching NotebookLM, Google Keep, and Notion.
class AppColors {
  AppColors._();

  // Light Mode Tokens (Default)
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF6F7F9);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF5B6472);
  static const Color textMuted = Color(0xFF5B6472);

  // Single Accent Brand Color
  static const Color accent = Color(0xFF2563EB); // Royal Blue
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color accentCyan = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF2563EB);

  // Status & Feedback
  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFB45309);
  static const Color error = Color(0xFFB91C1C);
  static const Color info = Color(0xFF2563EB);

  // Dark Mode Tokens (Available for dark theme)
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF171A20);
  static const Color darkBorder = Color(0xFF262B33);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFFA0A7B4);
  static const Color darkAccent = Color(0xFF6C9BFF);
  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkError = Color(0xFFF87171);

  // Neutral Aliases (clean flat styling, zero glow, zero gradients)
  static const Color cardSurface = surface;
  static const Color cardBorder = border;

  // Zero gradient fallbacks for backwards compatibility
  static const LinearGradient sageGlowGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF2563EB)],
  );
  static const LinearGradient glassFillGradient = LinearGradient(
    colors: [Color(0xFFF6F7F9), Color(0xFFF6F7F9)],
  );
  static const LinearGradient glassBorderGradient = LinearGradient(
    colors: [Color(0xFFE5E7EB), Color(0xFFE5E7EB)],
  );
}
