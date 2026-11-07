import '../models/flashcard_model.dart';

/// Implementation of the SuperMemo SM-2 Spaced Repetition Algorithm.
///
/// Rating scale:
/// 0 - Complete blackout
/// 1 - Incorrect; remember upon seeing answer
/// 2 - Incorrect; serious difficulty
/// 3 - Correct; with significant hesitation
/// 4 - Correct; with slight hesitation
/// 5 - Perfect recall
class Sm2Algorithm {
  Sm2Algorithm._();

  static const double minEaseFactor = 1.3;

  /// Calculates the next review date and updated SM-2 parameters for a flashcard.
  static FlashcardModel calculateNextReview({
    required FlashcardModel card,
    required int rating, // 0 to 5
  }) {
    assert(rating >= 0 && rating <= 5, 'Rating must be between 0 and 5');

    int repetitions = card.repetitions;
    int interval = card.interval;
    double easeFactor = card.easeFactor;

    if (rating >= 3) {
      // Successful recall
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * easeFactor).round();
      }
      repetitions += 1;
    } else {
      // Failed recall -> reset repetitions to 0 and interval to 1 day
      repetitions = 0;
      interval = 1;
    }

    // Update Easiness Factor (EF)
    // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    final q = rating;
    easeFactor = easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (easeFactor < minEaseFactor) {
      easeFactor = minEaseFactor;
    }

    final now = DateTime.now();
    final nextReview = now.add(Duration(days: interval));

    return card.copyWith(
      repetitions: repetitions,
      interval: interval,
      easeFactor: easeFactor,
      nextReviewDate: nextReview,
      lastReviewDate: now,
    );
  }

  /// Checks if a flashcard is due for review today.
  static bool isDue(FlashcardModel card) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return card.nextReviewDate.isBefore(today);
  }
}
