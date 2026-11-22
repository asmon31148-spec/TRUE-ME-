import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _daysLeft = 30;
  double _planProgress = 0.0;
  int _streak = 0;
  int _totalWeeklyMinutes = 0;
  List<int> _weeklyBars = [0, 0, 0, 0, 0, 0, 0];
  List<Map<String, dynamic>> _weakTopics = [];
  int _quizzesTaken = 0;

  // Real-data analytics
  List<Map<String, dynamic>> _subjectMastery = [];
  int _totalCards = 0;
  int _dueCards = 0;
  int _learningCards = 0;
  int _developingCards = 0;
  int _consolidatingCards = 0;
  int _masteredCards = 0;
  int _readinessScore = 0;
  String _sageAdvice = '';
  List<Map<String, dynamic>> _recentSessions = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final now = DateTime.now();
    final deadline = OfflineCacheService.getTargetExamDate();
    final daysLeft = OfflineCacheService.daysUntil(deadline);

    final todayPlan = OfflineCacheService.getCachedStudyPlan(OfflineCacheService.dateKey(now));
    final tasks = (todayPlan?['sessions'] as List? ?? []);
    final completed = tasks.where((t) => (t as Map)['completed'] == true).length;
    final planProgress = tasks.isNotEmpty ? completed / tasks.length : 0.0;

    final allNotebooks = OfflineCacheService.getAllCachedNotebooks();
    final allQuizzes = OfflineCacheService.getQuizAttempts();
    final allDecks = OfflineCacheService.getAllCachedDecks();
    final recent = OfflineCacheService.getRecentSessions();

    // 1. Compute Subject-by-Subject Mastery
    final List<Map<String, dynamic>> subjectMastery = [];
    final nowPlus = DateTime.now().add(const Duration(minutes: 5));

    for (final nb in allNotebooks) {
      final subject = (nb['title'] as String? ?? 'General').trim();
      final docs = (nb['documents'] as List? ?? []);

      // Quizzes for this subject
      final subQuizzes = allQuizzes.where((q) {
        final s = (q['subject'] as String? ?? '').trim().toLowerCase();
        final t = (q['topic'] as String? ?? '').trim().toLowerCase();
        return s == subject.toLowerCase() || t.contains(subject.toLowerCase());
      }).toList();

      final qCount = subQuizzes.length;
      final avgQuizScore = qCount > 0
          ? (subQuizzes.fold<int>(0, (sum, q) => sum + ((q['percentage'] as num? ?? 0).toInt())) / qCount).round()
          : 0;

      // Flashcards for this subject
      final subDecks = allDecks.where((d) {
        final s = (d['subject'] as String? ?? '').trim().toLowerCase();
        final t = (d['title'] as String? ?? '').trim().toLowerCase();
        return s == subject.toLowerCase() || t.contains(subject.toLowerCase());
      }).toList();

      int sTotalCards = 0;
      int sMasteredCards = 0;
      int sDueCards = 0;

      for (final d in subDecks) {
        final cards = (d['cards'] as List? ?? []);
        sTotalCards += cards.length;
        for (final c in cards) {
          final rep = (c as Map)['repetitions'] as num? ?? 0;
          final interval = c['interval'] as num? ?? 0;
          if (rep >= 3 || interval >= 14) {
            sMasteredCards++;
          }
          final nextStr = c['nextReviewDate'] as String?;
          final nextDt = nextStr != null ? DateTime.tryParse(nextStr) : null;
          if (nextDt == null || nextDt.isBefore(nowPlus)) {
            sDueCards++;
          }
        }
      }

      // Weighted mastery formula:
      // Note: Only proven retrieval practice (quizzes and mastered flashcards) earns mastery score.
      // Merely uploading notes without testing knowledge awards 0% mastery.
      double score = 0.0;
      if (qCount > 0 && sTotalCards > 0) {
        score = (avgQuizScore * 0.60) + ((sMasteredCards / sTotalCards) * 100 * 0.40);
      } else if (qCount > 0) {
        score = avgQuizScore.toDouble();
      } else if (sTotalCards > 0 && sMasteredCards > 0) {
        score = ((sMasteredCards / sTotalCards) * 100.0);
      } else {
        score = 0.0;
      }

      subjectMastery.add({
        'subject': subject,
        'notebookId': nb['id'],
        'docsCount': docs.length,
        'quizCount': qCount,
        'avgQuizScore': avgQuizScore,
        'totalCards': sTotalCards,
        'masteredCards': sMasteredCards,
        'dueCards': sDueCards,
        'mastery': score.round().clamp(0, 100),
      });
    }

    // 2. Compute Global Spaced Repetition (Leitner) Stats
    int totalCards = 0;
    int dueCards = 0;
    int learning = 0;
    int developing = 0;
    int consolidating = 0;
    int mastered = 0;

    for (final d in allDecks) {
      final cards = (d['cards'] as List? ?? []);
      totalCards += cards.length;
      for (final c in cards) {
        final rep = (c as Map)['repetitions'] as num? ?? 0;
        final interval = c['interval'] as num? ?? 0;
        if (rep <= 1 || interval <= 1) {
          learning++;
        } else if (rep == 2 || interval <= 6) {
          developing++;
        } else if (rep == 3 || interval <= 14) {
          consolidating++;
        } else {
          mastered++;
        }

        final nextStr = c['nextReviewDate'] as String?;
        final nextDt = nextStr != null ? DateTime.tryParse(nextStr) : null;
        if (nextDt == null || nextDt.isBefore(nowPlus)) {
          dueCards++;
        }
      }
    }

    // 3. Compute Composite Readiness Index (0 - 100%)
    double overall = 0.0;
    if (subjectMastery.isNotEmpty) {
      final sum = subjectMastery.fold<int>(0, (s, m) => s + (m['mastery'] as int));
      overall = sum / subjectMastery.length;
    } else {
      overall = planProgress * 45.0;
    }
    final readiness = overall.round().clamp(0, 100);

    // 4. Formulate Actionable Sage Prescription
    final weakTopics = OfflineCacheService.getWeakTopics();
    String advice = '';
    if (dueCards > 0) {
      advice = 'Memory Recall Alert: $dueCards flashcards are due for review. Reviewing them today prevents forgetting curve decay and secures your long-term memory.';
    } else if (weakTopics.isNotEmpty) {
      final topWeak = weakTopics.first;
      advice = 'Targeted Gap: "${topWeak['topic']}" scored ${topWeak['score']}%. Take a 5-question targeted quiz to turn this critical gap into a strength.';
    } else if (allNotebooks.isEmpty) {
      advice = 'Get Started: Upload your first syllabus or lecture notes in Library. Sage will extract high-yield concepts, quizzes, and spaced flashcards.';
    } else if (allQuizzes.isEmpty) {
      advice = 'Take a Diagnostic Quiz: Practice active recall on your subjects to unlock exam readiness analytics and detect hidden blind spots.';
    } else {
      advice = 'High Study Velocity: Your review pace is on track for your exam in $daysLeft days. Keep up your daily streak to ensure peak retention.';
    }

    setState(() {
      _daysLeft = daysLeft;
      _planProgress = planProgress;
      _streak = OfflineCacheService.getCurrentStreak();
      _weeklyBars = OfflineCacheService.getWeeklyStudyMinutes();
      _totalWeeklyMinutes = _weeklyBars.fold(0, (s, m) => s + m);
      _weakTopics = weakTopics;
      _quizzesTaken = allQuizzes.length;
      _subjectMastery = subjectMastery;
      _totalCards = totalCards;
      _dueCards = dueCards;
      _learningCards = learning;
      _developingCards = developing;
      _consolidatingCards = consolidating;
      _masteredCards = mastered;
      _readinessScore = readiness;
      _sageAdvice = advice;
      _recentSessions = recent;
    });
  }

  String _formatDuration(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String _getReadinessLabel(int score) {
    if (score >= 85) return 'Distinction Ready';
    if (score >= 70) return 'Solid Passing Range';
    if (score >= 50) return 'Developing Mastery';
    if (score > 0) return 'Early Study Phase';
    return 'Diagnostic Needed';
  }

  Color _getMasteryColor(int score, BuildContext context) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return context.accentColor;
    return const Color(0xFFF59E0B); // Amber
  }

  @override
  Widget build(BuildContext context) {
    final maxBarVal = _weeklyBars.fold<int>(30, (maxVal, v) => v > maxVal ? v : maxVal);
    final days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayWeekday = DateTime.now().weekday; // 1=Mon .. 7=Sun

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Progress', style: AppTypography.screenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            tooltip: 'Refresh analytics',
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 22),
            tooltip: 'Ask Sage Diagnostic',
            onPressed: () => context.push(
              '/chat?prompt=${Uri.encodeComponent('Give me an honest diagnostic assessment of my exam readiness, retention rate, and what I should study next.')}',
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: context.accentColor,
          onRefresh: () async {
            await OfflineCacheService.syncFromCloud();
            if (mounted) _loadStats();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // 1. Exam Readiness & Diagnostic Index Card
              _buildExamReadinessCard(context),
              const SizedBox(height: 16),

              // 2. Sage AI Diagnostic Prescription Callout
              _buildSagePrescriptionCard(context),
              const SizedBox(height: 16),

              // 3. Subject Mastery Breakdown (Real data per enrolled subject)
              _buildSubjectMasteryCard(context),
              const SizedBox(height: 16),

              // 4. Spaced Repetition Memory Pipeline (Leitner Retention Engine)
              _buildSpacedRepetitionCard(context),
              const SizedBox(height: 16),

              // 5. Critical Weak Topics & Gaps Card
              _buildWeakTopicsCard(context),
              const SizedBox(height: 16),

              // 6. Study Consistency & Weekly Rhythm (Streak + Chart)
              _buildWeeklyRhythmCard(context, days, todayWeekday, maxBarVal),
              const SizedBox(height: 16),

              // 7. Recent Study Activity Timeline
              if (_recentSessions.isNotEmpty) ...[
                _buildRecentActivityCard(context),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. EXAM READINESS & DIAGNOSTIC CARD
  // ---------------------------------------------------------------------------
  Widget _buildExamReadinessCard(BuildContext context) {
    final statusLabel = _getReadinessLabel(_readinessScore);
    final badgeColor = _getMasteryColor(_readinessScore, context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exam Readiness Index',
                      style: AppTypography.smallLabel.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_readinessScore%',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Visual Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_readinessScore / 100.0).clamp(0.04, 1.0),
              backgroundColor: context.borderColor,
              color: badgeColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),

          // Diagnostic Metrics Row (Wrapped so it never overflows)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: context.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    '$_daysLeft ${_daysLeft == 1 ? 'day' : 'days'} to exam',
                    style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                  ),
                ],
              ),
              Text('•', style: AppTypography.smallLabel.copyWith(color: context.textSecondary)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_outlined, size: 14, color: context.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    '$_quizzesTaken ${_quizzesTaken == 1 ? 'quiz' : 'quizzes'} taken',
                    style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                  ),
                ],
              ),
              Text('•', style: AppTypography.smallLabel.copyWith(color: context.textSecondary)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.style_outlined, size: 14, color: context.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    '$_totalCards cards',
                    style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. SAGE DIAGNOSTIC PRESCRIPTION
  // ---------------------------------------------------------------------------
  Widget _buildSagePrescriptionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode ? const Color(0xFF1E1A17) : const Color(0xFFF9F6F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.accentColor.withOpacity(0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: context.accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: context.accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Sage Diagnostic Prescription',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.accentColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _sageAdvice,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                if (_dueCards > 0) {
                  context.push('/flashcards');
                } else if (_weakTopics.isNotEmpty) {
                  context.push('/quiz?topic=${Uri.encodeComponent(_weakTopics.first['topic'] as String)}');
                } else {
                  context.push('/practice');
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dueCards > 0
                          ? 'Review Due Cards'
                          : (_weakTopics.isNotEmpty ? 'Practice Weak Topic' : 'Open Practice'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.accentColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: context.accentColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. SUBJECT-BY-SUBJECT MASTERY RADAR
  // ---------------------------------------------------------------------------
  Widget _buildSubjectMasteryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subject Mastery Radar', style: AppTypography.sectionHeading),
              Text(
                '${_subjectMastery.length} Enrolled',
                style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_subjectMastery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No subjects added yet. Add subjects in the Library to track granular mastery.',
                style: AppTypography.secondary,
              ),
            )
          else
            ...List.generate(_subjectMastery.length, (i) {
              final s = _subjectMastery[i];
              final subjectName = s['subject'] as String;
              final mastery = s['mastery'] as int;
              final docs = s['docsCount'] as int;
              final qCount = s['quizCount'] as int;
              final avgQuiz = s['avgQuizScore'] as int;
              final tCards = s['totalCards'] as int;
              final mCards = s['masteredCards'] as int;
              final color = _getMasteryColor(mastery, context);

              return Padding(
                padding: EdgeInsets.only(bottom: i < _subjectMastery.length - 1 ? 16 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            subjectName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '$mastery%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (mastery / 100.0).clamp(0.02, 1.0),
                        backgroundColor: context.borderColor,
                        color: color,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '$docs ${docs == 1 ? 'doc' : 'docs'}',
                          style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                        ),
                        const Text(' • ', style: AppTypography.smallLabel),
                        Text(
                          qCount > 0 ? '$avgQuiz% quiz avg ($qCount)' : 'No quizzes yet',
                          style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                        ),
                        const Text(' • ', style: AppTypography.smallLabel),
                        Text(
                          tCards > 0 ? '$mCards/$tCards cards' : '0 cards',
                          style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => context.push('/quiz?subject=${Uri.encodeComponent(subjectName)}'),
                          child: Text(
                            'Practice →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < _subjectMastery.length - 1)
                      Divider(color: context.borderColor, height: 18),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. SPACED REPETITION MEMORY PIPELINE (LEITNER ENGINE)
  // ---------------------------------------------------------------------------
  Widget _buildSpacedRepetitionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Memory Retention & Recall', style: AppTypography.sectionHeading),
              if (_dueCards > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_dueCards Due Today',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cards progress through spaced repetition intervals to lock facts into permanent memory.',
            style: AppTypography.secondary,
          ),
          const SizedBox(height: 16),

          // 4 Cognitive Stages
          Row(
            children: [
              _buildMemoryBox(context, 'Learning', _learningCards, const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              _buildMemoryBox(context, 'Review', _developingCards, const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _buildMemoryBox(context, 'Strong', _consolidatingCards, const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              _buildMemoryBox(context, 'Mastered', _masteredCards, AppColors.success),
            ],
          ),
          const SizedBox(height: 14),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: AppSecondaryButton(
              label: _dueCards > 0 ? 'Review $_dueCards due cards now' : 'Practice flashcards',
              icon: const Icon(Icons.style_outlined, size: 18),
              onPressed: () => context.push('/flashcards'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryBox(BuildContext context, String stage, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                stage,
                maxLines: 1,
                style: AppTypography.smallLabel.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. CRITICAL WEAK TOPICS & GAPS
  // ---------------------------------------------------------------------------
  Widget _buildWeakTopicsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Topics Needing Focus', style: AppTypography.sectionHeading),
              if (_weakTopics.isNotEmpty)
                Text(
                  'Score < 80%',
                  style: AppTypography.smallLabel.copyWith(color: AppColors.error),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_weakTopics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _quizzesTaken == 0
                    ? 'Take a quiz in Practice to pinpoint weak topics and gaps.'
                    : 'No weak spots detected! You scored 80%+ on all quizzes.',
                style: AppTypography.secondary,
              ),
            )
          else
            ...List.generate(_weakTopics.length, (i) {
              final w = _weakTopics[i];
              final topic = w['topic'] as String;
              final score = '${w['score']}%';
              return Column(
                children: [
                  _buildWeakTopicRow(context, topic, score),
                  if (i < _weakTopics.length - 1)
                    Divider(color: context.borderColor, height: 16),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildWeakTopicRow(BuildContext context, String topic, String score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              topic,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: context.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              score,
              style: const TextStyle(fontSize: 12.5, color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () async {
              await context.push('/quiz?topic=${Uri.encodeComponent(topic)}');
              if (mounted) _loadStats();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Review', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. WEEKLY STUDY RHYTHM & CONSISTENCY (CHART)
  // ---------------------------------------------------------------------------
  Widget _buildWeeklyRhythmCard(
    BuildContext context,
    List<String> days,
    int todayWeekday,
    int maxBarVal,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Weekly Study Rhythm', style: AppTypography.sectionHeading),
              Row(
                children: [
                  const Text('🔥 ', style: TextStyle(fontSize: 14)),
                  Text(
                    '$_streak ${_streak == 1 ? 'day' : 'days'} streak',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Total study time this week: ${_formatDuration(_totalWeeklyMinutes)}',
            style: AppTypography.secondary,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 125,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                return _buildBar(
                  context,
                  days[i],
                  _weeklyBars[i],
                  maxBarVal,
                  isToday: (i + 1) == todayWeekday,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, String day, int minutes, int maxVal, {bool isToday = false}) {
    final ratio = maxVal > 0 ? (minutes / maxVal).clamp(0.0, 1.0) : 0.0;
    final barHeight = minutes > 0 ? (ratio * 76).clamp(6.0, 76.0) : 4.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (minutes > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${minutes}m', style: TextStyle(fontSize: 10, color: context.textSecondary)),
          ),
        Container(
          width: 24,
          height: barHeight,
          decoration: BoxDecoration(
            color: minutes > 0 ? context.accentColor : context.borderColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: AppTypography.smallLabel.copyWith(
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? context.accentColor : context.textSecondary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 7. RECENT STUDY ACTIVITY TIMELINE
  // ---------------------------------------------------------------------------
  Widget _buildRecentActivityCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Study Sessions', style: AppTypography.sectionHeading),
          const SizedBox(height: 12),
          ..._recentSessions.take(5).map((s) {
            final title = s['title'] as String? ?? 'Study session';
            final subtitle = s['subtitle'] as String? ?? '';
            final activity = s['activity'] as String? ?? 'study';

            IconData icon = Icons.school_outlined;
            if (activity == 'quiz') icon = Icons.quiz_outlined;
            if (activity == 'flashcards') icon = Icons.style_outlined;
            if (activity == 'document' || activity == 'pdf') icon = Icons.description_outlined;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: context.accentTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: context.accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(subtitle, style: AppTypography.secondary),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
