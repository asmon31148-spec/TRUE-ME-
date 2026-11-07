import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/algorithms/sm2_algorithm.dart';
import '../../../core/models/flashcard_model.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  bool _isStudying = false;
  bool _isFlipped = false;
  int _currentCardIdx = 0;

  final List<FlashcardModel> _sampleCards = [
    FlashcardModel(
      id: '1',
      front: 'What are the 4 Coffman conditions required for Deadlock?',
      back:
          '1. Mutual Exclusion (non-shareable resources)\n2. Hold and Wait (process holds resource while waiting for more)\n3. No Preemption (resources cannot be forcibly taken)\n4. Circular Wait (circular chain of processes waiting on each other)',
      nextReviewDate: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    FlashcardModel(
      id: '2',
      front: 'What is an Eigenvector and Eigenvalue geometrically?',
      back:
          'An eigenvector of a linear transformation is a non-zero vector whose direction does not change when that linear transformation is applied. The eigenvalue is the scalar factor by which the eigenvector is stretched or shrunk: A * v = λ * v.',
      nextReviewDate: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    FlashcardModel(
      id: '3',
      front: 'State the Principle of Least Action (Hamilton\'s Principle).',
      back:
          'The actual path taken by a physical system between two states in a given time interval is the one for which the action integral S = ∫ L dt is stationary (extremum).',
      nextReviewDate: DateTime.now().add(const Duration(days: 2)),
    ),
  ];

  void _rateCurrentCard(int rating) {
    final updatedCard = Sm2Algorithm.calculateNextReview(
      card: _sampleCards[_currentCardIdx],
      rating: rating,
    );
    _sampleCards[_currentCardIdx] = updatedCard;

    setState(() {
      _isFlipped = false;
      if (_currentCardIdx < _sampleCards.length - 1) {
        _currentCardIdx++;
      } else {
        _isStudying = false;
        _currentCardIdx = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isStudying) {
      final card = _sampleCards[_currentCardIdx];

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: GlassAppBar(
          title: 'Reviewing Card ${_currentCardIdx + 1}/${_sampleCards.length}',
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _isStudying = false),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentCardIdx + 1) / _sampleCards.length,
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
                        onPressed: () => _rateCurrentCard(0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        height: 44,
                        padding: EdgeInsets.zero,
                        child: const Text('Hard (2)'),
                        onPressed: () => _rateCurrentCard(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        height: 44,
                        padding: EdgeInsets.zero,
                        child: const Text('Good (4)'),
                        onPressed: () => _rateCurrentCard(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        height: 44,
                        padding: EdgeInsets.zero,
                        isPrimary: true,
                        child: const Text('Easy (5)'),
                        onPressed: () => _rateCurrentCard(5),
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
                        '2 cards are due for spaced repetition review today.',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                GlassButton(
                  isPrimary: true,
                  child: const Text('Study Now'),
                  onPressed: () => setState(() => _isStudying = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('All Decks', style: AppTypography.headlineMedium),
          const SizedBox(height: 12),
          _buildDeckItem(
            title: 'OS — Process Synchronization',
            cardCount: 24,
            dueCount: 2,
            subject: 'Computer Science',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _buildDeckItem(
            title: 'Calculus — Matrices & Diagonalization',
            cardCount: 30,
            dueCount: 0,
            subject: 'Calculus',
            color: AppColors.accent,
          ),
          const SizedBox(height: 12),
          _buildDeckItem(
            title: 'Physics — Hamiltonian Mechanics',
            cardCount: 18,
            dueCount: 0,
            subject: 'Physics',
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildDeckItem({
    required String title,
    required int cardCount,
    required int dueCount,
    required String subject,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      onTap: () => setState(() => _isStudying = true),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.style, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(title, style: AppTypography.titleLarge.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  dueCount > 0 ? '$cardCount cards • $dueCount due today' : '$cardCount cards',
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
    );
  }
}
