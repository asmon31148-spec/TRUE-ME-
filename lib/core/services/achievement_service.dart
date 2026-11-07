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
    return [
      const AchievementBadge(
        id: 'streak_7',
        title: 'Consistent 7',
        description: 'Studied 7 days in a row without breaking streak',
        icon: '🔥',
        isUnlocked: true,
      ),
      const AchievementBadge(
        id: 'decay_slayer',
        title: 'Decay Slayer',
        description: 'Reviewed 25 flashcards with SM-2 spaced repetition',
        icon: '⚡',
        isUnlocked: true,
      ),
      const AchievementBadge(
        id: 'rag_scholar',
        title: 'RAG Scholar',
        description: 'Asked Sage 50 questions with verified textbook citations',
        icon: '📚',
        isUnlocked: false,
      ),
      const AchievementBadge(
        id: 'voice_master',
        title: 'Voice Scholar',
        description: 'Completed a 30-minute interactive voice tutor session',
        icon: '🎙️',
        isUnlocked: false,
      ),
      const AchievementBadge(
        id: 'perfect_quiz',
        title: '100% Mastery',
        description: 'Scored 100% on an adaptive hard concept quiz',
        icon: '🏆',
        isUnlocked: false,
      ),
    ];
  }
}
