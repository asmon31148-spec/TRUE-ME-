import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/rate_limiter.dart';

class GeminiService {
  final String _apiKey;
  late final GenerativeModel _reasoningModel;
  late final GenerativeModel _embeddingModel;

  GeminiService({String? apiKey})
      : _apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '' {
    _reasoningModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: 2048,
      ),
    );

    _embeddingModel = GenerativeModel(
      model: 'gemini-embedding-2',
      apiKey: _apiKey,
    );
  }

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Generate structured content using Gemini Flash.
  Future<String> generateContent(
    String prompt, {
    String? systemInstruction,
    bool jsonMode = false,
  }) async {
    if (!isConfigured) {
      throw StateError('GEMINI_API_KEY is not configured in .env');
    }

    final hasQuota = await LocalRateLimiter.hasQuota('gemini_flash');
    if (!hasQuota) {
      throw StateError('Gemini Flash daily limit reached');
    }

    final model = systemInstruction != null
        ? GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: _apiKey,
            systemInstruction: Content.system(systemInstruction),
            generationConfig: GenerationConfig(
              temperature: 0.3,
              responseMimeType: jsonMode ? 'application/json' : 'text/plain',
            ),
          )
        : _reasoningModel;

    final response = await model.generateContent([Content.text(prompt)]);
    await LocalRateLimiter.incrementUsage('gemini_flash');

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw StateError('Gemini returned empty response');
    }

    return text;
  }

  /// Generate 768-dimensional vector embedding for RAG chunks.
  Future<List<double>> generateEmbedding(String text) async {
    if (!isConfigured) {
      throw StateError('GEMINI_API_KEY is not configured in .env');
    }

    final hasQuota = await LocalRateLimiter.hasQuota('gemini_embeddings');
    if (!hasQuota) {
      throw StateError('Gemini embedding daily limit reached');
    }

    final content = Content.text(text);
    final response = await _embeddingModel.embedContent(content);
    await LocalRateLimiter.incrementUsage('gemini_embeddings');

    final values = response.embedding.values;
    // Ensure 768 dimensions for Supabase pgvector
    if (values.length > 768) {
      return values.sublist(0, 768).toList();
    }
    return values.toList();
  }

  /// Batch generate embeddings for multiple chunks.
  Future<List<List<double>>> generateBatchEmbeddings(List<String> texts) async {
    final List<List<double>> embeddings = [];
    for (final text in texts) {
      final vec = await generateEmbedding(text);
      embeddings.add(vec);
    }
    return embeddings;
  }
}
