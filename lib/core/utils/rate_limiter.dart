import 'package:shared_preferences/shared_preferences.dart';

class LocalRateLimiter {
  static const Map<String, int> dailyLimits = {
    'gemini_flash': 1500,
    'gemini_embeddings': 1500,
    'groq_8b': 14400,
    'groq_70b': 1000,
    'groq_whisper': 7200,
    'cloudflare': 10000,
  };

  static String _getDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Increments and returns the current request count for a given service.
  static Future<int> incrementUsage(String serviceKey) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getDateKey();
    final fullKey = 'usage_${serviceKey}_$dateKey';

    final current = prefs.getInt(fullKey) ?? 0;
    final updated = current + 1;
    await prefs.setInt(fullKey, updated);
    return updated;
  }

  /// Gets current request count for today.
  static Future<int> getUsage(String serviceKey) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getDateKey();
    return prefs.getInt('usage_${serviceKey}_$dateKey') ?? 0;
  }

  /// Checks if a service has remaining free capacity today.
  static Future<bool> hasQuota(String serviceKey) async {
    final limit = dailyLimits[serviceKey];
    if (limit == null) return true; // Unlimited by default
    final usage = await getUsage(serviceKey);
    return usage < limit;
  }

  /// Returns remaining requests today.
  static Future<int> remainingQuota(String serviceKey) async {
    final limit = dailyLimits[serviceKey];
    if (limit == null) return 999999;
    final usage = await getUsage(serviceKey);
    final remaining = limit - usage;
    return remaining > 0 ? remaining : 0;
  }
}
