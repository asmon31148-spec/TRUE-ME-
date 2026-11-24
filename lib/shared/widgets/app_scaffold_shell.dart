import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/liquid_glass_theme.dart';
import '../../app/theme/theme_provider.dart';
import '../../core/services/update_service.dart';
import 'glass_card.dart';

/// Application Shell hosting the Floating Liquid Glass Action Dock.
///
/// Features:
/// - Floating glass dock with 16px selective blur and 1px specular highlight
/// - 44px+ ergonomic touch target compliance across all navigation items
/// - Electric Indigo glowing active indicator and ambient Mother AI Sage orb
/// - Automatic keyboard dismissal handling
class AppScaffoldShell extends StatefulWidget {
  final Widget child;

  const AppScaffoldShell({super.key, required this.child});

  @override
  State<AppScaffoldShell> createState() => _AppScaffoldShellState();
}

class _AppScaffoldShellState extends State<AppScaffoldShell> {
  static bool _hasCheckedUpdateThisLaunch = false;

  @override
  void initState() {
    super.initState();
    if (!_hasCheckedUpdateThisLaunch) {
      _hasCheckedUpdateThisLaunch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForAppUpdate();
      });
    }
  }

  Future<void> _checkForAppUpdate() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final info = await UpdateService().checkForUpdate();
    if (mounted && info != null && info.hasUpdate) {
      UpdateService.showUpdateDialog(context: context, info: info);
    }
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/library' || location.startsWith('/notebook/')) return 1;
    if (location == '/chat') return 2;
    if (location == '/practice') return 3;
    if (location == '/progress') return 4;
    return 0; // Default: /today
  }

  bool _shouldShowBottomBar(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isRootTab = location == '/today' ||
        location == '/library' ||
        location == '/practice' ||
        location == '/progress';
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return isRootTab && !isKeyboardOpen;
  }

  void _onItemTapped(int index, BuildContext context) {
    HapticFeedback.lightImpact();
    switch (index) {
      case 0:
        context.go('/today');
        break;
      case 1:
        context.go('/library');
        break;
      case 2:
        context.push('/chat');
        break;
      case 3:
        context.go('/practice');
        break;
      case 4:
        context.go('/progress');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBar = _shouldShowBottomBar(context);
    final selectedIdx = _calculateSelectedIndex(context);
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.liquidCanvas,
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: showBar
          ? Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                MediaQuery.paddingOf(context).bottom > 0
                    ? MediaQuery.paddingOf(context).bottom
                    : 12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: LiquidGlassTheme.floatingNavBlurSigma,
                    sigmaY: LiquidGlassTheme.floatingNavBlurSigma,
                  ),
                  child: CustomPaint(
                    foregroundPainter: SpecularBorderPainter(
                      borderRadius: 26,
                      gradient: isDark
                          ? LiquidGlassTheme.darkSpecularBorder
                          : LiquidGlassTheme.lightSpecularBorder,
                      borderWidth: 1.0,
                    ),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark
                            ? LiquidGlassTheme.darkCanvas.withOpacity(0.78)
                            : LiquidGlassTheme.lightCanvas.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: isDark
                            ? LiquidGlassTheme.darkGlassShadow(
                                glowColor: LiquidGlassTheme.electricIndigo,
                              )
                            : LiquidGlassTheme.lightGlassShadow(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          _FloatingNavItem(
                            icon: Icons.today_outlined,
                            activeIcon: Icons.today_rounded,
                            label: 'Today',
                            isSelected: selectedIdx == 0,
                            onTap: () => _onItemTapped(0, context),
                          ),
                          _FloatingNavItem(
                            icon: Icons.folder_outlined,
                            activeIcon: Icons.folder_rounded,
                            label: 'Library',
                            isSelected: selectedIdx == 1,
                            onTap: () => _onItemTapped(1, context),
                          ),
                          _FloatingSageDockButton(
                            isSelected: selectedIdx == 2,
                            onTap: () => _onItemTapped(2, context),
                          ),
                          _FloatingNavItem(
                            icon: Icons.psychology_outlined,
                            activeIcon: Icons.psychology_rounded,
                            label: 'Practice',
                            isSelected: selectedIdx == 3,
                            onTap: () => _onItemTapped(3, context),
                          ),
                          _FloatingNavItem(
                            icon: Icons.insights_outlined,
                            activeIcon: Icons.insights_rounded,
                            label: 'Progress',
                            isSelected: selectedIdx == 4,
                            onTap: () => _onItemTapped(4, context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final activeColor = LiquidGlassTheme.electricIndigo;
    final inactiveColor = isDark
        ? LiquidGlassTheme.darkTextMuted
        : LiquidGlassTheme.lightTextSecondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: LiquidGlassTheme.minTouchTarget),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withOpacity(isDark ? 0.18 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 21,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingSageDockButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _FloatingSageDockButton({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: LiquidGlassTheme.minTouchTarget),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6366F1), // Electric Indigo
                      Color(0xFF8B5CF6), // Purple Iris
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: LiquidGlassTheme.electricIndigo.withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 19,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sage',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFA5B4FC) : LiquidGlassTheme.electricIndigo,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
