import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';
  static const List<String> sansFallbacks = ['Inter', 'Roboto', 'system-ui', 'sans-serif'];
  static const List<String> serifFallbacks = ['Georgia', 'Noto Serif', 'Times New Roman', 'serif'];

  /// Editorial Display Serif for top-level greetings & screen titles
  static const TextStyle editorialHero = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: serifFallbacks,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.18,
  );

  /// Screen Title: 25 px Editorial Serif Bold (matches "Library", "Progress", "Account")
  static const TextStyle screenTitle = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: serifFallbacks,
    fontSize: 25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
  );

  /// Section Heading: 18 px Editorial Serif Semibold (matches "Subject Mastery", "Quick Access")
  static const TextStyle sectionHeading = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: serifFallbacks,
    fontSize: 18.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.28,
  );

  /// Card Heading / Compact Header: 16 px Clean Sans Semibold
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: sansFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    height: 1.3,
  );

  /// Body: 15.5 px Clean Sans Regular
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: sansFallbacks,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    height: 1.48,
  );

  /// Secondary text and captions: 13.5 px Clean Sans Regular
  static const TextStyle secondary = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: sansFallbacks,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: Color(0xFF646182),
  );

  /// Small label / metadata: 12 px Medium
  static const TextStyle smallLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: sansFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: Color(0xFF646182),
  );

  // Backwards-compatible aliases
  static const TextStyle displayLarge = editorialHero;
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
    fontFamilyFallback: sansFallbacks,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  static const TextStyle labelMedium = smallLabel;
  static const TextStyle labelSmall = smallLabel;
}

/// Editorial Typography Token Aliases
class ZenTypography {
  ZenTypography._();

  static const List<String> serifFallbacks = AppTypography.serifFallbacks;
  static const List<String> sansFallbacks = AppTypography.sansFallbacks;

  static const TextStyle editorialTitle = AppTypography.screenTitle;
  static const TextStyle editorialHeadline = AppTypography.sectionHeading;

  static const TextStyle subtitleMist = TextStyle(
    fontFamilyFallback: sansFallbacks,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  static const TextStyle hankoSeal = TextStyle(
    fontFamilyFallback: sansFallbacks,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );
}
