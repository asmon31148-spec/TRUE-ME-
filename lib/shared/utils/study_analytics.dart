import '../../core/services/offline_cache_service.dart';

class SubjectMasterySnapshot {
  final String subject;
  final String notebookId;
  final int docsCount;
  final int quizCount;
  final int avgQuizScore;
  final int totalCards;
  final int masteredCards;
  final int dueCards;
  final int mastery;

  const SubjectMasterySnapshot({
    required this.subject,
    required this.notebookId,
    required this.docsCount,
    required this.quizCount,
    required this.avgQuizScore,
    required this.totalCards,
    required this.masteredCards,
    required this.dueCards,
    required this.mastery,
  });
}

class StudyAnalyticsSnapshot {
  final int daysLeft;
  final int totalExamSpanDays;
  final int streak;
  final double planProgress;
  final int quizzesTaken;
  final int totalCards;
  final int dueCards;
  final int learningCards;
  final int developingCards;
  final int consolidatingCards;
  final int masteredCards;
  final int readinessScore;
  final List<int> weeklyBars;
  final int totalWeeklyMinutes;
  final List<Map<String, dynamic>> weakTopics;
  final List<SubjectMasterySnapshot> subjectMastery;
  final List<Map<String, dynamic>> recentSessions;
  final String sagePrescription;
  final String prescriptionRoute;

  const StudyAnalyticsSnapshot({
    required this.daysLeft,
    required this.totalExamSpanDays,
    required this.streak,
    required this.planProgress,
    required this.quizzesTaken,
    required this.totalCards,
    required this.dueCards,
    required this.learningCards,
    required this.developingCards,
    required this.consolidatingCards,
    required this.masteredCards,
    required this.readinessScore,
    required this.weeklyBars,
    required this.totalWeeklyMinutes,
    required this.weakTopics,
    required this.subjectMastery,
    required this.recentSessions,
    required this.sagePrescription,
    required this.prescriptionRoute,
  });

  /// Aggregates live real-data analytics strictly from [OfflineCacheService].
  static StudyAnalyticsSnapshot computeLive() {
    final now = DateTime.now();
    final deadline = OfflineCacheService.getTargetExamDate();
    final setupDate = OfflineCacheService.getExamSetupDate();
    final daysLeft = OfflineCacheService.daysUntil(deadline);
    final totalExamSpanDays = deadline.difference(setupDate).inDays.clamp(1, 999);

    final todayPlan = OfflineCacheService.getCachedStudyPlan(OfflineCacheService.dateKey(now));
    final tasks = (todayPlan?['sessions'] as List? ?? []);
    final completed = tasks.where((t) => (t as Map)['completed'] == true).length;
    final planProgress = tasks.isNotEmpty ? completed / tasks.length : 0.0;

    final allNotebooks = OfflineCacheService.getAllCachedNotebooks();
    final allQuizzes = OfflineCacheService.getQuizAttempts();
    final allDecks = OfflineCacheService.getAllCachedDecks();
    final recent = OfflineCacheService.getRecentPracticeSessions();
    final weakTopics = OfflineCacheService.getWeakTopics();

    final List<SubjectMasterySnapshot> subjectMastery = [];
    final nowPlus = now.add(const Duration(minutes: 5));

    for (final nb in allNotebooks) {
      final subject = (nb['title'] as String? ?? 'General').trim();
      final nbId = nb['id'] as String? ?? '';
      final docs = (nb['documents'] as List? ?? []);

      final subQuizzes = allQuizzes.where((q) {
        final s = (q['subject'] as String? ?? '').trim().toLowerCase();
        final t = (q['topic'] as String? ?? '').trim().toLowerCase();
        return s == subject.toLowerCase() || t.contains(subject.toLowerCase());
      }).toList();

      final qCount = subQuizzes.length;
      final avgQuizScore = qCount > 0
          ? (subQuizzes.fold<int>(0, (sum, q) => sum + ((q['percentage'] as num? ?? 0).toInt())) /
                  qCount)
              .round()
          : 0;

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

      double score = 0.0;
      if (qCount > 0 && sTotalCards > 0) {
        score = (avgQuizScore * 0.60) + ((sMasteredCards / sTotalCards) * 100 * 0.40);
      } else if (qCount > 0) {
        score = avgQuizScore.toDouble();
      } else if (sTotalCards > 0 && sMasteredCards > 0) {
        score = (sMasteredCards / sTotalCards) * 100.0;
      }

      subjectMastery.add(
        SubjectMasterySnapshot(
          subject: subject,
          notebookId: nbId,
          docsCount: docs.length,
          quizCount: qCount,
          avgQuizScore: avgQuizScore,
          totalCards: sTotalCards,
          masteredCards: sMasteredCards,
          dueCards: sDueCards,
          mastery: score.round().clamp(0, 100),
        ),
      );
    }

    int totalCards = 0;
    int dueCards = 0;
    int learning = 0;
    int developing = 0;
    int consolidating = 0;
    int mastered = 0;
    String? dueSubject;

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
          dueSubject ??= d['subject'] as String?;
        }
      }
    }

    double overall = 0.0;
    if (subjectMastery.isNotEmpty) {
      final sum = subjectMastery.fold<int>(0, (s, m) => s + m.mastery);
      overall = sum / subjectMastery.length;
    } else if (allQuizzes.isNotEmpty) {
      final sum = allQuizzes.fold<int>(0, (s, q) => s + ((q['percentage'] as num? ?? 0).toInt()));
      overall = sum / allQuizzes.length;
    }
    final readiness = overall.round().clamp(0, 100);

    String advice;
    String route;
    if (dueCards > 0) {
      advice =
          '$dueCards ${dueCards == 1 ? 'flashcard is' : 'flashcards are'} due for spaced review${dueSubject != null ? ' in $dueSubject' : ''}. Reviewing today locks facts into long-term memory.';
      route = '/flashcards';
    } else if (weakTopics.isNotEmpty) {
      final topWeak = weakTopics.first;
      final topic = topWeak['topic'] as String;
      advice =
          'Focus more on "$topic" (${topWeak['score']}% recent score). A targeted 5-question quiz will strengthen this gap.';
      route = '/quiz?topic=${Uri.encodeComponent(topic)}';
    } else if (allNotebooks.isEmpty) {
      advice =
          'Add your subjects in Library and upload study materials so Sage can personalize your study plan and quizzes.';
      route = '/library';
    } else if (allQuizzes.isEmpty) {
      advice =
          'Take a diagnostic quiz in Practice to measure your exam readiness and uncover weak spots early.';
      route = '/quiz';
    } else {
      advice =
          'You are on a strong path for your exam in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}. Keep reinforcing high-yield topics.';
      route = '/practice';
    }

    final weeklyBars = OfflineCacheService.getWeeklyStudyMinutes();
    final totalWeekly = weeklyBars.fold<int>(0, (s, m) => s + m);

    return StudyAnalyticsSnapshot(
      daysLeft: daysLeft,
      totalExamSpanDays: totalExamSpanDays,
      streak: OfflineCacheService.getCurrentStreak(),
      planProgress: planProgress,
      quizzesTaken: allQuizzes.length,
      totalCards: totalCards,
      dueCards: dueCards,
      learningCards: learning,
      developingCards: developing,
      consolidatingCards: consolidating,
      masteredCards: mastered,
      readinessScore: readiness,
      weeklyBars: weeklyBars,
      totalWeeklyMinutes: totalWeekly,
      weakTopics: weakTopics,
      subjectMastery: subjectMastery,
      recentSessions: recent,
      sagePrescription: advice,
      prescriptionRoute: route,
    );
  }
}
