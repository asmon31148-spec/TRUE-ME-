import 'ai_gateway_client.dart';

/// Gateway-backed OpenRouter adapter. Private OPENROUTER_API_KEY lives exclusively on the backend.
class OpenRouterService {
  final AiGatewayClient _gateway;

  static const String modelNemotronUltra = 'nvidia/nemotron-3-ultra-550b-a55b:free';
  static const String modelNemotronLightning = 'nvidia/nemotron-3.5-lightning:free';
  static const String modelLiquidSmall = 'liquid/lfm-3-1.7b:free';
  static const String modelLiquidMedium = 'google/gemma-4-26b-a4b-it:free';
  static const String modelCohereCode = 'google/gemma-4-31b-it:free';
  static const String modelNemotronOmni = 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free';
  static const String modelNemotronSuperVl = 'nvidia/nemotron-3.5-super-vl:free';

  static const List<String> freeModels = [
    modelNemotronLightning,
    modelCohereCode,
    modelLiquidMedium,
    modelLiquidSmall,
    modelNemotronSuperVl,
    modelNemotronOmni,
    modelNemotronUltra,
  ];

  OpenRouterService({String? apiKey, dynamic dio, AiGatewayClient? gateway})
      : _gateway = gateway ?? AiGatewayClient.instance;

  bool get isConfigured => _gateway.isConfigured;

  /// Completion fallback routed via authenticated Supabase AI Gateway.
  Future<String> completeFallback({
    required String prompt,
    String? systemPrompt,
    String model = modelNemotronLightning,
    bool jsonMode = false,
    int? maxTokens,
  }) async {
    return _gateway.chat(
      prompt: prompt,
      systemPrompt: systemPrompt,
      tier: 'realtime',
      preferredProvider: 'openrouter',
      taskType: 'openrouter_fallback',
      modelHint: model,
      jsonMode: jsonMode,
      maxTokens: maxTokens,
    );
  }
}
