import 'dart:convert';
import '../../../core/ai/ai_router.dart';
import '../models/explainer_script_model.dart';

class ExplainerGenerator {
  final AiRouter _aiRouter;

  ExplainerGenerator({AiRouter? aiRouter}) : _aiRouter = aiRouter ?? AiRouter();

  /// Synthesizes an animated 10-minute video explainer script from student notes.
  Future<ExplainerScriptModel> generateScript({
    required String topic,
    required String notesContent,
  }) async {
    final systemPrompt = '''
You are an award-winning academic video director like 3Blue1Brown or Kurzgesagt.
Break down this topic into a 5-scene animated explainer script totaling 10 minutes (600 seconds).
Return ONLY valid JSON matching this schema:
{
  "title": "Engaging Video Title",
  "topic": "$topic",
  "totalDurationSeconds": 600,
  "scenes": [
    {
      "sceneNumber": 1,
      "title": "Scene Name",
      "narrationText": "Verbal explanation for text-to-speech to read aloud",
      "durationSeconds": 120,
      "animationType": "diagram|formula|flowchart|bulletReveal",
      "elements": ["Key Term 1", "Key Term 2", "Diagram Node"]
    }
  ]
}
''';

    try {
      final jsonString = await _aiRouter.executeHeavyReasoning(
        prompt: 'Topic: $topic\n\nStudy Notes:\n$notesContent',
        systemPrompt: systemPrompt,
        jsonMode: true,
      );

      final Map<String, dynamic> data = jsonDecode(jsonString);
      return ExplainerScriptModel.fromMap(data);
    } catch (_) {
      // Safe fallback default scene script
      return ExplainerScriptModel(
        title: 'Mastering $topic',
        topic: topic,
        scenes: [
          ExplainerSceneModel(
            sceneNumber: 1,
            title: 'Foundational Intuition',
            narrationText:
                'Welcome! Today we are deconstructing $topic. Let us understand the core motivation behind this concept and why it matters in computing.',
            durationSeconds: 120,
            animationType: AnimationType.diagram,
            elements: ['Core Motivation', 'Problem Statement', 'Constraints'],
          ),
          ExplainerSceneModel(
            sceneNumber: 2,
            title: 'Mechanisms & Equations',
            narrationText:
                'Now let us trace the underlying equations and algorithmic transitions step by step.',
            durationSeconds: 180,
            animationType: AnimationType.formula,
            elements: ['Vector Allocation', 'Available Resources', 'Safe Sequence'],
          ),
        ],
      );
    }
  }
}
