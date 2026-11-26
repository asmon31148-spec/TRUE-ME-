import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/env_config.dart';
import '../../services/supabase_service.dart';
import 'ai_model_registry.dart';
import 'ai_monitor_models.dart';
import 'provider_quota_adapters.dart';
import 'quota_calculation_engine.dart';

/// Centralized AI Tracking Middleware, Snapshot Cache, and Monitor API.
/// Persists telemetry locally in Hive (no prompts/PII) and syncs to Supabase.
class AiTelemetryService {
  AiTelemetryService._();
  static final AiTelemetryService instance = AiTelemetryService._();

  static const String _boxName = 'trueme_ai_monitor_v1';
  static const String _recordsKey = 'request_records';
  static const String _snapshotsKey = 'provider_snapshots';
  static const String _headersKey = 'latest_rate_headers';
  static const int _maxStoredRecords = 1500;

  static final List<AiRequestRecord> _memoryRecords = [];
  static final Map<String, ProviderSnapshot> _memorySnapshots = {};
  static final Map<String, Map<String, String>> _latestProviderHeaders = {};
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);

      final rawRecords = box.get(_recordsKey);
      if (rawRecords is String && rawRecords.isNotEmpty) {
        final decoded = jsonDecode(rawRecords) as List<dynamic>;
        _memoryRecords
          ..clear()
          ..addAll(decoded.map((e) => AiRequestRecord.fromMap(Map<String, dynamic>.from(e as Map))));
      }

      final rawSnaps = box.get(_snapshotsKey);
      if (rawSnaps is String && rawSnaps.isNotEmpty) {
        final decoded = Map<String, dynamic>.from(jsonDecode(rawSnaps) as Map);
        _memorySnapshots.clear();
        for (final entry in decoded.entries) {
          _memorySnapshots[entry.key] =
              ProviderSnapshot.fromMap(Map<String, dynamic>.from(entry.value as Map));
        }
      }

      final rawHeaders = box.get(_headersKey);
      if (rawHeaders is String && rawHeaders.isNotEmpty) {
        final decoded = Map<String, dynamic>.from(jsonDecode(rawHeaders) as Map);
        _latestProviderHeaders.clear();
        for (final entry in decoded.entries) {
          _latestProviderHeaders[entry.key] =
              Map<String, String>.from(entry.value as Map);
        }
      }
    } catch (_) {
      // Safe fallback to in-memory state in unit tests where Hive isn't initialized
    }
  }

  static Future<void> _persist() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;
      final box = Hive.box(_boxName);
      await box.put(
        _recordsKey,
        jsonEncode(_memoryRecords.map((e) => e.toMap()).toList()),
      );
      await box.put(
        _snapshotsKey,
        jsonEncode(_memorySnapshots.map((k, v) => MapEntry(k, v.toMap()))),
      );
      await box.put(_headersKey, jsonEncode(_latestProviderHeaders));
    } catch (_) {}
  }

  /// Records a completed or failed AI call (idempotent by [requestId]).
  static Future<void> recordFromGateway({
    required String requestId,
    required String featureName,
    required String callbackRoute,
    required String fallbackProvider,
    required String fallbackModel,
    required int promptChars,
    required int responseChars,
    required String status,
    Map<String, dynamic>? gatewayTelemetry,
    String? errorDetail,
  }) async {
    await _ensureInitialized();
    if (_memoryRecords.any((r) => r.requestId == requestId)) return;

    final provider = gatewayTelemetry?['provider']?.toString() ?? fallbackProvider;
    final modelId = gatewayTelemetry?['model']?.toString() ?? fallbackModel;

    final rawIn = (gatewayTelemetry?['inputTokens'] as num?)?.toInt();
    final rawOut = (gatewayTelemetry?['outputTokens'] as num?)?.toInt();
    final cached = (gatewayTelemetry?['cachedTokens'] as num?)?.toInt() ?? 0;

    final estIn = (promptChars / 4).ceil();
    final estOut = (responseChars / 4).ceil();

    final inTokens = rawIn ?? estIn;
    final outTokens = rawOut ?? estOut;
    final totalTokens = (gatewayTelemetry?['totalTokens'] as num?)?.toInt() ?? (inTokens + outTokens);

    final tokenSourceStr = gatewayTelemetry?['tokenSource']?.toString() ?? 'ESTIMATED';
    final tokenSource = tokenSourceStr == 'OFFICIAL'
        ? DataSourceBadge.official
        : DataSourceBadge.estimated;

    final discovered = AiModelRegistry.discoverModels(snapshots: _memorySnapshots);
    final modelEntry = discovered.firstWhere(
      (m) => m.modelId == modelId && m.provider == provider,
      orElse: () => ModelRegistryEntry(provider: provider, modelId: modelId, displayName: modelId),
    );

    final providerCost = (gatewayTelemetry?['costUsd'] as num?)?.toDouble();
    final calcCost = providerCost ??
        QuotaCalculationEngine.calculateCostUsd(
          model: modelEntry,
          inputTokens: inTokens,
          outputTokens: outTokens,
          cachedTokens: cached,
        );

    final rateHeaders = Map<String, String>.from(
      gatewayTelemetry?['rateLimits'] as Map? ?? const {},
    );
    if (rateHeaders.isNotEmpty) {
      _latestProviderHeaders[provider] = {
        ...(_latestProviderHeaders[provider] ?? const {}),
        ...rateHeaders,
      };
    }

    final record = AiRequestRecord(
      requestId: requestId,
      provider: provider,
      modelId: modelId,
      featureName: featureName,
      callbackRoute: callbackRoute,
      timestamp: DateTime.now(),
      status: status,
      inputTokens: inTokens,
      outputTokens: outTokens,
      cachedTokens: cached,
      totalTokens: totalTokens,
      tokenSource: tokenSource,
      providerCostUsd: providerCost,
      calculatedCostUsd: calcCost,
      costSource: providerCost != null
          ? DataSourceBadge.official
          : (modelEntry.isFreeTier ? DataSourceBadge.official : DataSourceBadge.estimated),
      latencyMs: (gatewayTelemetry?['latencyMs'] as num?)?.toInt() ?? 0,
      retryCount: ((gatewayTelemetry?['attemptCount'] as num?)?.toInt() ?? 1) - 1,
      fallbackUsed: gatewayTelemetry?['fallbackUsed'] == true,
      errorDetail: errorDetail,
    );

    _memoryRecords.insert(0, record);
    if (_memoryRecords.length > _maxStoredRecords) {
      _memoryRecords.removeRange(_maxStoredRecords, _memoryRecords.length);
    }
    await _persist();

    // Best-effort non-blocking sync to Supabase telemetry table
    unawaited(_syncRecordToSupabase(record));
  }

  static Future<void> _syncRecordToSupabase(AiRequestRecord record) async {
    try {
      final client = SupabaseService.instance.clientOrNull;
      final uid = SupabaseService.instance.authUserId;
      if (client == null || uid == null) return;
      await client.from('ai_request_telemetry').upsert({
        'request_id': record.requestId,
        'user_id': uid,
        'provider': record.provider,
        'model_id': record.modelId,
        'feature_name': record.featureName,
        'callback_route': record.callbackRoute,
        'status': record.status,
        'input_tokens': record.inputTokens,
        'output_tokens': record.outputTokens,
        'cached_tokens': record.cachedTokens,
        'total_tokens': record.totalTokens,
        'token_source': record.tokenSource.label,
        if (record.providerCostUsd != null) 'provider_cost_usd': record.providerCostUsd,
        'calculated_cost_usd': record.calculatedCostUsd,
        'cost_source': record.costSource.label,
        'latency_ms': record.latencyMs,
        'retry_count': record.retryCount,
        'fallback_used': record.fallbackUsed,
        if (record.errorDetail != null) 'error_detail': record.errorDetail,
        'created_at': record.timestamp.toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Queries official provider quota & model discovery endpoints via `ai-gateway`.
  /// Preserves last successful snapshot if any provider fails.
  static Future<Map<String, ProviderSnapshot>> refreshOfficialQuotas() async {
    await _ensureInitialized();
    final token = SupabaseService.instance.currentAccessToken;
    var baseUrl = EnvConfig.get('SUPABASE_URL').trim();
    final anonKey = EnvConfig.get('SUPABASE_ANON_KEY').trim();
    if (token == null || token.isEmpty || baseUrl.isEmpty || anonKey.isEmpty) {
      return Map.unmodifiable(_memorySnapshots);
    }
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 25),
      ));
      final res = await dio.post(
        '$baseUrl/functions/v1/ai-gateway',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'apikey': anonKey,
          'Content-Type': 'application/json',
        }),
        data: {'action': 'provider_quotas'},
      );
      final map = Map<String, dynamic>.from(res.data as Map);
      final normalized = ProviderQuotaAdapterRegistry.normalizeAll(map);

      for (final entry in normalized.entries) {
        final existing = _memorySnapshots[entry.key];
        // Keep last successful official snapshot if current call failed
        if (entry.value.status == DataSourceBadge.official || existing == null) {
          _memorySnapshots[entry.key] = entry.value;
        }
      }
      await _persist();
    } catch (_) {}

    return Map.unmodifiable(_memorySnapshots);
  }

  static Future<List<AiRequestRecord>> getRecords({
    MonitorDateRange range = MonitorDateRange.last7Days,
    String? providerFilter,
    String? featureFilter,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    await _ensureInitialized();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    DateTime? start;
    DateTime? end;
    switch (range) {
      case MonitorDateRange.today:
        start = todayStart;
        break;
      case MonitorDateRange.yesterday:
        start = todayStart.subtract(const Duration(days: 1));
        end = todayStart;
        break;
      case MonitorDateRange.last7Days:
        start = todayStart.subtract(const Duration(days: 6));
        break;
      case MonitorDateRange.last30Days:
        start = todayStart.subtract(const Duration(days: 29));
        break;
      case MonitorDateRange.allTime:
        break;
    }
    if (customStart != null) start = customStart;
    if (customEnd != null) end = customEnd;

    return _memoryRecords.where((r) {
      if (start != null && r.timestamp.isBefore(start)) return false;
      if (end != null && !r.timestamp.isBefore(end)) return false;
      if (providerFilter != null && providerFilter != 'all' && r.provider != providerFilter) {
        return false;
      }
      if (featureFilter != null && featureFilter != 'all' && r.featureName != featureFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  static Future<List<MonitoredModelState>> buildModelStates({
    MonitorDateRange range = MonitorDateRange.last7Days,
    String? providerFilter,
    String? featureFilter,
  }) async {
    await _ensureInitialized();
    final models = AiModelRegistry.discoverModels(snapshots: _memorySnapshots);
    final filteredRecords = await getRecords(
      range: range,
      providerFilter: providerFilter,
      featureFilter: featureFilter,
    );
    final todayRecords = await getRecords(range: MonitorDateRange.today);

    final out = <MonitoredModelState>[];
    for (final m in models) {
      if (providerFilter != null && providerFilter != 'all' && m.provider != providerFilter) {
        continue;
      }
      if (featureFilter != null &&
          featureFilter != 'all' &&
          !m.assignedFeatures.contains(featureFilter)) {
        continue;
      }
      final mRecords = filteredRecords.where((r) => r.modelId == m.modelId).toList();
      final mToday = todayRecords.where((r) => r.modelId == m.modelId).toList();
      out.add(QuotaCalculationEngine.evaluateModel(
        model: m,
        records: mRecords,
        todayRecords: mToday,
        snapshot: _memorySnapshots[m.provider],
        latestRateHeaders: _latestProviderHeaders[m.provider] ?? const {},
      ));
    }

    // Sort active/used models first, then primary models
    out.sort((a, b) {
      final reqCmp = b.totalRequests.compareTo(a.totalRequests);
      if (reqCmp != 0) return reqCmp;
      if (a.model.isPrimary != b.model.isPrimary) return a.model.isPrimary ? -1 : 1;
      return a.model.displayName.compareTo(b.model.displayName);
    });

    return out;
  }

  static Map<String, ProviderSnapshot> get cachedSnapshots =>
      Map.unmodifiable(_memorySnapshots);

  /// Clears in-memory test state (for unit tests only).
  static void resetForTest() {
    _initialized = true;
    _memoryRecords.clear();
    _memorySnapshots.clear();
    _latestProviderHeaders.clear();
  }
}
