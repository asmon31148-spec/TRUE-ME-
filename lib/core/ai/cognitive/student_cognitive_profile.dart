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
    final examDateStr = profile['examDate'] as String?;
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

    // 2. Quiz Attempts & Overall Mastery
    final allQuizzes = OfflineCacheService.getQuizAttempts();
    int overallScore = 70;
    if (allQuizzes.isNotEmpty) {
      final sum = allQuizzes.fold<int>(
        0,
        (prev, q) => prev + ((q['percentage'] as num?)?.toInt() ?? 0),
      );
      overallScore = (sum / allQuizzes.length).round();
    }

    final overallTier = overallScore < 60
        ? CognitiveTier.foundational
        : (overallScore < 85 ? CognitiveTier.reinforcing : CognitiveTier.mastery);

    // 3. Weak Topics & Memory Decay Radar
    final weakList = OfflineCacheService.getWeakTopics();

    // 4. Flashcard review pressure
    final allDecks = OfflineCacheService.getAllCachedDecks();
    int totalCards = 0;
    int dueCards = 0;
    final nowPlus = now.add(const Duration(minutes: 5));
    for (final d in allDecks) {
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

    // 6. Subject-specific drill-down if scoped
    int? subjectMastery;
    CognitiveTier? subjectTier;
    if (subjectScope != null && subjectScope.trim().isNotEmpty) {
      final s = subjectScope.trim().toLowerCase();
      final subQuizzes = allQuizzes
          .where((q) => (q['subject'] as String? ?? '').trim().toLowerCase() == s)
          .toList();
      if (subQuizzes.isNotEmpty) {
        final sSum = subQuizzes.fold<int>(
          0,
          (prev, q) => prev + ((q['percentage'] as num?)?.toInt() ?? 0),
        );
        subjectMastery = (sSum / subQuizzes.length).round();
        subjectTier = subjectMastery < 60
            ? CognitiveTier.foundational
            : (subjectMastery < 85 ? CognitiveTier.reinforcing : CognitiveTier.mastery);
      } else {
        subjectMastery = overallScore;
        subjectTier = overallTier;
      }
    }

    return StudentCognitiveProfile(
      studentName: name.isNotEmpty ? name : 'Scholar',
      overallMasteryPercentage: overallScore,
      tier: overallTier,
      daysToExam: days,
      urgencyTier: urgency,
      weakTopics: weakList,
      dueFlashcardsCount: dueCards,
      totalFlashcardsCount: totalCards,
      quizzesTakenCount: allQuizzes.length,
      todayMinutesStudied: todayMinutes,
      streakDays: streak,
      activeSubject: subjectScope,
      activeSubjectMasteryPercentage: subjectMastery,
      activeSubjectTier: subjectTier,
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
