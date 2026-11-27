import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/offline_cache_service.dart';
import '../../services/supabase_service.dart';
import 'memory_derivation_service.dart';
import 'smai_models.dart';

/// Shared SMAI Event Capture & Lifecycle Service (Section 5).
/// Every participating feature emits normalized events here rather than
/// writing directly into derived memory tables.
class MemoryEventService {
  MemoryEventService._();

  static String _eventsKey(String userId) => 'events::$userId';

  static Future<Box> _openStore() async {
    return Hive.isBoxOpen(MemoryDerivationService.storeBoxName)
        ? Hive.box(MemoryDerivationService.storeBoxName)
        : await Hive.openBox(MemoryDerivationService.storeBoxName);
  }

  static String resolveAuthenticatedUserId([String? overrideUserId]) {
    final authUid = SupabaseService.instance.authUserId;
    if (authUid != null && authUid.isNotEmpty) return authUid;
    if (overrideUserId != null && overrideUserId.trim().isNotEmpty) {
      return overrideUserId.trim();
    }
    return OfflineCacheService.getUserId();
  }

  /// Captures, validates, deduplicates (via [idempotencyKey]), persists,
  /// syncs, and triggers conservative derivation for a [LearningEvent].
  static Future<LearningEvent> capture({
    required SmaiEventType eventType,
    required String idempotencyKey,
    String? subjectId,
    String? nodeId,
    Map<String, dynamic> payload = const {},
    List<String> provenanceRefs = const [],
    String searchText = '',
    DateTime? occurredAt,
    String? overrideUserId,
  }) async {
    final userId = resolveAuthenticatedUserId(overrideUserId);
    final cleanKey = idempotencyKey.trim();
    if (cleanKey.isEmpty) {
      throw ArgumentError('SMAI LearningEvent requires a non-empty idempotencyKey.');
    }

    final box = await _openStore();
    final rawList = box.get(_eventsKey(userId)) as List? ?? [];
    final events = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // Idempotency check: never duplicate or re-derive the same event
    final existingIdx = events.indexWhere((e) => e['idempotency_key'] == cleanKey);
    if (existingIdx >= 0) {
      return LearningEvent.fromMap(events[existingIdx]);
    }

    final now = occurredAt ?? DateTime.now();
    final event = LearningEvent(
      id: 'evt_${now.millisecondsSinceEpoch}_${cleanKey.hashCode.abs()}',
      userId: userId,
      subjectId: (subjectId != null && subjectId.trim().isNotEmpty)
          ? subjectId.trim()
          : null,
      nodeId: (nodeId != null && nodeId.trim().isNotEmpty) ? nodeId.trim() : null,
      eventType: eventType,
      idempotencyKey: cleanKey,
      processingStatus: 'processed',
      occurredAt: now,
      payload: payload,
      provenanceRefs: provenanceRefs,
      searchText: searchText.trim(),
    );

    events.insert(0, event.toMap());
    if (events.length > 1000) events.removeRange(1000, events.length);
    await box.put(_eventsKey(userId), events);

    // Derive structured memories & mastery snapshots
    await MemoryDerivationService.deriveFromEvent(event);

    // Sync asynchronously to Supabase learning_events (unique on user_id, idempotency_key)
    unawaited(_syncEventToSupabase(event));
    return event;
  }

  static Future<List<LearningEvent>> getEvents(
    String userId, {
    String? subjectId,
    SmaiEventType? eventType,
  }) async {
    final box = await _openStore();
    final raw = box.get(_eventsKey(userId)) as List? ?? [];
    return raw
        .map((e) => LearningEvent.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((e) => subjectId == null || e.subjectId == subjectId)
        .where((e) => eventType == null || e.eventType == eventType)
        .toList();
  }

  /// Storage hygiene (100-student multi-year scaling):
  /// Prunes raw transient events older than [retainDays] locally after mastery
  /// snapshots & memories have already been derived.
  static Future<int> compactOldEvents(String userId, {int retainDays = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: retainDays));
    final box = await _openStore();
    final raw = box.get(_eventsKey(userId)) as List? ?? [];
    final before = raw.length;
    final kept = raw.where((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final dt = DateTime.tryParse(m['occurred_at']?.toString() ?? '') ?? DateTime.now();
      return dt.isAfter(cutoff);
    }).toList();
    await box.put(_eventsKey(userId), kept);
    return before - kept.length;
  }

  static Future<void> _syncEventToSupabase(LearningEvent event) async {
    try {
      final client = SupabaseService.instance.clientOrNull;
      final uid = SupabaseService.instance.authUserId;
      if (client == null || uid == null || uid != event.userId) return;
      await client.from('learning_events').upsert(
            event.toMap(),
            onConflict: 'user_id,idempotency_key',
          );
    } catch (_) {}
  }
}
