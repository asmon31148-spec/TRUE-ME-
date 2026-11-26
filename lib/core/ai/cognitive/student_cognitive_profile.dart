import 'package:hive_flutter/hive_flutter.dart';
import '../../services/offline_cache_service.dart';

/// The student's current cognitive mastery tier for a subject or overall.
enum CognitiveTier {
  /// Score < 60% or fresh subject: Needs first-principles analogies, guided scaffolding, and encouraging tone.
  foundational,

  /// Score 60%–84%: Needs active recall, comparative distinctions, edge-case testing, and problem-solving.
  reinforcing,

  /// Score >= 85%: Needs high-yield exam board vignettes, multi-step synthesis, and trap-avoidance drills.
  mastery,
}

/// The urgency level based on the countdown to the student's exam/trial date.
enum ExamUrgencyTier {
  /// <= 3 days: Emergency high-yield crunch mode. Zero academic fluff, only key formulas, traps, and mnemonics.
  critical,

  /// <= 7 days: Intensive review mode. 80% weak/decaying topics, 20% general verification.
  urgent,

  /// <= 21 days: Strategic mastery mode. Systemic spaced repetition and full-scope synthesis.
  approaching,

  /// > 21 days: Progressive curriculum learning and foundational concept acquisition.
  steady,
}

/// Real-time live snapshot of the student's cognitive status, strengths, decay, and momentum.
class StudentCognitiveProfile {
  final String studentName;
  final int overallMasteryPercentage;
  final CognitiveTier tier;
  CognitiveTier get overallTier => tier;
  final int daysToExam;
  final ExamUrgencyTier urgencyTier;
  final List<Map<String, dynamic>> weakTopics;
  final int dueFlashcardsCount;
  final int totalFlashcardsCount;
  final int quizzesTakenCount;
  final int todayMinutesStudied;
  final int streakDays;
  final String? activeSubject;
  final int? activeSubjectMasteryPercentage;
  final CognitiveTier? activeSubjectTier;

  const StudentCognitiveProfile({
    required this.studentName,
    required this.overallMasteryPercentage,
    required this.tier,
    required this.daysToExam,
    required this.urgencyTier,
    required this.weakTopics,
    required this.dueFlashcardsCount,
    required this.totalFlashcardsCount,
    required this.quizzesTakenCount,
    required this.todayMinutesStudied,
    required this.streakDays,
    this.activeSubject,
    this.activeSubjectMasteryPercentage,
    this.activeSubjectTier,
  });

  /// Builds a live, real-data snapshot of the student directly from local analytics in < 1ms.
  factory StudentCognitiveProfile.buildLive({String? subjectScope}) {
    final name = OfflineCacheService.getUserName();
    final profile = OfflineCacheService.getUserProfile();
    final examDateStr = (profile['targetExamDate'] ?? profile['examDate']) as String?;
    final examDate = examDateStr != null ? DateTime.tryParse(examDateStr) : null;
    final now = DateTime.now();

    // 1. Calculate Days to Exam & Urgency Tier
    int days = 30;
    if (examDate != null) {
      days = examDate.difference(now).inDays;
      if (days < 0) days = 0;
    }
    final urgency = days <= 3
        ? ExamUrgencyTier.critical
        : (days <= 7
            ? ExamUrgencyTier.urgent
            : (days <= 21 ? ExamUrgencyTier.approaching : ExamUrgencyTier.steady));

    final hasSubjectScope = subjectScope != null && subjectScope.trim().isNotEmpty;
    final scopeLower = hasSubjectScope ? subjectScope.trim().toLowerCase() : '';

    // 2. Quiz Attempts & Mastery (strictly isolated to subjectScope when scoped)
    final allQuizzes = OfflineCacheService.getQuizAttempts();
    final relevantQuizzes = hasSubjectScope
        ? allQuizzes
            .where((q) => (q['subject'] as String? ?? '').trim().toLowerCase() == scopeLower)
            .toList()
        : allQuizzes;

    int masteryScore = hasSubjectScope ? 0 : 70;
    if (relevantQuizzes.isNotEmpty) {
      final sum = relevantQuizzes.fold<int>(
        0,
        (prev, q) => prev + ((q['percentage'] as num?)?.toInt() ?? 0),
      );
      masteryScore = (sum / relevantQuizzes.length).round();
    }

    final resolvedTier = masteryScore < 60
        ? CognitiveTier.foundational
        : (masteryScore < 85 ? CognitiveTier.reinforcing : CognitiveTier.mastery);

    // 3. Weak Topics (strictly isolated to subjectScope when scoped)
    final allWeak = OfflineCacheService.getWeakTopics();
    final weakList = hasSubjectScope
        ? allWeak
            .where((w) => (w['subject'] as String? ?? '').trim().toLowerCase() == scopeLower)
            .toList()
        : allWeak;

    // 4. Flashcard review pressure (strictly isolated to subjectScope when scoped)
    final allDecks = OfflineCacheService.getAllCachedDecks();
    final relevantDecks = hasSubjectScope
        ? allDecks
            .where((d) => (d['subject'] as String? ?? '').trim().toLowerCase() == scopeLower)
            .toList()
        : allDecks;

    int totalCards = 0;
    int dueCards = 0;
    final nowPlus = now.add(const Duration(minutes: 5));
    for (final d in relevantDecks) {
      final cards = d['cards'] as List? ?? [];
      totalCards += cards.length;
      for (final c in cards) {
        final nextStr = (c as Map)['nextReviewDate'] as String?;
        final nextDt = nextStr != null ? DateTime.tryParse(nextStr) : null;
        if (nextDt == null || nextDt.isBefore(nowPlus)) dueCards++;
      }
    }

    // 5. Study momentum
    int todayMinutes = 0;
    try {
      final aBox = Hive.box(OfflineCacheService.analyticsBox);
      final rawDaily = aBox.get('daily_minutes') as Map? ?? {};
      final todayKey = OfflineCacheService.dateKey(now);
      final val = rawDaily[todayKey];
      if (val is num) todayMinutes = val.toInt();
    } catch (_) {}
    final streak = OfflineCacheService.getCurrentStreak();

    return StudentCognitiveProfile(
      studentName: name.isNotEmpty ? name : 'Scholar',
      overallMasteryPercentage: masteryScore,
      tier: resolvedTier,
      daysToExam: days,
      urgencyTier: urgency,
      weakTopics: weakList,
      dueFlashcardsCount: dueCards,
      totalFlashcardsCount: totalCards,
      quizzesTakenCount: relevantQuizzes.length,
      todayMinutesStudied: todayMinutes,
      streakDays: streak,
      activeSubject: hasSubjectScope ? subjectScope.trim() : null,
      activeSubjectMasteryPercentage: hasSubjectScope ? masteryScore : null,
      activeSubjectTier: hasSubjectScope ? resolvedTier : null,
    );
  }

  /// Formats this cognitive state into an authoritative prompt injection for Sage.
  String toSageContextString() {
    final effectiveTier = activeSubjectTier ?? tier;
    final effectiveMastery = activeSubjectMasteryPercentage ?? overallMasteryPercentage;
    final tierLabel = effectiveTier == CognitiveTier.foundational
        ? 'FOUNDATIONAL (Needs conceptual scaffolding & analogies)'
        : (effectiveTier == CognitiveTier.reinforcing
            ? 'REINFORCING (Ready for active recall & edge cases)'
            : 'HIGH-YIELD MASTERY (Exam board caliber, needs clinical vignettes & trap defense)');

    final urgencyLabel = urgencyTier == ExamUrgencyTier.critical
        ? 'CRITICAL EXAM COUNTDOWN ($daysToExam days left - Max efficiency, high-yield only)'
        : (urgencyTier == ExamUrgencyTier.urgent
            ? 'URGENT EXAM COUNTDOWN ($daysToExam days left - Attack weak spots)'
            : (urgencyTier == ExamUrgencyTier.approaching
                ? 'APPROACHING EXAM ($daysToExam days left)'
                : 'STEADY PACE ($daysToExam days left)'));

    final weakFormatted = weakTopics.isNotEmpty
        ? weakTopics.map((w) => '${w['topic']} (${w['score']}%)').join(', ')
        : 'None recorded yet (promote assessment test)';

    final subjectLine = activeSubject != null && activeSubject!.isNotEmpty
        ? 'Active Subject Scoping: "$activeSubject" (Subject Mastery: $effectiveMastery%)\n'
        : 'Cross-Subject Scope (Overall Mastery: $overallMasteryPercentage%)\n';

    return '''
=== LIVE STUDENT COGNITIVE PROFILE ===
Student: $studentName
${subjectLine}Cognitive Tier: $tierLabel
Exam Timeline: $urgencyLabel
Recorded Weaknesses / Decaying Knowledge: $weakFormatted
Memory Decay Risk: $dueFlashcardsCount flashcards overdue (out of $totalFlashcardsCount total)
Study Momentum: $todayMinutesStudied mins studied today • $streakDays-day active streak
Assessments Completed: $quizzesTakenCount quiz sessions
======================================''';
  }
}
