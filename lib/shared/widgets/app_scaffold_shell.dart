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
    if (location == '/chat') return 1;
    if (location == '/flashcards') return 2;
    if (location == '/dashboard') return 3;
    return 0; // Default: /library
  }

  bool _shouldShowBottomBar(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isRootTab = location == '/library' ||
        location == '/chat' ||
        location == '/flashcards' ||
        location == '/dashboard';
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return isRootTab && !isKeyboardOpen;
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
    final showBar = _shouldShowBottomBar(context);
    final selectedIdx = _calculateSelectedIndex(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: showBar
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: LiquidGlassTheme.blurStandard,
                  sigmaY: LiquidGlassTheme.blurStandard,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xF20B0F19),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 58,
                      child: Row(
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
            )
          : null,
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
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.accentCyan.withOpacity(0.12),
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentCyan.withOpacity(0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 22,
                  color: isSelected ? AppColors.accentCyan : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
