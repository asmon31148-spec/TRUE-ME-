import 'package:flutter/material.dart';

/// Deterministic pastel theme tokens per academic subject or category.
class SubjectPastelStyle {
  final Color bgStart;
  final Color bgEnd;
  final Color accent;
  final Color border;
  final IconData icon;

  const SubjectPastelStyle({
    required this.bgStart,
    required this.bgEnd,
    required this.accent,
    required this.border,
    required this.icon,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [bgStart, bgEnd],
      );

  static SubjectPastelStyle forSubject(String subject, {required bool isDark}) {
    final s = subject.trim().toLowerCase();

    // Biological / Medical / Chemical / Organic -> Mint Emerald or Sunny Amber
    if (s.contains('micro') ||
        s.contains('bio') ||
        s.contains('anat') ||
        s.contains('physiol') ||
        s.contains('botany') ||
        s.contains('zool') ||
        s.contains('med') ||
        s.contains('ecology')) {
      return isDark
          ? const SubjectPastelStyle(
              bgStart: Color(0xFF0E2922),
              bgEnd: Color(0xFF133329),
              accent: Color(0xFF4ADE80),
              border: Color(0xFF1E4D3E),
              icon: Icons.eco_rounded,
            )
          : const SubjectPastelStyle(
              bgStart: Color(0xFFF0FDF4),
              bgEnd: Color(0xFFDCFCE7),
              accent: Color(0xFF15803D),
              border: Color(0xFFBBF7D0),
              icon: Icons.eco_rounded,
            );
    }

    if (s.contains('chem') || s.contains('pharm') || s.contains('food')) {
      return isDark
          ? const SubjectPastelStyle(
              bgStart: Color(0xFF2B2110),
              bgEnd: Color(0xFF332613),
              accent: Color(0xFFFBBF24),
              border: Color(0xFF523D1B),
              icon: Icons.science_rounded,
            )
          : const SubjectPastelStyle(
              bgStart: Color(0xFFFFFBEB),
              bgEnd: Color(0xFFFEF3C7),
              accent: Color(0xFFB45309),
              border: Color(0xFFFDE68A),
              icon: Icons.science_rounded,
            );
    }

    if (s.contains('phys') || s.contains('astro') || s.contains('mech') || s.contains('elec')) {
      return isDark
          ? const SubjectPastelStyle(
              bgStart: Color(0xFF11233D),
              bgEnd: Color(0xFF152A47),
              accent: Color(0xFF60A5FA),
              border: Color(0xFF1E3A63),
              icon: Icons.hub_outlined,
            )
          : const SubjectPastelStyle(
              bgStart: Color(0xFFEFF6FF),
              bgEnd: Color(0xFFDBEAFE),
              accent: Color(0xFF2563EB),
              border: Color(0xFFBFDBFE),
              icon: Icons.hub_outlined,
            );
    }

    if (s.contains('math') ||
        s.contains('calc') ||
        s.contains('alg') ||
        s.contains('stat') ||
        s.contains('geom') ||
        s.contains('econ')) {
      return isDark
          ? const SubjectPastelStyle(
              bgStart: Color(0xFF1D1B3B),
              bgEnd: Color(0xFF232048),
              accent: Color(0xFFA5B4FC),
              border: Color(0xFF33306B),
              icon: Icons.architecture_rounded,
            )
          : const SubjectPastelStyle(
              bgStart: Color(0xFFF4F3FF),
              bgEnd: Color(0xFFE8E6FF),
              accent: Color(0xFF5B5CE6),
              border: Color(0xFFD6D3FC),
              icon: Icons.architecture_rounded,
            );
    }

    if (s.contains('cs') ||
        s.contains('comp') ||
        s.contains('code') ||
        s.contains('data') ||
        s.contains('soft') ||
        s.contains('ai')) {
      return isDark
          ? const SubjectPastelStyle(
              bgStart: Color(0xFF241938),
              bgEnd: Color(0xFF2B1D44),
              accent: Color(0xFFC4B5FD),
              border: Color(0xFF422C69),
              icon: Icons.code_rounded,
            )
          : const SubjectPastelStyle(
              bgStart: Color(0xFFF5F3FF),
              bgEnd: Color(0xFFEDE9FE),
              accent: Color(0xFF7C3AED),
              border: Color(0xFFDDD6FE),
              icon: Icons.code_rounded,
            );
    }

    if (s.contains('hist') ||
        s.contains('lit') ||
        s.contains('eng') ||
        s.contains('law') ||
        s.contains('phil')) {
      return isDark
          ? const SubjectPastelStyle(
              bgStart: Color(0xFF321822),
              bgEnd: Color(0xFF3C1D29),
              accent: Color(0xFFFDA4AF),
              border: Color(0xFF592A3C),
              icon: Icons.menu_book_rounded,
            )
          : const SubjectPastelStyle(
              bgStart: Color(0xFFFFF1F2),
              bgEnd: Color(0xFFFFE4E6),
              accent: Color(0xFFE11D48),
              border: Color(0xFFFECDD3),
              icon: Icons.menu_book_rounded,
            );
    }

    // Deterministic rotation for arbitrary user subjects so each feels distinct
    final paletteLight = [
      const SubjectPastelStyle(
        bgStart: Color(0xFFF4F3FF),
        bgEnd: Color(0xFFE8E6FF),
        accent: Color(0xFF5B5CE6),
        border: Color(0xFFD6D3FC),
        icon: Icons.menu_book_rounded,
      ),
      const SubjectPastelStyle(
        bgStart: Color(0xFFEFF6FF),
        bgEnd: Color(0xFFDBEAFE),
        accent: Color(0xFF2563EB),
        border: Color(0xFFBFDBFE),
        icon: Icons.auto_stories_rounded,
      ),
      const SubjectPastelStyle(
        bgStart: Color(0xFFF0FDF4),
        bgEnd: Color(0xFFDCFCE7),
        accent: Color(0xFF15803D),
        border: Color(0xFFBBF7D0),
        icon: Icons.biotech_rounded,
      ),
      const SubjectPastelStyle(
        bgStart: Color(0xFFFFFBEB),
        bgEnd: Color(0xFFFEF3C7),
        accent: Color(0xFFB45309),
        border: Color(0xFFFDE68A),
        icon: Icons.lightbulb_outline_rounded,
      ),
    ];

    final paletteDark = [
      const SubjectPastelStyle(
        bgStart: Color(0xFF1D1B3B),
        bgEnd: Color(0xFF232048),
        accent: Color(0xFFA5B4FC),
        border: Color(0xFF33306B),
        icon: Icons.menu_book_rounded,
      ),
      const SubjectPastelStyle(
        bgStart: Color(0xFF11233D),
        bgEnd: Color(0xFF152A47),
        accent: Color(0xFF60A5FA),
        border: Color(0xFF1E3A63),
        icon: Icons.auto_stories_rounded,
      ),
      const SubjectPastelStyle(
        bgStart: Color(0xFF0E2922),
        bgEnd: Color(0xFF133329),
        accent: Color(0xFF4ADE80),
        border: Color(0xFF1E4D3E),
        icon: Icons.biotech_rounded,
      ),
      const SubjectPastelStyle(
        bgStart: Color(0xFF2B2110),
        bgEnd: Color(0xFF332613),
        accent: Color(0xFFFBBF24),
        border: Color(0xFF523D1B),
        icon: Icons.lightbulb_outline_rounded,
      ),
    ];

    final hash = s.isEmpty ? 0 : s.codeUnits.fold<int>(0, (a, b) => a + b);
    return isDark ? paletteDark[hash % paletteDark.length] : paletteLight[hash % paletteLight.length];
  }
}

/// Calm Editorial Ivory & Lavender Design Tokens ("True Me Studio")
class ZenColors {
  ZenColors._();

  // Light Mode ("Warm Milk Ivory & Soft Lavender")
  static const Color washiCanvas = Color(0xFFFAF7F4); // Warm milk-cream ivory canvas
  static const Color warmIvory = Color(0xFFF6F2EC);   // Warm parchment ivory tint
  static const Color washiSurface = Color(0xFFFFFFFF); // Pure crisp elevated card
  static const Color washiBorder = Color(0xFFECE8F5);  // Subtle barely-there hairline
  static const Color sumiInk = Color(0xFF1D1B3A);      // Deep editorial indigo-black ink
  static const Color stoneMist = Color(0xFF6B6888);    // Calm muted lavender-slate text

  // Primary Brand Indigo / Periwinkle
  static const Color vermilionSeal = Color(0xFF5B5CE6); // Calm Executive Indigo
  static const Color vermilionSoft = Color(0xFFF0EEFD); // Milky soft lavender wash

  // Dark Mode ("Deep Twilight Obsidian" — preserved for Theme toggle)
  static const Color darkCanvas = Color(0xFF0F111A);
  static const Color darkSurface = Color(0xFF171A27);
  static const Color darkBorder = Color(0xFF272B3F);
  static const Color darkInk = Color(0xFFF3F2FA);
  static const Color darkMist = Color(0xFF9B98B8);
  static const Color darkVermilion = Color(0xFF818CF8);

  // Subject Ink Tags (Pastel Washes)
  static const Color csInk = Color(0xFF7C3AED);
  static const Color csWash = Color(0xFFEDE9FE);
  static const Color microbioInk = Color(0xFF15803D);
  static const Color microbioWash = Color(0xFFDCFCE7);
  static const Color calculusInk = Color(0xFFB45309);
  static const Color calculusWash = Color(0xFFFEF3C7);
}

/// Unified App Colors — Soft Ivory, Elevated White, & Calm Indigo-Lavender Palette.
class AppColors {
  AppColors._();

  // Light Mode Tokens
  static const Color background = ZenColors.washiCanvas;
  static const Color warmCream = ZenColors.warmIvory;
  static const Color surface = ZenColors.washiSurface;
  static const Color surfaceMuted = Color(0xFFF3F1FA);
  static const Color border = ZenColors.washiBorder;
  static const Color textPrimary = ZenColors.sumiInk;
  static const Color textSecondary = ZenColors.stoneMist;
  static const Color textMuted = Color(0xFF9491B0);

  // Signature Lavender-Indigo Brand Accents
  static const Color accent = Color(0xFF5B5CE6);
  static const Color accentLight = Color(0xFF7B7CF7);
  static const Color accentDark = Color(0xFF4746C8);
  static const Color accentWash = Color(0xFFF1EEFC);
  static const Color milkyLavender = Color(0xFFF1EEFC);
  static const Color charcoalInk = Color(0xFF1B1A33);
  static const Color lavenderBloom = Color(0xFFDCD6FA);
  static const Color primary = accent;
  static const Color primaryLight = accentLight;
  static const Color accentCyan = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFF7C6CF0);

  // Pastel Card Accents (Matching Reference Palette)
  static const Color pastelBlue = Color(0xFFDBEAFE);
  static const Color pastelBlueInk = Color(0xFF2563EB);
  static const Color pastelGreen = Color(0xFFDCFCE7);
  static const Color pastelGreenInk = Color(0xFF15803D);
  static const Color pastelAmber = Color(0xFFFEF3C7);
  static const Color pastelAmberInk = Color(0xFFB45309);
  static const Color pastelLavender = Color(0xFFEDE9FE);
  static const Color pastelLavenderInk = Color(0xFF6D28D9);
  static const Color pastelRose = Color(0xFFFFE4E6);
  static const Color pastelRoseInk = Color(0xFFE11D48);

  // Status & Feedback
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFE11D48);
  static const Color info = Color(0xFF2563EB);

  // Dark Mode Tokens
  static const Color darkBackground = ZenColors.darkCanvas;
  static const Color darkSurface = ZenColors.darkSurface;
  static const Color darkSurfaceMuted = Color(0xFF1F2335);
  static const Color darkBorder = ZenColors.darkBorder;
  static const Color darkTextPrimary = ZenColors.darkInk;
  static const Color darkTextSecondary = ZenColors.darkMist;
  static const Color darkAccent = Color(0xFF818CF8);
  static const Color darkAccentWash = Color(0xFF252449);
  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkError = Color(0xFFFB7185);

  // Neutral Aliases
  static const Color cardSurface = surface;
  static const Color cardBorder = border;

  // Signature Tasteful Gradients
  static const LinearGradient indigoButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6F70F5), Color(0xFF524EE0)],
  );

  static const LinearGradient sageOrbGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7D79F6), Color(0xFF524CE0)],
  );

  static const LinearGradient heroFocusLightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEDEBF9), Color(0xFFE0DCF8)],
  );

  static const LinearGradient heroFocusDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D1F36), Color(0xFF252444)],
  );

  // Backwards-compatible aliases
  static const LinearGradient sageGlowGradient = indigoButtonGradient;
  static const LinearGradient glassFillGradient = LinearGradient(
    colors: [ZenColors.washiSurface, ZenColors.washiSurface],
  );
  static const LinearGradient glassBorderGradient = LinearGradient(
    colors: [ZenColors.washiBorder, ZenColors.washiBorder],
  );
}
