import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/app_components.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Practice', style: AppTypography.screenTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Quiz Card
            AppCard(
              showChevron: true,
              onTap: () => context.push('/quiz'),
              child: const Row(
                children: [
                  Icon(Icons.quiz_outlined, size: 28, color: AppColors.textPrimary),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quiz', style: AppTypography.sectionHeading),
                        SizedBox(height: 2),
                        Text('Test your understanding', style: AppTypography.secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Flashcards Card
            AppCard(
              showChevron: true,
              onTap: () => context.push('/flashcards'),
              child: const Row(
                children: [
                  Icon(Icons.style_outlined, size: 28, color: AppColors.textPrimary),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Flashcards', style: AppTypography.sectionHeading),
                        SizedBox(height: 2),
                        Text('Active recall key concepts', style: AppTypography.secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Voice Tutor Card
            AppCard(
              showChevron: true,
              onTap: () => context.push('/voice-tutor'),
              child: const Row(
                children: [
                  Icon(Icons.mic_none_outlined, size: 28, color: AppColors.textPrimary),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Voice tutor', style: AppTypography.sectionHeading),
                        SizedBox(height: 2),
                        Text('Talk with Sage tutor', style: AppTypography.secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Recent Sessions
            const Text('Recent', style: AppTypography.sectionHeading),
            const SizedBox(height: 10),

            AppListRow(
              title: 'Cell structure quiz',
              subtitle: 'Score: 4/5 • Yesterday',
              onTap: () => context.push('/quiz'),
            ),
            const SizedBox(height: 8),
            AppListRow(
              title: 'Sterilization methods',
              subtitle: '12 cards reviewed • 2 days ago',
              onTap: () => context.push('/flashcards'),
            ),
            const SizedBox(height: 8),
            AppListRow(
              title: 'Gram stain procedure',
              subtitle: 'Voice discussion • 3 days ago',
              onTap: () => context.push('/voice-tutor'),
            ),
          ],
        ),
      ),
    );
  }
}
