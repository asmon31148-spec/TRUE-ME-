import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/mega_vault_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/true_me_ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _orbBreathCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<double> _progressAnim;
  String _statusText = 'Preparing your study space...';

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
    _orbBreathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack)),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.45, curve: Curves.easeIn)),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.30, 0.75, curve: Curves.easeOut)),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.15, 0.95, curve: Curves.easeInOutCubic)),
    );

    _progressAnim.addListener(() {
      if (!mounted) return;
      final v = _progressAnim.value;
      if (v >= 0.45 && v < 0.85 && _statusText != 'Syncing notes & progress...') {
        setState(() => _statusText = 'Syncing notes & progress...');
      } else if (v >= 0.85 && _statusText != 'Welcome to True Me') {
        setState(() => _statusText = 'Welcome to True Me');
      }
    });

    _entranceCtrl.forward();
    _startBootSequence();
  }

  Future<void> _startBootSequence() async {
    if (OfflineCacheService.isMegaConnected()) {
      MegaVaultService.instance.restoreSession();
    }
    if (OfflineCacheService.isDriveConnected()) {
      DriveService.instance.signInSilently();
    }

    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;

    if (OfflineCacheService.isLoggedIn()) {
      OfflineCacheService.syncFromCloud();
      context.go('/today');
    } else if (OfflineCacheService.hasCompletedOnboarding()) {
      context.go('/login');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _orbBreathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        intenseLavender: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_entranceCtrl, _orbBreathCtrl]),
                    builder: (_, __) {
                      final breath = disableAnim ? 0.4 : _orbBreathCtrl.value;
                      return Opacity(
                        opacity: _logoFade.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Container(
                            width: 152,
                            height: 152,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: isDark ? 0.28 : (0.16 + breath * 0.12),
                                  ),
                                  blurRadius: 28 + breath * 10,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : Colors.white.withValues(alpha: 0.9),
                                width: 2.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(34),
                              child: Image.asset(
                                'assets/icons/app_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        Text(
                          'True Me',
                          style: AppTypography.editorialHero.copyWith(
                            fontSize: 34,
                            color: context.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'YOUR AI STUDY COMPANION',
                          style: AppTypography.smallLabel.copyWith(
                            letterSpacing: 2.3,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 44),
                  FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        Container(
                          width: 170,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBorder : const Color(0xFFE7E2F7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: AnimatedBuilder(
                            animation: _progressAnim,
                            builder: (context, _) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 170 * _progressAnim.value.clamp(0.0, 1.0),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.indigoButtonGradient,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _statusText,
                          style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: FadeTransition(
                  opacity: _textFade,
                  child: Text(
                    'CALM FOCUS · ACTIVE RECALL',
                    style: AppTypography.smallLabel.copyWith(
                      fontSize: 10.5,
                      letterSpacing: 2.0,
                      color: context.textSecondary.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
