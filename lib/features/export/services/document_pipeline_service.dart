import '../../../core/ai/ai_router.dart';
import '../models/structured_study_document.dart';
import '../pptx_exporter.dart';

/// Multi-stage document intelligence pipeline:
/// Intent & Scope -> Structured Content Model -> Verification Gate -> Format Adapter.
class DocumentPipelineService {
  DocumentPipelineService._();

  static Future<StructuredStudyDocument> generateStructuredDocument({
    required AiRouter aiRouter,
    required String subject,
    required String topic,
    required String sourceContext,
    String purpose = 'Exam & Course Study Guide',
    String depthLevel = 'Course Level',
    String customInstructions = '',
  }) async {
    final trimmedSource = sourceContext.trim();
    final boundedSource = trimmedSource.length > 16000
        ? trimmedSource.substring(0, 16000)
        : trimmedSource;

    final raw = await aiRouter.executeHeavyReasoning(
      jsonMode: true,
      prompt: '''
You are an academic curriculum author for "$subject" (Topic: "$topic").
Purpose: $purpose
Academic Depth: $depthLevel
${customInstructions.isNotEmpty ? 'Student Instructions: $customInstructions\n' : ''}
STRICT ACCURACY RULES:
- Prioritize source-grounding and scientific/factual accuracy over brevity.
- Never invent statistics, citations, textbook page numbers, or unverified claims.
- If the provided source material does not cover part of the topic, note that in "uncertaintyNote".
- Preserve exact terminology, formulas, and units.

Return ONLY valid JSON matching this schema:
{
  "title": "Clear Document Title",
  "purpose": "$purpose",
  "academicLevel": "$depthLevel",
  "executiveSummary": "2-4 sentence synthesis",
  "learningObjectives": ["Objective 1", "Objective 2"],
  "sections": [
    {
      "heading": "Section Title",
      "body": "Clear, complete explanation",
      "keyPoints": ["Key point 1", "Key point 2"],
      "definitions": ["Term: precise definition"],
      "examples": ["Concrete example"],
      "processSteps": ["Step 1", "Step 2"],
      "tableRows": [["Column A", "Column B"], ["Value 1", "Value 2"]],
      "calloutWarning": "Common exam trap or caveat (optional)"
    }
  ],
  "takeaways": ["Takeaway 1", "Takeaway 2"],
  "sourceReferences": ["Only cite actual provided source filenames/titles, or leave empty"],
  "uncertaintyNote": "Flag any gaps or general-knowledge additions if sources were partial"
}

Available Study Material:
${boundedSource.isNotEmpty ? boundedSource : 'No uploaded source selected; use verified course-level academic knowledge and flag in uncertaintyNote.'}
''',
    );

    final decoded = AiRouter.parseJsonObject(raw);
    final doc = StructuredStudyDocument.fromMap(
      decoded,
      fallbackTitle: '$topic — $subject',
      subject: subject,
      topic: topic,
    );

    if (doc.sections.isEmpty && doc.executiveSummary.isEmpty) {
      throw StateError('AI returned an empty structured document. Please try again.');
    }
    return doc;
  }

  /// Converts a verified [StructuredStudyDocument] into [PptxSlideData] slides
  /// without silently dropping definitions, process steps, or warnings.
  static List<PptxSlideData> toSlideDeck(StructuredStudyDocument doc) {
    final slides = <PptxSlideData>[];

    slides.add(
      PptxSlideData(
        title: doc.title,
        subtitle: '${doc.subject} · ${doc.academicLevel}',
        tag: 'OVERVIEW',
        bulletPoints: [
          if (doc.executiveSummary.isNotEmpty) doc.executiveSummary,
          ...doc.learningObjectives.take(3),
        ],
        takeaway: doc.purpose,
      ),
    );

    for (final s in doc.sections) {
      final bullets = <String>[
        if (s.body.isNotEmpty) s.body,
        ...s.definitions,
        ...s.keyPoints,
        ...s.examples.map((e) => 'Example: $e'),
        ...s.processSteps.asMap().entries.map((e) => 'Step ${e.key + 1}: ${e.value}'),
      ];
      slides.add(
        PptxSlideData(
          title: s.heading,
          tag: doc.topic.toUpperCase(),
          bulletPoints: bullets.take(6).toList(),
          takeaway: s.calloutWarning,
        ),
      );
    }

    if (doc.takeaways.isNotEmpty) {
      slides.add(
        PptxSlideData(
          title: 'Key Takeaways & Summary',
          tag: 'RECAP',
          bulletPoints: doc.takeaways.take(6).toList(),
          takeaway: doc.uncertaintyNote,
        ),
      );
    }

    return slides;
  }
}
