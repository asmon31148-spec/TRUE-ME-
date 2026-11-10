import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/app_components.dart';

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
      'icon': Icons.folder_open_outlined,
      'title': 'Add your study material',
      'body': 'Syllabus, notes, books and previous papers in one place.',
    },
    {
      'icon': Icons.calendar_today_outlined,
      'title': 'Get a daily plan',
      'body': 'Sage splits your syllabus across the days you have.',
    },
    {
      'icon': Icons.quiz_outlined,
      'title': 'Practice what you forget',
      'body': 'Quizzes and flashcards built from your own material.',
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

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
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
                        Icon(
                          slide['icon'] as IconData,
                          size: 96,
                          color: context.textPrimary,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide['title'] as String,
                          textAlign: TextAlign.center,
                          style: AppTypography.screenTitle,
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
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

              // Page Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _pageIndex == i ? context.accentColor : context.borderColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Navigation Controls
              Row(
                children: [
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Skip'),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 140,
                    child: AppPrimaryButton(
                      label: isLast ? 'Get started' : 'Next',
                      onPressed: () {
                        if (isLast) {
                          context.go('/login');
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
