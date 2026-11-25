import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';

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
        SnackBar(content: Text('Marked "$question" as mastered!')),
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
        SnackBar(content: Text('Created spaced-repetition deck with ${_mistakes.length} cards!')),
      );
      context.push('/flashcards?subject=${Uri.encodeComponent(targetSubject)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              TrueMeTopBar(
                title: 'Mistake Vault',
                onBack: () => Navigator.pop(context),
                trailing: _mistakes.isNotEmpty
                    ? TrueMeTonalPill(
                        label: 'To Deck',
                        icon: Icons.style_outlined,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        onTap: _convertToFlashcards,
                      )
                    : null,
              ),

              if (_subjects.length > 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
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

              Expanded(
                child: _mistakes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: TrueMeCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIconBadge(
                                  icon: Icons.verified_outlined,
                                  size: 56,
                                  iconSize: 28,
                                  color: AppColors.success,
                                  backgroundColor:
                                      isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Missed Questions in Vault',
                                  style: AppTypography.sectionHeading,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedFilter == 'All'
                                      ? 'Take quizzes in Practice. Any questions you answer incorrectly will be preserved here for active-recall mastery.'
                                      : 'No mistakes recorded for $_selectedFilter. Great work keeping your retention clean!',
                                  style: AppTypography.secondary.copyWith(color: context.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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

                          return TrueMeCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    TrueMeTonalPill(
                                      label: sub.toUpperCase(),
                                      backgroundColor:
                                          isDark ? const Color(0xFF321822) : AppColors.pastelRose,
                                      foregroundColor: AppColors.error,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                                      tooltip: 'Mark as mastered',
                                      color: context.textSecondary,
                                      onPressed: () => _removeMistake(id, question),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  question,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.38,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Correct Concept',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(correctAnswer, style: AppTypography.body),
                                    ],
                                  ),
                                ),
                                if (explanation.trim().isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    explanation,
                                    style: AppTypography.secondary.copyWith(
                                      fontSize: 13,
                                      color: context.textSecondary,
                                    ),
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
      ),
    );
  }
}
