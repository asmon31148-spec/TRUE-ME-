import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme_provider.dart';
import '../../core/services/update_service.dart';
import 'true_me_illustrations.dart';

/// Application Shell hosting the True Me Calm Ivory Bottom Dock & Animated Center Sage Orb.
///
/// Preserves the existing 5-slot navigation structure:
/// [Home (/today)] [Library (/library)] [★ Sage Orb (/chat)] [Practice (/practice)] [Progress (/progress)]
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
    final isDark = context.isDarkMode;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: context.bgColor,
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: showBar
          ? SizedBox(
              height: 82 + bottomPad,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Pure clean curved white dock matching Reference Images 2 & 3
                  Container(
                    height: 66 + bottomPad,
                    padding: EdgeInsets.only(bottom: bottomPad, left: 6, right: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.97),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E2A5C).withValues(alpha: isDark ? 0.36 : 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _NavTabItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: 'Home',
                          isSelected: selectedIdx == 0,
                          onTap: () => _onItemTapped(0, context),
                        ),
                        _NavTabItem(
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book_rounded,
                          label: 'Library',
                          isSelected: selectedIdx == 1,
                          onTap: () => _onItemTapped(1, context),
                        ),
                        const SizedBox(width: 68), // Space reserved for centered Sage Orb
                        _NavTabItem(
                          icon: Icons.check_box_outlined,
                          activeIcon: Icons.check_box_rounded,
                          label: 'Practice',
                          isSelected: selectedIdx == 3,
                          onTap: () => _onItemTapped(3, context),
                        ),
                        _NavTabItem(
                          icon: Icons.bar_chart_rounded,
                          activeIcon: Icons.bar_chart_rounded,
                          label: 'Progress',
                          isSelected: selectedIdx == 4,
                          onTap: () => _onItemTapped(4, context),
                        ),
                      ],
                    ),
                  ),

                  // Luminous Animated Centered Sage Star Orb
                  Positioned(
                    top: 0,
                    child: _SageCenterOrb(
                      isSelected: selectedIdx == 2,
                      isDark: isDark,
                      onTap: () => _onItemTapped(2, context),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _NavTabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = context.accentColor;
    final inactiveColor = context.textSecondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.10 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 23,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: -0.1,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SageCenterOrb extends StatefulWidget {
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _SageCenterOrb({
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SageCenterOrb> createState() => _SageCenterOrbState();
}

class _SageCenterOrbState extends State<_SageCenterOrb> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (_pressed && !disableAnim) ? 0.91 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, child) {
            final t = disableAnim ? 0.4 : _pulseCtrl.value;
            return Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isDark ? AppColors.darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(
                      alpha: (widget.isDark ? 0.34 : 0.24) + (t * 0.12),
                    ),
                    blurRadius: 16 + (t * 6),
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8380F9), Color(0xFF534BE2)],
              ),
            ),
            child: const Center(
              child: CustomPaint(
                size: Size(28, 28),
                painter: SageDockStarPainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
