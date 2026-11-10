import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  void _loadRecent() {
    setState(() {
      _recent = OfflineCacheService.getRecentPracticeSessions();
    });
  }

  String _formatDateLabel(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
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
              onTap: () async {
                await context.push('/quiz');
                if (mounted) _loadRecent();
              },
              child: Row(
                children: [
                  Icon(Icons.quiz_outlined, size: 28, color: context.textPrimary),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quiz', style: AppTypography.sectionHeading),
                        SizedBox(height: 2),
                        Text('Test your understanding with AI quizzes', style: AppTypography.secondary),
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
              onTap: () async {
                await context.push('/flashcards');
                if (mounted) _loadRecent();
              },
              child: Row(
                children: [
                  Icon(Icons.style_outlined, size: 28, color: context.textPrimary),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Flashcards', style: AppTypography.sectionHeading),
                        SizedBox(height: 2),
                        Text('Active recall spaced-repetition cards', style: AppTypography.secondary),
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
              onTap: () async {
                await context.push('/voice-tutor');
                if (mounted) _loadRecent();
              },
              child: Row(
                children: [
                  Icon(Icons.mic_none_outlined, size: 28, color: context.textPrimary),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Voice tutor', style: AppTypography.sectionHeading),
                        SizedBox(height: 2),
                        Text('Talk directly with Sage tutor', style: AppTypography.secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Mind Map Card
            AppCard(
              showChevron: true,
              onTap: () async {
                await context.push('/mindmap');
                if (mounted) _loadRecent();
              },
              child: Row(
                children: [
                  Icon(Icons.account_tree_outlined, size: 28, color: context.textPrimary),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mind map', style: AppTypography.sectionHeading),
                        SizedBox(height: 2),
                        Text('Explore concepts visually', style: AppTypography.secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Recent Sessions (REAL)
            const Text('Recent', style: AppTypography.sectionHeading),
            const SizedBox(height: 10),

            if (_recent.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor, width: 1),
                ),
                child: const Text(
                  'No practice history yet. Start a quiz, flashcard deck, or voice session above.',
                  style: AppTypography.secondary,
                ),
              )
            else
              ..._recent.take(6).map((item) {
                final activity = item['activity'] as String? ?? 'quiz';
                final title = item['title'] as String? ?? 'Session';
                final sub = item['subtitle'] as String? ?? '';
                final time = _formatDateLabel(item['timestamp'] as String?);
                final subject = Uri.encodeComponent(item['subject'] as String? ?? '');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppListRow(
                    title: title,
                    subtitle: [sub, time].where((s) => s.isNotEmpty).join(' • '),
                    onTap: () async {
                      if (activity == 'quiz') {
                        await context.push('/quiz?subject=$subject');
                      } else if (activity == 'flashcards') {
                        await context.push('/flashcards?subject=$subject');
                      } else {
                        await context.push('/voice-tutor');
                      }
                      if (mounted) _loadRecent();
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
