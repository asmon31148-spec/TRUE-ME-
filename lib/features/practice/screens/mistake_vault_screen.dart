import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class MistakeVaultScreen extends StatefulWidget {
  final String? initialSubject;

  const MistakeVaultScreen({super.key, this.initialSubject});

  @override
  State<MistakeVaultScreen> createState() => _MistakeVaultScreenState();
}

class _MistakeVaultScreenState extends State<MistakeVaultScreen> {
  String _selectedFilter = 'All';
  List<String> _subjects = [];
  List<Map<String, dynamic>> _mistakes = [];

  @override
  void initState() {
    super.initState();
    final userSubs = OfflineCacheService.getUserSubjects();
    final nbSubs = OfflineCacheService.getAllCachedNotebooks()
        .map((n) => (n['title'] as String? ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();

    _subjects = {'All', ...userSubs, ...nbSubs}.toList();

    if (widget.initialSubject != null && _subjects.contains(widget.initialSubject)) {
      _selectedFilter = widget.initialSubject!;
    }

    _loadMistakes();
  }

  void _loadMistakes() {
    setState(() {
      final all = OfflineCacheService.getMistakes();
      if (_selectedFilter == 'All') {
        _mistakes = all;
      } else {
        _mistakes = all
            .where((m) =>
                (m['subject'] as String? ?? '').trim().toLowerCase() ==
                _selectedFilter.trim().toLowerCase())
            .toList();
      }
    });
  }

  Future<void> _removeMistake(String id, String question) async {
    HapticFeedback.lightImpact();
    await OfflineCacheService.removeMistake(id);
    _loadMistakes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked "$question" as mastered! 🎯')),
      );
    }
  }

  Future<void> _convertToFlashcards() async {
    if (_mistakes.isEmpty) return;

    final targetSubject = _selectedFilter == 'All'
        ? (_mistakes.first['subject'] as String? ?? 'General')
        : _selectedFilter;

    final deckId = await OfflineCacheService.convertMistakesToDeck(
      subject: targetSubject,
      topic: '$_selectedFilter Mistake Review',
      specificMistakes: _mistakes,
    );

    if (mounted && deckId != null) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created spaced-repetition deck with ${_mistakes.length} cards! 🃏')),
      );
      context.push('/flashcards?subject=${Uri.encodeComponent(targetSubject)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mistake Vault', style: AppTypography.screenTitle),
        actions: [
          if (_mistakes.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.style_outlined, size: 18),
              label: const Text('To Flashcards'),
              onPressed: _convertToFlashcards,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Subject Filter Bar
            if (_subjects.length > 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _subjects.map((sub) {
                      final isSelected = _selectedFilter == sub;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AppChip(
                          label: sub,
                          isSelected: isSelected,
                          onTap: () {
                            if (_selectedFilter != sub) {
                              setState(() => _selectedFilter = sub);
                              _loadMistakes();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // Main Content List or Empty State
            Expanded(
              child: _mistakes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_outlined, size: 56, color: context.accentColor.withOpacity(0.6)),
                            const SizedBox(height: 16),
                            const Text(
                              'No Missed Questions in Vault',
                              style: AppTypography.sectionHeading,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFilter == 'All'
                                  ? 'Take quizzes in Practice or Today. Any questions you answer incorrectly will automatically be preserved here for active-recall mastery.'
                                  : 'No mistakes recorded for $_selectedFilter. Great job keeping your retention clean!',
                              style: AppTypography.secondary,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _mistakes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final m = _mistakes[i];
                        final id = m['id'] as String? ?? 'err_$i';
                        final question = m['question'] as String? ?? 'Question';
                        final sub = m['subject'] as String? ?? 'General';
                        final topic = m['topic'] as String? ?? sub;
                        final options = (m['options'] as List? ?? []).map((e) => e.toString()).toList();
                        final correctIdx = (m['correctOptionIndex'] as num? ?? 0).toInt();
                        final correctAnswer = (correctIdx >= 0 && correctIdx < options.length)
                            ? options[correctIdx]
                            : (options.isNotEmpty ? options.first : 'Correct answer');
                        final explanation = m['explanation'] as String? ?? '';

                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      sub.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      topic,
                                      style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline, size: 20),
                                    tooltip: 'Mark as mastered',
                                    color: context.textSecondary,
                                    onPressed: () => _removeMistake(id, question),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                question,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Correct Concept:',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(correctAnswer, style: AppTypography.body),
                                  ],
                                ),
                              ),
                              if (explanation.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  explanation,
                                  style: AppTypography.secondary.copyWith(fontSize: 12.5),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
