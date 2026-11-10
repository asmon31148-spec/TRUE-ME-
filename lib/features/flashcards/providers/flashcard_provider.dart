import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/algorithms/sm2_algorithm.dart';
import '../../../core/models/flashcard_model.dart';
import '../../../core/services/offline_cache_service.dart';

class FlashcardState {
  final List<FlashcardDeckModel> decks;
  final bool isGenerating;
  final String? error;

  const FlashcardState({
    required this.decks,
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
        super(FlashcardState(decks: _loadInitialDecks()));

  static List<FlashcardDeckModel> _loadInitialDecks() {
    try {
      final cached = OfflineCacheService.getAllCachedDecks();
      if (cached.isNotEmpty) {
        return cached
            .map((m) => FlashcardDeckModel.fromMap(m, m['id']?.toString() ?? 'deck'))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Generates a brand new high-yield deck on any topic using Gemini/Groq AI.
  Future<void> generateDeck({
    required String notebookId,
    required String subject,
    required String topic,
    required String content,
    int count = 6,
  }) async {
    state = state.copyWith(isGenerating: true, error: null);

    try {
      final promptContent = content.trim().isNotEmpty
          ? content
          : 'High-yield key concepts, formulas, definitions, and active recall questions for $subject on the topic: $topic.';

      final jsonString = await _aiRouter.generateFlashcards(
        content: promptContent,
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

      if (newCards.isEmpty) {
        // Fallback card if AI returned empty
        newCards.add(
          FlashcardModel(
            id: 'gen_${DateTime.now().millisecondsSinceEpoch}_0',
            front: 'Core concept of $topic',
            back: 'Key formulation and definitions in $subject.',
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

      // Persist to Hive
      await OfflineCacheService.cacheDeck(newDeck.id, newDeck.toMap());

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

  /// Creates a manual custom deck created by the student.
  Future<void> createCustomDeck({
    required String subject,
    required String topic,
    required List<FlashcardModel> cards,
  }) async {
    final newDeck = FlashcardDeckModel(
      id: 'deck_${DateTime.now().millisecondsSinceEpoch}',
      notebookId: 'custom',
      subject: subject,
      topic: topic,
      cards: cards,
      createdAt: DateTime.now(),
    );

    await OfflineCacheService.cacheDeck(newDeck.id, newDeck.toMap());
    state = state.copyWith(decks: [newDeck, ...state.decks]);
  }

  /// Deletes a deck from state and Hive cache.
  Future<void> deleteDeck(String deckId) async {
    await OfflineCacheService.deleteDeck(deckId);
    state = state.copyWith(
      decks: state.decks.where((d) => d.id != deckId).toList(),
    );
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

      final updated = FlashcardDeckModel(
        id: deck.id,
        notebookId: deck.notebookId,
        subject: deck.subject,
        topic: deck.topic,
        cards: updatedCards,
        createdAt: deck.createdAt,
      );

      OfflineCacheService.cacheDeck(deck.id, updated.toMap());
      return updated;
    }).toList();

    state = state.copyWith(decks: updatedDecks);
  }
}

final flashcardProvider =
    StateNotifierProvider<FlashcardNotifier, FlashcardState>((ref) {
  return FlashcardNotifier(aiRouter: ref.watch(aiRouterProvider));
});
