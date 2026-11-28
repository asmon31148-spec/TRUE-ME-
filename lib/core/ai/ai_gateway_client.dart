import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../config/env_config.dart';
import '../services/supabase_service.dart';
import '../utils/rate_limiter.dart';
import 'monitor/ai_telemetry_service.dart';

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
            receiveTimeout: const Duration(seconds: 65),
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

  static String _featureFromTaskType(String taskType) {
    switch (taskType) {
      case 'heavy_reasoning':
      case 'groq_heavy':
        return 'Study Assistant (Sage)';
      case 'realtime_chat':
      case 'groq_speed':
        return 'Realtime Voice & Chat';
      case 'chat_with_notes':
        return 'Chat with Notes';
      case 'quiz':
        return 'Quiz Generator';
      case 'flashcards':
        return 'Flashcards';
      case 'mindmap':
        return 'Mindmap';
      case 'study_plan':
        return 'Study Planner';
      case 'embedding':
        return 'RAG Document Ingestion';
      case 'rerank':
        return 'RAG Chunk Reranking';
      case 'transcribe':
        return 'Audio & Lecture Transcription';
      case 'cloudflare_summarize':
        return 'Web Article & URL Summarizer';
      case 'openrouter_fallback':
        return 'Document Generation Fallback';
      case 'gemini_chat':
        return 'Study Assistant (Sage)';
      default:
        return taskType;
    }
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
      final telemetry = map['telemetry'] is Map
          ? Map<String, dynamic>.from(map['telemetry'] as Map)
          : null;
      unawaited(AiTelemetryService.recordFromGateway(
        requestId: rid,
        featureName: _featureFromTaskType(taskType),
        callbackRoute: 'AiGatewayClient.chat($taskType)',
        fallbackProvider: preferredProvider ?? map['provider']?.toString() ?? 'groq',
        fallbackModel: modelHint ?? map['model']?.toString() ?? 'openai/gpt-oss-120b',
        promptChars: prompt.length + (systemPrompt?.length ?? 0),
        responseChars: text.length,
        status: 'success',
        gatewayTelemetry: telemetry,
      ));
      return text;
    } on DioException catch (e) {
      unawaited(AiTelemetryService.recordFromGateway(
        requestId: rid,
        featureName: _featureFromTaskType(taskType),
        callbackRoute: 'AiGatewayClient.chat($taskType)',
        fallbackProvider: preferredProvider ?? 'groq',
        fallbackModel: modelHint ?? 'openai/gpt-oss-120b',
        promptChars: prompt.length + (systemPrompt?.length ?? 0),
        responseChars: 0,
        status: 'error',
        errorDetail: e.message ?? '${e.response?.statusCode ?? e.type.name}',
      ));
      _throwFriendlyDioError(e);
    }
  }

  /// Streams SSE token deltas from `ai-gateway` (`stream: true`), falling back
  /// seamlessly to full-text emission if the upstream returns JSON.
  Stream<String> chatStream({
    required String prompt,
    String? systemPrompt,
    required String tier,
    required String taskType,
    String? preferredProvider,
    double? temperature,
    int? maxTokens,
    String? modelHint,
    String? requestId,
  }) async* {
    if (!isConfigured) {
      throw StateError('Supabase AI Gateway is not configured.');
    }
    final rid = requestId ?? RateLimitGuardian.newRequestId(taskType);
    try {
      final res = await _dio.post<ResponseBody>(
        _gatewayUrl,
        options: Options(
          headers: {
            ..._authHeaders(),
            'Accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'action': 'chat',
          'stream': true,
          'requestId': rid,
          'taskType': taskType,
          'tier': tier,
          if (preferredProvider != null) 'preferredProvider': preferredProvider,
          'prompt': prompt,
          if (systemPrompt != null && systemPrompt.isNotEmpty) 'systemPrompt': systemPrompt,
          'jsonMode': false,
          if (temperature != null) 'temperature': temperature,
          if (maxTokens != null) 'maxTokens': maxTokens,
          if (modelHint != null) 'modelHint': modelHint,
        },
      );

      final contentType = res.headers.value('content-type') ?? '';
      final stream = res.data?.stream;
      if (stream == null) {
        throw StateError('Empty AI stream response.');
      }

      if (!contentType.contains('text/event-stream')) {
        final fullBytes = await stream.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
        final decoded = jsonDecode(utf8.decode(fullBytes)) as Map<String, dynamic>;
        final text = decoded['text']?.toString() ?? '';
        if (text.isEmpty) throw StateError('AI gateway returned an empty response.');
        yield text;
        return;
      }

      var emittedAny = false;
      await for (final line in utf8.decoder.bind(stream.cast<List<int>>()).transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final payload = trimmed.substring(5).trim();
        if (payload == '[DONE]') break;
        try {
          final parsed = jsonDecode(payload) as Map<String, dynamic>;
          final delta = parsed['delta']?.toString() ?? '';
          if (delta.isNotEmpty) {
            emittedAny = true;
            yield delta;
          }
        } catch (_) {}
      }

      if (!emittedAny) {
        final fallbackText = await chat(
          prompt: prompt,
          systemPrompt: systemPrompt,
          tier: tier,
          taskType: taskType,
          preferredProvider: preferredProvider,
          temperature: temperature,
          maxTokens: maxTokens,
          modelHint: modelHint,
          requestId: rid,
        );
        yield fallbackText;
      }
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
      final telemetry = map['telemetry'] is Map
          ? Map<String, dynamic>.from(map['telemetry'] as Map)
          : null;
      unawaited(AiTelemetryService.recordFromGateway(
        requestId: rid,
        featureName: 'RAG Document Ingestion',
        callbackRoute: 'AiGatewayClient.embed',
        fallbackProvider: 'gemini',
        fallbackModel: 'gemini-embedding-001',
        promptChars: text.length,
        responseChars: 0,
        status: 'success',
        gatewayTelemetry: telemetry,
      ));
      return vec;
    } on DioException catch (e) {
      _throwFriendlyDioError(e);
    }
  }

  Future<List<List<double>>> embedBatch({
    required List<String> texts,
    String? requestId,
  }) async {
    if (texts.isEmpty) return const [];
    if (!isConfigured) {
      throw StateError('Supabase AI Gateway is not configured.');
    }
    final rid = requestId ?? RateLimitGuardian.newRequestId('batch_embed');
    try {
      final res = await _dio.post(
        _gatewayUrl,
        options: Options(headers: _authHeaders()),
        data: {
          'action': 'batch_embed',
          'requestId': rid,
          'taskType': 'embedding',
          'texts': texts,
        },
      );
      final map = Map<String, dynamic>.from(res.data as Map);
      final rawList = map['embeddings'] as List<dynamic>? ?? const [];
      final vectors = rawList
          .map((item) => (item as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList();
      if (vectors.length != texts.length || vectors.any((v) => v.length != 768)) {
        throw StateError('Invalid batch embedding response.');
      }
      return vectors;
    } on DioException catch (e) {
      // If deployed edge function is older and returns 400 for batch_embed, fall back to embed
      if (e.response?.statusCode == 400) {
        final out = <List<double>>[];
        for (final t in texts) {
          out.add(await embed(text: t));
        }
        return out;
      }
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
      final telemetry = map['telemetry'] is Map
          ? Map<String, dynamic>.from(map['telemetry'] as Map)
          : null;
      if (map['provider'] == 'cohere') {
        unawaited(AiTelemetryService.recordFromGateway(
          requestId: rid,
          featureName: 'RAG Chunk Reranking',
          callbackRoute: 'AiGatewayClient.rerank',
          fallbackProvider: 'cohere',
          fallbackModel: 'rerank-v3.5',
          promptChars: query.length + documents.fold<int>(0, (s, d) => s + d.length),
          responseChars: 0,
          status: 'success',
          gatewayTelemetry: telemetry,
        ));
      }
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
      final text = map['text']?.toString() ?? '';
      final telemetry = map['telemetry'] is Map
          ? Map<String, dynamic>.from(map['telemetry'] as Map)
          : null;
      unawaited(AiTelemetryService.recordFromGateway(
        requestId: rid,
        featureName: 'Audio & Lecture Transcription',
        callbackRoute: 'AiGatewayClient.transcribe',
        fallbackProvider: 'groq',
        fallbackModel: 'whisper-large-v3',
        promptChars: 0,
        responseChars: text.length,
        status: 'success',
        gatewayTelemetry: telemetry,
      ));
      return text;
    } on DioException catch (e) {
      _throwFriendlyDioError(e);
    }
  }
}
