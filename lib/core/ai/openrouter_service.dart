import 'package:dio/dio.dart';
import '../config/env_config.dart';

class OpenRouterService {
  final String _apiKey;
  final Dio _dio;

  // Named constants for verified free models
  static const String modelNemotronUltra = 'nvidia/nemotron-3-ultra-550b-a55b:free'; // Heavy reasoning (550B)
  static const String modelNemotronLightning = 'nvidia/nemotron-3.5-lightning:free'; // Fast chat fallback
  static const String modelLiquidSmall = 'liquid/lfm-3-1.7b:free'; // Micro-tasks, low latency
  static const String modelLiquidMedium = 'liquid/lfm-2.5-2.6b:free';
  static const String modelCohereCode = 'cohere/north-mini-code:free'; // Structured JSON & Code
  static const String modelNemotronOmni = 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free';
  static const String modelNemotronSuperVl = 'nvidia/nemotron-3.5-super-vl:free';

  /// Verified 100% free & active models tested on OpenRouter
  static const List<String> freeModels = [
    modelNemotronLightning,
    modelLiquidSmall,
    modelLiquidMedium,
    modelCohereCode,
    modelNemotronSuperVl,
    modelNemotronOmni,
    modelNemotronUltra,
    'dots-studio/dots-3-note-preview:free',
    'recursive/flint-v1.0:free',
  ];

  OpenRouterService({String? apiKey, Dio? dio})
      : _apiKey = apiKey ?? EnvConfig.get('OPENROUTER_API_KEY'),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://openrouter.ai/api/v1',
                connectTimeout: const Duration(seconds: 25),
                receiveTimeout: const Duration(seconds: 40),
              ),
            );

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Free model completion fallback.
  Future<String> completeFallback({
    required String prompt,
    String? systemPrompt,
    String model = modelNemotronLightning,
    bool jsonMode = false,
  }) async {
    if (!isConfigured) {
      throw StateError('OPENROUTER_API_KEY is not configured in .env');
    }

    final List<Map<String, String>> messages = [];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    final Map<String, dynamic> requestBody = {
      'model': model,
      'messages': messages,
    };

    if (jsonMode) {
      requestBody['response_format'] = {'type': 'json_object'};
    }

    final response = await _dio.post(
      '/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://github.com/asmon31148-spec/TRUE-ME-',
          'X-Title': 'True Me Study App',
          'Content-Type': 'application/json',
        },
      ),
      data: requestBody,
    );

    if (response.statusCode == 200) {
      final choices = response.data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String? ?? '';
      }
    }

    throw StateError('OpenRouter fallback failed: ${response.statusCode}');
  }
}
