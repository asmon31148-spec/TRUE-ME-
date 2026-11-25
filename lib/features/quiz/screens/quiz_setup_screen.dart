import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/cognitive/student_cognitive_profile.dart';
import '../../../core/models/quiz_model.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/generation_progress_view.dart';
import '../../../shared/widgets/true_me_ui.dart';
import '../providers/quiz_provider.dart';

class QuizSetupScreen extends ConsumerStatefulWidget {
  final String? notebookId;
  final String? initialSubject;
  final String? initialTopic;

  const QuizSetupScreen({
    super.key,
    this.notebookId,
    this.initialSubject,
    this.initialTopic,
  });

  @override
  ConsumerState<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends ConsumerState<QuizSetupScreen> {
  bool _isPlaying = false;
  bool _isFinished = false;
  bool _reviewingMissed = false;
  int _reviewIdx = 0;

  // Setup options
  List<Map<String, dynamic>> _notebooks = [];
  String? _selectedNotebookId;
  final TextEditingController _customSubjectCtrl = TextEditingController();
  final TextEditingController _topicCtrl = TextEditingController();
  String _selectedDifficulty = 'Medium';
  int _questionCount = 10;

  // Active Quiz State
  int _currentIdx = 0;
  int? _selectedOptionIdx;
  bool _hasChecked = false;
  int _score = 0;
  final List<QuizQuestionModel> _missedQuestions = [];

  @override
  void initState() {
    super.initState();
    _notebooks = OfflineCacheService.getAllCachedNotebooks();

    if (widget.notebookId != null && _notebooks.any((n) => n['id'] == widget.notebookId)) {
      _selectedNotebookId = widget.notebookId;
    } else if (widget.initialSubject != null) {
      final match = _notebooks.where(
        (n) => (n['title'] as String? ?? '').toLowerCase() == widget.initialSubject!.toLowerCase(),
      );
      if (match.isNotEmpty) {
        _selectedNotebookId = match.first['id'] as String?;
      } else {
        _customSubjectCtrl.text = widget.initialSubject!;
      }
    } else if (_notebooks.isNotEmpty) {
      _selectedNotebookId = _notebooks.first['id'] as String?;
    }

    if (widget.initialTopic != null) {
      _topicCtrl.text = widget.initialTopic!;
    }

    _adaptDifficultyToStudent();
  }

  void _adaptDifficultyToStudent() {
    final profile = StudentCognitiveProfile.buildLive(subjectScope: _effectiveSubject);
    final tier = profile.activeSubjectTier ?? profile.overallTier;
    switch (tier) {
      case CognitiveTier.mastery:
        _selectedDifficulty = 'Hard';
        break;
      case CognitiveTier.reinforcing:
        _selectedDifficulty = 'Medium';
        break;
      case CognitiveTier.foundational:
        _selectedDifficulty = 'Easy';
        break;
    }
  }

  @override
  void dispose() {
    _customSubjectCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  String get _effectiveSubject {
    if (_selectedNotebookId != null) {
      final nb = _notebooks.firstWhere(
        (n) => n['id'] == _selectedNotebookId,
        orElse: () => {},
      );
      final title = nb['title'] as String?;
      if (title != null && title.isNotEmpty) return title;
    }
    final custom = _customSubjectCtrl.text.trim();
    return custom.isNotEmpty ? custom : 'General Study';
  }

  int get _effectiveFileCount {
    if (_selectedNotebookId == null) return 0;
    final nb = _notebooks.firstWhere((n) => n['id'] == _selectedNotebookId, orElse: () => {});
    return (nb['documents'] as List? ?? []).length;
  }

  Future<void> _startQuiz() async {
    final subject = _effectiveSubject;
    final topic = _topicCtrl.text.trim().isNotEmpty ? _topicCtrl.text.trim() : subject;
    final nbId = _selectedNotebookId ?? '';
    final sourceContent = nbId.isNotEmpty
        ? OfflineCacheService.getNotebookCombinedText(nbId, maxChars: 16000)
        : '';

    setState(() {
      _isPlaying = true;
      _isFinished = false;
      _reviewingMissed = false;
      _currentIdx = 0;
      _selectedOptionIdx = null;
      _hasChecked = false;
      _score = 0;
      _missedQuestions.clear();
    });

    await ref.read(quizProvider.notifier).generateQuiz(
          notebookId: nbId.isNotEmpty ? nbId : 'general',
          subject: subject,
          topic: topic,
          content: sourceContent,
          difficulty: _selectedDifficulty.toLowerCase(),
          count: _questionCount,
        );
  }

  void _onCheck(QuizQuestionModel q) {
    if (_selectedOptionIdx == null || _hasChecked) return;
    HapticFeedback.lightImpact();
    final isCorrect = _selectedOptionIdx == q.correctOptionIndex;
    setState(() {
      _hasChecked = true;
      if (isCorrect) {
        _score++;
      } else {
        _missedQuestions.add(q);
      }
    });
  }

  Future<void> _onNext(QuizModel quiz) async {
    if (_currentIdx < quiz.questions.length - 1) {
      setState(() {
        _currentIdx++;
        _selectedOptionIdx = null;
        _hasChecked = false;
      });
    } else {
      await OfflineCacheService.saveQuizAttempt(
        id: quiz.id,
        subject: quiz.subject,
        topic: quiz.topic,
        score: _score,
        total: quiz.questions.length,
        missedTopics: _missedQuestions.map((q) => q.question).toList(),
      );
      if (_missedQuestions.isNotEmpty) {
        await OfflineCacheService.saveMistakes(
          subject: quiz.subject,
          topic: quiz.topic,
          questions: _missedQuestions.map((q) => q.toMap()).toList(),
        );
      }
      if (mounted) {
        setState(() => _isFinished = true);
      }
    }
  }

  Future<bool> _confirmExitQuiz() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Quiz?'),
        content: const Text('Your current score and answers will be lost. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Quiz'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    return shouldExit == true;
  }

  void _showRecentScoresSheet() {
    final attempts = OfflineCacheService.getQuizAttempts();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent Quiz Scores', style: AppTypography.sectionHeading),
              const SizedBox(height: 12),
              if (attempts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No quizzes completed yet. Finish a quiz to record your progress.',
                    style: AppTypography.secondary.copyWith(color: context.textSecondary),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: attempts.take(6).length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final q = attempts[i];
                      final pct = (q['percentage'] as num? ?? 0).toInt();
                      return AppListRow(
                        title: '${q['topic'] ?? q['subject']}',
                        subtitle: '${q['subject']} · ${q['score']}/${q['total']}',
                        trailing: TrueMeTonalPill(
                          label: '$pct%',
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  void _showSubjectPickerSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Subject', style: AppTypography.sectionHeading),
              const SizedBox(height: 12),
              ..._notebooks.map((n) {
                final id = n['id'] as String;
                final title = n['title'] as String? ?? 'Subject';
                final docs = (n['documents'] as List? ?? []).length;
                final isSelected = _selectedNotebookId == id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppListRow(
                    leading: AppIconBadge(icon: Icons.menu_book_rounded, color: context.accentColor),
                    title: title,
                    subtitle: '$docs ${docs == 1 ? 'file' : 'files'} included',
                    trailing: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? context.accentColor : context.textSecondary,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedNotebookId = id;
                        _adaptDifficultyToStudent();
                      });
                    },
                  ),
                );
              }),
              AppListRow(
                leading: AppIconBadge(icon: Icons.edit_outlined, color: context.textSecondary),
                title: 'Custom Topic (No Notebook)',
                subtitle: 'Quiz yourself on any subject',
                trailing: Icon(
                  _selectedNotebookId == null ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: _selectedNotebookId == null ? context.accentColor : context.textSecondary,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedNotebookId = null;
                    _adaptDifficultyToStudent();
                  });
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
    final quizState = ref.watch(quizProvider);
    final quiz = quizState.currentQuiz;

    // 1. Loading / Generating state
    if (_isPlaying && quizState.isGenerating) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: TrueMeAmbientBackground(
          child: SafeArea(
            child: Column(
              children: [
                TrueMeTopBar(
                  title: 'Creating Quiz',
                  onBack: () => setState(() => _isPlaying = false),
                ),
                Expanded(
                  child: GenerationProgressView(
                    title: 'Building $_questionCount-question $_selectedDifficulty quiz...',
                    subtitle: _selectedNotebookId != null
                        ? 'Using your $_effectiveSubject notes and syllabus'
                        : 'Topic: ${_topicCtrl.text.trim().isNotEmpty ? _topicCtrl.text.trim() : _effectiveSubject}',
                    stages: const [
                      'Reading your study material...',
                      'Drafting quiz questions with Sage...',
                      'Verifying options & explanations...',
                      'Finalizing quiz...',
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 1b. Quiz Generation Error View
    if (_isPlaying && !quizState.isGenerating && quiz == null && quizState.error != null) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: TrueMeAmbientBackground(
          child: SafeArea(
            child: Column(
              children: [
                TrueMeTopBar(
                  title: 'Quiz Error',
                  onBack: () => setState(() => _isPlaying = false),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: TrueMeCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 46),
                            const SizedBox(height: 14),
                            const Text('Could not generate quiz', style: AppTypography.sectionHeading),
                            const SizedBox(height: 8),
                            Text(quizState.error!, style: AppTypography.secondary, textAlign: TextAlign.center),
                            const SizedBox(height: 22),
                            TrueMePrimaryButton(label: 'Retry', onPressed: _startQuiz),
                            const SizedBox(height: 10),
                            AppSecondaryButton(
                              label: 'Back to Setup',
                              onPressed: () => setState(() => _isPlaying = false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. Reviewing Missed Questions
    if (_reviewingMissed && _missedQuestions.isNotEmpty) {
      final q = _missedQuestions[_reviewIdx];
      return Scaffold(
        backgroundColor: context.bgColor,
        body: TrueMeAmbientBackground(
          child: SafeArea(
            child: Column(
              children: [
                TrueMeTopBar(
                  title: 'Missed ${_reviewIdx + 1} of ${_missedQuestions.length}',
                  onBack: () => setState(() => _reviewingMissed = false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrueMeCard(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            q.question,
                            style: AppTypography.sectionHeading.copyWith(color: context.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TrueMeCard(
                          borderColor: AppColors.success,
                          color: isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Correct Answer',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
                              ),
                              const SizedBox(height: 4),
                              Text(q.options[q.correctOptionIndex], style: AppTypography.body),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TrueMeCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Explanation',
                                style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(q.explanation, style: AppTypography.body),
                            ],
                          ),
                        ),
                        const Spacer(),
                        TrueMePrimaryButton(
                          label: _reviewIdx < _missedQuestions.length - 1 ? 'Next Missed Question' : 'Back to Results',
                          onPressed: () {
                            setState(() {
                              if (_reviewIdx < _missedQuestions.length - 1) {
                                _reviewIdx++;
                              } else {
                                _reviewingMissed = false;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Result Screen
    if (_isFinished && quiz != null) {
      final total = quiz.questions.length;
      final pct = total > 0 ? ((_score / total) * 100).round() : 0;

      return Scaffold(
        backgroundColor: context.bgColor,
        body: TrueMeAmbientBackground(
          child: SafeArea(
            child: Column(
              children: [
                TrueMeTopBar(
                  title: 'Quiz Results',
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Column(
                      children: [
                        TrueMeCard(
                          borderRadius: 24,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                          gradient: isDark ? AppColors.heroFocusDarkGradient : AppColors.heroFocusLightGradient,
                          child: Column(
                            children: [
                              TrueMeCircularRing(
                                progress: pct / 100.0,
                                size: 108,
                                strokeWidth: 10,
                                center: Text(
                                  '$pct%',
                                  style: AppTypography.screenTitle.copyWith(color: context.textPrimary),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '$_score of $total Correct · ${quiz.subject}',
                                style: AppTypography.cardTitle.copyWith(color: context.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                pct >= 80
                                    ? 'Strong grasp of ${quiz.topic}.'
                                    : (pct >= 50
                                        ? 'Good progress — review the missed concepts below.'
                                        : 'Keep practicing — focus on the missed topics below.'),
                                textAlign: TextAlign.center,
                                style: AppTypography.secondary.copyWith(color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_missedQuestions.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Missed Questions (${_missedQuestions.length})',
                              style: AppTypography.sectionHeading.copyWith(color: context.textPrimary),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _missedQuestions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final mq = _missedQuestions[i];
                                return AppListRow(
                                  title: mq.question,
                                  subtitle: 'Correct: ${mq.options[mq.correctOptionIndex]}',
                                  onTap: () => setState(() {
                                    _reviewIdx = i;
                                    _reviewingMissed = true;
                                  }),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          TrueMePrimaryButton(
                            label: 'Review Missed Questions',
                            onPressed: () => setState(() {
                              _reviewIdx = 0;
                              _reviewingMissed = true;
                            }),
                          ),
                          const SizedBox(height: 8),
                          AppSecondaryButton(
                            label: 'Convert Missed to Flashcards',
                            icon: const Icon(Icons.style_outlined, size: 18),
                            onPressed: () async {
                              final deckId = await OfflineCacheService.convertMistakesToDeck(
                                subject: quiz.subject,
                                topic: '${quiz.topic} Mistakes',
                                specificMistakes: _missedQuestions.map((q) => q.toMap()).toList(),
                              );
                              if (context.mounted && deckId != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Created spaced flashcards from missed questions!')),
                                );
                                context.push('/flashcards?subject=${Uri.encodeComponent(quiz.subject)}');
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                        ] else ...[
                          const Spacer(),
                        ],
                        AppSecondaryButton(
                          label: 'Done',
                          onPressed: () => context.pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 4. Active Quiz Question View
    if (_isPlaying && quiz != null && quiz.questions.isNotEmpty) {
      final q = quiz.questions[_currentIdx.clamp(0, quiz.questions.length - 1)];
      final total = quiz.questions.length;
      const letters = ['A', 'B', 'C', 'D'];

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final exit = await _confirmExitQuiz();
          if (exit && mounted) {
            setState(() => _isPlaying = false);
          }
        },
        child: Scaffold(
          backgroundColor: context.bgColor,
          body: TrueMeAmbientBackground(
            child: SafeArea(
              child: Column(
                children: [
                  TrueMeTopBar(
                    title: 'Question ${_currentIdx + 1} of $total',
                    onBack: () async {
                      final exit = await _confirmExitQuiz();
                      if (exit && mounted) {
                        setState(() => _isPlaying = false);
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: AppProgressBar(value: (_currentIdx + 1) / total),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrueMeCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              q.question,
                              style: AppTypography.sectionHeading.copyWith(
                                fontSize: 19,
                                color: context.textPrimary,
                                height: 1.38,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(q.options.length, (i) {
                            final isSelected = _selectedOptionIdx == i;
                            final isCorrectOption = i == q.correctOptionIndex;

                            Color borderColor = context.borderColor;
                            Color bgColor = context.surfaceColor;

                            if (_hasChecked) {
                              if (isCorrectOption) {
                                borderColor = AppColors.success;
                                bgColor = isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen;
                              } else if (isSelected) {
                                borderColor = AppColors.error;
                                bgColor = isDark ? const Color(0xFF321822) : AppColors.pastelRose;
                              }
                            } else if (isSelected) {
                              borderColor = context.accentColor;
                              bgColor = context.accentTint;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TrueMeCard(
                                borderRadius: 16,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                color: bgColor,
                                borderColor: borderColor,
                                borderWidth: isSelected || (_hasChecked && isCorrectOption) ? 1.5 : 1.0,
                                onTap: _hasChecked ? null : () => setState(() => _selectedOptionIdx = i),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? context.accentColor
                                            : context.bgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        i < letters.length ? letters[i] : '${i + 1}',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? Colors.white : context.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        q.options[i],
                                        style: TextStyle(fontSize: 15, color: context.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (_hasChecked) ...[
                            const SizedBox(height: 8),
                            TrueMeCard(
                              borderRadius: 18,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedOptionIdx == q.correctOptionIndex ? 'Correct!' : 'Incorrect',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: _selectedOptionIdx == q.correctOptionIndex
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(q.explanation, style: AppTypography.body),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                    child: TrueMePrimaryButton(
                      label: !_hasChecked ? 'Check Answer' : (_currentIdx < total - 1 ? 'Next Question' : 'Finish Quiz'),
                      onPressed: _selectedOptionIdx == null
                          ? null
                          : (!_hasChecked ? () => _onCheck(q) : () => _onNext(quiz)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 5. Quiz Setup Screen matching Reference Image 4 Center
    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              TrueMeTopBar(
                title: 'Quiz Setup',
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/practice');
                  }
                },
                trailing: TrueMeCircleIconButton(
                  icon: Icons.emoji_events_rounded,
                  iconColor: isDark ? AppColors.darkWarning : const Color(0xFFF59E0B),
                  tooltip: 'Recent scores',
                  size: 40,
                  onPressed: _showRecentScoresSheet,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject Selector Card
                      if (_notebooks.isNotEmpty) ...[
                        TrueMeCard(
                          borderRadius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          onTap: _showSubjectPickerSheet,
                          child: Row(
                            children: [
                              AppIconBadge(
                                icon: Icons.menu_book_rounded,
                                color: context.accentColor,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedNotebookId != null ? _effectiveSubject : 'Custom Topic',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      _selectedNotebookId != null
                                          ? '$_effectiveFileCount ${_effectiveFileCount == 1 ? 'file' : 'files'} included'
                                          : 'Test any custom subject or concept',
                                      style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: context.textSecondary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      if (_selectedNotebookId == null) ...[
                        AppInput(
                          label: 'Subject',
                          hintText: 'e.g. Organic Chemistry, Microbiology...',
                          controller: _customSubjectCtrl,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Topic Field with Edit Icon
                      AppInput(
                        label: 'Topic',
                        hintText: 'Leave blank to test entire subject',
                        controller: _topicCtrl,
                        suffixIcon: Icon(Icons.edit_outlined, size: 18, color: context.textSecondary),
                      ),
                      const SizedBox(height: 22),

                      // Difficulty Level Segmented Control
                      Text(
                        'Difficulty Level',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.borderColor),
                          boxShadow: context.cardShadow,
                        ),
                        child: Row(
                          children: ['Easy', 'Medium', 'Hard'].map((diff) {
                            final selected = _selectedDifficulty == diff;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedDifficulty = diff);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  decoration: BoxDecoration(
                                    gradient: selected ? AppColors.indigoButtonGradient : null,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    diff,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      color: selected ? Colors.white : context.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Number of Questions Stepper
                      Text(
                        'Number of Questions',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.borderColor),
                          boxShadow: context.cardShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: _questionCount > 5
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _questionCount = (_questionCount - 1).clamp(5, 25));
                                    }
                                  : null,
                              icon: Icon(Icons.remove_rounded, color: context.accentColor),
                            ),
                            Text(
                              '$_questionCount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                            IconButton(
                              onPressed: _questionCount < 25
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _questionCount = (_questionCount + 1).clamp(5, 25));
                                    }
                                  : null,
                              icon: Icon(Icons.add_rounded, color: context.accentColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Adaptive Difficulty Info Banner
                      TrueMeCard(
                        borderRadius: 18,
                        padding: const EdgeInsets.all(14),
                        color: isDark ? AppColors.darkAccentWash : AppColors.accentWash,
                        borderColor: context.accentColor.withValues(alpha: 0.25),
                        showShadow: false,
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.lightbulb_outline_rounded, size: 20, color: context.accentColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Adaptive difficulty will adjust based on your $_effectiveSubject mastery ($_selectedDifficulty recommended).',
                                style: AppTypography.secondary.copyWith(
                                  fontSize: 13,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      TrueMePrimaryButton(
                        label: 'Generate Quiz',
                        trailingIcon: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                        onPressed: _startQuiz,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
