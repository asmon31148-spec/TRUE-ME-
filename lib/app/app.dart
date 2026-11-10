import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

class TrueMeApp extends ConsumerWidget {
  const TrueMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final activeBrightness = themeMode == ThemeMode.dark
        ? Brightness.dark
        : (themeMode == ThemeMode.light ? Brightness.light : platformBrightness);

    ThemeModeNotifier.applySystemUiOverlay(activeBrightness);

    return MaterialApp.router(
      title: 'True Me',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
