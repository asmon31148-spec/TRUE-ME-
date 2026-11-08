import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterService {
  final String _apiKey;
  final Dio _dio;

  /// Verified 100% free models on OpenRouter
  static const List<String> freeModels = [
    'nvidia/nemotron-3.5-lightning:free',
    'liquid/lfm-3-1.7b:free',
    'liquid/lfm-2.5-2.6b:free',
    'cohere/north-mini-code:free',
    'google/gemma-4-31b-it:free',
  ];

  OpenRouterService({String? apiKey, Dio? dio})
      : _apiKey = apiKey ?? dotenv.env['OPENROUTER_API_KEY'] ?? '',
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
    String model = 'nvidia/nemotron-3.5-lightning:free',
  }) async {
    if (!isConfigured) {
      throw StateError('OPENROUTER_API_KEY is not configured in .env');
    }

    final List<Map<String, String>> messages = [];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

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
      data: {
        'model': model,
        'messages': messages,
      },
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
