import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persistent local outbox for cloud writes that failed while offline or due to
/// transient errors (DATA-01). Operations are deduplicated by `dedupKey` so
/// retries remain idempotent across restarts.
class SyncOutboxService {
  SyncOutboxService._();

  static const String _boxName = 'sync_outbox_v1';
  static const int _maxQueueSize = 100;
  static Box? _box;
  static bool _isFlushing = false;

  static Future<Box?> _ensureBox() async {
    if (_box != null && _box!.isOpen) return _box;
    try {
      _box = await Hive.openBox(_boxName);
      return _box;
    } catch (e) {
      debugPrint('SyncOutboxService openBox failed: $e');
      return null;
    }
  }

  /// Enqueues an idempotent cloud operation for retry.
  static Future<void> enqueue({
    required String opType,
    required String dedupKey,
    required Map<String, dynamic> payload,
  }) async {
    final box = await _ensureBox();
    if (box == null) return;

    try {
      final entry = jsonEncode({
        'opType': opType,
        'dedupKey': dedupKey,
        'payload': payload,
        'queuedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await box.put(dedupKey, entry);

      // Keep queue bounded
      if (box.length > _maxQueueSize) {
        final oldestKey = box.keys.first;
        await box.delete(oldestKey);
      }
    } catch (e) {
      debugPrint('SyncOutboxService enqueue failed: $e');
    }
  }

  static Future<int> pendingCount() async {
    final box = await _ensureBox();
    return box?.length ?? 0;
  }

  static Future<void> clearAll() async {
    final box = await _ensureBox();
    await box?.clear();
  }

  /// Replays queued operations using [executor]. Stops early on network failure
  /// so remaining items stay persisted for the next retry.
  static Future<int> flush(
    Future<bool> Function(String opType, Map<String, dynamic> payload) executor,
  ) async {
    if (_isFlushing) return 0;
    final box = await _ensureBox();
    if (box == null || box.isEmpty) return 0;

    _isFlushing = true;
    int synced = 0;
    try {
      final keys = box.keys.toList();
      for (final key in keys) {
        final raw = box.get(key);
        if (raw is! String) {
          await box.delete(key);
          continue;
        }
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final opType = decoded['opType']?.toString() ?? '';
          final payload = Map<String, dynamic>.from(decoded['payload'] as Map? ?? {});
          final ok = await executor(opType, payload);
          if (ok) {
            await box.delete(key);
            synced++;
          } else {
            // Stop flushing if cloud is unreachable so order is preserved
            break;
          }
        } catch (e) {
          debugPrint('SyncOutboxService replay error for $key: $e');
          break;
        }
      }
    } finally {
      _isFlushing = false;
    }
    return synced;
  }
}
