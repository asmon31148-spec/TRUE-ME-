import 'package:shared_preferences/shared_preferences.dart';

/// Guardian that actively prevents 429 errors and enforces quotas
/// across all free-tier providers using sliding RPM windows,
/// dynamic circuit breakers, and daily budget counters.
class RateLimitGuardian {
  // Provider rate limits: RPM (Requests Per Minute) & RPD (Requests Per Day)
  static const Map<String, int> rpmLimits = {
    'gemini_flash': 14, // Under 15 RPM
    'gemini_embeddings': 14,
    'groq_speed': 28, // Under 30 RPM
    'groq_heavy': 28,
    'groq_whisper': 28,
    'cohere': 8, // Under 10 RPM
    'openrouter': 18, // Under 20 RPM
  };

  static const Map<String, int> dailyLimits = {
    'gemini_flash': 1500,
    'gemini_embeddings': 1500,
    'groq_speed': 14400,
    'groq_heavy': 1000,
    'groq_whisper': 7200,
    'cohere': 100, // Safe trial budget
    'openrouter': 10000,
  };

  // In-memory sliding window timestamps for RPM (last 60 seconds)
  static final Map<String, List<int>> _slidingRpmTimestamps = {};

  // Dynamic circuit breaker: stores when a tripped provider can be retried
  static final Map<String, DateTime> _circuitBreakers = {};

  static String _getUtcDateKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Checks if a provider is healthy: not tripped, within RPM window, and has daily quota.
  static Future<bool> isAvailable(String providerKey) async {
    // 1. Check Circuit Breaker
    final trippedUntil = _circuitBreakers[providerKey];
    if (trippedUntil != null) {
      if (DateTime.now().isBefore(trippedUntil)) {
        return false; // Currently in cooldown
      } else {
        _circuitBreakers.remove(providerKey); // Cooldown expired, half-open
      }
    }

    // 2. Check Sliding RPM Window
    final maxRpm = rpmLimits[providerKey] ?? 30;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final windowStart = nowMs - 60000;

    final timestamps = _slidingRpmTimestamps[providerKey] ?? [];
    timestamps.removeWhere((ts) => ts < windowStart);
    _slidingRpmTimestamps[providerKey] = timestamps;

    if (timestamps.length >= maxRpm) {
      return false; // RPM limit reached for this minute
    }

    // 3. Check Daily Quota
    final maxDaily = dailyLimits[providerKey];
    if (maxDaily != null) {
      final currentDaily = await getDailyUsage(providerKey);
      if (currentDaily >= maxDaily) {
        return false; // Daily limit reached
      }
    }

    return true;
  }

  /// Records a successful or in-flight request to track RPM and daily totals.
  static Future<void> recordRequest(String providerKey) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final timestamps = _slidingRpmTimestamps.putIfAbsent(providerKey, () => []);
    timestamps.add(nowMs);

    // Increment daily usage
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getUtcDateKey();
    final fullKey = 'usage_${providerKey}_$dateKey';
    final current = prefs.getInt(fullKey) ?? 0;
    await prefs.setInt(fullKey, current + 1);
  }

  /// Trips a provider's circuit breaker on 429/503/timeout for a cooldown duration (default: 60s).
  static void trip(String providerKey, [Duration duration = const Duration(seconds: 60)]) {
    _circuitBreakers[providerKey] = DateTime.now().add(duration);
  }

  /// Manually clears a tripped circuit breaker.
  static void resetTrip(String providerKey) {
    _circuitBreakers.remove(providerKey);
  }

  /// Gets current day's usage count.
  static Future<int> getDailyUsage(String providerKey) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getUtcDateKey();
    return prefs.getInt('usage_${providerKey}_$dateKey') ?? 0;
  }

  /// Returns remaining daily requests.
  static Future<int> getRemainingDaily(String providerKey) async {
    final maxDaily = dailyLimits[providerKey] ?? 999999;
    final used = await getDailyUsage(providerKey);
    final remaining = maxDaily - used;
    return remaining > 0 ? remaining : 0;
  }

  // Backward-compatible helpers
  static Future<bool> hasQuota(String providerKey) => isAvailable(providerKey);
  static Future<int> incrementUsage(String providerKey) async {
    await recordRequest(providerKey);
    return getDailyUsage(providerKey);
  }
  static Future<int> getUsage(String providerKey) => getDailyUsage(providerKey);
  static Future<int> remainingQuota(String providerKey) => getRemainingDaily(providerKey);
}

/// Backwards compatibility alias for existing code
typedef LocalRateLimiter = RateLimitGuardian;
