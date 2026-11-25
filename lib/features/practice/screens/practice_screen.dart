import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';

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
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.accentColor,
            onRefresh: () async => _loadRecent(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
              children: [
                // Editorial Serif Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Practice',
                            style: AppTypography.editorialHero.copyWith(
                              fontSize: 29,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Active Recall & Mastery Tools',
                            style: AppTypography.secondary.copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TrueMeCircleIconButton(
                      icon: Icons.auto_awesome_rounded,
                      tooltip: 'Ask Sage',
                      iconColor: context.accentColor,
                      size: 42,
                      onPressed: () async {
                        await context.push('/chat');
                        if (mounted) _loadRecent();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2-Column Pastel Tool Grid
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _PracticeGridTile(
                      icon: Icons.quiz_rounded,
                      title: 'Quiz',
                      subtitle: 'Adaptive MCQs',
                      bgColor: isDark ? const Color(0xFF1D1B3B) : AppColors.accentWash,
                      accentColor: context.accentColor,
                      onTap: () async {
                        await context.push('/quiz');
                        if (mounted) _loadRecent();
                      },
                    ),
                    _PracticeGridTile(
                      icon: Icons.style_rounded,
                      title: 'Flashcards',
                      subtitle: 'Spaced recall',
                      bgColor: isDark ? const Color(0xFF2B2110) : AppColors.pastelAmber,
                      accentColor: isDark ? AppColors.darkWarning : AppColors.pastelAmberInk,
                      onTap: () async {
                        await context.push('/flashcards');
                        if (mounted) _loadRecent();
                      },
                    ),
                    _PracticeGridTile(
                      icon: Icons.mic_rounded,
                      title: 'Voice Tutor',
                      subtitle: 'Oral Socratic exam',
                      bgColor: isDark ? const Color(0xFF11233D) : AppColors.pastelBlue,
                      accentColor: isDark ? const Color(0xFF60A5FA) : AppColors.pastelBlueInk,
                      onTap: () async {
                        await context.push('/voice-tutor');
                        if (mounted) _loadRecent();
                      },
                    ),
                    _PracticeGridTile(
                      icon: Icons.timer_rounded,
                      title: 'Focus Flow',
                      subtitle: 'Pomodoro timer',
                      bgColor: isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen,
                      accentColor: isDark ? AppColors.darkSuccess : AppColors.pastelGreenInk,
                      onTap: () async {
                        await context.push('/focus');
                        if (mounted) _loadRecent();
                      },
                    ),
                    _PracticeGridTile(
                      icon: Icons.account_tree_rounded,
                      title: 'Mind Map',
                      subtitle: 'Visual concept trees',
                      bgColor: isDark ? const Color(0xFF241938) : AppColors.pastelLavender,
                      accentColor: isDark ? const Color(0xFFC4B5FD) : AppColors.pastelLavenderInk,
                      onTap: () async {
                        await context.push('/mindmap');
                        if (mounted) _loadRecent();
                      },
                    ),
                    _PracticeGridTile(
                      icon: Icons.history_edu_rounded,
                      title: 'Mistake Vault',
                      subtitle: 'Review weak spots',
                      bgColor: isDark ? const Color(0xFF321822) : AppColors.pastelRose,
                      accentColor: isDark ? AppColors.darkError : AppColors.error,
                      onTap: () async {
                        await context.push('/mistake-vault');
                        if (mounted) _loadRecent();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Featured Audio Explainer Banner Row
                TrueMeCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(14),
                  gradient: isDark ? AppColors.heroFocusDarkGradient : AppColors.heroFocusLightGradient,
                  onTap: () async {
                    await context.push('/explainer');
                    if (mounted) _loadRecent();
                  },
                  child: Row(
                    children: [
                      AppIconBadge(
                        icon: Icons.headphones_rounded,
                        color: context.accentColor,
                        backgroundColor: context.surfaceColor.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audio Explainer Studio',
                              style: AppTypography.cardTitle.copyWith(color: context.textPrimary),
                            ),
                            Text(
                              'Narrated interactive topic walkthroughs',
                              style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.play_arrow_rounded, size: 22, color: context.accentColor),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recent Sessions
                TrueMeSectionHeader(title: 'Recent Sessions'),
                const SizedBox(height: 12),

                if (_recent.isEmpty)
                  TrueMeCard(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'No practice history yet. Start a quiz, flashcard deck, or voice session above.',
                      style: AppTypography.secondary.copyWith(color: context.textSecondary),
                    ),
                  )
                else
                  ..._recent.take(6).map((item) {
                    final activity = item['activity'] as String? ?? 'quiz';
                    final title = item['title'] as String? ?? 'Session';
                    final sub = item['subtitle'] as String? ?? '';
                    final time = _formatDateLabel(item['timestamp'] as String?);
                    final subject = Uri.encodeComponent(item['subject'] as String? ?? '');

                    IconData badgeIcon = Icons.quiz_outlined;
                    if (activity == 'flashcards') badgeIcon = Icons.style_outlined;
                    if (activity == 'focus') badgeIcon = Icons.timer_outlined;
                    if (activity == 'voice') badgeIcon = Icons.mic_none_rounded;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppListRow(
                        leading: AppIconBadge(icon: badgeIcon, color: context.accentColor),
                        title: title,
                        subtitle: [sub, time].where((s) => s.isNotEmpty).join(' · '),
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
      ),
    );
  }
}

class _PracticeGridTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _PracticeGridTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TrueMeCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(15),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 22, color: accentColor),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
