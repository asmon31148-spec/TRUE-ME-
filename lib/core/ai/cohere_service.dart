import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CohereService {
  final String _apiKey;
  final Dio _dio;

  static const String _baseUrl = 'https://api.cohere.com/v2';

  CohereService({String? apiKey, Dio? dio})
      : _apiKey = apiKey ?? dotenv.env['COHERE_API_KEY'] ?? '',
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

  /// High-intelligence reasoning using Cohere Command R+ (v2 API).
  Future<String> chat({
    required String prompt,
    String? systemPrompt,
    String model = 'command-r-plus-08-2024',
    double temperature = 0.3,
  }) async {
    if (!isConfigured) {
      throw StateError('COHERE_API_KEY is not configured in .env');
    }

    final List<Map<String, String>> messages = [];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    final response = await _dio.post(
      '/chat',
      options: Options(headers: _headers),
      data: {
        'model': model,
        'messages': messages,
        'temperature': temperature,
      },
    );

    if (response.statusCode == 200) {
      final content = response.data['message']?['content'] as List<dynamic>?;
      if (content != null && content.isNotEmpty) {
        return content[0]['text'] as String? ?? '';
      }
    }

    throw StateError('Cohere chat failed: ${response.statusCode}');
  }

  /// State-of-the-art document chunk reranking using Cohere Rerank v3.5.
  /// Reranks retrieved vector chunks by true semantic relevance to the query.
  Future<List<String>> rerankDocuments({
    required String query,
    required List<String> documents,
    int topN = 4,
  }) async {
    if (!isConfigured || documents.isEmpty) {
      return documents.take(topN).toList();
    }

    try {
      final response = await _dio.post(
        '/rerank',
        options: Options(headers: _headers),
        data: {
          'model': 'rerank-v3.5',
          'query': query,
          'documents': documents,
          'top_n': topN > documents.length ? documents.length : topN,
        },
      );

      if (response.statusCode == 200) {
        final results = response.data['results'] as List<dynamic>? ?? [];
        final List<String> reranked = [];
        for (final item in results) {
          final idx = (item['index'] as num).toInt();
          if (idx >= 0 && idx < documents.length) {
            reranked.add(documents[idx]);
          }
        }
        return reranked.isNotEmpty ? reranked : documents.take(topN).toList();
      }
    } catch (_) {
      // Graceful fallback to original vector order if rerank network issue
    }

    return documents.take(topN).toList();
  }
}
