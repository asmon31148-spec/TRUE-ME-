/// Canonical SMAI (Student Memory & Adaptive Intelligence) domain contracts.

enum SmaiEventType {
  conversationMessageCreated('conversation.message.created'),
  conversationVoiceTranscribed('conversation.voice.transcribed'),
  conversationSessionCompleted('conversation.session.completed'),
  sourceUploaded('source.uploaded'),
  sourceProcessed('source.processed'),
  studyArtifactCreated('study_artifact.created'),
  quizAttemptCompleted('quiz.attempt.completed'),
  flashcardReviewed('flashcard.reviewed'),
  topicStudied('topic.studied'),
  goalUpdated('goal.updated'),
  studentMemoryFeedback('student.memory.feedback');

  final String wireName;
  const SmaiEventType(this.wireName);

  static SmaiEventType fromWire(String raw) {
    return SmaiEventType.values.firstWhere(
      (e) => e.wireName == raw || e.name == raw,
      orElse: () => SmaiEventType.topicStudied,
    );
  }
}

enum InformationClass {
  observedFact('observed_fact'),
  derivedInsight('derived_insight'),
  unknown('unknown');

  final String wireName;
  const InformationClass(this.wireName);

  static InformationClass fromWire(String? raw) {
    return InformationClass.values.firstWhere(
      (e) => e.wireName == raw || e.name == raw,
      orElse: () => InformationClass.derivedInsight,
    );
  }
}

enum SmaiAiMode { main, subject }

class LearningEvent {
  final String id;
  final String userId;
  final String? subjectId;
  final String? nodeId;
  final SmaiEventType eventType;
  final String idempotencyKey;
  final int schemaVersion;
  final String processingStatus; // 'pending' | 'processed' | 'failed'
  final DateTime occurredAt;
  final Map<String, dynamic> payload;
  final List<String> provenanceRefs;
  final String searchText;

  const LearningEvent({
    required this.id,
    required this.userId,
    this.subjectId,
    this.nodeId,
    required this.eventType,
    required this.idempotencyKey,
    this.schemaVersion = 1,
    this.processingStatus = 'processed',
    required this.occurredAt,
    this.payload = const {},
    this.provenanceRefs = const [],
    this.searchText = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        if (subjectId != null) 'subject_id': subjectId,
        if (nodeId != null) 'node_id': nodeId,
        'event_type': eventType.wireName,
        'idempotency_key': idempotencyKey,
        'schema_version': schemaVersion,
        'processing_status': processingStatus,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'payload': payload,
        'provenance_refs': provenanceRefs,
        'search_text': searchText,
      };

  factory LearningEvent.fromMap(Map<String, dynamic> m) {
    return LearningEvent(
      id: m['id']?.toString() ?? '',
      userId: m['user_id']?.toString() ?? '',
      subjectId: m['subject_id']?.toString(),
      nodeId: m['node_id']?.toString(),
      eventType: SmaiEventType.fromWire(m['event_type']?.toString() ?? ''),
      idempotencyKey: m['idempotency_key']?.toString() ?? '',
      schemaVersion: (m['schema_version'] as num?)?.toInt() ?? 1,
      processingStatus: m['processing_status']?.toString() ?? 'processed',
      occurredAt: DateTime.tryParse(m['occurred_at']?.toString() ?? '') ?? DateTime.now(),
      payload: m['payload'] is Map
          ? Map<String, dynamic>.from(m['payload'] as Map)
          : const {},
      provenanceRefs: (m['provenance_refs'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      searchText: m['search_text']?.toString() ?? '',
    );
  }
}

class MemoryRecord {
  final String id;
  final String userId;
  final String? subjectId;
  final String? nodeId;
  final String memoryType; // 'topic_difficulty' | 'learning_preference' | 'goal' | 'mastery_note' | 'correction'
  final InformationClass informationClass;
  final String content;
  final double confidence;
  final int sampleSize;
  final List<String> evidenceIds;
  final String? supersedesId;
  final int derivationVersion;
  final String accessScope; // 'global_approved' | 'subject'
  final bool isActive;
  final DateTime observedAt;
  final DateTime lastConfirmedAt;

  const MemoryRecord({
    required this.id,
    required this.userId,
    this.subjectId,
    this.nodeId,
    required this.memoryType,
    required this.informationClass,
    required this.content,
    required this.confidence,
    required this.sampleSize,
    required this.evidenceIds,
    this.supersedesId,
    this.derivationVersion = 1,
    this.accessScope = 'subject',
    this.isActive = true,
    required this.observedAt,
    required this.lastConfirmedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        if (subjectId != null) 'subject_id': subjectId,
        if (nodeId != null) 'node_id': nodeId,
        'memory_type': memoryType,
        'information_class': informationClass.wireName,
        'content': content,
        'confidence': confidence,
        'sample_size': sampleSize,
        'evidence_ids': evidenceIds,
        if (supersedesId != null) 'supersedes_id': supersedesId,
        'derivation_version': derivationVersion,
        'access_scope': accessScope,
        'is_active': isActive,
        'observed_at': observedAt.toUtc().toIso8601String(),
        'last_confirmed_at': lastConfirmedAt.toUtc().toIso8601String(),
      };

  factory MemoryRecord.fromMap(Map<String, dynamic> m) {
    return MemoryRecord(
      id: m['id']?.toString() ?? '',
      userId: m['user_id']?.toString() ?? '',
      subjectId: m['subject_id']?.toString(),
      nodeId: m['node_id']?.toString(),
      memoryType: m['memory_type']?.toString() ?? 'mastery_note',
      informationClass: InformationClass.fromWire(m['information_class']?.toString()),
      content: m['content']?.toString() ?? '',
      confidence: (m['confidence'] as num?)?.toDouble() ?? 0.5,
      sampleSize: (m['sample_size'] as num?)?.toInt() ?? 1,
      evidenceIds: (m['evidence_ids'] as List? ?? []).map((e) => e.toString()).toList(),
      supersedesId: m['supersedes_id']?.toString(),
      derivationVersion: (m['derivation_version'] as num?)?.toInt() ?? 1,
      accessScope: m['access_scope']?.toString() ?? 'subject',
      isActive: m['is_active'] != false,
      observedAt: DateTime.tryParse(m['observed_at']?.toString() ?? '') ?? DateTime.now(),
      lastConfirmedAt:
          DateTime.tryParse(m['last_confirmed_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class MasterySnapshot {
  final String id;
  final String userId;
  final String subjectId;
  final String? nodeId;
  final String topicLabel;
  final double masteryScore; // 0.0..1.0
  final double confidence; // 0.0..1.0
  final int sampleSize;
  final String method;
  final List<String> evidenceIds;
  final DateTime capturedAt;

  const MasterySnapshot({
    required this.id,
    required this.userId,
    required this.subjectId,
    this.nodeId,
    required this.topicLabel,
    required this.masteryScore,
    required this.confidence,
    required this.sampleSize,
    this.method = 'deterministic_weighted',
    required this.evidenceIds,
    required this.capturedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'subject_id': subjectId,
        if (nodeId != null) 'node_id': nodeId,
        'topic_label': topicLabel,
        'mastery_score': masteryScore,
        'confidence': confidence,
        'sample_size': sampleSize,
        'method': method,
        'evidence_ids': evidenceIds,
        'captured_at': capturedAt.toUtc().toIso8601String(),
      };

  factory MasterySnapshot.fromMap(Map<String, dynamic> m) {
    return MasterySnapshot(
      id: m['id']?.toString() ?? '',
      userId: m['user_id']?.toString() ?? '',
      subjectId: m['subject_id']?.toString() ?? '',
      nodeId: m['node_id']?.toString(),
      topicLabel: m['topic_label']?.toString() ?? 'General',
      masteryScore: (m['mastery_score'] as num?)?.toDouble() ?? 0.0,
      confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
      sampleSize: (m['sample_size'] as num?)?.toInt() ?? 0,
      method: m['method']?.toString() ?? 'deterministic_weighted',
      evidenceIds: (m['evidence_ids'] as List? ?? []).map((e) => e.toString()).toList(),
      capturedAt: DateTime.tryParse(m['captured_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Typed, bounded context package assembled by [MemoryRetrievalService] (Section 9.2).
class SmaiContextPackage {
  final String studentId;
  final SmaiAiMode aiMode;
  final String? subjectId;
  final String requestIntent;
  final List<String> currentGoals;
  final List<String> relevantProfileFacts;
  final List<MasterySnapshot> topicMasterySignals;
  final List<LearningEvent> recentEvents;
  final List<MemoryRecord> retrievedMemories;
  final List<String> conversationReferences;
  final List<String> uncertaintyFlags;
  final int tokenBudget;
  final String retrievalTraceId;

  const SmaiContextPackage({
    required this.studentId,
    required this.aiMode,
    this.subjectId,
    required this.requestIntent,
    this.currentGoals = const [],
    this.relevantProfileFacts = const [],
    this.topicMasterySignals = const [],
    this.recentEvents = const [],
    this.retrievedMemories = const [],
    this.conversationReferences = const [],
    this.uncertaintyFlags = const [],
    this.tokenBudget = 1800,
    required this.retrievalTraceId,
  });

  String toPromptBlock() {
    final buf = StringBuffer();
    if (currentGoals.isNotEmpty) {
      buf.writeln('Goals: ${currentGoals.join(' | ')}');
    }
    if (relevantProfileFacts.isNotEmpty) {
      buf.writeln('Verified Profile Facts: ${relevantProfileFacts.join(' | ')}');
    }
    if (topicMasterySignals.isNotEmpty) {
      buf.writeln('Topic Mastery Signals:');
      for (final m in topicMasterySignals.take(6)) {
        final pct = (m.masteryScore * 100).round();
        final conf = m.sampleSize < 2 ? 'provisional, n=${m.sampleSize}' : 'n=${m.sampleSize}';
        buf.writeln('- ${m.topicLabel}: $pct% ($conf)');
      }
    }
    if (retrievedMemories.isNotEmpty) {
      buf.writeln('Evidence-Backed Memories:');
      for (final r in retrievedMemories.take(6)) {
        buf.writeln(
            '- [${r.informationClass.wireName}, conf=${(r.confidence * 100).round()}%] ${r.content}');
      }
    }
    if (conversationReferences.isNotEmpty) {
      buf.writeln('Relevant Past Discussion:');
      for (final c in conversationReferences.take(4)) {
        buf.writeln('- $c');
      }
    }
    if (uncertaintyFlags.isNotEmpty) {
      buf.writeln('Uncertainty Notes: ${uncertaintyFlags.join(' ')}');
    }
    final out = buf.toString().trim();
    final maxChars = tokenBudget * 4;
    return out.length > maxChars ? out.substring(0, maxChars) : out;
  }
}
