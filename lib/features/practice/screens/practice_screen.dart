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
        automaticallyImplyLeading: false,
        title: const Text('Practice', style: AppTypography.screenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 22),
            tooltip: 'Ask Sage',
            onPressed: () async {
              await context.push('/chat');
              if (mounted) _loadRecent();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: context.accentColor,
          onRefresh: () async {
            _loadRecent();
          },
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 2-Column Practice Tool Grid
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _PracticeGridTile(
                  icon: Icons.quiz_outlined,
                  title: 'Quiz',
                  subtitle: 'Adaptive MCQs',
                  tintColor: const Color(0xFF6366F1),
                  onTap: () async {
                    await context.push('/quiz');
                    if (mounted) _loadRecent();
                  },
                ),
                _PracticeGridTile(
                  icon: Icons.style_outlined,
                  title: 'Flashcards',
                  subtitle: 'Spaced recall',
                  tintColor: const Color(0xFFF59E0B),
                  onTap: () async {
                    await context.push('/flashcards');
                    if (mounted) _loadRecent();
                  },
                ),
                _PracticeGridTile(
                  icon: Icons.mic_none_rounded,
                  title: 'Voice Tutor',
                  subtitle: 'Oral Socratic exam',
                  tintColor: const Color(0xFFEC4899),
                  onTap: () async {
                    await context.push('/voice-tutor');
                    if (mounted) _loadRecent();
                  },
                ),
                _PracticeGridTile(
                  icon: Icons.timer_outlined,
                  title: 'Focus Flow',
                  subtitle: 'Pomodoro timer',
                  tintColor: const Color(0xFF10B981),
                  onTap: () async {
                    await context.push('/focus');
                    if (mounted) _loadRecent();
                  },
                ),
                _PracticeGridTile(
                  icon: Icons.account_tree_outlined,
                  title: 'Mind Map',
                  subtitle: 'Visual concept trees',
                  tintColor: const Color(0xFF8B5CF6),
                  onTap: () async {
                    await context.push('/mindmap');
                    if (mounted) _loadRecent();
                  },
                ),
                _PracticeGridTile(
                  icon: Icons.history_edu_outlined,
                  title: 'Mistake Vault',
                  subtitle: 'Review weak spots',
                  tintColor: const Color(0xFFEF4444),
                  onTap: () async {
                    await context.push('/mistake-vault');
                    if (mounted) _loadRecent();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                      } else if (activity == 'focus') {
                        await context.push('/focus?subject=$subject');
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
    ),
  );
  }
}

class _PracticeGridTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tintColor;
  final VoidCallback onTap;

  const _PracticeGridTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tintColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF263044) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tintColor.withOpacity(isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: tintColor),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
