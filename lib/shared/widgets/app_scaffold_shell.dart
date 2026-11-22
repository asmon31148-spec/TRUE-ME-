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
    HapticFeedback.selectionClick();
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
                  height: 62,
                  child: Row(
                    children: [
                      _NavItem(
                        icon: Icons.today_outlined,
                        activeIcon: Icons.today_rounded,
                        label: 'Today',
                        isSelected: selectedIdx == 0,
                        onTap: () => _onItemTapped(0, context),
                      ),
                      _NavItem(
                        icon: Icons.folder_outlined,
                        activeIcon: Icons.folder_rounded,
                        label: 'Library',
                        isSelected: selectedIdx == 1,
                        onTap: () => _onItemTapped(1, context),
                      ),
                      _SageCenterButton(
                        isSelected: selectedIdx == 2,
                        onTap: () => _onItemTapped(2, context),
                      ),
                      _NavItem(
                        icon: Icons.psychology_outlined,
                        activeIcon: Icons.psychology_rounded,
                        label: 'Practice',
                        isSelected: selectedIdx == 3,
                        onTap: () => _onItemTapped(3, context),
                      ),
                      _NavItem(
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
    final activeColor = context.isDarkMode ? ZenColors.darkVermilion : ZenColors.vermilionSeal;
    final inactiveColor = context.isDarkMode ? ZenColors.darkMist : ZenColors.stoneMist;

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
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SageCenterButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _SageCenterButton({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                      : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
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
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
