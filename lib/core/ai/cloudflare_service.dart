import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/rate_limiter.dart';

class CloudflareService {
  final String _accountId;
  final String _apiToken;
  final Dio _dio;

  CloudflareService({String? accountId, String? apiToken, Dio? dio})
      : _accountId = accountId ?? dotenv.env['CLOUDFLARE_ACCOUNT_ID'] ?? '',
        _apiToken = apiToken ?? dotenv.env['CLOUDFLARE_API_TOKEN'] ?? '',
        _dio = dio ?? Dio();

  bool get isConfigured => _accountId.isNotEmpty && _apiToken.isNotEmpty;

  /// Summarize long text or extracted web pages using Cloudflare Workers AI.
  Future<String> summarizeText(String text, {int maxTokens = 300}) async {
    if (!isConfigured) {
      throw StateError('CLOUDFLARE_ACCOUNT_ID or CLOUDFLARE_API_TOKEN is missing');
    }

    final hasQuota = await LocalRateLimiter.hasQuota('cloudflare');
    if (!hasQuota) {
      throw StateError('Cloudflare Workers AI daily quota reached');
    }

    final url =
        'https://api.cloudflare.com/client/v4/accounts/$_accountId/ai/run/@cf/meta/llama-3-8b-instruct';

    final response = await _dio.post(
      url,
      options: Options(
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert academic summarizer. Provide concise, clear, bullet-point summaries of the core concepts, definitions, and takeaways.',
          },
          {
            'role': 'user',
            'content': 'Summarize the following study material thoroughly:\n\n$text',
          },
        ],
        'max_tokens': maxTokens,
      },
    );

    await LocalRateLimiter.incrementUsage('cloudflare');

    if (response.statusCode == 200 && response.data['success'] == true) {
      final result = response.data['result'];
      return result['response'] as String? ?? '';
    }

    throw StateError('Cloudflare Workers AI call failed: ${response.data}');
  }
}
