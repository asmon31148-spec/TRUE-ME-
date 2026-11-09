import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/models/quiz_model.dart';
import '../../../core/services/offline_cache_service.dart';

class QuizState {
  final QuizModel? currentQuiz;
  final bool isGenerating;
  final int currentQuestionIndex;
  final int? selectedOptionIndex;
  final bool hasSubmitted;
  final int correctCount;
  final String? error;

  const QuizState({
    this.currentQuiz,
    this.isGenerating = false,
    this.currentQuestionIndex = 0,
    this.selectedOptionIndex,
    this.hasSubmitted = false,
    this.correctCount = 0,
    this.error,
  });

  QuizState copyWith({
    QuizModel? currentQuiz,
    bool? isGenerating,
    int? currentQuestionIndex,
    int? selectedOptionIndex,
    bool? hasSubmitted,
    int? correctCount,
    String? error,
    bool resetSelection = false,
  }) {
    return QuizState(
      currentQuiz: currentQuiz ?? this.currentQuiz,
      isGenerating: isGenerating ?? this.isGenerating,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedOptionIndex:
          resetSelection ? null : (selectedOptionIndex ?? this.selectedOptionIndex),
      hasSubmitted: hasSubmitted ?? this.hasSubmitted,
      correctCount: correctCount ?? this.correctCount,
      error: error,
    );
  }
}

class QuizNotifier extends StateNotifier<QuizState> {
  final AiRouter _aiRouter;

  QuizNotifier({required AiRouter aiRouter})
      : _aiRouter = aiRouter,
        super(const QuizState());

  /// Generates an adaptive quiz from study notes using Gemini or Groq.
  Future<void> generateQuiz({
    required String notebookId,
    required String subject,
    required String topic,
    String? content,
    String difficulty = 'medium',
    int count = 5,
  }) async {
    state = state.copyWith(isGenerating: true, error: null);

    try {
      final prompt = (content != null && content.trim().isNotEmpty)
          ? content
          : 'High-yield exam review for $subject covering the topic: $topic. Formulate challenging multiple choice questions for a college-level student.';

      final jsonString = await _aiRouter.generateQuiz(
        content: prompt,
        count: count,
        difficulty: difficulty,
      );

      final Map<String, dynamic> data = jsonDecode(jsonString);
      final rawQuestions = data['questions'] as List<dynamic>? ?? [];

      final List<QuizQuestionModel> questions = [];
      for (int i = 0; i < rawQuestions.length; i++) {
        final q = rawQuestions[i];
        final options = List<String>.from(q['options'] ?? const []);
        if (options.length >= 2) {
          questions.add(
            QuizQuestionModel(
              id: 'q_${DateTime.now().millisecondsSinceEpoch}_$i',
              question: q['question'] as String? ?? 'Concept Question',
              options: options,
              correctOptionIndex: ((q['correctOptionIndex'] as num?)?.toInt() ?? 0)
                  .clamp(0, options.length - 1),
              explanation: q['explanation'] as String? ?? 'Grounded in core conceptual definitions.',
            ),
          );
        }
      }

      if (questions.isEmpty) {
        // Dynamic fallback questions tailored to subject
        questions.addAll(_buildFallbackQuestions(subject, topic));
      }

      final quiz = QuizModel(
        id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
        notebookId: notebookId,
        subject: subject,
        topic: topic,
        difficulty: difficulty,
        questions: questions,
        createdAt: DateTime.now(),
      );

      // Cache to Hive
      try {
        await OfflineCacheService.cacheQuiz(quiz.id, quiz.toMap());
      } catch (_) {}

      state = state.copyWith(
        currentQuiz: quiz,
        isGenerating: false,
        currentQuestionIndex: 0,
        selectedOptionIndex: null,
        hasSubmitted: false,
        correctCount: 0,
      );
    } catch (e) {
      // Create subject-specific questions on offline/error
      final fallbackQuestions = _buildFallbackQuestions(subject, topic);
      final quiz = QuizModel(
        id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
        notebookId: notebookId,
        subject: subject,
        topic: topic,
        difficulty: difficulty,
        questions: fallbackQuestions,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        currentQuiz: quiz,
        isGenerating: false,
        currentQuestionIndex: 0,
        selectedOptionIndex: null,
        hasSubmitted: false,
        correctCount: 0,
      );
    }
  }

  List<QuizQuestionModel> _buildFallbackQuestions(String subject, String topic) {
    return [
      QuizQuestionModel(
        id: 'fb_1',
        question: 'In the context of $subject, what is the primary objective of studying $topic?',
        options: [
          'To model and analyze core system dynamics and analytical relationships',
          'To eliminate all theoretical constraints without empirical testing',
          'To bypass the standard axioms of $subject',
          'None of the above',
        ],
        correctOptionIndex: 0,
        explanation: 'Axiomatic foundations in $subject seek to formally model physical, computational, or theoretical behavior under verified constraints.',
      ),
      QuizQuestionModel(
        id: 'fb_2',
        question: 'Which method is standard practice when evaluating problems in $topic?',
        options: [
          'Uncontrolled trial and error',
          'Decomposition into sub-problems and applying conservation/invariant principles',
          'Ignoring boundary and initial conditions',
          'Random sampling without statistical validity',
        ],
        correctOptionIndex: 1,
        explanation: 'Decomposition and invariant verification are foundational across collegiate $subject curricula.',
      ),
    ];
  }

  void selectOption(int index) {
    if (state.hasSubmitted) return;
    state = state.copyWith(selectedOptionIndex: index);
  }

  void submitAnswer() {
    if (state.selectedOptionIndex == null || state.hasSubmitted) return;
    final quiz = state.currentQuiz;
    if (quiz == null) return;

    final currentQ = quiz.questions[state.currentQuestionIndex];
    final isCorrect = state.selectedOptionIndex == currentQ.correctOptionIndex;

    state = state.copyWith(
      hasSubmitted: true,
      correctCount: isCorrect ? state.correctCount + 1 : state.correctCount,
    );
  }

  void nextQuestion() {
    final quiz = state.currentQuiz;
    if (quiz == null) return;

    if (state.currentQuestionIndex < quiz.questions.length - 1) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
        resetSelection: true,
        hasSubmitted: false,
      );
    }
  }

  void resetQuiz() {
    state = state.copyWith(
      currentQuestionIndex: 0,
      resetSelection: true,
      hasSubmitted: false,
      correctCount: 0,
    );
  }
}

final quizProvider = StateNotifierProvider<QuizNotifier, QuizState>((ref) {
  return QuizNotifier(aiRouter: ref.watch(aiRouterProvider));
});
