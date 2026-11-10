import 'offline_cache_service.dart';

class AchievementBadge {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
    this.unlockedAt,
  });
}

class AchievementService {
  AchievementService._();

  static List<AchievementBadge> getInitialBadges() {
    final streak = OfflineCacheService.getCurrentStreak();
    final quizzes = OfflineCacheService.getQuizAttempts();
    final sessions = OfflineCacheService.getRecentPracticeSessions();
    final decks = OfflineCacheService.getAllCachedDecks();

    int totalReviewedCards = 0;
    for (final s in sessions.where((e) => e['activity'] == 'flashcards')) {
      final sub = (s['subtitle'] as String? ?? '');
      final match = RegExp(r'(\d+)').firstMatch(sub);
      if (match != null) {
        totalReviewedCards += int.tryParse(match.group(1) ?? '0') ?? 0;
      }
    }

    final hasVoiceSession = sessions.any((e) => e['activity'] == 'voice');
    final hasPerfectQuiz = quizzes.any((q) => (q['percentage'] as num? ?? 0) >= 100);

    return [
      AchievementBadge(
        id: 'streak_7',
        title: 'Consistent 7',
        description: 'Studied 7 days in a row without breaking streak',
        icon: '7d',
        isUnlocked: streak >= 7,
      ),
      AchievementBadge(
        id: 'decay_slayer',
        title: 'Decay Slayer',
        description: 'Reviewed 25 flashcards with SM-2 spaced repetition',
        icon: '25c',
        isUnlocked: totalReviewedCards >= 25,
      ),
      AchievementBadge(
        id: 'deck_builder',
        title: 'Card Creator',
        description: 'Created or generated at least 1 flashcard deck',
        icon: 'Deck',
        isUnlocked: decks.isNotEmpty,
      ),
      AchievementBadge(
        id: 'voice_master',
        title: 'Voice Scholar',
        description: 'Completed an interactive voice tutor session',
        icon: 'Mic',
        isUnlocked: hasVoiceSession,
      ),
      AchievementBadge(
        id: 'perfect_quiz',
        title: '100% Mastery',
        description: 'Scored 100% on a practice quiz',
        icon: '100%',
        isUnlocked: hasPerfectQuiz,
      ),
    ];
  }
}
