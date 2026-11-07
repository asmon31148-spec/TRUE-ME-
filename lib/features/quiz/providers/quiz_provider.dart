import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/models/quiz_model.dart';

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

  /// Generates an adaptive quiz from study notes using Groq 8B.
  Future<void> generateQuiz({
    required String notebookId,
    required String subject,
    required String topic,
    required String content,
    String difficulty = 'medium',
    int count = 5,
  }) async {
    state = state.copyWith(isGenerating: true, error: null);

    try {
      final jsonString = await _aiRouter.generateQuiz(
        content: content,
        count: count,
        difficulty: difficulty,
      );

      final Map<String, dynamic> data = jsonDecode(jsonString);
      final rawQuestions = data['questions'] as List<dynamic>? ?? [];

      final List<QuizQuestionModel> questions = [];
      for (int i = 0; i < rawQuestions.length; i++) {
        final q = rawQuestions[i];
        questions.add(
          QuizQuestionModel(
            id: 'q_${DateTime.now().millisecondsSinceEpoch}_$i',
            question: q['question'] as String? ?? 'Question',
            options: List<String>.from(q['options'] ?? const []),
            correctOptionIndex: (q['correctOptionIndex'] as num?)?.toInt() ?? 0,
            explanation: q['explanation'] as String? ?? '',
          ),
        );
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

      state = state.copyWith(
        currentQuiz: quiz,
        isGenerating: false,
        currentQuestionIndex: 0,
        correctCount: 0,
        hasSubmitted: false,
        resetSelection: true,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  void selectOption(int index) {
    if (state.hasSubmitted) return;
    state = state.copyWith(selectedOptionIndex: index);
  }

  void submitAnswer() {
    if (state.selectedOptionIndex == null || state.currentQuiz == null) return;

    final currentQ = state.currentQuiz!.questions[state.currentQuestionIndex];
    final isCorrect = state.selectedOptionIndex == currentQ.correctOptionIndex;

    state = state.copyWith(
      hasSubmitted: true,
      correctCount: isCorrect ? state.correctCount + 1 : state.correctCount,
    );
  }

  void nextQuestion() {
    if (state.currentQuiz == null) return;

    if (state.currentQuestionIndex < state.currentQuiz!.questions.length - 1) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
        hasSubmitted: false,
        resetSelection: true,
      );
    }
  }
}

final quizProvider = StateNotifierProvider<QuizNotifier, QuizState>((ref) {
  return QuizNotifier(aiRouter: ref.watch(aiRouterProvider));
});
