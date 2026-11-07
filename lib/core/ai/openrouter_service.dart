import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterService {
  final String _apiKey;
  final Dio _dio;

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
    String model = 'meta-llama/llama-3.1-8b-instruct:free',
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
