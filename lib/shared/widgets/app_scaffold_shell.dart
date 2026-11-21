import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme_provider.dart';
import '../../core/services/update_service.dart';

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
    final navBg = context.isDarkMode ? ZenColors.darkCanvas : ZenColors.washiCanvas;
    final navBorder = context.isDarkMode ? ZenColors.darkBorder : ZenColors.washiBorder;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: widget.child,
      bottomNavigationBar: showBar
          ? Container(
              decoration: BoxDecoration(
                color: navBg,
                border: Border(
                  top: BorderSide(color: navBorder, width: 0.8),
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
                        subLabel: '日',
                        isSelected: selectedIdx == 0,
                        onTap: () => _onItemTapped(0, context),
                      ),
                      _NavItem(
                        icon: Icons.auto_stories_outlined,
                        activeIcon: Icons.auto_stories,
                        label: 'Library',
                        subLabel: '書',
                        isSelected: selectedIdx == 1,
                        onTap: () => _onItemTapped(1, context),
                      ),
                      _NavItem(
                        icon: Icons.psychology_outlined,
                        activeIcon: Icons.psychology,
                        label: 'Practice',
                        subLabel: '練',
                        isSelected: selectedIdx == 2,
                        onTap: () => _onItemTapped(2, context),
                      ),
                      _NavItem(
                        icon: Icons.bar_chart_outlined,
                        activeIcon: Icons.bar_chart,
                        label: 'Progress',
                        subLabel: '道',
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
  final String subLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.subLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = context.isDarkMode ? ZenColors.darkInk : ZenColors.sumiInk;
    final inactiveColor = context.isDarkMode ? ZenColors.darkMist : ZenColors.stoneMist;
    final dotColor = context.isDarkMode ? ZenColors.darkVermilion : ZenColors.vermilionSeal;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 20,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            // Calligraphic vermilion dot or empty spacer
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isSelected ? dotColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
