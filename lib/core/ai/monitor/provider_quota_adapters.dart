import 'ai_monitor_models.dart';

/// Base contract for normalizing official provider quota/usage responses.
abstract class ProviderQuotaAdapter {
  String get providerId;
  ProviderSnapshot normalize(Map<String, dynamic> rawPayload, DateTime fetchedAt);
}

class OpenRouterQuotaAdapter implements ProviderQuotaAdapter {
  @override
  String get providerId => 'openrouter';

  @override
  ProviderSnapshot normalize(Map<String, dynamic> raw, DateTime fetchedAt) {
    final status = raw['status'] == 'OFFICIAL'
        ? DataSourceBadge.official
        : DataSourceBadge.unavailable;
    return ProviderSnapshot(
      provider: providerId,
      status: status,
      fetchedAt: fetchedAt,
      officialCreditLimit: (raw['limit'] as num?)?.toDouble(),
      officialCreditUsed: (raw['usageTotal'] as num?)?.toDouble(),
      officialCreditRemaining: (raw['limitRemaining'] as num?)?.toDouble(),
      officialDailyUsage: (raw['usageDaily'] as num?)?.toDouble(),
      officialWeeklyUsage: (raw['usageWeekly'] as num?)?.toDouble(),
      officialMonthlyUsage: (raw['usageMonthly'] as num?)?.toDouble(),
      limitReset: raw['limitReset']?.toString(),
      isFreeTier: raw['isFreeTier'] as bool?,
      errorDetail: raw['error']?.toString(),
    );
  }
}

class GroqQuotaAdapter implements ProviderQuotaAdapter {
  @override
  String get providerId => 'groq';

  @override
  ProviderSnapshot normalize(Map<String, dynamic> raw, DateTime fetchedAt) {
    final status = raw['status'] == 'OFFICIAL'
        ? DataSourceBadge.official
        : DataSourceBadge.unavailable;
    final rawModels = raw['models'] as List? ?? const [];
    final modelIds = <String>[];
    final contextLimits = <String, int>{};
    for (final m in rawModels) {
      if (m is Map) {
        final id = m['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          modelIds.add(id);
          final ctx = (m['contextWindow'] as num?)?.toInt();
          if (ctx != null) contextLimits[id] = ctx;
        }
      }
    }
    return ProviderSnapshot(
      provider: providerId,
      status: status,
      fetchedAt: fetchedAt,
      isFreeTier: true,
      rateLimitHeaders: Map<String, String>.from(raw['rateLimits'] as Map? ?? const {}),
      discoveredModelIds: modelIds,
      modelContextLimits: contextLimits,
      errorDetail: raw['error']?.toString(),
      note: raw['note']?.toString(),
    );
  }
}

class GeminiQuotaAdapter implements ProviderQuotaAdapter {
  @override
  String get providerId => 'gemini';

  @override
  ProviderSnapshot normalize(Map<String, dynamic> raw, DateTime fetchedAt) {
    final status = raw['status'] == 'OFFICIAL'
        ? DataSourceBadge.official
        : DataSourceBadge.unavailable;
    final rawModels = raw['models'] as List? ?? const [];
    final modelIds = <String>[];
    final contextLimits = <String, int>{};
    for (final m in rawModels) {
      if (m is Map) {
        final id = m['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          modelIds.add(id);
          final ctx = (m['inputTokenLimit'] as num?)?.toInt();
          if (ctx != null) contextLimits[id] = ctx;
        }
      }
    }
    return ProviderSnapshot(
      provider: providerId,
      status: status,
      fetchedAt: fetchedAt,
      isFreeTier: true,
      discoveredModelIds: modelIds,
      modelContextLimits: contextLimits,
      errorDetail: raw['error']?.toString(),
      note: raw['note']?.toString(),
    );
  }
}

class CohereQuotaAdapter implements ProviderQuotaAdapter {
  @override
  String get providerId => 'cohere';

  @override
  ProviderSnapshot normalize(Map<String, dynamic> raw, DateTime fetchedAt) {
    final status = raw['status'] == 'OFFICIAL'
        ? DataSourceBadge.official
        : DataSourceBadge.unavailable;
    final rawModels = raw['models'] as List? ?? const [];
    final modelIds = <String>[];
    final contextLimits = <String, int>{};
    for (final m in rawModels) {
      if (m is Map) {
        final id = m['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          modelIds.add(id);
          final ctx = (m['contextLength'] as num?)?.toInt();
          if (ctx != null) contextLimits[id] = ctx;
        }
      }
    }
    return ProviderSnapshot(
      provider: providerId,
      status: status,
      fetchedAt: fetchedAt,
      isFreeTier: true,
      rateLimitHeaders: Map<String, String>.from(raw['rateLimits'] as Map? ?? const {}),
      discoveredModelIds: modelIds,
      modelContextLimits: contextLimits,
      errorDetail: raw['error']?.toString(),
    );
  }
}

class CloudflareQuotaAdapter implements ProviderQuotaAdapter {
  @override
  String get providerId => 'cloudflare';

  @override
  ProviderSnapshot normalize(Map<String, dynamic> raw, DateTime fetchedAt) {
    final status = raw['status'] == 'OFFICIAL'
        ? DataSourceBadge.official
        : DataSourceBadge.unavailable;
    return ProviderSnapshot(
      provider: providerId,
      status: status,
      fetchedAt: fetchedAt,
      isFreeTier: true,
      discoveredModelIds: const ['@cf/meta/llama-3-8b-instruct'],
      errorDetail: raw['error']?.toString(),
    );
  }
}

class ProviderQuotaAdapterRegistry {
  static final Map<String, ProviderQuotaAdapter> _adapters = {
    'openrouter': OpenRouterQuotaAdapter(),
    'groq': GroqQuotaAdapter(),
    'gemini': GeminiQuotaAdapter(),
    'cohere': CohereQuotaAdapter(),
    'cloudflare': CloudflareQuotaAdapter(),
  };

  static Map<String, ProviderSnapshot> normalizeAll(Map<String, dynamic> gatewayPayload) {
    final fetchedAt =
        DateTime.tryParse(gatewayPayload['fetchedAt']?.toString() ?? '') ?? DateTime.now();
    final rawProviders = Map<String, dynamic>.from(
      gatewayPayload['providers'] as Map? ?? const {},
    );
    final out = <String, ProviderSnapshot>{};
    for (final entry in _adapters.entries) {
      final raw = rawProviders[entry.key];
      if (raw is Map) {
        out[entry.key] = entry.value.normalize(Map<String, dynamic>.from(raw), fetchedAt);
      }
    }
    return out;
  }
}
