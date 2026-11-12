import 'dart:math' as math;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/env_config.dart';
import '../utils/rate_limiter.dart';

class GeminiService {
  final String _apiKey;
  late final GenerativeModel _embeddingModel;

  static const List<String> _chatModels = [
    'gemini-3.5-flash',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];

  GeminiService({String? apiKey})
      : _apiKey = apiKey ?? EnvConfig.get('GEMINI_API_KEY') {
    _embeddingModel = GenerativeModel(
      model: 'gemini-embedding-001',
      apiKey: _apiKey,
    );
  }

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Generate structured content using active Gemini Flash models with fallback.
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

    Object? lastError;
    for (final modelId in _chatModels) {
      try {
        final model = GenerativeModel(
          model: modelId,
          apiKey: _apiKey,
          systemInstruction:
              systemInstruction != null ? Content.system(systemInstruction) : null,
          generationConfig: GenerationConfig(
            temperature: systemInstruction != null ? 0.3 : 0.4,
            maxOutputTokens: 8192,
            responseMimeType: jsonMode ? 'application/json' : 'text/plain',
          ),
        );

        final response = await model
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 12));
        final text = response.text;
        if (text != null && text.isNotEmpty) {
          await LocalRateLimiter.incrementUsage('gemini_flash');
          return text;
        }
      } catch (e) {
        lastError = e;
      }
    }

    throw StateError('All Gemini Flash models failed: $lastError');
  }

  /// Generate 768-dimensional vector embedding for RAG chunks via gemini-embedding-001.
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

    final rawValues = response.embedding.values;
    final sliced = rawValues.length > 768
        ? rawValues.sublist(0, 768).toList()
        : rawValues.toList();

    // L2-normalize sliced Matryoshka vector for accurate pgvector cosine search
    double sumSq = 0.0;
    for (final v in sliced) {
      sumSq += v * v;
    }
    final norm = math.sqrt(sumSq);
    if (norm > 0) {
      return sliced.map((v) => v / norm).toList();
    }
    return sliced;
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
