import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/supabase_service.dart';
import 'smai_models.dart';

/// Derives conservative, evidence-linked, versioned memories and mastery
/// snapshots from validated [LearningEvent]s (SMAI Section 6).
class MemoryDerivationService {
  MemoryDerivationService._();

  static const String storeBoxName = 'smai_store_v1';
  static const int currentDerivationVersion = 1;

  static Future<Box> _openStore() async {
    return Hive.isBoxOpen(storeBoxName)
        ? Hive.box(storeBoxName)
        : await Hive.openBox(storeBoxName);
  }

  static String _memoriesKey(String userId) => 'memories::$userId';
  static String _masteryKey(String userId) => 'mastery::$userId';

  static Future<List<MemoryRecord>> getMemories(
    String userId, {
    String? subjectId,
    bool activeOnly = true,
  }) async {
    final box = await _openStore();
    final raw = box.get(_memoriesKey(userId)) as List? ?? [];
    return raw
        .map((e) => MemoryRecord.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((m) => !activeOnly || m.isActive)
        .where((m) =>
            subjectId == null ||
            m.subjectId == subjectId ||
            (m.subjectId == null && m.accessScope == 'global_approved'))
        .toList();
  }

  static Future<List<MasterySnapshot>> getMasterySnapshots(
    String userId, {
    String? subjectId,
  }) async {
    final box = await _openStore();
    final raw = box.get(_masteryKey(userId)) as List? ?? [];
    final list = raw
        .map((e) => MasterySnapshot.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((s) => subjectId == null || s.subjectId == subjectId)
        .toList();
    list.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return list;
  }

  static Future<void> _saveMemory(MemoryRecord record) async {
    final box = await _openStore();
    final raw = box.get(_memoriesKey(record.userId)) as List? ?? [];
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final idx = list.indexWhere((m) => m['id'] == record.id);
    if (idx >= 0) {
      list[idx] = record.toMap();
    } else {
      list.insert(0, record.toMap());
    }
    if (list.length > 500) list.removeRange(500, list.length);
    await box.put(_memoriesKey(record.userId), list);
    unawaited(_syncMemoryToSupabase(record));
  }

  static Future<void> _saveMasterySnapshot(MasterySnapshot snap) async {
    final box = await _openStore();
    final raw = box.get(_masteryKey(snap.userId)) as List? ?? [];
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    list.insert(0, snap.toMap());
    if (list.length > 500) list.removeRange(500, list.length);
    await box.put(_masteryKey(snap.userId), list);
    unawaited(_syncMasteryToSupabase(snap));
  }

  static Future<void> _syncMemoryToSupabase(MemoryRecord record) async {
    try {
      final client = SupabaseService.instance.clientOrNull;
      final uid = SupabaseService.instance.authUserId;
      if (client == null || uid == null || uid != record.userId) return;
      await client.from('memory_records').upsert(record.toMap());
    } catch (_) {}
  }

  static Future<void> _syncMasteryToSupabase(MasterySnapshot snap) async {
    try {
      final client = SupabaseService.instance.clientOrNull;
      final uid = SupabaseService.instance.authUserId;
      if (client == null || uid == null || uid != snap.userId) return;
      await client.from('mastery_snapshots').upsert(snap.toMap());
    } catch (_) {}
  }

  /// Derives conservative, evidence-linked insights from a single validated event.
  static Future<void> deriveFromEvent(LearningEvent event) async {
    switch (event.eventType) {
      case SmaiEventType.quizAttemptCompleted:
        await _deriveFromQuiz(event);
        break;
      case SmaiEventType.flashcardReviewed:
        await _deriveFromFlashcard(event);
        break;
      case SmaiEventType.goalUpdated:
        await _deriveFromGoal(event);
        break;
      case SmaiEventType.studentMemoryFeedback:
        await _applyStudentFeedback(event);
        break;
      default:
        break;
    }
  }

  static Future<void> _deriveFromQuiz(LearningEvent event) async {
    final subjectId = event.subjectId;
    if (subjectId == null || subjectId.isEmpty) return;

    final topic = (event.payload['topic']?.toString() ?? 'General').trim();
    final total = (event.payload['totalQuestions'] as num?)?.toInt() ?? 0;
    final correct = (event.payload['correctCount'] as num?)?.toInt() ?? 0;
    if (total <= 0) return;

    final score = (correct / total).clamp(0.0, 1.0);
    final priorSnaps = (await getMasterySnapshots(event.userId, subjectId: subjectId))
        .where((s) => s.topicLabel.toLowerCase() == topic.toLowerCase())
        .toList();

    final prevSample = priorSnaps.isNotEmpty ? priorSnaps.first.sampleSize : 0;
    final newSample = prevSample + 1;
    // Time-sensitive weighted average: recent attempts carry 65% weight
    final weightedScore = priorSnaps.isNotEmpty
        ? (priorSnaps.first.masteryScore * 0.35 + score * 0.65).clamp(0.0, 1.0)
        : score;
    final confidence = newSample >= 3
        ? 0.85
        : (newSample == 2 ? 0.68 : 0.40); // Never overconfident on 1 attempt!

    final snap = MasterySnapshot(
      id: 'ms_${event.id}',
      userId: event.userId,
      subjectId: subjectId,
      nodeId: event.nodeId,
      topicLabel: topic,
      masteryScore: double.parse(weightedScore.toStringAsFixed(2)),
      confidence: confidence,
      sampleSize: newSample,
      evidenceIds: [
        event.id,
        if (priorSnaps.isNotEmpty) ...priorSnaps.first.evidenceIds.take(3),
      ],
      capturedAt: event.occurredAt,
    );
    await _saveMasterySnapshot(snap);

    // Conservative difficulty / improvement memory
    final existingMemories = (await getMemories(event.userId, subjectId: subjectId))
        .where((m) =>
            m.memoryType == 'topic_difficulty' &&
            m.content.toLowerCase().contains(topic.toLowerCase()))
        .toList();

    if (score < 0.65) {
      final isProvisional = newSample < 2;
      final text = isProvisional
          ? 'Provisional signal ($correct/$total on 1 attempt): may need review on "$topic".'
          : 'Recurring difficulty on "$topic" ($correct/$total; weighted mastery ${(weightedScore * 100).round()}% across $newSample attempts).';
      final prevId = existingMemories.isNotEmpty ? existingMemories.first.id : null;
      if (prevId != null) {
        await _deactivateMemory(event.userId, prevId);
      }
      await _saveMemory(
        MemoryRecord(
          id: 'mem_${event.id}',
          userId: event.userId,
          subjectId: subjectId,
          nodeId: event.nodeId,
          memoryType: 'topic_difficulty',
          informationClass: InformationClass.derivedInsight,
          content: text,
          confidence: isProvisional ? 0.38 : 0.78,
          sampleSize: newSample,
          evidenceIds: snap.evidenceIds,
          supersedesId: prevId,
          derivationVersion: currentDerivationVersion,
          accessScope: 'subject',
          observedAt: event.occurredAt,
          lastConfirmedAt: event.occurredAt,
        ),
      );
    } else if (score >= 0.75 && existingMemories.isNotEmpty) {
      // Later improvement supersedes earlier difficulty without erasing history
      final prevId = existingMemories.first.id;
      await _deactivateMemory(event.userId, prevId);
      await _saveMemory(
        MemoryRecord(
          id: 'mem_${event.id}',
          userId: event.userId,
          subjectId: subjectId,
          nodeId: event.nodeId,
          memoryType: 'mastery_note',
          informationClass: InformationClass.derivedInsight,
          content:
              'Improved on "$topic" ($correct/$total; weighted mastery ${(weightedScore * 100).round()}%).',
          confidence: confidence,
          sampleSize: newSample,
          evidenceIds: snap.evidenceIds,
          supersedesId: prevId,
          derivationVersion: currentDerivationVersion,
          accessScope: 'subject',
          observedAt: event.occurredAt,
          lastConfirmedAt: event.occurredAt,
        ),
      );
    }
  }

  static Future<void> _deriveFromFlashcard(LearningEvent event) async {
    final subjectId = event.subjectId;
    if (subjectId == null || subjectId.isEmpty) return;
    final topic = (event.payload['topic']?.toString() ?? 'Flashcards').trim();
    final remembered = event.payload['remembered'] == true;

    final priorSnaps = (await getMasterySnapshots(event.userId, subjectId: subjectId))
        .where((s) => s.topicLabel.toLowerCase() == topic.toLowerCase())
        .toList();
    final prevScore = priorSnaps.isNotEmpty ? priorSnaps.first.masteryScore : 0.5;
    final prevSample = priorSnaps.isNotEmpty ? priorSnaps.first.sampleSize : 0;
    final delta = remembered ? 0.06 : -0.04;
    final updatedScore = (prevScore + delta).clamp(0.1, 1.0);

    await _saveMasterySnapshot(
      MasterySnapshot(
        id: 'ms_${event.id}',
        userId: event.userId,
        subjectId: subjectId,
        nodeId: event.nodeId,
        topicLabel: topic,
        masteryScore: double.parse(updatedScore.toStringAsFixed(2)),
        confidence: (prevSample + 1) >= 3 ? 0.72 : 0.42,
        sampleSize: prevSample + 1,
        method: 'flashcard_practice',
        evidenceIds: [event.id],
        capturedAt: event.occurredAt,
      ),
    );
  }

  static Future<void> _deriveFromGoal(LearningEvent event) async {
    final goalText = (event.payload['goal']?.toString() ?? '').trim();
    if (goalText.isEmpty) return;
    await _saveMemory(
      MemoryRecord(
        id: 'mem_${event.id}',
        userId: event.userId,
        memoryType: 'goal',
        informationClass: InformationClass.observedFact,
        content: goalText,
        confidence: 1.0,
        sampleSize: 1,
        evidenceIds: [event.id],
        accessScope: 'global_approved',
        observedAt: event.occurredAt,
        lastConfirmedAt: event.occurredAt,
      ),
    );
  }

  static Future<void> _applyStudentFeedback(LearningEvent event) async {
    final targetId = event.payload['targetMemoryId']?.toString() ?? '';
    final action = event.payload['action']?.toString() ?? 'correct'; // 'correct' | 'forget'
    final correctedContent = event.payload['correctedContent']?.toString().trim() ?? '';

    if (targetId.isNotEmpty) {
      await _deactivateMemory(event.userId, targetId);
    }

    if (action == 'correct' && correctedContent.isNotEmpty) {
      await _saveMemory(
        MemoryRecord(
          id: 'mem_${event.id}',
          userId: event.userId,
          subjectId: event.subjectId,
          nodeId: event.nodeId,
          memoryType: 'correction',
          informationClass: InformationClass.observedFact,
          content: correctedContent,
          confidence: 1.0,
          sampleSize: 1,
          evidenceIds: [event.id],
          supersedesId: targetId.isNotEmpty ? targetId : null,
          accessScope: event.subjectId == null ? 'global_approved' : 'subject',
          observedAt: event.occurredAt,
          lastConfirmedAt: event.occurredAt,
        ),
      );
    }
  }

  static Future<void> _deactivateMemory(String userId, String memoryId) async {
    final box = await _openStore();
    final raw = box.get(_memoriesKey(userId)) as List? ?? [];
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    for (int i = 0; i < list.length; i++) {
      if (list[i]['id'] == memoryId) {
        list[i]['is_active'] = false;
        final updated = MemoryRecord.fromMap(list[i]);
        unawaited(_syncMemoryToSupabase(updated));
        break;
      }
    }
    await box.put(_memoriesKey(userId), list);
  }
}
