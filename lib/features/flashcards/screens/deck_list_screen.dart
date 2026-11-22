import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/algorithms/sm2_algorithm.dart';
import '../../../core/models/flashcard_model.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/stem_formula_formatter.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/generation_progress_view.dart';
import '../providers/flashcard_provider.dart';

class DeckListScreen extends ConsumerStatefulWidget {
  final String? notebookId;
  final String? initialSubject;

  const DeckListScreen({
    super.key,
    this.notebookId,
    this.initialSubject,
  });

  @override
  ConsumerState<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends ConsumerState<DeckListScreen> {
  final TtsService _tts = TtsService();
  bool _isSpeaking = false;
  FlashcardDeckModel? _activeDeck;
  List<FlashcardModel> _sessionCards = [];
  final Set<String> _requeuedCardIds = {};
  int _cardIndex = 0;
  bool _isFlipped = false;
  int _reviewedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(flashcardProvider.notifier).refreshFromCache();
      }
    });
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _speakCurrentCard() async {
    if (_activeDeck == null || _sessionCards.isEmpty) return;
    final card = _sessionCards[_cardIndex];
    final rawText = _isFlipped ? card.back : card.front;
    final cleanText = StemFormulaFormatter.format(rawText);

    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      if (mounted) setState(() => _isSpeaking = true);
      await _tts.speak(cleanText);
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  void _showEditCardDialog(FlashcardModel card) {
    if (_activeDeck == null) return;
    final frontCtrl = TextEditingController(text: card.front);
    final backCtrl = TextEditingController(text: card.back);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note, color: context.accentColor, size: 22),
            const SizedBox(width: 8),
            const Text('Edit card', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInput(
                label: 'Question (Front)',
                hintText: 'Enter question, term, or formula',
                controller: frontCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              AppInput(
                label: 'Answer (Back)',
                hintText: 'Enter answer or key explanation',
                controller: backCtrl,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newFront = frontCtrl.text.trim();
              final newBack = backCtrl.text.trim();
              if (newFront.isEmpty || newBack.isEmpty) return;

              Navigator.pop(ctx);

              await ref.read(flashcardProvider.notifier).updateCard(
                    deckId: _activeDeck!.id,
                    cardId: card.id,
                    front: newFront,
                    back: newBack,
                  );

              if (mounted) {
                setState(() {
                  _sessionCards[_cardIndex] = card.copyWith(
                    front: newFront,
                    back: newBack,
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card updated successfully')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _previewInterval(FlashcardModel card, int rating) {
    final days = Sm2Algorithm.calculateNextReview(card: card, rating: rating).interval;
    return '${days}d';
  }

  void _startDeck(FlashcardDeckModel deck, {bool onlyDue = false}) {
    final now = DateTime.now().add(const Duration(minutes: 5));
    final due = deck.cards.where((c) => c.nextReviewDate.isBefore(now)).toList();
    final cardsToStudy = onlyDue && due.isNotEmpty ? due : deck.cards;

    if (cardsToStudy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This deck has no cards yet.')),
      );
      return;
    }

    _tts.stop();
    setState(() {
      _isSpeaking = false;
      _activeDeck = deck;
      _sessionCards = List<FlashcardModel>.from(cardsToStudy);
      _requeuedCardIds.clear();
      _cardIndex = 0;
      _isFlipped = false;
      _reviewedCount = 0;
    });
  }

  void _startAllDue(List<FlashcardDeckModel> decks) {
    final now = DateTime.now().add(const Duration(minutes: 5));
    for (final d in decks) {
      if (d.cards.any((c) => c.nextReviewDate.isBefore(now))) {
        _startDeck(d, onlyDue: true);
        return;
      }
    }
    if (decks.isNotEmpty) {
      _startDeck(decks.first);
    }
  }

  void _rateCard(int sm2Rating) {
    if (_activeDeck == null) return;
    _tts.stop();
    _isSpeaking = false;
    final card = _sessionCards[_cardIndex];
    ref.read(flashcardProvider.notifier).recordCardRating(
          deckId: _activeDeck!.id,
          cardId: card.id,
          rating: sm2Rating,
        );

    if (sm2Rating == 0 && !_requeuedCardIds.contains(card.id)) {
      _requeuedCardIds.add(card.id);
      _sessionCards.add(card);
    } else {
      _reviewedCount++;
    }

    if (_cardIndex < _sessionCards.length - 1) {
      setState(() {
        _cardIndex++;
        _isFlipped = false;
      });
    } else {
      final finishedDeck = _activeDeck!;
      final count = _reviewedCount;
      OfflineCacheService.logStudySession(
        activity: 'flashcards',
        subject: finishedDeck.subject,
        title: finishedDeck.topic,
        subtitle: '$count ${count == 1 ? 'card' : 'cards'} reviewed',
        minutes: (count * 0.5).ceil().clamp(2, 30),
      );
      setState(() {
        _activeDeck = null;
        _sessionCards = [];
        _requeuedCardIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reviewed $count cards in "${finishedDeck.topic}"')),
      );
    }
  }

  void _showGenerateDeckSheet() {
    final notebooks = OfflineCacheService.getAllCachedNotebooks();
    String? selectedNbId = widget.notebookId ??
        (notebooks.isNotEmpty ? notebooks.first['id'] as String : null);
    final customSubjectCtrl = TextEditingController(text: widget.initialSubject ?? '');
    final topicCtrl = TextEditingController();
    int count = 10;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Generate deck with Sage', style: AppTypography.sectionHeading),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),

                if (notebooks.isNotEmpty) ...[
                  const Text('Subject / Notebook', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor, width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedNbId,
                        isExpanded: true,
                        dropdownColor: context.surfaceColor,
                        items: [
                          ...notebooks.map((n) {
                            return DropdownMenuItem<String?>(
                              value: n['id'] as String,
                              child: Text(n['title'] as String? ?? 'Subject'),
                            );
                          }),
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Custom subject'),
                          ),
                        ],
                        onChanged: (v) => setSheetState(() => selectedNbId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (selectedNbId == null) ...[
                  AppInput(
                    label: 'Subject',
                    hintText: 'e.g. Calculus, History...',
                    controller: customSubjectCtrl,
                  ),
                  const SizedBox(height: 16),
                ],

                AppInput(
                  label: 'Topic',
                  hintText: 'e.g. Chapter 3 definitions, key formulas',
                  controller: topicCtrl,
                ),
                const SizedBox(height: 16),
                const Text('Number of cards', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [5, 10, 15].map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppChip(
                        label: '$c cards',
                        isSelected: count == c,
                        onTap: () => setSheetState(() => count = c),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Generate deck',
                  onPressed: () async {
                    String subjectName = customSubjectCtrl.text.trim();
                    String sourceText = '';
                    if (selectedNbId != null) {
                      final nb = OfflineCacheService.getCachedNotebook(selectedNbId!);
                      subjectName = nb?['title'] as String? ?? 'Study';
                      sourceText = OfflineCacheService.getNotebookCombinedText(selectedNbId!, maxChars: 14000);
                    }
                    if (subjectName.isEmpty) subjectName = 'General Study';
                    final topic = topicCtrl.text.trim().isNotEmpty ? topicCtrl.text.trim() : '$subjectName Review';

                    Navigator.pop(ctx);

                    await ref.read(flashcardProvider.notifier).generateDeck(
                          notebookId: selectedNbId ?? 'custom',
                          subject: subjectName,
                          topic: topic,
                          content: sourceText,
                          count: count,
                        );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateManualSheet() {
    final subjectCtrl = TextEditingController(text: widget.initialSubject ?? '');
    final topicCtrl = TextEditingController();
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Create flashcard', style: AppTypography.sectionHeading),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              AppInput(label: 'Subject', hintText: 'e.g. Biology', controller: subjectCtrl),
              const SizedBox(height: 12),
              AppInput(label: 'Deck title', hintText: 'e.g. Cell Division', controller: topicCtrl),
              const SizedBox(height: 12),
              AppInput(label: 'Question (Front)', hintText: 'Enter question...', controller: frontCtrl),
              const SizedBox(height: 12),
              AppInput(label: 'Answer (Back)', hintText: 'Enter answer...', controller: backCtrl),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: 'Save card',
                onPressed: () async {
                  if (frontCtrl.text.trim().isEmpty || backCtrl.text.trim().isEmpty) return;
                  final sub = subjectCtrl.text.trim().isNotEmpty ? subjectCtrl.text.trim() : 'General';
                  final top = topicCtrl.text.trim().isNotEmpty ? topicCtrl.text.trim() : '$sub Cards';
                  await ref.read(flashcardProvider.notifier).createCustomDeck(
                    subject: sub,
                    topic: top,
                    cards: [
                      FlashcardModel(
                        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                        front: frontCtrl.text.trim(),
                        back: backCtrl.text.trim(),
                        nextReviewDate: DateTime.now(),
                      ),
                    ],
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flashState = ref.watch(flashcardProvider);
    final decks = flashState.decks;

    // 1. Active Study Session View
    if (_activeDeck != null && _sessionCards.isNotEmpty) {
      final card = _sessionCards[_cardIndex.clamp(0, _sessionCards.length - 1)];
      final total = _sessionCards.length;

      return Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: () {
              _tts.stop();
              setState(() {
                _isSpeaking = false;
                _activeDeck = null;
              });
            },
          ),
          title: Text(
            'Card ${_cardIndex + 1} of $total',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.textPrimary),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                color: _isSpeaking ? context.accentColor : context.textPrimary,
              ),
              tooltip: _isSpeaking ? 'Stop audio' : 'Listen with Speech',
              onPressed: _speakCurrentCard,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit card',
              onPressed: () => _showEditCardDialog(card),
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: AppProgressBar(value: (_cardIndex + 1) / total),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: GestureDetector(
                    onTap: () {
                      _tts.stop();
                      setState(() {
                        _isSpeaking = false;
                        _isFlipped = !_isFlipped;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.borderColor, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(context.isDarkMode ? 0.35 : 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          key: ValueKey(_isFlipped),
                          children: [
                            // Card Type Indicator Chip
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_isFlipped ? context.accentColor : const Color(0xFF6366F1)).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (_isFlipped ? context.accentColor : const Color(0xFF6366F1)).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isFlipped ? Icons.check_circle_outline_rounded : Icons.help_outline_rounded,
                                        size: 13,
                                        color: _isFlipped ? context.accentColor : const Color(0xFF6366F1),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _isFlipped ? 'ANSWER' : 'QUESTION',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: _isFlipped ? context.accentColor : const Color(0xFF6366F1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Card Body Content
                            SingleChildScrollView(
                              child: Text(
                                StemFormulaFormatter.format(_isFlipped ? card.back : card.front),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _isFlipped ? 17 : 20,
                                  fontWeight: _isFlipped ? FontWeight.w500 : FontWeight.w600,
                                  color: context.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Hint
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.touch_app_outlined, size: 14, color: context.textSecondary.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  _isFlipped ? 'Tap to see question' : 'Tap to reveal answer',
                                  style: AppTypography.smallLabel.copyWith(
                                    color: context.textSecondary.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: context.bgColor,
                  border: Border(top: BorderSide(color: context.borderColor, width: 1)),
                ),
                child: !_isFlipped
                    ? AppPrimaryButton(
                        label: 'Show answer',
                        onPressed: () => setState(() => _isFlipped = true),
                      )
                    : Row(
                        children: [
                          _buildIntervalButton(
                            'Again',
                            _requeuedCardIds.contains(card.id) ? '1d' : '< 1m',
                            const Color(0xFFEF4444),
                            () => _rateCard(0),
                          ),
                          const SizedBox(width: 8),
                          _buildIntervalButton('Hard', _previewInterval(card, 3), const Color(0xFFF59E0B), () => _rateCard(3)),
                          const SizedBox(width: 8),
                          _buildIntervalButton('Good', _previewInterval(card, 4), const Color(0xFF3B82F6), () => _rateCard(4)),
                          const SizedBox(width: 8),
                          _buildIntervalButton('Easy', _previewInterval(card, 5), const Color(0xFF10B981), () => _rateCard(5)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Deck List View
    final now = DateTime.now().add(const Duration(minutes: 5));
    int totalDue = 0;
    for (final d in decks) {
      totalDue += d.cards.where((c) => c.nextReviewDate.isBefore(now)).length;
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Flashcards', style: AppTypography.screenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 24),
            tooltip: 'Create card manually',
            onPressed: _showCreateManualSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            if (flashState.isGenerating) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: GenerationProgressView(
                  compact: true,
                  title: 'Generating flashcards with Sage',
                  stages: [
                    'Extracting key concepts...',
                    'Creating active-recall Q&A cards...',
                    'Scheduling SM-2 intervals...',
                    'Almost ready...',
                  ],
                ),
              ),
            ],

            if (flashState.error != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        flashState.error!,
                        style: const TextStyle(fontSize: 13, color: AppColors.error),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                      onPressed: () => ref.read(flashcardProvider.notifier).clearError(),
                    ),
                  ],
                ),
              ),
            ],

            if (decks.isEmpty && !flashState.isGenerating) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: AppEmptyState(
                  icon: Icons.style_outlined,
                  message: 'No flashcard decks yet. Generate a deck from your notes with Sage or add cards manually.',
                  buttonLabel: 'Generate deck with Sage',
                  onButtonPressed: _showGenerateDeckSheet,
                ),
              ),
            ] else ...[
              // Due Today Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            totalDue > 0 ? 'Due today: $totalDue' : 'All caught up!',
                            style: AppTypography.sectionHeading,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${decks.length} ${decks.length == 1 ? 'deck' : 'decks'} in your library',
                            style: AppTypography.secondary,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: AppPrimaryButton(
                        label: totalDue > 0 ? 'Study now' : 'Review',
                        onPressed: () => _startAllDue(decks),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('Decks', style: AppTypography.sectionHeading),
              const SizedBox(height: 10),

              ...decks.map((deck) {
                final dueCount = deck.cards.where((c) => c.nextReviewDate.isBefore(now)).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppListRow(
                    title: deck.topic,
                    subtitle: '${deck.subject} • ${deck.cards.length} cards ($dueCount due)',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: context.textSecondary),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Deck?'),
                                content: Text('Are you sure you want to delete "${deck.topic}"? This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              ref.read(flashcardProvider.notifier).deleteDeck(deck.id);
                            }
                          },
                        ),
                        Icon(Icons.chevron_right, size: 18, color: context.textSecondary),
                      ],
                    ),
                    onTap: () => _startDeck(deck),
                  ),
                );
              }),
              const SizedBox(height: 16),

              AppSecondaryButton(
                label: 'Generate deck with Sage',
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                onPressed: _showGenerateDeckSheet,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalButton(String label, String interval, Color accent, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: accent.withOpacity(context.isDarkMode ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                interval,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: accent.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
