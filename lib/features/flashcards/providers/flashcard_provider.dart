import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/algorithms/sm2_algorithm.dart';
import '../../../core/models/flashcard_model.dart';

class FlashcardState {
  final List<FlashcardDeckModel> decks;
  final bool isGenerating;
  final String? error;

  const FlashcardState({
    this.decks = const [],
    this.isGenerating = false,
    this.error,
  });

  FlashcardState copyWith({
    List<FlashcardDeckModel>? decks,
    bool? isGenerating,
    String? error,
  }) {
    return FlashcardState(
      decks: decks ?? this.decks,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
    );
  }
}

class FlashcardNotifier extends StateNotifier<FlashcardState> {
  final AiRouter _aiRouter;

  FlashcardNotifier({required AiRouter aiRouter})
      : _aiRouter = aiRouter,
        super(
          FlashcardState(
            decks: [
              FlashcardDeckModel(
                id: 'deck_1',
                notebookId: '1',
                subject: 'Computer Science',
                topic: 'OS — Process Synchronization',
                createdAt: DateTime.now().subtract(const Duration(days: 3)),
                cards: [
                  FlashcardModel(
                    id: 'c1',
                    front: 'What are the 4 Coffman conditions required for Deadlock?',
                    back:
                        '1. Mutual Exclusion\n2. Hold and Wait\n3. No Preemption\n4. Circular Wait',
                    easeFactor: 2.5,
                    interval: 1,
                    repetitions: 2,
                    nextReviewDate: DateTime.now().subtract(const Duration(hours: 3)),
                  ),
                  FlashcardModel(
                    id: 'c2',
                    front: 'What is the distinction between a Mutex and a Binary Semaphore?',
                    back:
                        'A Mutex has an ownership mechanism (only the thread that locked it can unlock it). A Binary Semaphore has no ownership and can be signaled by any thread.',
                    easeFactor: 2.3,
                    interval: 3,
                    repetitions: 3,
                    nextReviewDate: DateTime.now().add(const Duration(days: 2)),
                  ),
                ],
              ),
            ],
          ),
        );

  /// Generates a brand new high-yield deck from lecture notes using Groq LLaMA 8B.
  Future<void> generateDeck({
    required String notebookId,
    required String subject,
    required String topic,
    required String content,
    int count = 10,
  }) async {
    state = state.copyWith(isGenerating: true, error: null);

    try {
      final jsonString = await _aiRouter.generateFlashcards(
        content: content,
        count: count,
      );

      final Map<String, dynamic> data = jsonDecode(jsonString);
      final rawCards = data['cards'] as List<dynamic>? ?? [];

      final List<FlashcardModel> newCards = [];
      for (int i = 0; i < rawCards.length; i++) {
        final c = rawCards[i];
        final front = c['front'] as String? ?? 'Concept';
        final back = c['back'] as String? ?? 'Definition';

        newCards.add(
          FlashcardModel(
            id: 'gen_${DateTime.now().millisecondsSinceEpoch}_$i',
            front: front,
            back: back,
            imageUrl: _aiRouter.generateImageUrl(front),
            nextReviewDate: DateTime.now(),
          ),
        );
      }

      final newDeck = FlashcardDeckModel(
        id: 'deck_${DateTime.now().millisecondsSinceEpoch}',
        notebookId: notebookId,
        subject: subject,
        topic: topic,
        cards: newCards,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        decks: [newDeck, ...state.decks],
        isGenerating: false,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  /// Rates a card and applies SuperMemo SM-2 algorithm to reschedule review.
  void recordCardRating({
    required String deckId,
    required String cardId,
    required int rating, // 0 to 5
  }) {
    final updatedDecks = state.decks.map((deck) {
      if (deck.id != deckId) return deck;

      final updatedCards = deck.cards.map((card) {
        if (card.id != cardId) return card;
        return Sm2Algorithm.calculateNextReview(card: card, rating: rating);
      }).toList();

      return FlashcardDeckModel(
        id: deck.id,
        notebookId: deck.notebookId,
        subject: deck.subject,
        topic: deck.topic,
        cards: updatedCards,
        createdAt: deck.createdAt,
      );
    }).toList();

    state = state.copyWith(decks: updatedDecks);
  }
}

final flashcardProvider =
    StateNotifierProvider<FlashcardNotifier, FlashcardState>((ref) {
  return FlashcardNotifier(aiRouter: ref.watch(aiRouterProvider));
});
