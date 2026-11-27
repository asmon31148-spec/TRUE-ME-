import '../../features/export/services/document_generation_service.dart';

enum SageScopeMode { globalSage, subjectSage }

enum SageIntentType {
  explain,
  answer,
  summarize,
  extract,
  compare,
  quiz,
  flashcards,
  mindmap,
  explainer,
  exportPdf,
  exportDocx,
  exportPptx,
  schedule,
  voiceTutor,
}

enum SourcePriority { teacherNotesFirst, syllabusFirst, pyqFirst, balanced }

/// Structured orchestration plan produced before retrieval/generation (SAGE-004).
class SageIntentPlan {
  final SageIntentType intent;
  final SageScopeMode scopeMode;
  final SourcePriority sourcePriority;
  final String topic;
  final String? explicitStyleId;
  final bool needsClarification;
  final String? clarificationQuestion;

  const SageIntentPlan({
    required this.intent,
    required this.scopeMode,
    required this.sourcePriority,
    required this.topic,
    this.explicitStyleId,
    this.needsClarification = false,
    this.clarificationQuestion,
  });

  bool get isDocumentExport =>
      intent == SageIntentType.exportPdf ||
      intent == SageIntentType.exportDocx ||
      intent == SageIntentType.exportPptx;
}

/// SAGE-004 Intent Understanding & Orchestration layer.
class SageOrchestrator {
  SageOrchestrator._();

  static SageIntentPlan classify({
    required String query,
    String? notebookId,
    String? subject,
  }) {
    final q = query.trim();
    final lower = q.toLowerCase();
    final hasSubject = (notebookId != null && notebookId.trim().isNotEmpty) ||
        (subject != null && subject.trim().isNotEmpty);
    final scopeMode =
        hasSubject ? SageScopeMode.subjectSage : SageScopeMode.globalSage;

    // 1. Source priority
    final SourcePriority priority;
    if (RegExp(r'\b(teacher|class notes|lecture)\b').hasMatch(lower)) {
      priority = SourcePriority.teacherNotesFirst;
    } else if (RegExp(r'\b(syllabus|unit|curriculum)\b').hasMatch(lower)) {
      priority = SourcePriority.syllabusFirst;
    } else if (RegExp(r'\b(pyq|previous year|past paper|exam question)\b')
        .hasMatch(lower)) {
      priority = SourcePriority.pyqFirst;
    } else {
      priority = SourcePriority.balanced;
    }

    // 2. Intent classification
    SageIntentType intent = SageIntentType.answer;
    String? formatForStyle;

    if (RegExp(r'\b(pdf|study sheet)\b').hasMatch(lower) &&
        RegExp(r'\b(make|create|export|give|provide|convert|generate|save|download|as a|into)\b')
            .hasMatch(lower)) {
      intent = SageIntentType.exportPdf;
      formatForStyle = 'pdf';
    } else if (RegExp(r'\b(docx|word doc|word file|word document)\b').hasMatch(lower)) {
      intent = SageIntentType.exportDocx;
      formatForStyle = 'docx';
    } else if (RegExp(r'\b(pptx|powerpoint|ppt|slides|presentation)\b').hasMatch(lower) &&
        RegExp(r'\b(make|create|export|give|provide|convert|generate|build)\b')
            .hasMatch(lower)) {
      intent = SageIntentType.exportPptx;
      formatForStyle = 'pptx';
    } else if (RegExp(r'\b(mind ?map|concept map)\b').hasMatch(lower)) {
      intent = SageIntentType.mindmap;
    } else if (RegExp(r'\b(flashcard|flash card|cards)\b').hasMatch(lower) &&
        RegExp(r'\b(make|create|generate|build|give|open|practice|review)\b')
            .hasMatch(lower)) {
      intent = SageIntentType.flashcards;
    } else if (RegExp(r'\b(quiz|test me|mcq|practice questions)\b').hasMatch(lower)) {
      intent = SageIntentType.quiz;
    } else if (RegExp(r'\b(audio explainer|narrated|podcast|listen)\b').hasMatch(lower)) {
      intent = SageIntentType.explainer;
    } else if (RegExp(r'\b(schedule|today.?s plan|add task|study plan)\b').hasMatch(lower) &&
        RegExp(r'\b(add|schedule|put|plan)\b').hasMatch(lower)) {
      intent = SageIntentType.schedule;
    } else if (RegExp(r'\b(voice tutor|live tutor|oral exam|talk with sage|speak with sage|voice mode)\b')
            .hasMatch(lower) ||
        (RegExp(r'\b(talk|speak|voice)\b').hasMatch(lower) &&
            RegExp(r'\b(sage|tutor|me|practice)\b').hasMatch(lower))) {
      intent = SageIntentType.voiceTutor;
    } else if (RegExp(r'\b(compare|difference between|versus|vs\.?)\b').hasMatch(lower)) {
      intent = SageIntentType.compare;
    } else if (RegExp(r'\b(summari[sz]e|summary|tl;dr|recap)\b').hasMatch(lower)) {
      intent = SageIntentType.summarize;
    } else if (RegExp(r'\b(extract|list all|find all)\b').hasMatch(lower)) {
      intent = SageIntentType.extract;
    } else if (RegExp(r'\b(explain|what is|how does|why does)\b').hasMatch(lower)) {
      intent = SageIntentType.explain;
    }

    // 3. Carry explicit user style constraint
    final explicitStyleId = formatForStyle != null
        ? DocumentGenerationService.detectExplicitStyleId(q, formatForStyle)
        : null;

    // 4. Clarification check when user asks for an artifact with no subject and no topic
    final isArtifactIntent = formatForStyle != null ||
        intent == SageIntentType.quiz ||
        intent == SageIntentType.flashcards ||
        intent == SageIntentType.mindmap;
    final strippedTopic = q
        .replaceAll(
          RegExp(
            r'\b(make|create|generate|build|export|give|me|a|an|the|pdf|docx|pptx|ppt|slides|presentation|quiz|flashcards|mind ?map|please)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    final needsClarification =
        isArtifactIntent && !hasSubject && strippedTopic.length < 3;

    return SageIntentPlan(
      intent: intent,
      scopeMode: scopeMode,
      sourcePriority: priority,
      topic: strippedTopic.isNotEmpty
          ? strippedTopic
          : (subject?.trim().isNotEmpty == true ? subject!.trim() : 'Study'),
      explicitStyleId: explicitStyleId,
      needsClarification: needsClarification,
      clarificationQuestion: needsClarification
          ? 'Which subject or topic would you like me to create this for?'
          : null,
    );
  }
}
