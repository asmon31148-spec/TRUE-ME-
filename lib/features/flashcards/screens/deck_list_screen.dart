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

  void _showGenerateDeckDialog() {
    final topicController = TextEditingController();
    final userSubjects = OfflineCacheService.getUserSubjects();
    String selectedSubject = userSubjects.isNotEmpty ? userSubjects.first : 'General';
    bool isGeneratingLocal = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.accentCyan, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Generate AI Deck', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Subject', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSubject,
                        dropdownColor: AppColors.surface,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        items: userSubjects.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedSubject = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Topic / Chapter Concept', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: topicController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Mitosis & Meiosis, Thermodynamics...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (isGeneratingLocal) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppColors.accentCyan),
                          SizedBox(height: 10),
                          Text('Sage AI is creating active recall cards...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: isGeneratingLocal
                    ? null
                    : () async {
                        final topic = topicController.text.trim();
                        if (topic.isEmpty) return;

                        setDialogState(() => isGeneratingLocal = true);
                        try {
                          await ref.read(flashcardProvider.notifier).generateDeck(
                                notebookId: 'nb_custom',
                                subject: selectedSubject,
                                topic: topic,
                                content: 'Key definitions and high-yield questions on $topic in $selectedSubject',
                                count: 6,
                              );
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🎉 Sage generated a new deck for "$topic"!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isGeneratingLocal = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      },
                child: const Text('Generate with Sage', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteDeck(FlashcardDeckModel deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Deck', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${deck.topic}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref.read(flashcardProvider.notifier).deleteDeck(deck.id);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flashState = ref.watch(flashcardProvider);
    final allDecks = flashState.decks;

    if (_isStudying && _selectedDeck != null) {
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: _isFlipped ? AppColors.surface : AppColors.surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: _isFlipped
                            ? AppColors.primary.withOpacity(0.4)
                            : Colors.white.withOpacity(0.1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isFlipped
                              ? AppColors.primary.withOpacity(0.15)
                              : Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isFlipped ? 'ANSWER (BACK)' : 'QUESTION (FRONT)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Text(
                                _isFlipped ? card.back : card.front,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app, size: 16, color: Colors.white.withOpacity(0.4)),
                            const SizedBox(width: 6),
                            Text(
                              _isFlipped ? 'Tap to see question' : 'Tap to reveal answer',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Rating Buttons
              if (_isFlipped) ...[
                const Text(
                  'How well did you know this concept?',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        surfaceColor: AppColors.error.withOpacity(0.2),
                        borderColor: AppColors.error.withOpacity(0.4),
                        child: const Text('Again (1)', style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: () => _rateCurrentCard(liveDeck, 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        surfaceColor: AppColors.warning.withOpacity(0.2),
                        borderColor: AppColors.warning.withOpacity(0.4),
                        child: const Text('Hard (2)', style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: () => _rateCurrentCard(liveDeck, 2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        surfaceColor: AppColors.primary.withOpacity(0.3),
                        borderColor: AppColors.primaryLight.withOpacity(0.4),
                        child: const Text('Good (3)', style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: () => _rateCurrentCard(liveDeck, 3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        surfaceColor: AppColors.success.withOpacity(0.2),
                        borderColor: AppColors.success.withOpacity(0.4),
                        child: const Text('Easy (5)', style: TextStyle(color: Colors.white, fontSize: 12)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.accentCyan),
            tooltip: 'Generate AI Deck',
            onPressed: _showGenerateDeckDialog,
          ),
        ],
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
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16, color: AppColors.accentCyan),
                label: const Text('New Deck', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                onPressed: _showGenerateDeckDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allDecks.isEmpty)
            GlassCard(
              padding: const EdgeInsets.all(32),
              borderRadius: 20,
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.style_outlined, size: 48, color: Colors.white38),
                    const SizedBox(height: 12),
                    const Text('No decks created yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Tap "New Deck" to generate AI active recall cards on any topic.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 16),
                    GlassButton(
                      isPrimary: true,
                      child: const Text('Generate First Deck'),
                      onPressed: _showGenerateDeckDialog,
                    ),
                  ],
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white38),
                      tooltip: 'Delete Deck',
                      onPressed: () => _confirmDeleteDeck(deck),
                    ),
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
