import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../../shared/widgets/true_me_illustrations.dart';
import '../../../shared/widgets/true_me_ui.dart';
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

class _DeckListScreenState extends ConsumerState<DeckListScreen> with SingleTickerProviderStateMixin {
  final TtsService _tts = TtsService();
  bool _isSpeaking = false;
  FlashcardDeckModel? _activeDeck;
  List<FlashcardModel> _sessionCards = [];
  final Set<String> _requeuedCardIds = {};
  int _cardIndex = 0;
  bool _isFlipped = false;
  int _reviewedCount = 0;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(flashcardProvider.notifier).refreshFromCache();
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _tts.dispose();
    super.dispose();
  }

  void _toggleCardFlip() {
    _tts.stop();
    HapticFeedback.lightImpact();
    setState(() {
      _isSpeaking = false;
      _isFlipped = !_isFlipped;
    });
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
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
        title: const Text('Edit Flashcard', style: AppTypography.sectionHeading),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(92, 42)),
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
            child: const Text('Save'),
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
    _flipController.reset();
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

    final updatedCard = Sm2Algorithm.calculateNextReview(card: card, rating: sm2Rating);

    if (sm2Rating == 0 && !_requeuedCardIds.contains(card.id)) {
      _requeuedCardIds.add(card.id);
      _sessionCards.add(updatedCard);
    } else {
      _reviewedCount++;
    }

    _flipController.reset();
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

  void _showDeckSwitcherSheet(List<FlashcardDeckModel> decks) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Switch Flashcard Deck', style: AppTypography.sectionHeading),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: decks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = decks[i];
                    final isCurrent = _activeDeck?.id == d.id;
                    return AppListRow(
                      leading: AppIconBadge(icon: Icons.style_rounded, color: context.accentColor),
                      title: d.topic,
                      subtitle: '${d.subject} · ${d.cards.length} cards',
                      trailing: isCurrent
                          ? Icon(Icons.check_circle_rounded, color: context.accentColor)
                          : Icon(Icons.play_arrow_rounded, color: context.textSecondary),
                      onTap: () {
                        Navigator.pop(ctx);
                        _startDeck(d);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Generate Deck with Sage', style: AppTypography.sectionHeading),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                if (notebooks.isNotEmpty) ...[
                  const Text('Subject / Notebook', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: context.bgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
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
                    hintText: 'e.g. Calculus, Microbiology...',
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
                const Text('Number of Cards', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                TrueMePrimaryButton(
                  label: 'Generate Deck',
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
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Create Flashcard', style: AppTypography.sectionHeading),
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
              TrueMePrimaryButton(
                label: 'Save Card',
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
    final isDark = context.isDarkMode;
    final flashState = ref.watch(flashcardProvider);
    final decks = flashState.decks;

    // 1. Active Flashcard Session matching Reference Image 4 Left
    if (_activeDeck != null && _sessionCards.isNotEmpty) {
      final card = _sessionCards[_cardIndex.clamp(0, _sessionCards.length - 1)];
      final total = _sessionCards.length;
      final pastel = SubjectPastelStyle.forSubject(_activeDeck!.subject, isDark: isDark);

      return Scaffold(
        backgroundColor: context.bgColor,
        body: TrueMeAmbientBackground(
          child: SafeArea(
            child: Column(
              children: [
                TrueMeTopBar(
                  title: 'Flashcards',
                  onBack: () {
                    _tts.stop();
                    setState(() {
                      _isSpeaking = false;
                      _activeDeck = null;
                    });
                  },
                  trailing: TrueMeCircleIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit current card',
                    size: 40,
                    onPressed: () => _showEditCardDialog(card),
                  ),
                ),

                // Deck Selector Dropdown Card with 3D Stacked Deck Emblem
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: TrueMeCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () => _showDeckSwitcherSheet(decks),
                    child: Row(
                      children: [
                        StackedDeckEmblem(accentColor: pastel.accent, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _activeDeck!.topic,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                              Text(
                                '$total ${total == 1 ? 'card' : 'cards'} · ${_activeDeck!.subject}',
                                style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: context.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Progress Tracker Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_cardIndex + 1} / $total',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppProgressBar(value: (_cardIndex + 1) / total),
                    ],
                  ),
                ),

                // Centered 3D Flippable Card
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    child: _build3dFlippableCard(card),
                  ),
                ),

                // Bottom Pastel SM-2 Rating Cards + Next Card Soft Pill
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Column(
                    children: [
                      if (!_isFlipped)
                        TrueMePrimaryButton(
                          label: 'Reveal Answer',
                          onPressed: _toggleCardFlip,
                        )
                      else ...[
                        Row(
                          children: [
                            _Sm2RatingTile(
                              label: 'Again',
                              interval: _requeuedCardIds.contains(card.id) ? '1d' : '< 1m',
                              icon: Icons.close_rounded,
                              bgStart: isDark ? const Color(0xFF321822) : const Color(0xFFFFF1F3),
                              bgEnd: isDark ? const Color(0xFF3F1D2B) : const Color(0xFFFFE2E6),
                              accentColor: isDark ? AppColors.darkError : AppColors.error,
                              onTap: () => _rateCard(0),
                            ),
                            const SizedBox(width: 8),
                            _Sm2RatingTile(
                              label: 'Hard',
                              interval: _previewInterval(card, 3),
                              icon: Icons.sentiment_neutral_rounded,
                              bgStart: isDark ? const Color(0xFF2B2110) : const Color(0xFFFFFAEB),
                              bgEnd: isDark ? const Color(0xFF382A14) : const Color(0xFFFEF0CE),
                              accentColor: isDark ? AppColors.darkWarning : AppColors.pastelAmberInk,
                              onTap: () => _rateCard(3),
                            ),
                            const SizedBox(width: 8),
                            _Sm2RatingTile(
                              label: 'Good',
                              interval: _previewInterval(card, 4),
                              icon: Icons.check_rounded,
                              bgStart: isDark ? const Color(0xFF0E2922) : const Color(0xFFF0FDF5),
                              bgEnd: isDark ? const Color(0xFF13362C) : const Color(0xFFDCFCE7),
                              accentColor: isDark ? AppColors.darkSuccess : AppColors.pastelGreenInk,
                              onTap: () => _rateCard(4),
                            ),
                            const SizedBox(width: 8),
                            _Sm2RatingTile(
                              label: 'Easy',
                              interval: _previewInterval(card, 5),
                              icon: Icons.star_rounded,
                              bgStart: isDark ? AppColors.darkAccentWash : const Color(0xFFF4F1FF),
                              bgEnd: isDark ? const Color(0xFF2D2B59) : const Color(0xFFE7E2FC),
                              accentColor: context.accentColor,
                              onTap: () => _rateCard(5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TrueMeTonalPill(
                            label: 'Next Card  ->',
                            backgroundColor: isDark ? AppColors.darkAccentWash : AppColors.milkyLavender,
                            foregroundColor: context.accentColor,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            onTap: () => _rateCard(4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. Deck Library View
    final now = DateTime.now().add(const Duration(minutes: 5));
    int totalDue = 0;
    for (final d in decks) {
      totalDue += d.cards.where((c) => c.nextReviewDate.isBefore(now)).length;
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              TrueMeTopBar(
                title: 'Flashcards',
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/practice');
                  }
                },
                trailing: TrueMeCircleIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Create manual card',
                  size: 40,
                  onPressed: _showCreateManualSheet,
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  children: [
                    if (flashState.isGenerating)
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

                    if (flashState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TrueMeCard(
                          borderColor: AppColors.error.withValues(alpha: 0.4),
                          color: isDark ? const Color(0xFF321822) : AppColors.pastelRose,
                          padding: const EdgeInsets.all(14),
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
                      ),

                    if (decks.isEmpty && !flashState.isGenerating)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: AppEmptyState(
                          icon: Icons.style_outlined,
                          message:
                              'No flashcard decks yet. Generate a deck from your notes with Sage or add cards manually.',
                          buttonLabel: 'Generate Deck with Sage',
                          onButtonPressed: _showGenerateDeckSheet,
                        ),
                      )
                    else ...[
                      // Due Today Hero Card
                      TrueMeCard(
                        borderRadius: 22,
                        padding: const EdgeInsets.all(18),
                        gradient: isDark ? AppColors.heroFocusDarkGradient : AppColors.heroFocusLightGradient,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    totalDue > 0 ? '$totalDue Cards Due' : 'All Caught Up!',
                                    style: AppTypography.sectionHeading.copyWith(
                                      fontSize: 21,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${decks.length} ${decks.length == 1 ? 'deck' : 'decks'} ready for review',
                                    style: AppTypography.secondary.copyWith(color: context.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 124,
                              child: TrueMePrimaryButton(
                                label: totalDue > 0 ? 'Study Now' : 'Review',
                                height: 44,
                                onPressed: () => _startAllDue(decks),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      TrueMeSectionHeader(
                        title: 'Your Decks',
                        actionLabel: 'Generate New',
                        onActionTap: _showGenerateDeckSheet,
                      ),
                      const SizedBox(height: 12),

                      ...decks.map((deck) {
                        final dueCount = deck.cards.where((c) => c.nextReviewDate.isBefore(now)).length;
                        final pastel = SubjectPastelStyle.forSubject(deck.subject, isDark: isDark);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppListRow(
                            leading: AppIconBadge(
                              icon: pastel.icon,
                              color: pastel.accent,
                              backgroundColor: pastel.bgEnd,
                            ),
                            title: deck.topic,
                            subtitle: '${deck.subject} · ${deck.cards.length} cards ($dueCount due)',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 19, color: context.textSecondary),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Deck?'),
                                        content: Text(
                                            'Are you sure you want to delete "${deck.topic}"? This cannot be undone.'),
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
                                Icon(Icons.chevron_right_rounded, size: 20, color: context.textSecondary),
                              ],
                            ),
                            onTap: () => _startDeck(deck),
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                      TrueMePrimaryButton(
                        label: 'Generate Deck with Sage',
                        leadingIcon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                        onPressed: _showGenerateDeckSheet,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3dFlippableCard(FlashcardModel card) {
    return GestureDetector(
      onTap: _toggleCardFlip,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, _) {
          final angle = _flipAnimation.value;
          final isBack = angle > (math.pi / 2);

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildCardFace(card, isAnswer: true),
                  )
                : _buildCardFace(card, isAnswer: false),
          );
        },
      ),
    );
  }

  Widget _buildCardFace(FlashcardModel card, {required bool isAnswer}) {
    final text = isAnswer ? card.back : card.front;
    final badgeLabel = isAnswer ? 'ANSWER' : 'QUESTION';
    final badgeColor = isAnswer ? AppColors.success : context.accentColor;

    return TrueMeCard(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TrueMeTonalPill(
                label: badgeLabel,
                backgroundColor: badgeColor.withValues(alpha: 0.12),
                foregroundColor: badgeColor,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              ),
              TrueMeCircleIconButton(
                icon: _isSpeaking ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                iconColor: _isSpeaking ? badgeColor : context.textSecondary,
                size: 40,
                onPressed: _speakCurrentCard,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final formatted = StemFormulaFormatter.format(text);
                final len = formatted.length;
                final double adaptiveFontSize = isAnswer
                    ? (len <= 90 ? 19.0 : (len <= 200 ? 16.5 : (len <= 380 ? 15.0 : 13.5)))
                    : (len <= 90 ? 22.0 : (len <= 180 ? 19.0 : 16.5));
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          formatted,
                          textAlign: TextAlign.center,
                          style: isAnswer
                              ? AppTypography.body.copyWith(
                                  fontSize: adaptiveFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: context.textPrimary,
                                  height: 1.45,
                                )
                              : AppTypography.sectionHeading.copyWith(
                                  fontSize: adaptiveFontSize,
                                  color: context.textPrimary,
                                  height: 1.32,
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sync_rounded, size: 15, color: context.textSecondary),
              const SizedBox(width: 6),
              Text(
                isAnswer ? 'Tap to see question' : 'Tap to flip',
                style: AppTypography.smallLabel.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sm2RatingTile extends StatelessWidget {
  final String label;
  final String interval;
  final IconData icon;
  final Color bgStart;
  final Color bgEnd;
  final Color accentColor;
  final VoidCallback onTap;

  const _Sm2RatingTile({
    required this.label,
    required this.interval,
    required this.icon,
    required this.bgStart,
    required this.bgEnd,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TrueMeCard(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgStart, bgEnd],
        ),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            Text(
              interval,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
