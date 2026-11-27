import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trueme/core/ai/smai/memory_derivation_service.dart';
import 'package:trueme/core/ai/smai/memory_event_service.dart';
import 'package:trueme/core/ai/smai/memory_retrieval_service.dart';
import 'package:trueme/core/ai/smai/smai_models.dart';
import 'package:trueme/core/services/offline_cache_service.dart';

void main() {
  group('SMAI Section 16 Acceptance Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('trueme_smai_test_');
      Hive.init(tempDir.path);
      if (!Hive.isBoxOpen(MemoryDerivationService.storeBoxName)) {
        await Hive.openBox(MemoryDerivationService.storeBoxName);
      }
      if (!Hive.isBoxOpen(OfflineCacheService.userProfileBox)) {
        await Hive.openBox(OfflineCacheService.userProfileBox);
      }
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Long-term recall, voice continuity, and artifact continuity', () async {
      const uid = 'student_1';
      await MemoryEventService.capture(
        eventType: SmaiEventType.conversationMessageCreated,
        idempotencyKey: 'chat_1',
        subjectId: 'nb_micro',
        overrideUserId: uid,
        searchText: 'Explain bacterial conjugation and F-plasmid transfer',
        payload: {'text': 'Explain bacterial conjugation and F-plasmid transfer'},
      );
      await MemoryEventService.capture(
        eventType: SmaiEventType.conversationVoiceTranscribed,
        idempotencyKey: 'voice_1',
        subjectId: 'nb_micro',
        overrideUserId: uid,
        searchText: 'Voice question about transduction vs transformation',
        payload: {'transcript': 'Voice question about transduction vs transformation'},
      );
      await MemoryEventService.capture(
        eventType: SmaiEventType.studyArtifactCreated,
        idempotencyKey: 'art_1',
        subjectId: 'nb_micro',
        overrideUserId: uid,
        provenanceRefs: const ['Microbiology_Notes.pdf'],
        payload: {'title': 'Bacterial Genetics Guide', 'format': 'pdf'},
        searchText: 'Bacterial Genetics Guide pdf',
      );

      final pkg = await MemoryRetrievalService.assembleContext(
        query: 'conjugation plasmid transduction',
        aiMode: SmaiAiMode.subject,
        subjectId: 'nb_micro',
        requestIntent: 'explain',
        overrideUserId: uid,
      );

      expect(pkg.conversationReferences.length, 2);
      expect(
        pkg.conversationReferences.any((r) => r.contains('[Chat') && r.contains('conjugation')),
        isTrue,
      );
      expect(
        pkg.conversationReferences.any((r) => r.contains('[Voice') && r.contains('transduction')),
        isTrue,
      );
    });

    test('Conservative quiz derivation, improvement supersession, and flashcard continuity', () async {
      const uid = 'student_quiz';
      // Attempt 1: 1/4 wrong -> MUST be provisional (<0.5 confidence), not permanent weakness
      await MemoryEventService.capture(
        eventType: SmaiEventType.quizAttemptCompleted,
        idempotencyKey: 'q_attempt_1',
        subjectId: 'nb_micro',
        overrideUserId: uid,
        payload: {
          'topic': 'Bacterial Genetics',
          'correctCount': 1,
          'totalQuestions': 4,
        },
      );
      var mems = await MemoryDerivationService.getMemories(uid, subjectId: 'nb_micro');
      expect(mems.length, 1);
      expect(mems.first.confidence, lessThan(0.5));
      expect(mems.first.content, contains('Provisional'));

      // Flashcard practice updates mastery snapshot
      await MemoryEventService.capture(
        eventType: SmaiEventType.flashcardReviewed,
        idempotencyKey: 'fc_1',
        subjectId: 'nb_micro',
        overrideUserId: uid,
        payload: {'topic': 'Bacterial Genetics', 'remembered': true},
      );

      // Attempt 2: improved 4/4 -> supersedes difficulty memory while preserving snapshot history
      await MemoryEventService.capture(
        eventType: SmaiEventType.quizAttemptCompleted,
        idempotencyKey: 'q_attempt_2',
        subjectId: 'nb_micro',
        overrideUserId: uid,
        payload: {
          'topic': 'Bacterial Genetics',
          'correctCount': 4,
          'totalQuestions': 4,
        },
      );

      mems = await MemoryDerivationService.getMemories(uid, subjectId: 'nb_micro', activeOnly: true);
      expect(mems.any((m) => m.memoryType == 'mastery_note' && m.content.contains('Improved')), isTrue);
      expect(mems.any((m) => m.memoryType == 'topic_difficulty'), isFalse);

      final snaps = await MemoryDerivationService.getMasterySnapshots(uid, subjectId: 'nb_micro');
      expect(snaps.length, 3); // All 3 historical snapshots preserved!
    });

    test('Subject isolation, Main Sage global view, and multi-user isolation', () async {
      await MemoryEventService.capture(
        eventType: SmaiEventType.goalUpdated,
        idempotencyKey: 'goal_a',
        overrideUserId: 'user_a',
        payload: {'goal': 'Score 90% in Semester 3 finals'},
      );
      await MemoryEventService.capture(
        eventType: SmaiEventType.conversationMessageCreated,
        idempotencyKey: 'micro_a',
        subjectId: 'nb_micro',
        overrideUserId: 'user_a',
        searchText: 'Gram positive peptidoglycan',
      );
      await MemoryEventService.capture(
        eventType: SmaiEventType.conversationMessageCreated,
        idempotencyKey: 'chem_a',
        subjectId: 'nb_chem',
        overrideUserId: 'user_a',
        searchText: 'Benzene electrophilic aromatic substitution',
      );
      await MemoryEventService.capture(
        eventType: SmaiEventType.conversationMessageCreated,
        idempotencyKey: 'micro_b',
        subjectId: 'nb_micro',
        overrideUserId: 'user_b',
        searchText: 'Secret User B microbiology notes',
      );

      // Subject isolation: Microbiology AI gets approved global goal + micro, NEVER chem or user_b
      final microPkg = await MemoryRetrievalService.assembleContext(
        query: 'peptidoglycan benzene Secret',
        aiMode: SmaiAiMode.subject,
        subjectId: 'nb_micro',
        requestIntent: 'explain',
        overrideUserId: 'user_a',
      );
      expect(microPkg.currentGoals, contains('Score 90% in Semester 3 finals'));
      expect(microPkg.conversationReferences.join('\n'), contains('peptidoglycan'));
      expect(microPkg.conversationReferences.join('\n'), isNot(contains('Benzene')));
      expect(microPkg.conversationReferences.join('\n'), isNot(contains('Secret User B')));

      // Main Sage sees global view across subjects for user_a only
      final mainPkg = await MemoryRetrievalService.assembleContext(
        query: 'peptidoglycan benzene',
        aiMode: SmaiAiMode.main,
        requestIntent: 'overview',
        overrideUserId: 'user_a',
      );
      expect(mainPkg.currentGoals, contains('Score 90% in Semester 3 finals'));
      expect(mainPkg.conversationReferences.length, 2);
      expect(mainPkg.conversationReferences.join('\n'), isNot(contains('Secret User B')));
    });

    test('Idempotency, memory correction, no-evidence disclosure, and 90-day compaction', () async {
      const uid = 'student_idem';
      // Idempotency
      await MemoryEventService.capture(
        eventType: SmaiEventType.quizAttemptCompleted,
        idempotencyKey: 'same_key_1',
        subjectId: 'nb_phys',
        overrideUserId: uid,
        payload: {'topic': 'Optics', 'correctCount': 2, 'totalQuestions': 4},
      );
      await MemoryEventService.capture(
        eventType: SmaiEventType.quizAttemptCompleted,
        idempotencyKey: 'same_key_1',
        subjectId: 'nb_phys',
        overrideUserId: uid,
        payload: {'topic': 'Optics', 'correctCount': 2, 'totalQuestions': 4},
      );
      final snaps = await MemoryDerivationService.getMasterySnapshots(uid, subjectId: 'nb_phys');
      expect(snaps.length, 1);

      // Correction & supersession
      final memsBefore = await MemoryDerivationService.getMemories(uid, subjectId: 'nb_phys');
      final oldId = memsBefore.first.id;
      await MemoryEventService.capture(
        eventType: SmaiEventType.studentMemoryFeedback,
        idempotencyKey: 'corr_1',
        subjectId: 'nb_phys',
        overrideUserId: uid,
        payload: {
          'action': 'correct',
          'targetMemoryId': oldId,
          'correctedContent': 'I already mastered Snell law; focus on diffraction.',
        },
      );
      final memsAfter = await MemoryDerivationService.getMemories(uid, subjectId: 'nb_phys', activeOnly: true);
      expect(memsAfter.any((m) => m.id == oldId), isFalse);
      expect(memsAfter.any((m) => m.supersedesId == oldId && m.content.contains('diffraction')), isTrue);

      // No-evidence behavior when asking about unknown past discussion
      final noEvPkg = await MemoryRetrievalService.assembleContext(
        query: 'Do you remember what we discussed last time about quantum tunneling?',
        aiMode: SmaiAiMode.subject,
        subjectId: 'nb_empty',
        requestIntent: 'recall',
        overrideUserId: uid,
      );
      expect(noEvPkg.uncertaintyFlags, isNotEmpty);

      // 90-day compaction removes old raw events while keeping derived memories
      await MemoryEventService.capture(
        eventType: SmaiEventType.topicStudied,
        idempotencyKey: 'old_evt_1',
        subjectId: 'nb_phys',
        overrideUserId: uid,
        occurredAt: DateTime.now().subtract(const Duration(days: 120)),
      );
      final pruned = await MemoryEventService.compactOldEvents(uid, retainDays: 90);
      expect(pruned, 1);
    });
  });
}
