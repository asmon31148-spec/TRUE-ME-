import '../services/offline_cache_service.dart';
import 'cognitive/app_capabilities_manifest.dart';
import 'cognitive/student_cognitive_profile.dart';
import 'syllabus_service.dart';

class BuiltSageContext {
  final String systemPrompt;
  final List<String> retrievedExcerpts;
  final String? citationSource;
  final String? syllabusSummary;

  const BuiltSageContext({
    required this.systemPrompt,
    required this.retrievedExcerpts,
    this.citationSource,
    this.syllabusSummary,
  });
}

/// Unified Sage Context Builder shared across Global Chat, Subject Chat, and Study flows.
/// Ensures every AI request receives consistent student profile, syllabus hierarchy,
/// grounded source evidence, and capability manifest regardless of whether RAG hits.
class SageContextBuilder {
  SageContextBuilder._();

  static BuiltSageContext build({
    required String studentName,
    String? subject,
    String? notebookId,
    List<String> retrievedExcerpts = const [],
    String? citationSource,
  }) {
    final effectiveSubject = subject?.trim() ?? '';
    StudentCognitiveProfile? cognitiveProfile;
    try {
      cognitiveProfile = StudentCognitiveProfile.buildLive(
        subjectScope: effectiveSubject.isNotEmpty ? effectiveSubject : null,
      );
    } catch (_) {}
    final cognitiveContext = cognitiveProfile?.toSageContextString() ??
        'Student Profile: Initialized (no local quiz/flashcard history yet).';
    final manifest = AppCapabilitiesManifest.manifestPrompt;

    String? syllabusSummary;
    if (notebookId != null && notebookId.isNotEmpty) {
      final nodes = SyllabusService.getSyllabusNodes(notebookId);
      if (nodes.isNotEmpty) {
        final stats = SyllabusService.computeCoverageStats(notebookId);
        final topUnits = nodes
            .where((n) => n['nodeType'] == 'unit' || n['nodeType'] == 'topic')
            .take(12)
            .map((n) => '- ${n['title']} (${n['status'] ?? 'pending'})')
            .join('\n');
        syllabusSummary =
            'Syllabus Coverage: ${stats['completed']}/${stats['total']} (${stats['percent']}%)\n$topUnits';
      }
    }

    String progressSummary = '';
    if (effectiveSubject.isNotEmpty) {
      try {
        progressSummary =
            OfflineCacheService.getSubjectProgressSummary(effectiveSubject, notebookId: notebookId);
      } catch (_) {}
    }

    final scopeInstruction = effectiveSubject.isNotEmpty
        ? 'You are scoped to the subject "$effectiveSubject". Stay grounded in "$effectiveSubject" and never leak another subject\'s data.\n'
            '${progressSummary.isNotEmpty ? 'Student Progress in $effectiveSubject:\n$progressSummary\n' : ''}'
            '${syllabusSummary != null ? '$syllabusSummary\n' : ''}'
        : 'General cross-subject study mentor mode.';

    final evidenceBlock = retrievedExcerpts.isNotEmpty
        ? '\n### VERIFIED SOURCE EXCERPTS (Primary Grounding):\n${retrievedExcerpts.join('\n\n---\n\n')}\n'
            'Distinguish verified source facts from general academic explanation. Never fabricate citations or page numbers.'
        : '\n### SOURCE STATUS:\nNo matching uploaded source excerpt was retrieved for this query. '
            'Be honest if a detail is general knowledge rather than from the student\'s uploaded notes.';

    final tierName =
        (cognitiveProfile?.activeSubjectTier ?? cognitiveProfile?.overallTier)
            ?.name
            .toUpperCase() ??
        'INTERMEDIATE';
    final systemPrompt = '''
You are Sage, the autonomous cognitive study companion, diagnostic mentor, and academic co-pilot for $studentName in the True Me app.
$scopeInstruction
$cognitiveContext
$evidenceBlock

$manifest

### RESPONSE DIRECTIVES:
- Meet the student at their verified cognitive level ($tierName) and syllabus depth.
- When you detect gaps or the student asks for study materials, recommend concrete action and append:
  [ACTION: export_pdf|export_docx|export_pptx|quiz|flashcards|mindmap|explainer|schedule|voice_tutor | <short topic>]
- Format with clean ## headings and high-yield bullet points (- ).
- CRITICAL: NEVER output raw #### headings or markdown pipe tables (| col |) in chat replies.
''';

    return BuiltSageContext(
      systemPrompt: systemPrompt,
      retrievedExcerpts: retrievedExcerpts,
      citationSource: citationSource,
      syllabusSummary: syllabusSummary,
    );
  }
}
