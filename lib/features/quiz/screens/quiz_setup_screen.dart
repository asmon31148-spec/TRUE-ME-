import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/models/quiz_model.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  bool _isPlaying = false;
  int _currentQuestionIdx = 0;
  int? _selectedOptionIdx;
  bool _hasSubmitted = false;
  int _scoreCount = 0;

  final List<QuizQuestionModel> _sampleQuestions = const [
    QuizQuestionModel(
      id: 'q1',
      question: 'Which of the following is NOT one of the Coffman conditions for deadlocks?',
      options: [
        'Mutual Exclusion',
        'Hold and Wait',
        'Preemptive Scheduling',
        'Circular Wait',
      ],
      correctOptionIndex: 2,
      explanation: 'The condition is "No Preemption". Preemptive scheduling actually helps break or prevent deadlocks.',
    ),
    QuizQuestionModel(
      id: 'q2',
      question: "In Banker's Algorithm, what must hold true for a state to be classified as 'safe'?",
      options: [
        'All processes have finished executing',
        'There exists at least one sequence of process allocations that does not lead to deadlock',
        'All resources are currently fully allocated to CPU threads',
        'No processes are currently waiting on I/O',
      ],
      correctOptionIndex: 1,
      explanation: 'A safe state guarantees that there exists at least one order in which all processes can satisfy their maximum claim without deadlock.',
    ),
  ];

  void _handleOptionSelect(int idx) {
    if (_hasSubmitted) return;
    setState(() => _selectedOptionIdx = idx);
  }

  void _submitAnswer() {
    if (_selectedOptionIdx == null) return;
    final currentQ = _sampleQuestions[_currentQuestionIdx];
    final isCorrect = _selectedOptionIdx == currentQ.correctOptionIndex;

    setState(() {
      _hasSubmitted = true;
      if (isCorrect) _scoreCount++;
    });
  }

  void _nextQuestion() {
    setState(() {
      _selectedOptionIdx = null;
      _hasSubmitted = false;
      if (_currentQuestionIdx < _sampleQuestions.length - 1) {
        _currentQuestionIdx++;
      } else {
        // Quiz completed
        _isPlaying = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlaying) {
      final q = _sampleQuestions[_currentQuestionIdx];

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: GlassAppBar(
          title: 'Question ${_currentQuestionIdx + 1}/${_sampleQuestions.length}',
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _isPlaying = false),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentQuestionIdx + 1) / _sampleQuestions.length,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(AppColors.accentCyan),
                ),
              ),
              const SizedBox(height: 24),

              // Question Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 24,
                child: Text(
                  q.question,
                  style: AppTypography.headlineMedium.copyWith(height: 1.4),
                ),
              ),
              const SizedBox(height: 20),

              // Options
              Expanded(
                child: ListView.builder(
                  itemCount: q.options.length,
                  itemBuilder: (context, idx) {
                    final opt = q.options[idx];
                    final isSelected = _selectedOptionIdx == idx;
                    final isCorrect = idx == q.correctOptionIndex;

                    Color? borderColor;
                    Color? bgColor;

                    if (_hasSubmitted) {
                      if (isCorrect) {
                        borderColor = AppColors.success;
                        bgColor = AppColors.success.withOpacity(0.18);
                      } else if (isSelected && !isCorrect) {
                        borderColor = AppColors.error;
                        bgColor = AppColors.error.withOpacity(0.18);
                      }
                    } else if (isSelected) {
                      borderColor = AppColors.accentCyan;
                      bgColor = AppColors.accent.withOpacity(0.12);
                    }

                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      borderRadius: 16,
                      surfaceColor: bgColor,
                      borderGradient: borderColor != null
                          ? LinearGradient(colors: [borderColor, borderColor])
                          : null,
                      onTap: () => _handleOptionSelect(idx),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.accentCyan
                                  : Colors.white.withOpacity(0.1),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + idx),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              opt,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Explanation if submitted
              if (_hasSubmitted) ...[
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  surfaceColor: AppColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EXPLANATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.accentCyan,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(q.explanation, style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Button
              GlassButton(
                isPrimary: true,
                width: double.infinity,
                onPressed: _selectedOptionIdx == null
                    ? null
                    : _hasSubmitted
                        ? _nextQuestion
                        : _submitAnswer,
                child: Text(
                  !_hasSubmitted
                      ? 'Submit Answer'
                      : _currentQuestionIdx < _sampleQuestions.length - 1
                          ? 'Next Question'
                          : 'View Results',
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Adaptive Quiz',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.18),
                    ),
                    child: const Icon(Icons.psychology_alt, color: AppColors.primaryLight, size: 40),
                  ),
                  const SizedBox(height: 18),
                  const Text('Adaptive Mastery Quiz', style: AppTypography.headlineMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Sage generates adaptive questions calibrated to your weak topics. Scoring >85% automatically raises your subject level.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  GlassButton(
                    isPrimary: true,
                    width: double.infinity,
                    child: const Text('Start Quiz (Operating Systems)'),
                    onPressed: () => setState(() {
                      _isPlaying = true;
                      _currentQuestionIdx = 0;
                      _selectedOptionIdx = null;
                      _hasSubmitted = false;
                      _scoreCount = 0;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
