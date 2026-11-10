import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/models/flashcard_model.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
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
  FlashcardDeckModel? _activeDeck;
  List<FlashcardModel> _sessionCards = [];
  int _cardIndex = 0;
  bool _isFlipped = false;
  int _reviewedCount = 0;

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

    setState(() {
      _activeDeck = deck;
      _sessionCards = List<FlashcardModel>.from(cardsToStudy);
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
    final card = _sessionCards[_cardIndex];
    ref.read(flashcardProvider.notifier).recordCardRating(
          deckId: _activeDeck!.id,
          cardId: card.id,
          rating: sm2Rating,
        );

    _reviewedCount++;

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
            onPressed: () => setState(() => _activeDeck = null),
          ),
          title: Text(
            'Card ${_cardIndex + 1} of $total',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.textPrimary),
          ),
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
                    onTap: () => setState(() => _isFlipped = !_isFlipped),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor, width: 1),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          key: ValueKey(_isFlipped),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isFlipped ? 'ANSWER' : 'QUESTION',
                              style: AppTypography.smallLabel.copyWith(
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w600,
                                color: _isFlipped ? context.accentColor : context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              child: Text(
                                _isFlipped ? card.back : card.front,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _isFlipped ? 17 : 20,
                                  fontWeight: _isFlipped ? FontWeight.w400 : FontWeight.w600,
                                  color: context.textPrimary,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            if (!_isFlipped) ...[
                              const SizedBox(height: 24),
                              Text('Tap card to reveal answer', style: AppTypography.smallLabel),
                            ],
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
                          _buildIntervalButton('Again', '< 1m', () => _rateCard(0)),
                          const SizedBox(width: 8),
                          _buildIntervalButton('Hard', '1d', () => _rateCard(2)),
                          const SizedBox(width: 8),
                          _buildIntervalButton('Good', '3d', () => _rateCard(4)),
                          const SizedBox(width: 8),
                          _buildIntervalButton('Easy', '6d', () => _rateCard(5)),
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
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.accentColor),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.accentColor)),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Sage is generating flashcards from your notes...',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
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
                          onPressed: () => ref.read(flashcardProvider.notifier).deleteDeck(deck.id),
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

  Widget _buildIntervalButton(String label, String interval, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.borderColor, width: 1),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
              const SizedBox(height: 2),
              Text(interval, style: TextStyle(fontSize: 11, color: context.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
