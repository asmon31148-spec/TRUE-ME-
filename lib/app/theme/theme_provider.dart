import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/offline_cache_service.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_loadSavedMode());

  static ThemeMode _loadSavedMode() {
    final saved = OfflineCacheService.getThemeMode();
    return _fromLabel(saved);
  }

  static ThemeMode _fromLabel(String label) {
    switch (label) {
      case 'Dark':
        return ThemeMode.dark;
      case 'Light':
        return ThemeMode.light;
      case 'System':
      default:
        return ThemeMode.system;
    }
  }

  String get currentLabel {
    switch (state) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> setTheme(String label) async {
    await OfflineCacheService.saveThemeMode(label);
    state = _fromLabel(label);
  }

  static void applySystemUiOverlay(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFFFFFFF),
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get bgColor => Theme.of(this).scaffoldBackgroundColor;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get borderColor => Theme.of(this).colorScheme.outline;
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;
  Color get textSecondary => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get accentColor => Theme.of(this).colorScheme.primary;
  Color get accentTint => Theme.of(this).colorScheme.primaryContainer;
}
