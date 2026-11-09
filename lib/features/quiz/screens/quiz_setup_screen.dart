import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/models/quiz_model.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/quiz_provider.dart';

class QuizSetupScreen extends ConsumerStatefulWidget {
  const QuizSetupScreen({super.key});

  @override
  ConsumerState<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends ConsumerState<QuizSetupScreen> {
  bool _isPlaying = false;
  final TextEditingController _topicController = TextEditingController();
  late String _selectedSubject;
  late List<String> _userSubjects;
  String _selectedDifficulty = 'medium';

  @override
  void initState() {
    super.initState();
    _userSubjects = OfflineCacheService.getUserSubjects();
    _selectedSubject = _userSubjects.isNotEmpty ? _userSubjects.first : 'Computer Science';
    _topicController.text = 'Core Principles & Formulas';
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateAndStartQuiz() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic for the quiz.')),
      );
      return;
    }

    await ref.read(quizProvider.notifier).generateQuiz(
          notebookId: 'nb_active',
          subject: _selectedSubject,
          topic: topic,
          difficulty: _selectedDifficulty,
          count: 5,
        );

    final quiz = ref.read(quizProvider).currentQuiz;
    if (quiz != null && quiz.questions.isNotEmpty) {
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);
    final quiz = quizState.currentQuiz;

    if (_isPlaying && quiz != null && quiz.questions.isNotEmpty) {
      final safeIdx = quizState.currentQuestionIndex.clamp(0, quiz.questions.length - 1);
      final q = quiz.questions[safeIdx];
      final isFinished = quizState.hasSubmitted && safeIdx == quiz.questions.length - 1;

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: GlassAppBar(
          title: '${quiz.subject} • Q${safeIdx + 1}/${quiz.questions.length}',
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
                  value: (safeIdx + 1) / quiz.questions.length,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
                ),
              ),
              const SizedBox(height: 24),

              // Question Card
              GlassCard(
                padding: const EdgeInsets.all(22),
                borderRadius: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            quiz.difficulty.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Score: ${quizState.correctCount}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(q.question, style: AppTypography.titleLarge),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Multiple-Choice Options
              Expanded(
                child: ListView.builder(
                  itemCount: q.options.length,
                  itemBuilder: (context, idx) {
                    final optText = q.options[idx];
                    final isSelected = quizState.selectedOptionIndex == idx;
                    final isCorrect = idx == q.correctOptionIndex;

                    Color borderColor = Colors.white.withOpacity(0.1);
                    Color bgColor = Colors.white.withOpacity(0.04);

                    if (quizState.hasSubmitted) {
                      if (isCorrect) {
                        borderColor = AppColors.success;
                        bgColor = AppColors.success.withOpacity(0.18);
                      } else if (isSelected && !isCorrect) {
                        borderColor = AppColors.error;
                        bgColor = AppColors.error.withOpacity(0.18);
                      }
                    } else if (isSelected) {
                      borderColor = AppColors.accentCyan;
                      bgColor = AppColors.accentCyan.withOpacity(0.15);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => ref.read(quizProvider.notifier).selectOption(idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? (quizState.hasSubmitted
                                          ? (isCorrect ? AppColors.success : AppColors.error)
                                          : AppColors.accentCyan)
                                      : Colors.white.withOpacity(0.08),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  String.fromCharCode(65 + idx),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isSelected ? Colors.black : Colors.white70,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  optText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Explanation Card
              if (quizState.hasSubmitted) ...[
                GlassCard(
                  padding: const EdgeInsets.all(14),
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
                      const SizedBox(height: 4),
                      Text(q.explanation, style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Action Button
              GlassButton(
                isPrimary: true,
                width: double.infinity,
                onPressed: quizState.selectedOptionIndex == null
                    ? null
                    : quizState.hasSubmitted
                        ? (isFinished
                            ? () {
                                setState(() => _isPlaying = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 Completed! Final Score: ${quizState.correctCount}/${quiz.questions.length}'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            : () => ref.read(quizProvider.notifier).nextQuestion())
                        : () => ref.read(quizProvider.notifier).submitAnswer(),
                child: Text(
                  !quizState.hasSubmitted
                      ? 'Submit Answer'
                      : isFinished
                          ? 'Finish Quiz'
                          : 'Next Question',
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
        title: 'Adaptive AI Quiz',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.18),
                      ),
                      child: const Icon(Icons.psychology_alt, color: AppColors.accentCyan, size: 36),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text('Adaptive Mastery Quiz', style: AppTypography.headlineMedium),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Sage uses active recall to test your exact course concepts.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subject Selector
                  const Text('Select Subject', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSubject,
                        dropdownColor: AppColors.surface,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        items: _userSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSubject = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Topic Input
                  const Text('Topic / Chapter Concept', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _topicController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Thermodynamics, Mitochondria, Taylor Series...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Difficulty Chips
                  const Text('Difficulty Level', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['easy', 'medium', 'hard'].map((d) {
                      final isSel = _selectedDifficulty == d;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Center(child: Text(d.toUpperCase())),
                            selected: isSel,
                            selectedColor: AppColors.accentCyan.withOpacity(0.3),
                            backgroundColor: Colors.white.withOpacity(0.06),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSel ? AppColors.accentCyan : AppColors.textMuted,
                            ),
                            onSelected: (_) => setState(() => _selectedDifficulty = d),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // Start Quiz Button
                  if (quizState.isGenerating)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppColors.accentCyan),
                          SizedBox(height: 12),
                          Text('Sage AI is formulating exam questions...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    GlassButton(
                      isPrimary: true,
                      width: double.infinity,
                      onPressed: _generateAndStartQuiz,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt, size: 20),
                          SizedBox(width: 8),
                          Text('Generate & Start AI Quiz'),
                        ],
                      ),
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
