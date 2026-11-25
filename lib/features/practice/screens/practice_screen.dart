import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_illustrations.dart';
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
                // Editorial Serif Header + Glowing Sage Pill
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
                            'Active Recall & Mastery Studio',
                            style: AppTypography.secondary.copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await context.push('/chat');
                        if (mounted) _loadRecent();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.sageOrbGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: CustomPaint(
                            size: Size(20, 20),
                            painter: SageDockStarPainter(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Featured Pastel Audio Explainer Banner with Microscope Motif
                TrueMeEntrance(
                  delayMs: 30,
                  child: TrueMeCard(
                    borderRadius: 24,
                    padding: EdgeInsets.zero,
                    gradient: isDark ? AppColors.heroFocusDarkGradient : AppColors.heroFocusLightGradient,
                    onTap: () async {
                      await context.push('/explainer');
                      if (mounted) _loadRecent();
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -14,
                            top: 0,
                            bottom: 0,
                            width: 148,
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: ExplainerMicroscopePainter(isDark: isDark, pulse: 0.0),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 130, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TrueMeTonalPill(
                                  label: 'Audio Studio',
                                  icon: Icons.headphones_rounded,
                                  backgroundColor: isDark
                                      ? AppColors.darkSurface
                                      : Colors.white.withValues(alpha: 0.88),
                                  foregroundColor: context.accentColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Audio Explainer',
                                  style: AppTypography.sectionHeading.copyWith(
                                    fontSize: 19,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Narrated visual scenes from your study notes',
                                  style: AppTypography.smallLabel.copyWith(
                                    color: context.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.accent : AppColors.charcoalInk,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Listen Now',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TrueMeSectionHeader(title: 'Study Features'),
                const SizedBox(height: 12),

                // 2-Column Rich Pastel Feature Buttons matching Reference Design Aesthetic
                TrueMeEntrance(
                  delayMs: 80,
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.08,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _FeaturePastelTile(
                        icon: Icons.quiz_rounded,
                        title: 'Quiz',
                        subtitle: 'Adaptive MCQs',
                        bgStart: isDark ? const Color(0xFF1D1B3B) : const Color(0xFFF3F1FF),
                        bgEnd: isDark ? const Color(0xFF26224C) : const Color(0xFFE4E0FD),
                        accentColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF5552E4),
                        onTap: () async {
                          await context.push('/quiz');
                          if (mounted) _loadRecent();
                        },
                      ),
                      _FeaturePastelTile(
                        icon: Icons.style_rounded,
                        title: 'Flashcards',
                        subtitle: 'SM-2 spaced recall',
                        bgStart: isDark ? const Color(0xFF2B2110) : const Color(0xFFFFFAEB),
                        bgEnd: isDark ? const Color(0xFF382A14) : const Color(0xFFFEEEE0),
                        accentColor: isDark ? AppColors.darkWarning : const Color(0xFFC26D16),
                        onTap: () async {
                          await context.push('/flashcards');
                          if (mounted) _loadRecent();
                        },
                      ),
                      _FeaturePastelTile(
                        icon: Icons.graphic_eq_rounded,
                        title: 'Voice Tutor',
                        subtitle: 'Oral Socratic exam',
                        bgStart: isDark ? const Color(0xFF11233D) : const Color(0xFFEEF7FF),
                        bgEnd: isDark ? const Color(0xFF172E50) : const Color(0xFFD9ECFE),
                        accentColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        onTap: () async {
                          await context.push('/voice-tutor');
                          if (mounted) _loadRecent();
                        },
                      ),
                      _FeaturePastelTile(
                        icon: Icons.timer_rounded,
                        title: 'Focus Flow',
                        subtitle: 'Deep focus sprints',
                        bgStart: isDark ? const Color(0xFF0E2922) : const Color(0xFFF0FDF6),
                        bgEnd: isDark ? const Color(0xFF13362C) : const Color(0xFFD6F7E5),
                        accentColor: isDark ? AppColors.darkSuccess : const Color(0xFF15803D),
                        onTap: () async {
                          await context.push('/focus');
                          if (mounted) _loadRecent();
                        },
                      ),
                      _FeaturePastelTile(
                        icon: Icons.hub_rounded,
                        title: 'Mind Map',
                        subtitle: 'Concept trees',
                        bgStart: isDark ? const Color(0xFF241938) : const Color(0xFFF6F1FF),
                        bgEnd: isDark ? const Color(0xFF2E2048) : const Color(0xFFEADFFD),
                        accentColor: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
                        onTap: () async {
                          await context.push('/mindmap');
                          if (mounted) _loadRecent();
                        },
                      ),
                      _FeaturePastelTile(
                        icon: Icons.auto_fix_high_rounded,
                        title: 'Mistake Vault',
                        subtitle: 'Turn errors to mastery',
                        bgStart: isDark ? const Color(0xFF321822) : const Color(0xFFFFF1F3),
                        bgEnd: isDark ? const Color(0xFF3F1D2B) : const Color(0xFFFEE0E5),
                        accentColor: isDark ? AppColors.darkError : const Color(0xFFE11D48),
                        onTap: () async {
                          await context.push('/mistake-vault');
                          if (mounted) _loadRecent();
                        },
                      ),
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

class _FeaturePastelTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgStart;
  final Color bgEnd;
  final Color accentColor;
  final VoidCallback onTap;

  const _FeaturePastelTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bgStart,
    required this.bgEnd,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return TrueMeCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(15),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [bgStart, bgEnd],
      ),
      onTap: onTap,
      child: Stack(
        children: [
          // Subtle pastel bokeh highlight in bottom-right corner
          Positioned(
            right: -22,
            bottom: -22,
            child: IgnorePointer(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: isDark ? 0.14 : 0.10),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 23, color: accentColor),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward_rounded, size: 15, color: accentColor),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.cardTitle.copyWith(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.smallLabel.copyWith(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
