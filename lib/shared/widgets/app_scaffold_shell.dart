import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/theme_provider.dart';

class AppScaffoldShell extends StatelessWidget {
  final Widget child;

  const AppScaffoldShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/library') return 1;
    if (location == '/practice') return 2;
    if (location == '/progress') return 3;
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
    HapticFeedback.selectionClick();
    switch (index) {
      case 0:
        context.go('/today');
        break;
      case 1:
        context.go('/library');
        break;
      case 2:
        context.go('/practice');
        break;
      case 3:
        context.go('/progress');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBar = _shouldShowBottomBar(context);
    final selectedIdx = _calculateSelectedIndex(context);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: child,
      bottomNavigationBar: showBar
          ? Container(
              decoration: BoxDecoration(
                color: context.bgColor,
                border: Border(
                  top: BorderSide(color: context.borderColor, width: 1.0),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      _NavItem(
                        icon: Icons.check_circle_outline,
                        activeIcon: Icons.check_circle,
                        label: 'Today',
                        isSelected: selectedIdx == 0,
                        onTap: () => _onItemTapped(0, context),
                      ),
                      _NavItem(
                        icon: Icons.auto_stories_outlined,
                        activeIcon: Icons.auto_stories,
                        label: 'Library',
                        isSelected: selectedIdx == 1,
                        onTap: () => _onItemTapped(1, context),
                      ),
                      _NavItem(
                        icon: Icons.psychology_outlined,
                        activeIcon: Icons.psychology,
                        label: 'Practice',
                        isSelected: selectedIdx == 2,
                        onTap: () => _onItemTapped(2, context),
                      ),
                      _NavItem(
                        icon: Icons.bar_chart_outlined,
                        activeIcon: Icons.bar_chart,
                        label: 'Progress',
                        isSelected: selectedIdx == 3,
                        onTap: () => _onItemTapped(3, context),
                      ),
                    ],
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
    final color = isSelected ? context.accentColor : context.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? context.accentTint : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 21,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
