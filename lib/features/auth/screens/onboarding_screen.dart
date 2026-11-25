import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/true_me_ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  final List<Map<String, dynamic>> _slides = const [
    {
      'icon': Icons.menu_book_rounded,
      'title': 'Add your study material',
      'body': 'Keep syllabus, notes, books, and past papers organized inside your personal library.',
    },
    {
      'icon': Icons.calendar_today_rounded,
      'title': 'Get a calm daily plan',
      'body': 'Sage breaks your coursework into balanced daily sessions ahead of your exam.',
    },
    {
      'icon': Icons.auto_awesome_rounded,
      'title': 'Master what matters',
      'body': 'Adaptive quizzes, spaced-repetition flashcards, mind maps, and audio walkthroughs from your notes.',
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _pageIndex == _slides.length - 1;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        intenseLavender: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (idx) => setState(() => _pageIndex = idx),
                    itemCount: _slides.length,
                    itemBuilder: (context, idx) {
                      final slide = _slides[idx];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: isDark
                                  ? AppColors.heroFocusDarkGradient
                                  : AppColors.heroFocusLightGradient,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.accentColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Icon(
                              slide['icon'] as IconData,
                              size: 52,
                              color: context.accentColor,
                            ),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            slide['title'] as String,
                            textAlign: TextAlign.center,
                            style: AppTypography.editorialHero.copyWith(
                              fontSize: 27,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              slide['body'] as String,
                              textAlign: TextAlign.center,
                              style: AppTypography.body.copyWith(color: context.textSecondary),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _pageIndex == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _pageIndex == i ? context.accentColor : context.borderColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                TrueMePrimaryButton(
                  label: isLast ? 'Get Started' : 'Continue',
                  trailingIcon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  onPressed: () {
                    if (isLast) {
                      context.go('/login');
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
