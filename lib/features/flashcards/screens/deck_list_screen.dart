import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/algorithms/sm2_algorithm.dart';
import '../../../core/models/flashcard_model.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/flashcard_provider.dart';

class DeckListScreen extends ConsumerStatefulWidget {
  const DeckListScreen({super.key});

  @override
  ConsumerState<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends ConsumerState<DeckListScreen> {
  bool _isStudying = false;
  bool _isFlipped = false;
  int _currentCardIdx = 0;
  FlashcardDeckModel? _selectedDeck;

  void _startStudying(FlashcardDeckModel deck) {
    if (deck.cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This deck has no flashcards yet.'),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }
    setState(() {
      _selectedDeck = deck;
      _currentCardIdx = 0;
      _isFlipped = false;
      _isStudying = true;
    });
  }

  void _rateCurrentCard(FlashcardDeckModel deck, int rating) {
    final card = deck.cards[_currentCardIdx];

    ref.read(flashcardProvider.notifier).recordCardRating(
          deckId: deck.id,
          cardId: card.id,
          rating: rating,
        );

    // Save updated deck state to Hive offline cache
    OfflineCacheService.cacheDeck(deck.id, deck.toMap());

    setState(() {
      _isFlipped = false;
      if (_currentCardIdx < deck.cards.length - 1) {
        _currentCardIdx++;
      } else {
        _isStudying = false;
        _currentCardIdx = 0;
        _selectedDeck = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Session complete! SM-2 review dates updated.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final flashState = ref.watch(flashcardProvider);
    final allDecks = flashState.decks;

    if (_isStudying && _selectedDeck != null) {
      // Find latest state of selected deck from provider
      final liveDeck = allDecks.firstWhere(
        (d) => d.id == _selectedDeck!.id,
        orElse: () => _selectedDeck!,
      );

      final cards = liveDeck.cards;
      final safeIdx = _currentCardIdx < cards.length ? _currentCardIdx : 0;
      final card = cards[safeIdx];

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: GlassAppBar(
          title: '${liveDeck.subject} (${safeIdx + 1}/${cards.length})',
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() {
              _isStudying = false;
              _selectedDeck = null;
            }),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (safeIdx + 1) / cards.length,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
                ),
              ),
              const SizedBox(height: 32),

              // Interactive Flip Card
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isFlipped = !_isFlipped),
                  child: GlassCard(
                    borderRadius: 32,
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isFlipped
                                    ? AppColors.success.withOpacity(0.2)
                                    : AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _isFlipped ? 'ANSWER (BACK)' : 'QUESTION (FRONT)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: _isFlipped ? AppColors.success : AppColors.primaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _isFlipped ? card.back : card.front,
                              textAlign: TextAlign.center,
                              style: AppTypography.headlineMedium.copyWith(height: 1.5),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              _isFlipped ? 'Tap to see question' : 'Tap to reveal answer',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // SM-2 Recall Rating Buttons
              if (_isFlipped) ...[
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        height: 44,
                        padding: EdgeInsets.zero,
                        child: const Text('Blackout (0)'),
                        onPressed: () => _rateCurrentCard(liveDeck, 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        height: 44,
                        padding: EdgeInsets.zero,
                        child: const Text('Hard (2)'),
                        onPressed: () => _rateCurrentCard(liveDeck, 2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        height: 44,
                        padding: EdgeInsets.zero,
                        child: const Text('Good (4)'),
                        onPressed: () => _rateCurrentCard(liveDeck, 4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        height: 44,
                        padding: EdgeInsets.zero,
                        isPrimary: true,
                        child: const Text('Easy (5)'),
                        onPressed: () => _rateCurrentCard(liveDeck, 5),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                GlassButton(
                  isPrimary: true,
                  width: double.infinity,
                  child: const Text('Show Answer'),
                  onPressed: () => setState(() => _isFlipped = true),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    final totalCards = allDecks.fold<int>(0, (sum, d) => sum + d.cards.length);
    final dueCards = allDecks.fold<int>(
      0,
      (sum, d) => sum + d.cards.where((c) => c.nextReviewDate.isBefore(DateTime.now())).length,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Flashcard Decks',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(20),
            surfaceGradient: const LinearGradient(
              colors: [Color(0x338B5CF6), Color(0x1A0F172A)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SuperMemo SM-2 Active', style: AppTypography.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        dueCards > 0
                            ? '$dueCards cards are due for spaced repetition review today.'
                            : 'All $totalCards cards are currently up to date! Great job.',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (allDecks.isNotEmpty)
                  GlassButton(
                    isPrimary: true,
                    child: const Text('Study Now'),
                    onPressed: () => _startStudying(allDecks.first),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('All Decks', style: AppTypography.headlineMedium),
              Text(
                '${allDecks.length} Decks',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allDecks.isEmpty)
            GlassCard(
              padding: const EdgeInsets.all(32),
              borderRadius: 20,
              child: const Center(
                child: Text(
                  'No decks created yet. Upload lecture notes or open a notebook to generate AI flashcards!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
          ...allDecks.map((deck) {
            final dueCount = deck.cards.where((c) => c.nextReviewDate.isBefore(DateTime.now())).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(18),
                borderRadius: 20,
                onTap: () => _startStudying(deck),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.style, color: AppColors.primaryLight, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deck.subject.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(deck.topic, style: AppTypography.titleLarge.copyWith(fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            dueCount > 0
                                ? '${deck.cards.length} cards • $dueCount due today'
                                : '${deck.cards.length} cards',
                            style: TextStyle(
                              fontSize: 12,
                              color: dueCount > 0 ? AppColors.warning : AppColors.textSecondary,
                              fontWeight: dueCount > 0 ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
