enum DataSourceBadge {
  official,
  internallyTracked,
  estimated,
  unavailable,
}

extension DataSourceBadgeX on DataSourceBadge {
  String get label {
    switch (this) {
      case DataSourceBadge.official:
        return 'OFFICIAL';
      case DataSourceBadge.internallyTracked:
        return 'INTERNALLY TRACKED';
      case DataSourceBadge.estimated:
        return 'ESTIMATED';
      case DataSourceBadge.unavailable:
        return 'UNAVAILABLE';
    }
  }
}

enum QuotaLimitType {
  daily,
  monthly,
  token,
  request,
  creditBalance,
  rpm,
  tpm,
  rollingWindow,
  prepaidBalance,
  internalBudget,
}

extension QuotaLimitTypeX on QuotaLimitType {
  String get label {
    switch (this) {
      case QuotaLimitType.daily:
        return 'Daily Quota';
      case QuotaLimitType.monthly:
        return 'Monthly Quota';
      case QuotaLimitType.token:
        return 'Token Quota';
      case QuotaLimitType.request:
        return 'Request Quota';
      case QuotaLimitType.creditBalance:
        return 'Credit Balance';
      case QuotaLimitType.rpm:
        return 'RPM';
      case QuotaLimitType.tpm:
        return 'TPM';
      case QuotaLimitType.rollingWindow:
        return 'Rolling Window';
      case QuotaLimitType.prepaidBalance:
        return 'Prepaid Balance';
      case QuotaLimitType.internalBudget:
        return 'Internal Budget';
    }
  }
}

enum ResetScheduleType {
  daily,
  monthly,
  rolling,
  creditNoReset,
  unknown,
}

extension ResetScheduleTypeX on ResetScheduleType {
  String get label {
    switch (this) {
      case ResetScheduleType.daily:
        return 'Daily (00:00 UTC)';
      case ResetScheduleType.monthly:
        return 'Monthly';
      case ResetScheduleType.rolling:
        return 'Rolling Window';
      case ResetScheduleType.creditNoReset:
        return 'Credit Balance (No periodic reset)';
      case ResetScheduleType.unknown:
        return 'Unknown';
    }
  }
}

class QuotaMetric {
  final QuotaLimitType limitType;
  final double? total;
  final double? totalMin;
  final double? totalMax;
  final double used;
  final double? remaining;
  final double? remainingMin;
  final double? remainingMax;
  final double? percentage;
  final double? percentageMin;
  final double? percentageMax;
  final String unit; // 'tokens', 'requests', 'USD', 'RPM', 'TPM'
  final DataSourceBadge source;
  final String confidence; // 'High', 'Medium', 'Low'
  final ResetScheduleType resetSchedule;
  final DateTime? nextResetAt;

  const QuotaMetric({
    required this.limitType,
    this.total,
    this.totalMin,
    this.totalMax,
    required this.used,
    this.remaining,
    this.remainingMin,
    this.remainingMax,
    this.percentage,
    this.percentageMin,
    this.percentageMax,
    required this.unit,
    required this.source,
    this.confidence = 'High',
    this.resetSchedule = ResetScheduleType.unknown,
    this.nextResetAt,
  });

  bool get isRangeEstimate =>
      totalMin != null && totalMax != null && totalMin != totalMax;
}

class ModelRegistryEntry {
  final String provider; // 'gemini', 'groq', 'openrouter', 'cohere', 'cloudflare'
  final String modelId;
  final String displayName;
  final bool isActive;
  final bool isDefault;
  final bool isPrimary;
  final bool isFallback;
  final bool isFreeTier;
  final int? contextWindow;
  final double inputPricePer1M;
  final double outputPricePer1M;
  final double cachedInputPricePer1M;
  final List<String> assignedFeatures;
  final List<String> callbackRoutes;

  const ModelRegistryEntry({
    required this.provider,
    required this.modelId,
    required this.displayName,
    this.isActive = true,
    this.isDefault = false,
    this.isPrimary = false,
    this.isFallback = false,
    this.isFreeTier = true,
    this.contextWindow,
    this.inputPricePer1M = 0.0,
    this.outputPricePer1M = 0.0,
    this.cachedInputPricePer1M = 0.0,
    this.assignedFeatures = const [],
    this.callbackRoutes = const [],
  });

  ModelRegistryEntry copyWith({
    bool? isActive,
    int? contextWindow,
    List<String>? assignedFeatures,
    List<String>? callbackRoutes,
  }) {
    return ModelRegistryEntry(
      provider: provider,
      modelId: modelId,
      displayName: displayName,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault,
      isPrimary: isPrimary,
      isFallback: isFallback,
      isFreeTier: isFreeTier,
      contextWindow: contextWindow ?? this.contextWindow,
      inputPricePer1M: inputPricePer1M,
      outputPricePer1M: outputPricePer1M,
      cachedInputPricePer1M: cachedInputPricePer1M,
      assignedFeatures: assignedFeatures ?? this.assignedFeatures,
      callbackRoutes: callbackRoutes ?? this.callbackRoutes,
    );
  }
}

class AiRequestRecord {
  final String requestId;
  final String provider;
  final String modelId;
  final String featureName;
  final String callbackRoute;
  final DateTime timestamp;
  final String status; // 'success' | 'error'
  final int inputTokens;
  final int outputTokens;
  final int cachedTokens;
  final int totalTokens;
  final DataSourceBadge tokenSource;
  final double? providerCostUsd;
  final double calculatedCostUsd;
  final DataSourceBadge costSource;
  final int latencyMs;
  final int retryCount;
  final bool fallbackUsed;
  final String? errorDetail;

  const AiRequestRecord({
    required this.requestId,
    required this.provider,
    required this.modelId,
    required this.featureName,
    required this.callbackRoute,
    required this.timestamp,
    required this.status,
    required this.inputTokens,
    required this.outputTokens,
    this.cachedTokens = 0,
    required this.totalTokens,
    required this.tokenSource,
    this.providerCostUsd,
    required this.calculatedCostUsd,
    required this.costSource,
    this.latencyMs = 0,
    this.retryCount = 0,
    this.fallbackUsed = false,
    this.errorDetail,
  });

  Map<String, dynamic> toMap() => {
        'requestId': requestId,
        'provider': provider,
        'modelId': modelId,
        'featureName': featureName,
        'callbackRoute': callbackRoute,
        'timestamp': timestamp.toIso8601String(),
        'status': status,
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'cachedTokens': cachedTokens,
        'totalTokens': totalTokens,
        'tokenSource': tokenSource.name,
        if (providerCostUsd != null) 'providerCostUsd': providerCostUsd,
        'calculatedCostUsd': calculatedCostUsd,
        'costSource': costSource.name,
        'latencyMs': latencyMs,
        'retryCount': retryCount,
        'fallbackUsed': fallbackUsed,
        if (errorDetail != null) 'errorDetail': errorDetail,
      };

  factory AiRequestRecord.fromMap(Map<String, dynamic> m) {
    DataSourceBadge parseBadge(String? raw, DataSourceBadge fallback) {
      for (final b in DataSourceBadge.values) {
        if (b.name == raw || b.label == raw) return b;
      }
      return fallback;
    }

    return AiRequestRecord(
      requestId: m['requestId']?.toString() ?? '',
      provider: m['provider']?.toString() ?? 'unknown',
      modelId: m['modelId']?.toString() ?? 'unknown',
      featureName: m['featureName']?.toString() ?? 'General',
      callbackRoute: m['callbackRoute']?.toString() ?? 'unknown',
      timestamp: DateTime.tryParse(m['timestamp']?.toString() ?? '') ?? DateTime.now(),
      status: m['status']?.toString() ?? 'success',
      inputTokens: (m['inputTokens'] as num? ?? 0).toInt(),
      outputTokens: (m['outputTokens'] as num? ?? 0).toInt(),
      cachedTokens: (m['cachedTokens'] as num? ?? 0).toInt(),
      totalTokens: (m['totalTokens'] as num? ?? 0).toInt(),
      tokenSource: parseBadge(m['tokenSource']?.toString(), DataSourceBadge.estimated),
      providerCostUsd: (m['providerCostUsd'] as num?)?.toDouble(),
      calculatedCostUsd: (m['calculatedCostUsd'] as num? ?? 0).toDouble(),
      costSource: parseBadge(m['costSource']?.toString(), DataSourceBadge.estimated),
      latencyMs: (m['latencyMs'] as num? ?? 0).toInt(),
      retryCount: (m['retryCount'] as num? ?? 0).toInt(),
      fallbackUsed: m['fallbackUsed'] == true,
      errorDetail: m['errorDetail']?.toString(),
    );
  }
}

class ProviderSnapshot {
  final String provider;
  final DataSourceBadge status;
  final DateTime fetchedAt;
  final double? officialCreditLimit;
  final double? officialCreditUsed;
  final double? officialCreditRemaining;
  final double? officialDailyUsage;
  final double? officialWeeklyUsage;
  final double? officialMonthlyUsage;
  final String? limitReset;
  final bool? isFreeTier;
  final Map<String, String> rateLimitHeaders;
  final List<String> discoveredModelIds;
  final Map<String, int> modelContextLimits;
  final String? errorDetail;
  final String? note;

  const ProviderSnapshot({
    required this.provider,
    required this.status,
    required this.fetchedAt,
    this.officialCreditLimit,
    this.officialCreditUsed,
    this.officialCreditRemaining,
    this.officialDailyUsage,
    this.officialWeeklyUsage,
    this.officialMonthlyUsage,
    this.limitReset,
    this.isFreeTier,
    this.rateLimitHeaders = const {},
    this.discoveredModelIds = const [],
    this.modelContextLimits = const {},
    this.errorDetail,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'provider': provider,
        'status': status.name,
        'fetchedAt': fetchedAt.toIso8601String(),
        if (officialCreditLimit != null) 'officialCreditLimit': officialCreditLimit,
        if (officialCreditUsed != null) 'officialCreditUsed': officialCreditUsed,
        if (officialCreditRemaining != null) 'officialCreditRemaining': officialCreditRemaining,
        if (officialDailyUsage != null) 'officialDailyUsage': officialDailyUsage,
        if (officialWeeklyUsage != null) 'officialWeeklyUsage': officialWeeklyUsage,
        if (officialMonthlyUsage != null) 'officialMonthlyUsage': officialMonthlyUsage,
        if (limitReset != null) 'limitReset': limitReset,
        if (isFreeTier != null) 'isFreeTier': isFreeTier,
        'rateLimitHeaders': rateLimitHeaders,
        'discoveredModelIds': discoveredModelIds,
        'modelContextLimits': modelContextLimits,
        if (errorDetail != null) 'errorDetail': errorDetail,
        if (note != null) 'note': note,
      };

  factory ProviderSnapshot.fromMap(Map<String, dynamic> m) {
    final badge = DataSourceBadge.values.firstWhere(
      (b) => b.name == m['status']?.toString(),
      orElse: () => DataSourceBadge.unavailable,
    );
    return ProviderSnapshot(
      provider: m['provider']?.toString() ?? 'unknown',
      status: badge,
      fetchedAt: DateTime.tryParse(m['fetchedAt']?.toString() ?? '') ?? DateTime.now(),
      officialCreditLimit: (m['officialCreditLimit'] as num?)?.toDouble(),
      officialCreditUsed: (m['officialCreditUsed'] as num?)?.toDouble(),
      officialCreditRemaining: (m['officialCreditRemaining'] as num?)?.toDouble(),
      officialDailyUsage: (m['officialDailyUsage'] as num?)?.toDouble(),
      officialWeeklyUsage: (m['officialWeeklyUsage'] as num?)?.toDouble(),
      officialMonthlyUsage: (m['officialMonthlyUsage'] as num?)?.toDouble(),
      limitReset: m['limitReset']?.toString(),
      isFreeTier: m['isFreeTier'] as bool?,
      rateLimitHeaders: Map<String, String>.from(m['rateLimitHeaders'] as Map? ?? const {}),
      discoveredModelIds: List<String>.from(m['discoveredModelIds'] as List? ?? const []),
      modelContextLimits: Map<String, int>.from(
        (m['modelContextLimits'] as Map? ?? const {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
      ),
      errorDetail: m['errorDetail']?.toString(),
      note: m['note']?.toString(),
    );
  }
}

class MonitoredModelState {
  final ModelRegistryEntry model;
  final int totalRequests;
  final int failedRequests;
  final int inputTokens;
  final int outputTokens;
  final int cachedTokens;
  final int totalTokens;
  final double estimatedCostUsd;
  final DataSourceBadge costSource;
  final List<QuotaMetric> quotaMetrics;
  final QuotaMetric? primaryQuota;
  final DateTime? lastUpdated;
  final String? discrepancyNote;

  const MonitoredModelState({
    required this.model,
    required this.totalRequests,
    required this.failedRequests,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedTokens,
    required this.totalTokens,
    required this.estimatedCostUsd,
    required this.costSource,
    required this.quotaMetrics,
    this.primaryQuota,
    this.lastUpdated,
    this.discrepancyNote,
  });
}

enum MonitorDateRange {
  today,
  yesterday,
  last7Days,
  last30Days,
  allTime,
}

extension MonitorDateRangeX on MonitorDateRange {
  String get label {
    switch (this) {
      case MonitorDateRange.today:
        return 'Today';
      case MonitorDateRange.yesterday:
        return 'Yesterday';
      case MonitorDateRange.last7Days:
        return '7 Days';
      case MonitorDateRange.last30Days:
        return '30 Days';
      case MonitorDateRange.allTime:
        return 'All Time';
    }
  }
}
