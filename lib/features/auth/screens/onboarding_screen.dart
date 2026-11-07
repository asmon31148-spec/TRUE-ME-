import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = const [
    {
      'title': 'Meet Sage, Your Mother AI',
      'subtitle':
          'A personal AI companion that tracks your learning, calculates exam countdowns, and designs your study schedule every morning.',
      'badge': '🧠 ADAPTIVE AI MENTOR',
    },
    {
      'title': 'Turn Any Note into Mastery',
      'subtitle':
          'Upload PDFs, voice notes, YouTube videos, and photos. Sage generates instant flashcards, quizzes, and grounded AI chats.',
      'badge': '⚡ ZERO-COST ARCHITECTURE',
    },
    {
      'title': '10-Min Videos & Voice Tutor',
      'subtitle':
          'Have interactive 30-minute voice conversations with Sage, or watch dynamic animated concept explainers created just for you.',
      'badge': '🎙️ MULTI-MODAL STUDY',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.22),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withOpacity(0.18),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // App Branding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.sageGlowGradient,
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'TRUE ME',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (idx) => setState(() => _currentPage = idx),
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        final item = _pages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GlassCard(
                                borderRadius: 32,
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(
                                          color: AppColors.primaryLight.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        item['badge']!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0,
                                          color: AppColors.accentCyan,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      item['title']!,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.displayMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      item['subtitle']!,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Pagination Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == i
                              ? AppColors.primaryLight
                              : Colors.white.withOpacity(0.18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      if (_currentPage < _pages.length - 1) ...[
                        Expanded(
                          child: GlassButton(
                            child: const Text('Skip'),
                            onPressed: () => context.go('/login'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GlassButton(
                            isPrimary: true,
                            child: const Text('Next'),
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: GlassButton(
                            isPrimary: true,
                            child: const Text('Get Started'),
                            onPressed: () => context.go('/login'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
