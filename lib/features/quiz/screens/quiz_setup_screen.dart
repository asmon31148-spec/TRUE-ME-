import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/models/quiz_model.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/generation_progress_view.dart';
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
  int _questionCount = 5;

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
      if (mounted) {
        setState(() => _isFinished = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);
    final quiz = quizState.currentQuiz;

    // 1. Loading / Generating state
    if (_isPlaying && quizState.isGenerating) {
      return Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _isPlaying = false),
          ),
          title: const Text('Creating Quiz', style: AppTypography.sectionHeading),
        ),
        body: GenerationProgressView(
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
      );
    }

    // 1b. Quiz Generation Error View (No fake questions)
    if (_isPlaying && !quizState.isGenerating && quiz == null && quizState.error != null) {
      return Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _isPlaying = false),
          ),
          title: const Text('Quiz Error', style: AppTypography.sectionHeading),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 44),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not generate quiz',
                    style: AppTypography.sectionHeading,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quizState.error!,
                    style: AppTypography.secondary,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  AppPrimaryButton(
                    label: 'Retry',
                    onPressed: _startQuiz,
                  ),
                  const SizedBox(height: 10),
                  AppSecondaryButton(
                    label: 'Back to setup',
                    onPressed: () => setState(() => _isPlaying = false),
                  ),
                ],
              ),
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _reviewingMissed = false),
          ),
          title: Text('Missed ${_reviewIdx + 1} of ${_missedQuestions.length}', style: AppTypography.sectionHeading),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.question, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textPrimary)),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Correct answer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                      const SizedBox(height: 4),
                      Text(q.options[q.correctOptionIndex], style: AppTypography.body),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Explanation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondary)),
                      const SizedBox(height: 4),
                      Text(q.explanation, style: AppTypography.body),
                    ],
                  ),
                ),
                const Spacer(),
                AppPrimaryButton(
                  label: _reviewIdx < _missedQuestions.length - 1 ? 'Next missed question' : 'Back to results',
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
      );
    }

    // 3. Result Screen
    if (_isFinished && quiz != null) {
      final total = quiz.questions.length;
      final pct = total > 0 ? ((_score / total) * 100).round() : 0;

      return Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          title: const Text('Result', style: AppTypography.screenTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                Text(
                  '$_score / $total',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
                Text(
                  '$pct% • ${quiz.subject}',
                  style: AppTypography.secondary.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Text(
                  pct >= 80
                      ? 'Strong grasp of ${quiz.topic}.'
                      : (pct >= 50
                          ? 'Good progress — review the missed concepts below.'
                          : 'Keep practicing — focus on the missed topics below.'),
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: 24),

                if (_missedQuestions.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Missed questions (${_missedQuestions.length})', style: AppTypography.sectionHeading),
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
                  AppPrimaryButton(
                    label: 'Review missed questions',
                    onPressed: () => setState(() {
                      _reviewIdx = 0;
                      _reviewingMissed = true;
                    }),
                  ),
                  const SizedBox(height: 10),
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
      );
    }

    // 4. Active Quiz Question View
    if (_isPlaying && quiz != null && quiz.questions.isNotEmpty) {
      final q = quiz.questions[_currentIdx.clamp(0, quiz.questions.length - 1)];
      final total = quiz.questions.length;
      final letters = ['A', 'B', 'C', 'D'];

      return Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: () => setState(() => _isPlaying = false),
          ),
          title: Text(
            'Question ${_currentIdx + 1} of $total',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.textPrimary),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: AppProgressBar(value: (_currentIdx + 1) / total),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.question,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      ...List.generate(q.options.length, (i) {
                        final isSelected = _selectedOptionIdx == i;
                        final isCorrectOption = i == q.correctOptionIndex;

                        Color borderColor = context.borderColor;
                        Color bgColor = context.surfaceColor;

                        if (_hasChecked) {
                          if (isCorrectOption) {
                            borderColor = AppColors.success;
                            bgColor = AppColors.success.withOpacity(0.1);
                          } else if (isSelected) {
                            borderColor = AppColors.error;
                            bgColor = AppColors.error.withOpacity(0.1);
                          }
                        } else if (isSelected) {
                          borderColor = context.accentColor;
                          bgColor = context.accentTint;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: _hasChecked ? null : () => setState(() => _selectedOptionIdx = i),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: borderColor,
                                  width: isSelected || (_hasChecked && isCorrectOption) ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    i < letters.length ? letters[i] : '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? context.accentColor : context.textSecondary,
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
                          ),
                        );
                      }),

                      if (_hasChecked) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedOptionIdx == q.correctOptionIndex ? 'Correct' : 'Incorrect',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
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

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.bgColor,
                  border: Border(top: BorderSide(color: context.borderColor, width: 1)),
                ),
                child: AppPrimaryButton(
                  label: !_hasChecked
                      ? 'Check'
                      : (_currentIdx < total - 1 ? 'Next' : 'Finish'),
                  onPressed: _selectedOptionIdx == null
                      ? null
                      : (!_hasChecked ? () => _onCheck(q) : () => _onNext(quiz)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 5. Quiz Setup Screen
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Quiz', style: AppTypography.screenTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_notebooks.isNotEmpty) ...[
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
                            value: _selectedNotebookId,
                            isExpanded: true,
                            dropdownColor: context.surfaceColor,
                            items: [
                              ..._notebooks.map((n) {
                                final id = n['id'] as String;
                                final title = n['title'] as String? ?? 'Subject';
                                final docCount = (n['documents'] as List? ?? []).length;
                                return DropdownMenuItem<String?>(
                                  value: id,
                                  child: Text('$title ($docCount files)'),
                                );
                              }),
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Custom topic (no notebook)'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _selectedNotebookId = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_selectedNotebookId == null) ...[
                      AppInput(
                        label: 'Subject',
                        hintText: 'e.g. Organic Chemistry, Economics...',
                        controller: _customSubjectCtrl,
                      ),
                      const SizedBox(height: 16),
                    ],

                    AppInput(
                      label: 'Topic (optional)',
                      hintText: 'Leave blank to test entire subject notes',
                      controller: _topicCtrl,
                    ),
                    const SizedBox(height: 20),

                    const Text('Difficulty', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Easy', 'Medium', 'Hard'].map((diff) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppChip(
                            label: diff,
                            isSelected: _selectedDifficulty == diff,
                            onTap: () => setState(() => _selectedDifficulty = diff),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    const Text('Questions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      children: [5, 10, 15].map((cnt) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppChip(
                            label: '$cnt',
                            isSelected: _questionCount == cnt,
                            onTap: () => setState(() => _questionCount = cnt),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.bgColor,
                border: Border(top: BorderSide(color: context.borderColor, width: 1)),
              ),
              child: AppPrimaryButton(
                label: 'Start quiz',
                onPressed: _startQuiz,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
