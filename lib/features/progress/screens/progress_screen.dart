import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/utils/study_analytics.dart';
import '../../../shared/widgets/true_me_ui.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late StudyAnalyticsSnapshot _analytics;

  @override
  void initState() {
    super.initState();
    _analytics = StudyAnalyticsSnapshot.computeLive();
  }

  void _loadStats() {
    if (!mounted) return;
    setState(() {
      _analytics = StudyAnalyticsSnapshot.computeLive();
    });
  }

  String _formatDuration(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String _relativeTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final maxBarVal = _analytics.weeklyBars.fold<int>(30, (maxVal, v) => v > maxVal ? v : maxVal);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayWeekday = DateTime.now().weekday;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.accentColor,
            onRefresh: () async {
              await OfflineCacheService.syncFromCloud();
              _loadStats();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
              children: [
                // 1. Editorial Header + Refresh + "Ask Sage" Orb Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress',
                            style: AppTypography.editorialHero.copyWith(
                              fontSize: 29,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Track your learning journey',
                            style: AppTypography.secondary.copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TrueMeCircleIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh analytics',
                      size: 42,
                      onPressed: _loadStats,
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => context.push(
                        '/chat?prompt=${Uri.encodeComponent('Give me an honest diagnostic assessment of my exam readiness, retention rate, and what I should study next.')}',
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.sageOrbGradient,
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ask Sage',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Hero Readiness Gauge + Sage Prescription Card
                TrueMeCard(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(18),
                  gradient: isDark ? AppColors.heroFocusDarkGradient : AppColors.heroFocusLightGradient,
                  borderColor: isDark ? AppColors.darkBorder : const Color(0xFFDCD6FA),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TrueMeCircularRing(
                            progress: _analytics.readinessScore / 100.0,
                            size: 112,
                            strokeWidth: 11,
                            gradientColors: const [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                              Color(0xFF2DD4BF),
                              Color(0xFF6366F1),
                            ],
                            center: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_analytics.readinessScore}%',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontFamilyFallback: AppTypography.serifFallbacks,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Exam\nReadiness',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome_rounded, size: 15, color: context.accentColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Sage Prescription',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _analytics.sagePrescription,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.secondary.copyWith(
                                    fontSize: 13,
                                    color: context.textPrimary.withValues(alpha: 0.85),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TrueMeTonalPill(
                                  label: 'View Details',
                                  icon: Icons.arrow_forward_rounded,
                                  backgroundColor: context.surfaceColor.withValues(alpha: 0.9),
                                  foregroundColor: context.textPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  onTap: () {
                                    if (_analytics.prescriptionRoute == '/library') {
                                      context.go('/library');
                                    } else {
                                      context.push(_analytics.prescriptionRoute);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.surfaceColor.withValues(alpha: isDark ? 0.25 : 0.68),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MiniStat(
                              icon: Icons.calendar_today_outlined,
                              label: '${_analytics.daysLeft}d left',
                            ),
                            _MiniStat(
                              icon: Icons.quiz_outlined,
                              label: '${_analytics.quizzesTaken} quizzes',
                            ),
                            _MiniStat(
                              icon: Icons.style_outlined,
                              label: '${_analytics.totalCards} cards',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 3. Subject Mastery (Pastel Horizontal Row matching Reference Img 2 Left)
                TrueMeSectionHeader(
                  title: 'Subject Mastery',
                  actionLabel: _analytics.subjectMastery.isNotEmpty ? 'View All' : 'Add Subject',
                  onActionTap: () => context.go('/library'),
                ),
                const SizedBox(height: 12),
                if (_analytics.subjectMastery.isEmpty)
                  TrueMeCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No subjects enrolled yet. Add subjects in Library to track your mastery.',
                      style: AppTypography.secondary.copyWith(color: context.textSecondary),
                    ),
                  )
                else
                  SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _analytics.subjectMastery.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, idx) {
                        final s = _analytics.subjectMastery[idx];
                        final pastel = SubjectPastelStyle.forSubject(s.subject, isDark: isDark);
                        return SizedBox(
                          width: _analytics.subjectMastery.length <= 2 ? 168 : 112,
                          child: TrueMeCard(
                            borderRadius: 18,
                            padding: const EdgeInsets.all(12),
                            gradient: pastel.gradient,
                            borderColor: pastel.border,
                            onTap: () => context.push('/quiz?subject=${Uri.encodeComponent(s.subject)}'),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(pastel.icon, size: 22, color: pastel.accent),
                                Text(
                                  s.subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${s.mastery}%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: (s.mastery / 100.0).clamp(0.0, 1.0),
                                    minHeight: 5,
                                    backgroundColor: context.surfaceColor.withValues(alpha: 0.7),
                                    valueColor: AlwaysStoppedAnimation<Color>(pastel.accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 22),

                // 4. Memory Pipeline (Flashcards)
                TrueMeSectionHeader(
                  title: 'Memory Pipeline (Flashcards)',
                  actionLabel: _analytics.dueCards > 0 ? 'Review ${_analytics.dueCards}' : 'View All',
                  onActionTap: () async {
                    await context.push('/flashcards');
                    if (mounted) _loadStats();
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _PipelineNode(
                        label: 'Total',
                        count: _analytics.totalCards,
                        icon: Icons.layers_rounded,
                        bgColor: isDark ? AppColors.darkAccentWash : AppColors.accentWash,
                        iconColor: context.accentColor,
                      ),
                      _PipelineArrow(),
                      _PipelineNode(
                        label: 'Due',
                        count: _analytics.dueCards,
                        icon: Icons.schedule_rounded,
                        bgColor: isDark ? const Color(0xFF2B2110) : AppColors.pastelAmber,
                        iconColor: isDark ? AppColors.darkWarning : AppColors.pastelAmberInk,
                      ),
                      _PipelineArrow(),
                      _PipelineNode(
                        label: 'Learning',
                        count: _analytics.learningCards,
                        icon: Icons.play_arrow_rounded,
                        bgColor: isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen,
                        iconColor: isDark ? AppColors.darkSuccess : AppColors.pastelGreenInk,
                      ),
                      _PipelineArrow(),
                      _PipelineNode(
                        label: 'Developing',
                        count: _analytics.developingCards,
                        icon: Icons.signal_cellular_alt_rounded,
                        bgColor: isDark ? const Color(0xFF11233D) : AppColors.pastelBlue,
                        iconColor: isDark ? const Color(0xFF60A5FA) : AppColors.pastelBlueInk,
                      ),
                      _PipelineArrow(),
                      _PipelineNode(
                        label: 'Consolidating',
                        count: _analytics.consolidatingCards,
                        icon: Icons.check_circle_outline_rounded,
                        bgColor: isDark ? const Color(0xFF0E2922) : const Color(0xFFD1FAE5),
                        iconColor: isDark ? AppColors.darkSuccess : const Color(0xFF059669),
                      ),
                      _PipelineArrow(),
                      _PipelineNode(
                        label: 'Mastered',
                        count: _analytics.masteredCards,
                        icon: Icons.emoji_events_rounded,
                        bgColor: isDark ? const Color(0xFF2B2110) : const Color(0xFFFEF3C7),
                        iconColor: isDark ? AppColors.darkWarning : const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 5. Split 2-Col Row: Weak Topics + Weekly Study Rhythm
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left: Weak Topics
                      Expanded(
                        child: TrueMeCard(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: isDark ? AppColors.darkWarning : const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Weak Topics',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.cardTitle.copyWith(
                                        fontSize: 14.5,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_analytics.weakTopics.isEmpty)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      _analytics.quizzesTaken == 0
                                          ? 'Take a quiz to spot gaps.'
                                          : 'All topics above 80%!',
                                      style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                    ),
                                  ),
                                )
                              else
                                ..._analytics.weakTopics.take(3).map((w) {
                                  final topic = w['topic'] as String? ?? 'Topic';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: InkWell(
                                      onTap: () async {
                                        await context.push('/quiz?topic=${Uri.encodeComponent(topic)}');
                                        if (mounted) _loadStats();
                                      },
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: context.accentColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Text(
                                              topic,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              const Spacer(),
                              const SizedBox(height: 8),
                              TrueMeTonalPill(
                                label: 'Review Topics',
                                icon: Icons.arrow_forward_rounded,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                onTap: () async {
                                  await context.push('/mistake-vault');
                                  if (mounted) _loadStats();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Right: Weekly Study Rhythm
                      Expanded(
                        child: TrueMeCard(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 15, color: context.accentColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Weekly Rhythm',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.cardTitle.copyWith(
                                        fontSize: 14,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2B2110) : AppColors.pastelAmber,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      size: 13,
                                      color: isDark ? AppColors.darkWarning : const Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_analytics.streak} ${_analytics.streak == 1 ? 'Day' : 'Days'} Streak',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.darkWarning : AppColors.pastelAmberInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 76,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(7, (i) {
                                    final mins = _analytics.weeklyBars[i];
                                    final ratio = maxBarVal > 0 ? (mins / maxBarVal).clamp(0.0, 1.0) : 0.0;
                                    final h = mins > 0 ? (ratio * 52).clamp(8.0, 52.0) : 6.0;
                                    final isToday = (i + 1) == todayWeekday;
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: 11,
                                          height: h,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(5),
                                            color: mins > 0
                                                ? (isToday
                                                    ? context.accentColor
                                                    : context.accentColor.withValues(alpha: 0.65))
                                                : context.borderColor,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          days[i][0],
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                            color: isToday ? context.accentColor : context.textSecondary,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 13, color: context.textSecondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${_formatDuration(_analytics.totalWeeklyMinutes)} this week',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.smallLabel.copyWith(color: context.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 6. Recent Activity Timeline
                TrueMeSectionHeader(
                  title: 'Recent Activity',
                  actionLabel: 'Practice',
                  onActionTap: () => context.go('/practice'),
                ),
                const SizedBox(height: 12),
                if (_analytics.recentSessions.isEmpty)
                  TrueMeCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No recorded sessions yet. Complete a quiz, flashcard deck, or study task to build your activity log.',
                      style: AppTypography.secondary.copyWith(color: context.textSecondary),
                    ),
                  )
                else
                  TrueMeCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: List.generate(_analytics.recentSessions.take(5).length, (i) {
                        final list = _analytics.recentSessions.take(5).toList();
                        final s = list[i];
                        final title = s['title'] as String? ?? 'Study Session';
                        final activity = (s['activity'] as String? ?? 'study').toLowerCase();
                        final ago = _relativeTime(s['timestamp'] as String?);
                        final isLast = i == list.length - 1;

                        String verb = 'Studied';
                        if (activity == 'quiz') verb = 'Completed';
                        if (activity == 'flashcards') verb = 'Reviewed';
                        if (activity == 'voice') verb = 'Practiced';

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 5),
                                  decoration: BoxDecoration(
                                    color: context.accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 30,
                                    color: context.accentColor.withValues(alpha: 0.25),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                                child: Row(
                                  children: [
                                    Text(
                                      '$verb  ',
                                      style: AppTypography.smallLabel.copyWith(
                                        color: context.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (ago.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        ago,
                                        style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.textSecondary),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.smallLabel.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PipelineNode extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const _PipelineNode({
    required this.label,
    required this.count,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return TrueMeCard(
      width: 78,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_rounded, size: 14, color: context.textSecondary.withValues(alpha: 0.6)),
    );
  }
}
