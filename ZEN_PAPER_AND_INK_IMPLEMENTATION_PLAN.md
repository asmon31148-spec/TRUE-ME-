# True Me: "Zen Paper & Ink" (The Mindful Scholar) Implementation Plan

## Executive Summary
This document outlines the step-by-step transformation of True Me's "Today" dashboard (`lib/features/today/screens/today_screen.dart`) from a generic stack of grey-bordered cards into **"Zen Paper & Ink" (The Mindful Scholar)**—a distinguished, cortisol-reducing study sanctuary inspired by traditional Japanese parchment (*Washi*), Sumi calligraphy, and vermilion seals (*Hanko*).

---

## 1. Design System Tokens (Zen Palette & Typography)

### File: `lib/app/theme/colors.dart`
Update/add the Zen Color Tokens:

```dart
// Zen Paper & Ink Design System Tokens
class ZenColors {
  ZenColors._();

  // Light Mode ("Morning Parchment")
  static const Color washiCanvas = Color(0xFFFBF9F5);      // Warm unbleached paper (zero blue light)
  static const Color washiSurface = Color(0xFFF4F1EA);     // Subtle tone shift for elevated surfaces
  static const Color washiBorder = Color(0xFFE7E3D9);      // Faint hairline divider
  static const Color sumiInk = Color(0xFF1C1917);          // Deep calligraphy black
  static const Color stoneMist = Color(0xFF78716C);        // Soft charcoal secondary text
  
  // Signature Accent: The Vermilion Hanko Seal
  static const Color vermilionSeal = Color(0xFFDC2626);    // Rich cinnabar red for streaks & stamps
  static const Color vermilionSoft = Color(0xFFFEE2E2);    // Soft blush wash for seal background

  // Dark Mode ("Midnight Scholar")
  static const Color darkCanvas = Color(0xFF121110);       // Smoked charcoal parchment
  static const Color darkSurface = Color(0xFF1C1A18);      // Elevated ink wash stone
  static const Color darkBorder = Color(0xFF292524);       // Hairline brush stroke
  static const Color darkInk = Color(0xFFF5F4F0);          // Warm bone-white text
  static const Color darkMist = Color(0xFFA8A29E);         // Muted parchment grey
  static const Color darkVermilion = Color(0xFFEF4444);    // Glowing ember red

  // Subject Ink Tags (Pastel Washes)
  static const Color csInk = Color(0xFF7C3AED);           // Violet ink
  static const Color csWash = Color(0xFFEDE9FE);
  static const Color microbioInk = Color(0xFF15803D);     // Forest ink
  static const Color microbioWash = Color(0xFFDCFCE7);
  static const Color calculusInk = Color(0xFFB45309);     // Amber ink
  static const Color calculusWash = Color(0xFFFEF3C7);
}
```

### File: `lib/app/theme/typography.dart`
```dart
// Serif Editorial Headlines paired with Clean Sans Body
class ZenTypography {
  ZenTypography._();

  static const String headlineFont = 'Newsreader'; // or 'PlayfairDisplay' / 'CormorantGaramond'
  static const String bodyFont = 'Plus Jakarta Sans'; // or 'Inter'

  static const TextStyle editorialTitle = TextStyle(
    fontFamily: headlineFont,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: ZenColors.sumiInk,
  );

  static const TextStyle subtitleMist = TextStyle(
    fontFamily: bodyFont,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: ZenColors.stoneMist,
  );
}
```

---

## 2. Layout Architecture & Re-positioning

### Re-positioning Principles:
1. **Zero Box Enclosures**: No rectangular cards with grey borders. Use whitespace and delicate 0.5px hairline dividers.
2. **Remove Standalone Exam Countdown**: Delete `Exam countdown: 24 days left` card at `y=911`. Move it inline as a sub-header tag under the greeting: `🎓 24 days until the trial`.
3. **Ergonomic Action Placement**: Bring the primary `[ ✦ Enter Flow ]` or `[ 筆 Begin Session • 25m ]` button into the bottom thumb-reach zone.

---

## 3. Component Implementation Plan

### Step 1: The Scholar's Header (`ZenHeader`)
- **Left**: 
  - Title: *"Good evening, Asif"* in editorial serif (`fontSize: 26`).
  - Subtitle: *"Saturday, 21 November · 🎓 24 days until the trial"* in stone mist.
- **Right**:
  - The **Hanko Seal Badge**: A square red cinnabar seal `[ 印 1 Day ]` with rounded 4px corners, red border, and red text.

### Step 2: The Focus Portal (`ZenFocusPortal`)
- Replace the current circular progress box.
- Layout:
  - An **Ink-Wash Horizontal Brushstroke**: A sleek progress stroke that fills as tasks are completed (33% = 1 of 3 sessions).
  - Active Topic Headline: *"Data Structures — Binary Trees"* (`fontSize: 20`, serif).
  - Meta Pill: `UP NEXT · 25 MIN FOCUS`.
  - The Action Button: A tactile, understated pill button:
    `[ 筆 Begin Session • 25m ]`
    - Solid `#1C1917` (or `#DC2626` Vermilion) with `#FFFFFF` text, subtle elevation, and haptic feedback on tap.

### Step 3: The Daily Scroll (`ZenTaskScroll`)
- Replace the 3 identical grey cards with **The Daily Scroll**:
  - Each task is an entry separated by a `0.5px` hairline divider (`ZenColors.washiBorder`).
  - **State 1 (Completed)**:
    - Text muted (`color: ZenColors.stoneMist`).
    - Stamped with the Hanko vermilion seal: `[ 完 Mastered ]`.
  - **State 2 (Active / Up Next)**:
    - Left border indicator (2px primary ink line).
    - Bold title.
    - Quick Play trigger icon.
  - **State 3 (Queued)**:
    - Clean neutral text with `[ Queued ]` indicator.

### Step 4: Calligraphic Bottom Navigation
- Fixed edge-to-edge bar with warm parchment surface (`#FBF9F5` in light, `#121110` in dark).
- 4 clean calligraphic items:
  - **Today** (日 · Daily Flow)
  - **Library** (書 · Vault)
  - **Practice** (練 · Quizzes)
  - **Progress** (道 · The Path)
- Active tab highlighted with a clean vermilion dot underneath the label.

---

## 4. Verification & Testing Protocol
After applying the changes to `lib/features/today/screens/today_screen.dart`:
1. Run `flutter run -d 463913a1` (or test on the OnePlus phone).
2. Confirm the screen loads with warm parchment canvas (`#FBF9F5`).
3. Verify that the standalone countdown card is removed and vertical scrolling flows freely.
4. Verify the task items have 3 clear visual states (Mastered with Red Hanko seal, Up Next, Queued).
5. Verify bottom scroll padding keeps the last task completely clear of the bottom navigation bar.
