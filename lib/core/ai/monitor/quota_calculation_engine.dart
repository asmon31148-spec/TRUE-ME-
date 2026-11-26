import 'dart:math' as math;
import 'ai_monitor_models.dart';

/// Official-first Quota Calculation & Estimation Engine.
/// Priority order:
///   1. OFFICIAL provider API data & live rate-limit headers
///   2. INTERNALLY TRACKED request & token logs (mixed-source when combined with official limits)
///   3. ESTIMATED ranges (only for missing metrics, never overwriting official values)
class QuotaCalculationEngine {
  QuotaCalculationEngine._();

  /// Provider-specific token estimation fallback when response usage metadata is missing.
  static int estimateTokensForProvider(String provider, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    final charsPerToken = switch (provider.toLowerCase()) {
      'gemini' => 4.0,
      'groq' => 3.8,
      'cohere' => 3.7,
      'openrouter' => 3.8,
      _ => 4.0,
    };
    return math.max(1, (trimmed.length / charsPerToken).ceil());
  }

  /// Calculates USD cost using model-specific pricing (free models always $0.00).
  static double calculateCostUsd({
    required ModelRegistryEntry model,
    required int inputTokens,
    required int outputTokens,
    int cachedTokens = 0,
  }) {
    if (model.isFreeTier && model.inputPricePer1M == 0 && model.outputPricePer1M == 0) {
      return 0.0;
    }
    final nonCachedIn = math.max(0, inputTokens - cachedTokens);
    final inCost = (nonCachedIn / 1000000.0) * model.inputPricePer1M;
    final cachedCost = (cachedTokens / 1000000.0) * model.cachedInputPricePer1M;
    final outCost = (outputTokens / 1000000.0) * model.outputPricePer1M;
    return inCost + cachedCost + outCost;
  }

  /// Next UTC midnight for daily quota resets (displayed in local timezone by UI).
  static DateTime nextUtcDailyReset([DateTime? now]) {
    final utc = (now ?? DateTime.now()).toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day).add(const Duration(days: 1)).toLocal();
  }

  /// Next 1st of month UTC for monthly quota resets.
  static DateTime nextUtcMonthlyReset([DateTime? now]) {
    final utc = (now ?? DateTime.now()).toUtc();
    final nextMonth = utc.month == 12 ? 1 : utc.month + 1;
    final nextYear = utc.month == 12 ? utc.year + 1 : utc.year;
    return DateTime.utc(nextYear, nextMonth, 1).toLocal();
  }

  /// Evaluates all applicable quota metrics for [model] given [records] and [snapshot].
  static MonitoredModelState evaluateModel({
    required ModelRegistryEntry model,
    required List<AiRequestRecord> records,
    required List<AiRequestRecord> todayRecords,
    ProviderSnapshot? snapshot,
    Map<String, String> latestRateHeaders = const {},
  }) {
    final totalRequests = records.length;
    final failedRequests = records.where((r) => r.status != 'success').length;
    int inTokens = 0;
    int outTokens = 0;
    int cachedTokens = 0;
    int totalTokens = 0;
    double totalCost = 0.0;
    bool hasOfficialCost = false;

    for (final r in records) {
      inTokens += r.inputTokens;
      outTokens += r.outputTokens;
      cachedTokens += r.cachedTokens;
      totalTokens += r.totalTokens;
      if (r.providerCostUsd != null) {
        totalCost += r.providerCostUsd!;
        hasOfficialCost = true;
      } else {
        totalCost += r.calculatedCostUsd;
      }
    }

    int todayRequests = todayRecords.length;
    int todayTokens = 0;
    for (final r in todayRecords) {
      todayTokens += r.totalTokens;
    }

    final metrics = <QuotaMetric>[];
    final headers = <String, String>{
      if (snapshot != null) ...snapshot.rateLimitHeaders,
      ...latestRateHeaders,
    };

    // 1. Official Credit Balance (e.g., OpenRouter /api/v1/key)
    if (model.provider == 'openrouter' && snapshot != null && snapshot.status == DataSourceBadge.official) {
      if (snapshot.officialCreditLimit != null) {
        final limit = snapshot.officialCreditLimit!;
        final used = snapshot.officialCreditUsed ?? 0.0;
        final remaining = snapshot.officialCreditRemaining ?? math.max(0.0, limit - used);
        final pct = limit > 0 ? ((used / limit) * 100.0).clamp(0.0, 100.0) : 0.0;
        metrics.add(QuotaMetric(
          limitType: QuotaLimitType.creditBalance,
          total: limit,
          used: used,
          remaining: remaining,
          percentage: pct,
          unit: 'USD',
          source: DataSourceBadge.official,
          confidence: 'High',
          resetSchedule: snapshot.limitReset == 'monthly'
              ? ResetScheduleType.monthly
              : snapshot.limitReset == 'daily'
                  ? ResetScheduleType.daily
                  : ResetScheduleType.creditNoReset,
          nextResetAt: snapshot.limitReset == 'monthly'
              ? nextUtcMonthlyReset()
              : snapshot.limitReset == 'daily'
                  ? nextUtcDailyReset()
                  : null,
        ));
      } else if (model.isFreeTier) {
        // OpenRouter :free models — documented free tier daily/RPM caps + tracked usage
        metrics.add(QuotaMetric(
          limitType: QuotaLimitType.daily,
          totalMin: 50,
          totalMax: 1000,
          used: todayRequests.toDouble(),
          remainingMin: math.max(0, 50 - todayRequests).toDouble(),
          remainingMax: math.max(0, 1000 - todayRequests).toDouble(),
          percentageMin: ((todayRequests / 1000) * 100).clamp(0.0, 100.0),
          percentageMax: ((todayRequests / 50) * 100).clamp(0.0, 100.0),
          unit: 'requests',
          source: DataSourceBadge.estimated,
          confidence: 'Medium',
          resetSchedule: ResetScheduleType.daily,
          nextResetAt: nextUtcDailyReset(),
        ));
      }
    }

    // 2. Official Rate-Limit Headers (Groq RPM/TPM/RPD or Cohere Trial)
    final headerLimitReq = double.tryParse(headers['x-ratelimit-limit-requests'] ?? '');
    final headerRemReq = double.tryParse(headers['x-ratelimit-remaining-requests'] ?? '');
    if (headerLimitReq != null && headerRemReq != null && headerLimitReq > 0) {
      final used = math.max(0.0, headerLimitReq - headerRemReq);
      metrics.add(QuotaMetric(
        limitType: QuotaLimitType.daily,
        total: headerLimitReq,
        used: used,
        remaining: headerRemReq,
        percentage: ((used / headerLimitReq) * 100.0).clamp(0.0, 100.0),
        unit: 'requests',
        source: DataSourceBadge.official,
        confidence: 'High',
        resetSchedule: ResetScheduleType.daily,
        nextResetAt: nextUtcDailyReset(),
      ));
    }

    final headerLimitTok = double.tryParse(headers['x-ratelimit-limit-tokens'] ?? '');
    final headerRemTok = double.tryParse(headers['x-ratelimit-remaining-tokens'] ?? '');
    if (headerLimitTok != null && headerRemTok != null && headerLimitTok > 0) {
      final used = math.max(0.0, headerLimitTok - headerRemTok);
      metrics.add(QuotaMetric(
        limitType: QuotaLimitType.tpm,
        total: headerLimitTok,
        used: used,
        remaining: headerRemTok,
        percentage: ((used / headerLimitTok) * 100.0).clamp(0.0, 100.0),
        unit: 'TPM',
        source: DataSourceBadge.official,
        confidence: 'High',
        resetSchedule: ResetScheduleType.rolling,
      ));
    }

    final cohereTrialRem = double.tryParse(headers['x-trial-endpoint-call-remaining'] ?? '');
    if (model.provider == 'cohere' && cohereTrialRem != null && model.isPrimary) {
      const trialTotal = 1000.0;
      final used = math.max(0.0, trialTotal - cohereTrialRem);
      metrics.add(QuotaMetric(
        limitType: QuotaLimitType.monthly,
        total: trialTotal,
        used: used,
        remaining: cohereTrialRem,
        percentage: ((used / trialTotal) * 100.0).clamp(0.0, 100.0),
        unit: 'account trial calls',
        source: DataSourceBadge.official,
        confidence: 'High',
        resetSchedule: ResetScheduleType.monthly,
        nextResetAt: nextUtcMonthlyReset(),
      ));
    }

    // 3. Secondary Estimation Fallback (only when no official daily/monthly quota metric exists)
    if (metrics.isEmpty) {
      final est = _estimateModelQuota(
        model: model,
        todayRequests: todayRequests,
        todayTokens: todayTokens,
      );
      if (est != null) metrics.add(est);
    }

    // Always expose tracked token consumption as a separate metric if primary isn't token-based
    if (metrics.every((m) => m.limitType != QuotaLimitType.token)) {
      metrics.add(QuotaMetric(
        limitType: QuotaLimitType.token,
        used: totalTokens.toDouble(),
        unit: 'tokens',
        source: DataSourceBadge.internallyTracked,
        confidence: 'High',
        resetSchedule: ResetScheduleType.unknown,
      ));
    }

    String? discrepancy;
    if (model.provider == 'openrouter' &&
        snapshot?.officialDailyUsage != null &&
        snapshot!.officialDailyUsage! > 0 &&
        totalCost == 0 &&
        todayRequests > 0) {
      discrepancy = 'OpenRouter reports \$${snapshot.officialDailyUsage!.toStringAsFixed(4)} daily spend while tracked free-tier cost is \$0.00.';
    }

    return MonitoredModelState(
      model: model,
      totalRequests: totalRequests,
      failedRequests: failedRequests,
      inputTokens: inTokens,
      outputTokens: outTokens,
      cachedTokens: cachedTokens,
      totalTokens: totalTokens,
      estimatedCostUsd: totalCost,
      costSource: model.isFreeTier
          ? DataSourceBadge.official
          : (hasOfficialCost ? DataSourceBadge.official : DataSourceBadge.estimated),
      quotaMetrics: metrics,
      primaryQuota: metrics.isNotEmpty ? metrics.first : null,
      lastUpdated: snapshot?.fetchedAt,
      discrepancyNote: discrepancy,
    );
  }

  static QuotaMetric? _estimateModelQuota({
    required ModelRegistryEntry model,
    required int todayRequests,
    required int todayTokens,
  }) {
    if (model.provider == 'gemini') {
      // Documented Gemini AI Studio free tier: ~250–1,500 RPD depending on Flash model
      return QuotaMetric(
        limitType: QuotaLimitType.daily,
        totalMin: 250,
        totalMax: 1500,
        used: todayRequests.toDouble(),
        remainingMin: math.max(0, 250 - todayRequests).toDouble(),
        remainingMax: math.max(0, 1500 - todayRequests).toDouble(),
        percentageMin: ((todayRequests / 1500) * 100).clamp(0.0, 100.0),
        percentageMax: ((todayRequests / 250) * 100).clamp(0.0, 100.0),
        unit: 'requests',
        source: DataSourceBadge.estimated,
        confidence: 'Medium',
        resetSchedule: ResetScheduleType.daily,
        nextResetAt: nextUtcDailyReset(),
      );
    }

    if (model.provider == 'groq') {
      final isHeavy = model.modelId.contains('120b') || model.modelId.contains('70b');
      final minRpd = isHeavy ? 1000.0 : 7200.0;
      final maxRpd = isHeavy ? 1000.0 : 14400.0;
      return QuotaMetric(
        limitType: QuotaLimitType.daily,
        total: minRpd == maxRpd ? minRpd : null,
        totalMin: minRpd,
        totalMax: maxRpd,
        used: todayRequests.toDouble(),
        remainingMin: math.max(0.0, minRpd - todayRequests),
        remainingMax: math.max(0.0, maxRpd - todayRequests),
        percentageMin: ((todayRequests / maxRpd) * 100).clamp(0.0, 100.0),
        percentageMax: ((todayRequests / minRpd) * 100).clamp(0.0, 100.0),
        unit: 'requests',
        source: DataSourceBadge.estimated,
        confidence: 'Medium',
        resetSchedule: ResetScheduleType.daily,
        nextResetAt: nextUtcDailyReset(),
      );
    }

    if (model.provider == 'cohere') {
      return QuotaMetric(
        limitType: QuotaLimitType.monthly,
        total: 1000,
        used: todayRequests.toDouble(),
        remaining: math.max(0.0, 1000.0 - todayRequests),
        percentage: ((todayRequests / 1000.0) * 100).clamp(0.0, 100.0),
        unit: 'requests',
        source: DataSourceBadge.estimated,
        confidence: 'Medium',
        resetSchedule: ResetScheduleType.monthly,
        nextResetAt: nextUtcMonthlyReset(),
      );
    }

    if (model.provider == 'cloudflare') {
      // 10,000 Neurons/day (~1,000–1,500 short requests/day)
      return QuotaMetric(
        limitType: QuotaLimitType.daily,
        totalMin: 800,
        totalMax: 1500,
        used: todayRequests.toDouble(),
        remainingMin: math.max(0, 800 - todayRequests).toDouble(),
        remainingMax: math.max(0, 1500 - todayRequests).toDouble(),
        percentageMin: ((todayRequests / 1500) * 100).clamp(0.0, 100.0),
        percentageMax: ((todayRequests / 800) * 100).clamp(0.0, 100.0),
        unit: 'requests',
        source: DataSourceBadge.estimated,
        confidence: 'Low',
        resetSchedule: ResetScheduleType.daily,
        nextResetAt: nextUtcDailyReset(),
      );
    }

    return null;
  }
}
