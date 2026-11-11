import '../models/study_plan_model.dart';
import '../models/user_model.dart';
import 'ai_router.dart';

class SageAgent {
  final AiRouter _aiRouter;

  SageAgent({AiRouter? aiRouter}) : _aiRouter = aiRouter ?? AiRouter();

  /// Sage System Prompt with live student context injection
  String _buildSystemPrompt({
    required UserModel user,
    required int daysToExam,
    required List<String> weakTopics,
  }) {
    return '''
You are Sage — the personal AI study coach for ${user.name} inside True Me.
You know everything about this student.

Student Profile:
- Name: ${user.name}
- Learning Style: ${user.learningStyle ?? 'Visual & Practical'}
- Goal: ${user.studyGoal ?? 'Master all core concepts'}
- Days Until Exam: $daysToExam
- Subjects: ${user.subjects.join(', ')}
- Weak / Decaying Topics: ${weakTopics.join(', ')}

Personality: Encouraging, direct, specific — like an elite senior student mentor.
Never give generic advice. Always prioritize weak topics before exam countdown runs out.
''';
  }

  /// Evaluates quiz score and returns recommended difficulty adjustment.
  /// Quiz Score > 85%  -> Raise difficulty
  /// Quiz Score 70–85% -> Keep same level
  /// Quiz Score 50–70% -> Slight reduction, more practice
  /// Quiz Score < 50%  -> Recommend 10-min explainer video before re-test
  String evaluateDifficulty({required double scorePercentage}) {
    if (scorePercentage > 85) return 'hard';
    if (scorePercentage >= 70) return 'medium';
    if (scorePercentage >= 50) return 'practice';
    return 'explainer_first';
  }

  /// Calculates exam urgency multiplier.
  double calculateExamUrgency({required int daysToExam}) {
    if (daysToExam <= 3) return 3.0; // Critical revision mode
    if (daysToExam <= 7) return 2.2;
    if (daysToExam <= 14) return 1.8;
    if (daysToExam <= 30) return 1.4;
    return 1.0;
  }

  /// Generates an optimized Daily Study Plan.
  Future<DailyStudyPlanModel> generateDailyStudyPlan({
    required UserModel user,
    required List<String> weakTopics,
    int targetTotalMinutes = 60,
  }) async {
    final now = DateTime.now();
    final examDate = user.examDate ?? now.add(const Duration(days: 45));
    final daysToExam = examDate.difference(now).inDays;

    final systemPrompt = _buildSystemPrompt(
      user: user,
      daysToExam: daysToExam,
      weakTopics: weakTopics,
    );

    final userPrompt = '''
Generate today's optimal study schedule totaling $targetTotalMinutes minutes.
Format your response strictly as JSON with this schema:
{
  "motivationalMessage": "Short, specific 1-2 sentence morning brief addressing their progress and urgency",
  "sessions": [
    {
      "id": "s1",
      "subject": "Name of subject",
      "topic": "Specific focused topic",
      "activityType": "flashcard|quiz|chat|reading|explainer",
      "targetMinutes": 20
    }
  ]
}
''';

    try {
      final responseText = await _aiRouter.executeHeavyReasoning(
        prompt: userPrompt,
        systemPrompt: systemPrompt,
        jsonMode: true,
      );

      final json = AiRouter.parseJsonObject(responseText);
      final rawSessions = json['sessions'] as List<dynamic>? ?? [];

      final sessions = rawSessions
          .map((s) => StudySessionPlanItem.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList();

      return DailyStudyPlanModel(
        date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        userId: user.id,
        sessions: sessions,
        totalTargetMinutes: targetTotalMinutes,
        motivationalMessage: json['motivationalMessage'] as String? ??
            'Ready to master today\'s study targets with Sage?',
        createdAt: now,
      );
    } catch (_) {
      // Safe fallback plan if offline or during API transition
      return DailyStudyPlanModel(
        date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        userId: user.id,
        sessions: [
          StudySessionPlanItem(
            id: 's1',
            subject: user.subjects.isNotEmpty ? user.subjects.first : 'General',
            topic: weakTopics.isNotEmpty ? weakTopics.first : 'Active Recall & Key Equations',
            activityType: 'flashcard',
            targetMinutes: 25,
          ),
          StudySessionPlanItem(
            id: 's2',
            subject: user.subjects.length > 1 ? user.subjects[1] : 'General',
            topic: 'Adaptive Concept Quiz',
            activityType: 'quiz',
            targetMinutes: 20,
          ),
        ],
        totalTargetMinutes: 45,
        motivationalMessage:
            'Good morning ${user.name}! Let\'s stay consistent with 45 minutes of targeted study today.',
        createdAt: now,
      );
    }
  }

  /// Automated 6:00 AM Morning Run workflow
  Future<Map<String, dynamic>> runDailyMorningAnalysis({
    required UserModel user,
    required List<String> weakTopics,
  }) async {
    final plan = await generateDailyStudyPlan(
      user: user,
      weakTopics: weakTopics,
      targetTotalMinutes: 60,
    );

    return {
      'plan': plan,
      'notificationTitle': 'Sage Morning Brief 🧠',
      'notificationBody': plan.motivationalMessage,
      'scheduledAt': DateTime.now(),
    };
  }
}
