import 'ai_gateway_client.dart';

/// Gateway-backed Cohere adapter. Private COHERE_API_KEY lives exclusively on the backend.
class CohereService {
  final AiGatewayClient _gateway;

  CohereService({String? apiKey, dynamic dio, AiGatewayClient? gateway})
      : _gateway = gateway ?? AiGatewayClient.instance;

  bool get isConfigured => _gateway.isConfigured;

  /// High-intelligence reasoning routed via authenticated Supabase AI Gateway.
  Future<String> chat({
    required String prompt,
    String? systemPrompt,
    String model = 'command-r-plus-08-2024',
    double temperature = 0.3,
  }) async {
    return _gateway.chat(
      prompt: prompt,
      systemPrompt: systemPrompt,
      tier: 'heavy',
      preferredProvider: 'cohere',
      taskType: 'cohere_chat',
      modelHint: model,
      temperature: temperature,
    );
  }

  /// Document chunk reranking routed via authenticated Supabase AI Gateway.
  Future<List<String>> rerankDocuments({
    required String query,
    required List<String> documents,
    int topN = 4,
  }) async {
    return _gateway.rerank(
      query: query,
      documents: documents,
      topN: topN,
    );
  }
}
