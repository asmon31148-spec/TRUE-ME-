import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/offline_cache_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _progressAnim;

  String _statusText = 'Igniting cognitive engine...';

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation sequence (1800ms)
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Smooth spring scale for the puzzle bulb logo
    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    // Smooth fade-in for logo
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
      ),
    );

    // Title and tagline fade & upward slide
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // Glowing progress capsule
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.20, 0.95, curve: Curves.easeInOutCubic),
      ),
    );

    // 2. Ambient background breathing glow (looping 3000ms)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _progressAnim.addListener(() {
      final v = _progressAnim.value;
      if (!mounted) return;
      if (v < 0.40 && _statusText != 'Igniting cognitive engine...') {
        setState(() => _statusText = 'Igniting cognitive engine...');
      } else if (v >= 0.40 && v < 0.85 && _statusText != 'Connecting knowledge vault...') {
        setState(() => _statusText = 'Connecting knowledge vault...');
      } else if (v >= 0.85 && _statusText != 'Welcome to True Me') {
        setState(() => _statusText = 'Welcome to True Me');
      }
    });

    _entranceCtrl.forward();
    _startBootSequence();
  }

  Future<void> _startBootSequence() async {
    // Background silent sign-in and cache preload concurrently
    if (OfflineCacheService.isDriveConnected()) {
      DriveService.instance.signInSilently();
    }

    // Wait for the full luxury entrance animation to deliver a smooth experience
    await Future.delayed(const Duration(milliseconds: 2100));
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
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0E), // Deep Obsidian luxury black
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Dynamic Ambient Aura Bloom behind the bulb
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, _) {
              final breath = _pulseCtrl.value; // 0.0 -> 1.0
              final scale = 1.0 + (breath * 0.12);
              final opacity = 0.65 + (breath * 0.35);

              return Center(
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFBBF24).withOpacity(0.18 * opacity), // Warm Amber
                          const Color(0xFFFB7185).withOpacity(0.15 * opacity), // Coral Rose
                          const Color(0xFF38BDF8).withOpacity(0.12 * opacity), // Sky Cyan
                          const Color(0xFFA3E635).withOpacity(0.08 * opacity), // Lime Matcha
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.30, 0.55, 0.78, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. Central Logo, Brand Name & Glowing Progress Capsule
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The Puzzle Lightbulb Icon with smooth spring & glow
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 124,
                    height: 124,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: const Color(0xFF0F1117),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.09),
                        width: 1.2,
                      ),
                      boxShadow: [
                        // Ambient multi-hued neon rim glow matching puzzle pieces
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withOpacity(0.20),
                          blurRadius: 36,
                          offset: const Offset(-8, 12),
                        ),
                        BoxShadow(
                          color: const Color(0xFFFB7185).withOpacity(0.22),
                          blurRadius: 36,
                          offset: const Offset(8, -10),
                        ),
                        BoxShadow(
                          color: const Color(0xFFFBBF24).withOpacity(0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.lightbulb_outline_rounded,
                            color: Color(0xFFFBBF24),
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Brand Title & Tagline with staggered fade & slide
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        // "TRUE ME" with high-end tracking
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Colors.white,
                              Color(0xFFE2E8F0),
                              Color(0xFFCBD5E1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds),
                          child: const Text(
                            'TRUE ME',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Aesthetic Tagline
                        const Text(
                          'ENLIGHTEN YOUR POTENTIAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3.2,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Sleek Luxury Glowing Progress Capsule
                FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      Container(
                        width: 170,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (context, _) {
                            final progress = _progressAnim.value.clamp(0.0, 1.0);
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 170 * progress,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF38BDF8), // Cyan
                                      Color(0xFFFBBF24), // Amber Gold
                                      Color(0xFFFB7185), // Coral Pink
                                      Color(0xFFA3E635), // Matcha Lime
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF38BDF8).withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 0.5,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Smooth changing status text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _statusText,
                          key: ValueKey<String>(_statusText),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Subtle bottom copyright / version badge
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: FadeTransition(
                opacity: _textFade,
                child: Text(
                  'AI STUDY & COGNITIVE ARCHITECTURE',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: Colors.white.withOpacity(0.20),
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
