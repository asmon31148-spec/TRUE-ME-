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
