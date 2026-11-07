enum QuestionType { mcq, trueFalse, fillBlank }

class QuizQuestionModel {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final QuestionType type;

  const QuizQuestionModel({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    this.type = QuestionType.mcq,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'type': type.name,
    };
  }

  factory QuizQuestionModel.fromMap(Map<String, dynamic> map) {
    return QuizQuestionModel(
      id: map['id'] as String? ?? '',
      question: map['question'] as String? ?? '',
      options: List<String>.from(map['options'] ?? const []),
      correctOptionIndex: (map['correctOptionIndex'] as num?)?.toInt() ?? 0,
      explanation: map['explanation'] as String? ?? '',
      type: QuestionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => QuestionType.mcq,
      ),
    );
  }
}

class QuizModel {
  final String id;
  final String notebookId;
  final String subject;
  final String topic;
  final String difficulty; // easy, medium, hard
  final List<QuizQuestionModel> questions;
  final double? score; // Percentage (0 - 100)
  final int? timeTakenSeconds;
  final List<int> wrongAnswerIndices;
  final DateTime createdAt;
  final DateTime? completedAt;

  const QuizModel({
    required this.id,
    required this.notebookId,
    required this.subject,
    required this.topic,
    this.difficulty = 'medium',
    required this.questions,
    this.score,
    this.timeTakenSeconds,
    this.wrongAnswerIndices = const [],
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notebookId': notebookId,
      'subject': subject,
      'topic': topic,
      'difficulty': difficulty,
      'questions': questions.map((q) => q.toMap()).toList(),
      'score': score,
      'timeTakenSeconds': timeTakenSeconds,
      'wrongAnswerIndices': wrongAnswerIndices,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory QuizModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawQuestions = map['questions'] as List<dynamic>? ?? [];
    return QuizModel(
      id: docId,
      notebookId: map['notebookId'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      difficulty: map['difficulty'] as String? ?? 'medium',
      questions: rawQuestions
          .map((q) => QuizQuestionModel.fromMap(Map<String, dynamic>.from(q as Map)))
          .toList(),
      score: (map['score'] as num?)?.toDouble(),
      timeTakenSeconds: (map['timeTakenSeconds'] as num?)?.toInt(),
      wrongAnswerIndices: List<int>.from(map['wrongAnswerIndices'] ?? const []),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'])
          : null,
    );
  }
}
