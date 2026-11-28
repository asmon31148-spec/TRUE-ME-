import 'ai_gateway_client.dart';

/// Gateway-backed Gemini adapter. Private GEMINI_API_KEY lives exclusively on the backend.
class GeminiService {
  final AiGatewayClient _gateway;

  GeminiService({String? apiKey, AiGatewayClient? gateway})
      : _gateway = gateway ?? AiGatewayClient.instance;

  bool get isConfigured => _gateway.isConfigured;

  /// Generate structured content via authenticated Supabase AI Gateway.
  Future<String> generateContent(
    String prompt, {
    String? systemInstruction,
    bool jsonMode = false,
    int? maxOutputTokens,
    double? temperature,
  }) async {
    return _gateway.chat(
      prompt: prompt,
      systemPrompt: systemInstruction,
      tier: 'balanced',
      preferredProvider: 'gemini',
      taskType: 'gemini_chat',
      jsonMode: jsonMode,
      maxTokens: maxOutputTokens,
      temperature: temperature,
    );
  }

  /// Generate 768-dimensional L2-normalized embedding via authenticated Supabase AI Gateway.
  Future<List<double>> generateEmbedding(String text) async {
    return _gateway.embed(text: text);
  }

  /// Batch generate embeddings for multiple chunks using `batch_embed` (up to 40 per call).
  Future<List<List<double>>> generateBatchEmbeddings(List<String> texts) async {
    if (texts.isEmpty) return const [];
    const batchSize = 40;
    final List<List<double>> embeddings = [];
    for (int i = 0; i < texts.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, texts.length);
      final batch = texts.sublist(i, end);
      final vecs = await _gateway.embedBatch(texts: batch);
      embeddings.addAll(vecs);
    }
    return embeddings;
  }
}
