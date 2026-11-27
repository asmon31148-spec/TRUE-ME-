import 'package:hive_flutter/hive_flutter.dart';
import '../models/flashcard_model.dart';
import '../services/offline_cache_service.dart';
import 'smai/memory_derivation_service.dart';

class WeakestTopicRecommendation {
  final String subject;
  final String topic;
  final double masteryScore;
  final int mistakeCount;

  const WeakestTopicRecommendation({
    required this.subject,
    required this.topic,
    required this.masteryScore,
    required this.mistakeCount,
  });
}

/// Phase 3 Daily Student Loop:
/// - Automatically records wrong quiz answers into a per-subject Mistake Bank.
/// - Converts mistakes into spaced-repetition Flashcards with 1 tap.
/// - Identifies the student's weakest topic from SMAI mastery + Mistake Bank.
class StudyLoopService {
  StudyLoopService._();

  static const String _boxName = 'study_loop_box';
  static const String _mistakesKey = 'mistake_bank';

  static Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  /// Records an incorrect quiz answer into the Mistake Bank (deduplicated by question text).
  static Future<void> recordQuizMistake({
    required String subject,
    required String notebookId,
    required String topic,
    required String question,
    required String wrongAnswer,
    required String correctAnswer,
    required String explanation,
  }) async {
    final box = await _openBox();
    final raw = box.get(_mistakesKey) as List? ?? [];
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final normQ = question.trim().toLowerCase();
    final existingIdx = list.indexWhere(
      (m) =>
          (m['subject']?.toString().toLowerCase() ?? '') == subject.trim().toLowerCase() &&
          (m['question']?.toString().trim().toLowerCase() ?? '') == normQ,
    );

    final entry = <String, dynamic>{
      'id': existingIdx >= 0
          ? list[existingIdx]['id']
          : 'mk_${DateTime.now().millisecondsSinceEpoch}',
      'subject': subject.trim(),
      'notebookId': notebookId.trim(),
      'topic': topic.trim().isEmpty ? subject.trim() : topic.trim(),
      'question': question.trim(),
      'wrongAnswer': wrongAnswer.trim(),
      'correctAnswer': correctAnswer.trim(),
      'explanation': explanation.trim(),
      'missCount': existingIdx >= 0 ? ((list[existingIdx]['missCount'] as int? ?? 1) + 1) : 1,
      'convertedToFlashcard': existingIdx >= 0
          ? (list[existingIdx]['convertedToFlashcard'] as bool? ?? false)
          : false,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    if (existingIdx >= 0) {
      list[existingIdx] = entry;
    } else {
      list.insert(0, entry);
    }

    await box.put(_mistakesKey, list.take(250).toList());
  }

  static Future<List<Map<String, dynamic>>> getMistakes({String? subject}) async {
    final box = await _openBox();
    final raw = box.get(_mistakesKey) as List? ?? [];
    final all = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (subject == null || subject.trim().isEmpty) return all;
    final lower = subject.trim().toLowerCase();
    return all
        .where((m) => (m['subject']?.toString().trim().toLowerCase() ?? '') == lower)
        .toList();
  }

  /// Converts a recorded mistake into a spaced-repetition flashcard in OfflineCacheService.
  static Future<FlashcardModel> convertMistakeToFlashcard(Map<String, dynamic> mistake) async {
    final subject = (mistake['subject'] ?? 'General Study').toString();
    final notebookId = (mistake['notebookId'] ?? '').toString();
    final question = (mistake['question'] ?? '').toString();
    final correct = (mistake['correctAnswer'] ?? '').toString();
    final explanation = (mistake['explanation'] ?? '').toString();

    final card = FlashcardModel(
      id: 'fc_mk_${DateTime.now().millisecondsSinceEpoch}',
      front: question,
      back: explanation.isNotEmpty ? '$correct\n\nWhy: $explanation' : correct,
      nextReviewDate: DateTime.now(),
    );

    if (!Hive.isBoxOpen(OfflineCacheService.flashcardsBox)) {
      await Hive.openBox(OfflineCacheService.flashcardsBox);
    }
    final deckId =
        'deck_mistakes_${subject.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final existingDeck = OfflineCacheService.getCachedDeck(deckId);
    final existingCards = (existingDeck?['cards'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    await OfflineCacheService.cacheDeck(deckId, {
      'id': deckId,
      'notebookId': notebookId,
      'subject': subject,
      'topic': 'Mistake Bank',
      'title': '$subject — Mistake Bank',
      'cards': [card.toMap(), ...existingCards],
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // Mark mistake as converted
    final box = await _openBox();
    final raw = box.get(_mistakesKey) as List? ?? [];
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    for (int i = 0; i < list.length; i++) {
      if (list[i]['id'] == mistake['id']) {
        list[i]['convertedToFlashcard'] = true;
        break;
      }
    }
    await box.put(_mistakesKey, list);

    return card;
  }

  /// Combines SMAI mastery snapshots and Mistake Bank counts to recommend
  /// the student's single highest-priority topic to review today.
  static Future<WeakestTopicRecommendation?> findWeakestTopic({
    required String userId,
    String? subjectId,
  }) async {
    final snapshots = await MemoryDerivationService.getMasterySnapshots(
      userId,
      subjectId: subjectId,
    );
    final mistakes = await getMistakes(subject: subjectId);

    if (snapshots.isEmpty && mistakes.isEmpty) return null;

    if (snapshots.isNotEmpty) {
      snapshots.sort((a, b) => a.masteryScore.compareTo(b.masteryScore));
      final weakest = snapshots.first;
      final topicMistakes = mistakes
          .where((m) =>
              (m['topic']?.toString().toLowerCase() ?? '') == weakest.topicLabel.toLowerCase())
          .length;
      return WeakestTopicRecommendation(
        subject: weakest.subjectId,
        topic: weakest.topicLabel,
        masteryScore: weakest.masteryScore,
        mistakeCount: topicMistakes,
      );
    }

    // Fallback: pick topic with most mistakes
    final counts = <String, int>{};
    final subjectByTopic = <String, String>{};
    for (final m in mistakes) {
      final t = (m['topic'] ?? m['subject'] ?? 'Core Concepts').toString();
      counts[t] = (counts[t] ?? 0) + (m['missCount'] as int? ?? 1);
      subjectByTopic[t] = (m['subject'] ?? 'General Study').toString();
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return WeakestTopicRecommendation(
      subject: subjectByTopic[top.key] ?? 'General Study',
      topic: top.key,
      masteryScore: 0.35,
      mistakeCount: top.value,
    );
  }
}
