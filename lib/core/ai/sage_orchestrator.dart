import '../../features/export/services/document_generation_service.dart';
import '../services/offline_cache_service.dart';
import 'syllabus_service.dart';

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
  final SageIntentType? secondaryOutputIntent; // e.g. mindmap -> exportPdf
  final SageScopeMode scopeMode;
  final SourcePriority sourcePriority;
  final String topic;
  final String? resolvedNotebookId;
  final String? resolvedSubject;
  final String? explicitStyleId;
  final bool needsClarification;
  final String? clarificationQuestion;
  final List<String> clarificationOptions;

  const SageIntentPlan({
    required this.intent,
    this.secondaryOutputIntent,
    required this.scopeMode,
    required this.sourcePriority,
    required this.topic,
    this.resolvedNotebookId,
    this.resolvedSubject,
    this.explicitStyleId,
    this.needsClarification = false,
    this.clarificationQuestion,
    this.clarificationOptions = const [],
  });

  bool get isCompound => secondaryOutputIntent != null;

  bool get isDocumentExport =>
      intent == SageIntentType.exportPdf ||
      intent == SageIntentType.exportDocx ||
      intent == SageIntentType.exportPptx ||
      secondaryOutputIntent == SageIntentType.exportPdf ||
      secondaryOutputIntent == SageIntentType.exportDocx ||
      secondaryOutputIntent == SageIntentType.exportPptx;
}

/// SAGE-004 Intent Understanding, Cross-App Subject Resolution & Compound Orchestration.
class SageOrchestrator {
  SageOrchestrator._();

  /// Resolves a subject/notebook from natural language even when invoked from Main Sage.
  static Map<String, dynamic>? resolveSubjectFromQuery(
    String query, {
    List<Map<String, dynamic>>? overrideNotebooks,
  }) {
    final lower = query.toLowerCase();
    final notebooks = overrideNotebooks ?? OfflineCacheService.getAllCachedNotebooks();
    Map<String, dynamic>? best;
    int bestLen = 0;

    for (final nb in notebooks) {
      final title = (nb['title'] as String? ?? '').trim();
      if (title.length < 2) continue;
      final tLower = title.toLowerCase();
      if (lower.contains(tLower) && tLower.length > bestLen) {
        best = nb;
        bestLen = tLower.length;
      }
    }
    return best;
  }

  static SageIntentPlan classify({
    required String query,
    String? notebookId,
    String? subject,
    List<Map<String, dynamic>>? overrideNotebooks,
    List<Map<String, dynamic>>? overrideSyllabusNodes,
    List<Map<String, dynamic>>? overrideDocs,
  }) {
    final q = query.trim();
    final lower = q.toLowerCase();

    // Auto-resolve subject from query if not already scoped
    String? resolvedNbId = (notebookId != null && notebookId.trim().isNotEmpty)
        ? notebookId.trim()
        : null;
    String? resolvedSub = (subject != null && subject.trim().isNotEmpty)
        ? subject.trim()
        : null;

    if (resolvedNbId == null) {
      final matchedNb = resolveSubjectFromQuery(q, overrideNotebooks: overrideNotebooks);
      if (matchedNb != null) {
        resolvedNbId = matchedNb['id']?.toString();
        resolvedSub ??= matchedNb['title']?.toString();
      }
    }

    final hasSubject = (resolvedNbId != null && resolvedNbId.isNotEmpty) ||
        (resolvedSub != null && resolvedSub.isNotEmpty);
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

    // 2. Detect primary study tool & secondary (compound) output format
    final wantsMindmap = RegExp(r'\b(mind ?map|concept map)\b').hasMatch(lower);
    final wantsQuiz = RegExp(r'\b(quiz|test me|mcq|practice questions)\b').hasMatch(lower);
    final mentionsFlashcards = RegExp(r'\b(flashcard|flash card|cards)\b').hasMatch(lower);
    final hasActionVerb = RegExp(
      r'\b(make|create|export|give|provide|convert|generate|save|download|send|build|open|practice|review|as a|into)\b',
    ).hasMatch(lower);
    final hasStudyTool = wantsMindmap || wantsQuiz || RegExp(r'\b(flashcards?|flash cards?)\b').hasMatch(lower);

    final wantsPdf = RegExp(r'\b(pdf|study sheet)\b').hasMatch(lower) &&
        (hasActionVerb || hasStudyTool);
    final wantsDocx = RegExp(r'\b(docx|word doc|word file|word document)\b').hasMatch(lower);
    final wantsPptx = RegExp(r'\b(pptx|powerpoint|ppt|slides|presentation)\b').hasMatch(lower) &&
        (hasActionVerb || hasStudyTool);

    final SageIntentType? exportFormatIntent = wantsPdf
        ? SageIntentType.exportPdf
        : (wantsDocx
            ? SageIntentType.exportDocx
            : (wantsPptx ? SageIntentType.exportPptx : null));

    final wantsFlashcards = mentionsFlashcards &&
        (hasActionVerb || exportFormatIntent != null);

    SageIntentType intent = SageIntentType.answer;
    SageIntentType? secondaryOutputIntent;

    if (wantsMindmap) {
      intent = SageIntentType.mindmap;
      secondaryOutputIntent = exportFormatIntent;
    } else if (wantsQuiz) {
      intent = SageIntentType.quiz;
      secondaryOutputIntent = exportFormatIntent;
    } else if (wantsFlashcards) {
      intent = SageIntentType.flashcards;
      secondaryOutputIntent = exportFormatIntent;
    } else if (exportFormatIntent != null) {
      intent = exportFormatIntent;
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

    final formatForStyle = exportFormatIntent == SageIntentType.exportPdf
        ? 'pdf'
        : (exportFormatIntent == SageIntentType.exportDocx
            ? 'docx'
            : (exportFormatIntent == SageIntentType.exportPptx ? 'pptx' : null));
    final explicitStyleId = formatForStyle != null
        ? DocumentGenerationService.detectExplicitStyleId(q, formatForStyle)
        : null;

    // 3. Topic extraction
    var strippedTopic = q
        .replaceAll(
          RegExp(
            r'\b(make|create|generate|build|export|give|send|provide|convert|save|download|me|a|an|the|of|my|for|on|in|and|as|into|to|subject|pdf|docx|pptx|ppt|slides|presentation|quiz|flashcards|mind ?map|concept map|please)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (resolvedSub != null &&
        strippedTopic.toLowerCase() == resolvedSub.toLowerCase()) {
      strippedTopic = '';
    }

    // 4. Smart Clarification:
    // Case A: Artifact requested with no subject and no topic ("make a ppt")
    final isArtifactIntent = exportFormatIntent != null ||
        wantsMindmap ||
        wantsQuiz ||
        wantsFlashcards;

    if (isArtifactIntent && !hasSubject && strippedTopic.length < 3) {
      return SageIntentPlan(
        intent: intent,
        secondaryOutputIntent: secondaryOutputIntent,
        scopeMode: scopeMode,
        sourcePriority: priority,
        topic: 'Study',
        explicitStyleId: explicitStyleId,
        needsClarification: true,
        clarificationQuestion: 'Which subject or topic would you like me to create this for?',
      );
    }

    // Case B: Broad subject-level compound/mindmap/export request where the subject
    // has multiple syllabus topics or files and user hasn't specified "full/all/entire" or a subtopic
    final explicitlyBroad = RegExp(
      r'\b(full|entire|whole|complete|all units|all chapters|everything|overview)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (isArtifactIntent &&
        resolvedNbId != null &&
        resolvedSub != null &&
        strippedTopic.isEmpty &&
        !explicitlyBroad) {
      final nodes = (overrideSyllabusNodes ?? SyllabusService.getSyllabusNodes(resolvedNbId))
          .where((n) => n['nodeType'] == 'unit' || n['nodeType'] == 'topic')
          .toList();
      final docs = overrideDocs ?? OfflineCacheService.getNotebookDocuments(resolvedNbId);

      if (nodes.length >= 2 || docs.length >= 2) {
        final outSuffix = wantsPdf ? 'PDF' : (wantsDocx ? 'Word Doc' : (wantsPptx ? 'Slides' : ''));
        final actionPhrase = wantsMindmap
            ? 'Mind Map${outSuffix.isNotEmpty ? ' $outSuffix' : ''}'
            : (wantsQuiz
                ? 'Quiz${outSuffix.isNotEmpty ? ' $outSuffix' : ''}'
                : (wantsFlashcards
                    ? 'Flashcards${outSuffix.isNotEmpty ? ' $outSuffix' : ''}'
                    : (outSuffix.isNotEmpty ? outSuffix : 'study material')));
        final options = <String>[
          'Full $resolvedSub $actionPhrase (complete syllabus)',
          ...nodes.take(2).map((n) => '${n['title']} — $resolvedSub $actionPhrase'),
          if (nodes.isEmpty)
            ...docs.take(2).map((d) => '${d['fileName']} — $resolvedSub $actionPhrase'),
        ];
        return SageIntentPlan(
          intent: intent,
          secondaryOutputIntent: secondaryOutputIntent,
          scopeMode: scopeMode,
          sourcePriority: priority,
          topic: resolvedSub,
          resolvedNotebookId: resolvedNbId,
          resolvedSubject: resolvedSub,
          explicitStyleId: explicitStyleId,
          needsClarification: true,
          clarificationQuestion:
              'I found multiple topics/sources in **$resolvedSub**. Should I build the **$actionPhrase** for the full subject or focus on a specific unit/file?',
          clarificationOptions: options,
        );
      }
    }

    return SageIntentPlan(
      intent: intent,
      secondaryOutputIntent: secondaryOutputIntent,
      scopeMode: scopeMode,
      sourcePriority: priority,
      topic: strippedTopic.isNotEmpty
          ? strippedTopic
          : (resolvedSub ?? 'Study'),
      resolvedNotebookId: resolvedNbId,
      resolvedSubject: resolvedSub,
      explicitStyleId: explicitStyleId,
    );
  }
}
