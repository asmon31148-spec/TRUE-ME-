import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/liquid_glass_theme.dart';

class AppScaffoldShell extends StatelessWidget {
  final Widget child;

  const AppScaffoldShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/chat') || location.startsWith('/voice-tutor')) return 1;
    if (location.startsWith('/flashcards') || location.startsWith('/quiz')) return 2;
    if (location.startsWith('/dashboard') || location.startsWith('/planner')) return 3;
    return 0; // Default: /library
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/library');
        break;
      case 1:
        context.go('/chat');
        break;
      case 2:
        context.go('/flashcards');
        break;
      case 3:
        context.go('/dashboard');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIdx = _calculateSelectedIndex(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Screen Content with bottom padding so floating nav bar never obscures content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 74),
              child: child,
            ),
          ),

          // Modern Floating Liquid Glass Bottom Navigation Bar
          Positioned(
            left: 18,
            right: 18,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.glassShadow,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: LiquidGlassTheme.blurStandard,
                      sigmaY: LiquidGlassTheme.blurStandard,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.glassSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.glassBorderDark,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _NavItem(
                            icon: Icons.auto_stories_outlined,
                            activeIcon: Icons.auto_stories,
                            label: 'Library',
                            isSelected: selectedIdx == 0,
                            onTap: () => _onItemTapped(0, context),
                          ),
                          _NavItem(
                            icon: Icons.psychology_outlined,
                            activeIcon: Icons.psychology,
                            label: 'Sage AI',
                            isSelected: selectedIdx == 1,
                            onTap: () => _onItemTapped(1, context),
                          ),
                          _NavItem(
                            icon: Icons.style_outlined,
                            activeIcon: Icons.style,
                            label: 'Study',
                            isSelected: selectedIdx == 2,
                            onTap: () => _onItemTapped(2, context),
                          ),
                          _NavItem(
                            icon: Icons.insights_outlined,
                            activeIcon: Icons.insights,
                            label: 'Progress',
                            isSelected: selectedIdx == 3,
                            onTap: () => _onItemTapped(3, context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentCyan.withOpacity(0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? AppColors.accentCyan : AppColors.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
