import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../config/env_config.dart';
import '../services/supabase_service.dart';
import '../utils/rate_limiter.dart';

/// Authenticated client for the Supabase Edge Function `ai-gateway`.
/// Keeps all private AI provider keys exclusively on the backend.
class AiGatewayClient {
  static final AiGatewayClient instance = AiGatewayClient._internal();
  factory AiGatewayClient({Dio? dio}) => dio != null ? AiGatewayClient._withDio(dio) : instance;

  final Dio _dio;

  AiGatewayClient._internal()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 48),
            sendTimeout: const Duration(seconds: 30),
          ),
        );

  AiGatewayClient._withDio(this._dio);

  static const int _maxAudioBytes = 25 * 1024 * 1024;

  bool get isConfigured =>
      SupabaseService.instance.isReady &&
      EnvConfig.get('SUPABASE_URL').isNotEmpty &&
      EnvConfig.get('SUPABASE_ANON_KEY').isNotEmpty;

  String get _gatewayUrl {
    var base = EnvConfig.get('SUPABASE_URL').trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/functions/v1/ai-gateway';
  }

  Map<String, String> _authHeaders() {
    final token = SupabaseService.instance.currentAccessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Please sign in to use AI features.');
    }
    return {
      'Authorization': 'Bearer $token',
      'apikey': EnvConfig.get('SUPABASE_ANON_KEY'),
      'Content-Type': 'application/json',
    };
  }

  Never _throwFriendlyDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final msg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'AI request failed';
    if (status == 401) {
      throw StateError('Session expired. Please sign in again.');
    }
    if (status == 429) {
      throw StateError('Daily AI quota reached. Please try again tomorrow.');
    }
    throw StateError('$msg (${status ?? e.type.name})');
  }

  Future<String> chat({
    required String prompt,
    String? systemPrompt,
    String tier = 'balanced',
    String? preferredProvider,
    String taskType = 'chat',
    bool jsonMode = false,
    double? temperature,
    int? maxTokens,
    String? modelHint,
    String? requestId,
  }) async {
    if (!isConfigured) {
      throw StateError('Supabase AI Gateway is not configured.');
    }
    final rid = requestId ?? RateLimitGuardian.newRequestId(taskType);
    try {
      final res = await _dio.post(
        _gatewayUrl,
        options: Options(headers: _authHeaders()),
        data: {
          'action': 'chat',
          'requestId': rid,
          'taskType': taskType,
          'tier': tier,
          if (preferredProvider != null) 'preferredProvider': preferredProvider,
          'prompt': prompt,
          if (systemPrompt != null && systemPrompt.isNotEmpty) 'systemPrompt': systemPrompt,
          'jsonMode': jsonMode,
          if (temperature != null) 'temperature': temperature,
          if (maxTokens != null) 'maxTokens': maxTokens,
          if (modelHint != null) 'modelHint': modelHint,
        },
      );
      final map = Map<String, dynamic>.from(res.data as Map);
      final text = map['text']?.toString() ?? '';
      if (text.isEmpty) {
        throw StateError('AI gateway returned an empty response.');
      }
      return text;
    } on DioException catch (e) {
      _throwFriendlyDioError(e);
    }
  }

  Future<List<double>> embed({
    required String text,
    String? requestId,
  }) async {
    if (!isConfigured) {
      throw StateError('Supabase AI Gateway is not configured.');
    }
    final rid = requestId ?? RateLimitGuardian.newRequestId('embed');
    try {
      final res = await _dio.post(
        _gatewayUrl,
        options: Options(headers: _authHeaders()),
        data: {
          'action': 'embed',
          'requestId': rid,
          'taskType': 'embedding',
          'text': text,
        },
      );
      final map = Map<String, dynamic>.from(res.data as Map);
      final raw = map['embedding'] as List<dynamic>? ?? const [];
      final vec = raw.map((v) => (v as num).toDouble()).toList();
      if (vec.length != 768) {
        throw StateError('Invalid embedding vector length (${vec.length}).');
      }
      return vec;
    } on DioException catch (e) {
      _throwFriendlyDioError(e);
    }
  }

  Future<List<String>> rerank({
    required String query,
    required List<String> documents,
    int topN = 4,
    String? requestId,
  }) async {
    if (documents.isEmpty || !isConfigured) {
      return documents.take(topN).toList();
    }
    final rid = requestId ?? RateLimitGuardian.newRequestId('rerank');
    try {
      final res = await _dio.post(
        _gatewayUrl,
        options: Options(headers: _authHeaders()),
        data: {
          'action': 'rerank',
          'requestId': rid,
          'taskType': 'rerank',
          'query': query,
          'documents': documents,
          'topN': topN,
        },
      );
      final map = Map<String, dynamic>.from(res.data as Map);
      final raw = map['documents'] as List<dynamic>? ?? const [];
      final out = raw.map((e) => e.toString()).toList();
      return out.isNotEmpty ? out : documents.take(topN).toList();
    } catch (_) {
      return documents.take(topN).toList();
    }
  }

  Future<String> transcribe({
    required File audioFile,
    String? requestId,
  }) async {
    if (!isConfigured) {
      throw StateError('Supabase AI Gateway is not configured.');
    }
    final bytes = await audioFile.readAsBytes();
    if (bytes.isEmpty || bytes.length > _maxAudioBytes) {
      throw ArgumentError('Audio file must be non-empty and under 25 MB.');
    }
    final rid = requestId ?? RateLimitGuardian.newRequestId('transcribe');
    final filename = audioFile.path.split(Platform.pathSeparator).last;
    try {
      final res = await _dio.post(
        _gatewayUrl,
        options: Options(headers: _authHeaders()),
        data: {
          'action': 'transcribe',
          'requestId': rid,
          'taskType': 'transcribe',
          'filename': filename,
          'audioBase64': base64Encode(bytes),
        },
      );
      final map = Map<String, dynamic>.from(res.data as Map);
      return map['text']?.toString() ?? '';
    } on DioException catch (e) {
      _throwFriendlyDioError(e);
    }
  }
}
