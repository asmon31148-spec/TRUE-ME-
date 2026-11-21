import 'package:flutter/material.dart';
import 'colors.dart';

class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';

  // Screen Title: 24 px, Semibold (w600) — inherits Theme onSurface automatically
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  // Section Heading: 18 px, Semibold (w600) — inherits Theme onSurface automatically
  static const TextStyle sectionHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  // Body: 16 px, Regular (w400) — inherits Theme onSurface automatically
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  // Secondary text and captions: 14 px, Regular (w400)
  static const TextStyle secondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: Color(0xFF6B7280),
  );

  // Small label: 12 px, Medium (w500)
  static const TextStyle smallLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Color(0xFF6B7280),
  );

  // Aliases for backwards compatibility
  static const TextStyle displayLarge = screenTitle;
  static const TextStyle displayMedium = screenTitle;
  static const TextStyle headlineLarge = screenTitle;
  static const TextStyle headlineMedium = sectionHeading;
  static const TextStyle headlineSmall = sectionHeading;
  static const TextStyle titleLarge = sectionHeading;
  static const TextStyle bodyLarge = body;
  static const TextStyle bodyMedium = body;
  static const TextStyle bodySmall = secondary;
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  static const TextStyle labelMedium = smallLabel;
  static const TextStyle labelSmall = smallLabel;
}

/// Zen Typography: Serif Editorial Headlines paired with Clean Sans Body
class ZenTypography {
  ZenTypography._();

  static const List<String> serifFallbacks = ['Georgia', 'Garamond', 'Times New Roman', 'serif'];
  static const List<String> sansFallbacks = ['Inter', 'Plus Jakarta Sans', 'system-ui', 'sans-serif'];

  static const TextStyle editorialTitle = TextStyle(
    fontFamilyFallback: serifFallbacks,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle editorialHeadline = TextStyle(
    fontFamilyFallback: serifFallbacks,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const TextStyle subtitleMist = TextStyle(
    fontFamilyFallback: sansFallbacks,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  static const TextStyle hankoSeal = TextStyle(
    fontFamilyFallback: serifFallbacks,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  );
}
