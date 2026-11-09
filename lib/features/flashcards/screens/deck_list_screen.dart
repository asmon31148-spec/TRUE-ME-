import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  bool _isStudying = false;
  int _cardIndex = 2; // Card 3 of 18 as per wireframe
  bool _isFlipped = false;

  final List<Map<String, String>> _cards = const [
    {
      'question': 'What are the 4 standard reagents used in Gram staining, in order?',
      'answer': '1. Crystal violet (primary stain)\n2. Gram’s iodine (mordant)\n3. 95% ethanol (decolorizer)\n4. Safranin (counterstain)',
    },
    {
      'question': 'What structural component makes bacterial endospores heat and radiation resistant?',
      'answer': 'Dipicolinic acid complexed with calcium (calcium dipicolinate) inside the dehydrated spore core.',
    },
    {
      'question': 'Which structure is primarily responsible for bacterial movement?',
      'answer': 'Bacterial flagellum driven by a proton-motive force motor at the cell membrane.',
    },
    {
      'question': 'Define the D-value (decimal reduction time) in sterilization kinetics.',
      'answer': 'The time required at a given temperature to reduce a microbial population by 90% (1 log reduction).',
    },
  ];

  void _showGenerateDeckSheet() {
    final subjects = OfflineCacheService.getUserSubjects();
    String selectedSub = subjects.isNotEmpty ? subjects.first : 'Microbiology';
    final topicCtrl = TextEditingController();
    int count = 10;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
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
                const Text('Subject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSub,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => selectedSub = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppInput(
                  label: 'Topic',
                  hintText: 'e.g. Endospore formation',
                  controller: topicCtrl,
                ),
                const SizedBox(height: 16),
                const Text('Cards', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [5, 10, 20].map((c) {
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
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deck generated from your notes.')),
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

  @override
  Widget build(BuildContext context) {
    if (_isStudying) {
      final card = _cards[_cardIndex.clamp(0, _cards.length - 1)];

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: () => setState(() => _isStudying = false),
          ),
          title: Text(
            'Card ${_cardIndex + 1} of 18',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: AppProgressBar(value: (_cardIndex + 1) / 18.0),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: InkWell(
                    onTap: () => setState(() => _isFlipped = !_isFlipped),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isFlipped ? 'Answer' : 'Question',
                            style: AppTypography.smallLabel,
                          ),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Text(
                              _isFlipped ? card['answer']! : card['question']!,
                              key: ValueKey(_isFlipped),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            _isFlipped ? 'Tap to see question' : 'Tap to flip',
                            style: AppTypography.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Rating Buttons with Neutral Borders & Intervals
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: _isFlipped
                    ? Row(
                        children: [
                          _buildIntervalButton('Again', '< 10 min'),
                          const SizedBox(width: 8),
                          _buildIntervalButton('Hard', '1 day'),
                          const SizedBox(width: 8),
                          _buildIntervalButton('Good', '3 days'),
                          const SizedBox(width: 8),
                          _buildIntervalButton('Easy', '6 days'),
                        ],
                      )
                    : AppPrimaryButton(
                        label: 'Show answer',
                        onPressed: () => setState(() => _isFlipped = true),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Flashcards', style: AppTypography.screenTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Due Today Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Due today: 18', style: AppTypography.sectionHeading),
                        SizedBox(height: 2),
                        Text('Microbiology and Biochemistry review', style: AppTypography.secondary),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: AppPrimaryButton(
                      label: 'Study now',
                      onPressed: () => setState(() {
                        _isStudying = true;
                        _cardIndex = 0;
                        _isFlipped = false;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Decks', style: AppTypography.sectionHeading),
            const SizedBox(height: 10),

            AppListRow(
              title: 'Microbial cell structure',
              subtitle: '12 cards due',
              onTap: () => setState(() {
                _isStudying = true;
                _cardIndex = 0;
                _isFlipped = false;
              }),
            ),
            const SizedBox(height: 8),
            AppListRow(
              title: 'Sterilization & Autoclaving',
              subtitle: '6 cards due',
              onTap: () => setState(() {
                _isStudying = true;
                _cardIndex = 2;
                _isFlipped = false;
              }),
            ),
            const SizedBox(height: 8),
            AppListRow(
              title: 'Gram staining protocols',
              subtitle: '0 cards due • Up to date',
              onTap: () => setState(() {
                _isStudying = true;
                _cardIndex = 0;
                _isFlipped = false;
              }),
            ),
            const SizedBox(height: 20),

            AppSecondaryButton(
              label: 'Generate deck with Sage',
              onPressed: _showGenerateDeckSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalButton(String label, String interval) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _isFlipped = false;
            if (_cardIndex < _cards.length - 1) {
              _cardIndex++;
            } else {
              _isStudying = false;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cards reviewed for today.')),
              );
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                interval,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
