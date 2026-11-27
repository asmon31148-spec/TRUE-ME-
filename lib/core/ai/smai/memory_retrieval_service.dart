import 'dart:async';
import '../../services/offline_cache_service.dart';
import '../../services/supabase_service.dart';
import 'memory_derivation_service.dart';
import 'memory_event_service.dart';
import 'smai_models.dart';

/// Ownership-first, scope-aware SMAI Retrieval & Context Assembly (Section 9 & 10).
/// Enforces strict separation between [SmaiAiMode.main] (global mentor)
/// and [SmaiAiMode.subject] (strictly scoped to one subjectId).
class MemoryRetrievalService {
  MemoryRetrievalService._();

  static Future<SmaiContextPackage> assembleContext({
    required String query,
    required SmaiAiMode aiMode,
    String? subjectId,
    required String requestIntent,
    String? overrideUserId,
    int tokenBudget = 1800,
  }) async {
    final userId = MemoryEventService.resolveAuthenticatedUserId(overrideUserId);
    final traceId = 'tr_${DateTime.now().millisecondsSinceEpoch}_${query.hashCode.abs()}';

    // Strict subject boundary: Subject AI must never pull another subject's data
    final scopedSubjectId =
        aiMode == SmaiAiMode.subject ? subjectId?.trim() : null;
    if (aiMode == SmaiAiMode.subject &&
        (scopedSubjectId == null || scopedSubjectId.isEmpty)) {
      return SmaiContextPackage(
        studentId: userId,
        aiMode: aiMode,
        requestIntent: requestIntent,
        uncertaintyFlags: const ['No valid subjectId provided for Subject AI.'],
        tokenBudget: tokenBudget,
        retrievalTraceId: traceId,
      );
    }

    // 1. Retrieve scoped memories (approved global facts + scoped subject memories)
    final allMemories = await MemoryDerivationService.getMemories(
      userId,
      subjectId: scopedSubjectId,
      activeOnly: true,
    );

    final goals = allMemories
        .where((m) => m.memoryType == 'goal')
        .map((m) => m.content)
        .take(3)
        .toList();

    final profileFacts = allMemories
        .where((m) => m.memoryType == 'correction' || m.memoryType == 'learning_preference')
        .map((m) => m.content)
        .take(4)
        .toList();

    final queryTerms = query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.length >= 2)
        .toSet();

    // Rank non-goal memories by relevance + confidence + recency
    final relevantMemories = allMemories
        .where((m) => m.memoryType != 'goal')
        .where((m) {
          if (queryTerms.isEmpty) return true;
          final lower = m.content.toLowerCase();
          return queryTerms.any((t) => lower.contains(t)) || m.confidence >= 0.7;
        })
        .take(6)
        .toList();

    // 2. Retrieve topic mastery snapshots (strictly scoped)
    final masterySignals = await MemoryDerivationService.getMasterySnapshots(
      userId,
      subjectId: scopedSubjectId,
    );

    // 3. Lexical search over historical conversation & voice transcript events
    final events = await MemoryEventService.getEvents(
      userId,
      subjectId: scopedSubjectId,
    );

    final List<String> convRefs = [];
    final conversationEvents = events.where((e) =>
        e.eventType == SmaiEventType.conversationMessageCreated ||
        e.eventType == SmaiEventType.conversationVoiceTranscribed);

    for (final ev in conversationEvents) {
      final text = ev.searchText.isNotEmpty
          ? ev.searchText
          : (ev.payload['text']?.toString() ?? '');
      if (text.trim().isEmpty) continue;
      final lower = text.toLowerCase();
      final hits = queryTerms.where((t) => lower.contains(t)).length;
      if (hits > 0 || (queryTerms.isEmpty && convRefs.length < 3)) {
        final modality = ev.eventType == SmaiEventType.conversationVoiceTranscribed
            ? 'Voice'
            : 'Chat';
        final dateStr = ev.occurredAt.toIso8601String().substring(0, 10);
        final clipped = text.length > 160 ? '${text.substring(0, 157)}...' : text;
        convRefs.add('[$modality · $dateStr] $clipped');
      }
      if (convRefs.length >= 4) break;
    }

    // 4. Uncertainty flags if historical recall was requested but no evidence exists
    final List<String> uncertaintyFlags = [];
    final asksAboutPast = RegExp(
      r'\b(remember|earlier|last time|previously|before|we discussed|my mistake)\b',
      caseSensitive: false,
    ).hasMatch(query);
    if (asksAboutPast && convRefs.isEmpty && relevantMemories.isEmpty && masterySignals.isEmpty) {
      uncertaintyFlags.add(
        'No verifiable prior discussion or memory record found for this query.',
      );
    }

    // Also include global user goal from OfflineCacheService if no goal memory yet
    if (goals.isEmpty) {
      final profile = OfflineCacheService.getUserProfile();
      final studyGoal = (profile['studyGoal'] as String? ?? '').trim();
      if (studyGoal.isNotEmpty) goals.add(studyGoal);
    }

    final pkg = SmaiContextPackage(
      studentId: userId,
      aiMode: aiMode,
      subjectId: scopedSubjectId,
      requestIntent: requestIntent,
      currentGoals: goals,
      relevantProfileFacts: profileFacts,
      topicMasterySignals: masterySignals.take(6).toList(),
      recentEvents: events.take(5).toList(),
      retrievedMemories: relevantMemories,
      conversationReferences: convRefs,
      uncertaintyFlags: uncertaintyFlags,
      tokenBudget: tokenBudget,
      retrievalTraceId: traceId,
    );

    unawaited(_logAudit(pkg));
    return pkg;
  }

  static Future<void> _logAudit(SmaiContextPackage pkg) async {
    try {
      final client = SupabaseService.instance.clientOrNull;
      final uid = SupabaseService.instance.authUserId;
      if (client == null || uid == null || uid != pkg.studentId) return;
      await client.from('retrieval_audits').upsert({
        'trace_id': pkg.retrievalTraceId,
        'user_id': pkg.studentId,
        'ai_mode': pkg.aiMode.name,
        if (pkg.subjectId != null) 'subject_id': pkg.subjectId,
        'request_intent': pkg.requestIntent,
        'retrieved_count': pkg.retrievedMemories.length +
            pkg.topicMasterySignals.length +
            pkg.conversationReferences.length,
        'uncertainty_flags': pkg.uncertaintyFlags,
      });
    } catch (_) {}
  }
}
