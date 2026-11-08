import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/rate_limiter.dart';

class GroqService {
  final String _apiKey;
  final Dio _dio;

  static const String _baseUrl = 'https://api.groq.com/openai/v1';

  GroqService({String? apiKey, Dio? dio})
      : _apiKey = apiKey ?? dotenv.env['GROQ_API_KEY'] ?? '',
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _baseUrl,
                connectTimeout: const Duration(seconds: 25),
                receiveTimeout: const Duration(seconds: 40),
              ),
            );

  bool get isConfigured => _apiKey.isNotEmpty;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  /// High-volume completion using fast inference model (14,400 free req/day).
  Future<String> complete8B({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
    double temperature = 0.3,
  }) async {
    try {
      return await _callChatCompletion(
        model: 'llama-3.1-8b-instant',
        rateLimitKey: 'groq_8b',
        prompt: prompt,
        systemPrompt: systemPrompt,
        jsonMode: jsonMode,
        temperature: temperature,
      );
    } catch (_) {
      return await _callChatCompletion(
        model: 'llama3-8b-8192',
        rateLimitKey: 'groq_8b',
        prompt: prompt,
        systemPrompt: systemPrompt,
        jsonMode: jsonMode,
        temperature: temperature,
      );
    }
  }

  /// Complex reasoning and RAG chat (1,000 free req/day).
  Future<String> complete70B({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
    double temperature = 0.3,
  }) async {
    try {
      return await _callChatCompletion(
        model: 'llama-3.3-70b-versatile',
        rateLimitKey: 'groq_70b',
        prompt: prompt,
        systemPrompt: systemPrompt,
        jsonMode: jsonMode,
        temperature: temperature,
      );
    } catch (_) {
      return await _callChatCompletion(
        model: 'mixtral-8x7b-32768',
        rateLimitKey: 'groq_70b',
        prompt: prompt,
        systemPrompt: systemPrompt,
        jsonMode: jsonMode,
        temperature: temperature,
      );
    }
  }

  Future<String> _callChatCompletion({
    required String model,
    required String rateLimitKey,
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
    double temperature = 0.3,
  }) async {
    if (!isConfigured) {
      throw StateError('GROQ_API_KEY is not configured in .env');
    }

    final hasQuota = await LocalRateLimiter.hasQuota(rateLimitKey);
    if (!hasQuota) {
      throw StateError('Groq $model daily quota reached');
    }

    final List<Map<String, String>> messages = [];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    final data = {
      'model': model,
      'messages': messages,
      'temperature': temperature,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };

    final response = await _dio.post(
      '/chat/completions',
      options: Options(headers: _headers),
      data: data,
    );

    await LocalRateLimiter.incrementUsage(rateLimitKey);

    if (response.statusCode == 200) {
      final choices = response.data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String? ?? '';
      }
    }

    throw StateError('Groq API error: ${response.statusCode} - ${response.data}');
  }

  /// Groq Whisper Large v3 audio transcription (7,200 req/day).
  Future<String> transcribeAudio(File audioFile) async {
    if (!isConfigured) {
      throw StateError('GROQ_API_KEY is not configured in .env');
    }

    final hasQuota = await LocalRateLimiter.hasQuota('groq_whisper');
    if (!hasQuota) {
      throw StateError('Groq Whisper daily quota reached');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioFile.path,
        filename: audioFile.path.split(Platform.pathSeparator).last,
      ),
      'model': 'whisper-large-v3',
      'response_format': 'json',
      'language': 'en',
    });

    final response = await _dio.post(
      '/audio/transcriptions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      ),
      data: formData,
    );

    await LocalRateLimiter.incrementUsage('groq_whisper');

    if (response.statusCode == 200) {
      return response.data['text'] as String? ?? '';
    }

    throw StateError('Whisper transcription failed: ${response.statusCode}');
  }
}
