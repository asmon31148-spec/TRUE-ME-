import 'ai_gateway_client.dart';

/// Gateway-backed Cloudflare Workers AI adapter.
/// Private CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN live exclusively on the backend.
class CloudflareService {
  final AiGatewayClient _gateway;

  CloudflareService({String? accountId, String? apiToken, dynamic dio, AiGatewayClient? gateway})
      : _gateway = gateway ?? AiGatewayClient.instance;

  bool get isConfigured => _gateway.isConfigured;

  /// Summarize long text or extracted web pages via authenticated Supabase AI Gateway.
  Future<String> summarizeText(String text, {int maxTokens = 300}) async {
    return _gateway.chat(
      prompt: text,
      tier: 'balanced',
      preferredProvider: 'cloudflare',
      taskType: 'cloudflare_summarize',
      maxTokens: maxTokens,
    );
  }
}
