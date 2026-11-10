import 'package:http/http.dart' as http;
import '../../../core/ai/ai_router.dart';
import '../../../core/ai/cloudflare_service.dart';

class UrlProcessor {
  final CloudflareService _cloudflareService;
  final AiRouter _aiRouter;

  UrlProcessor({CloudflareService? cloudflareService, AiRouter? aiRouter})
      : _cloudflareService = cloudflareService ?? CloudflareService(),
        _aiRouter = aiRouter ?? AiRouter();

  /// Fetches an article or web page URL, cleans HTML tags, and summarizes it.
  Future<Map<String, String>> fetchAndSummarize(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw ArgumentError('Invalid URL provided: $url');
    }

    final response = await http.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError('Failed to fetch URL: HTTP ${response.statusCode}');
    }

    final rawHtml = response.body;

    // Strip scripts, styles, and tags
    var cleanText = rawHtml.replaceAll(RegExp(r'<script[\s\S]*?</script>'), ' ');
    cleanText = cleanText.replaceAll(RegExp(r'<style[\s\S]*?</style>'), ' ');
    cleanText = cleanText.replaceAll(RegExp(r'<[^>]*>'), ' ');
    cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleanText.isEmpty) {
      throw StateError('No readable text content found on this webpage.');
    }

    final truncated = cleanText.length > 12000 ? cleanText.substring(0, 12000) : cleanText;

    // Summarize with Cloudflare Workers AI if configured, otherwise fallback to AiRouter
    String summary = '';
    if (_cloudflareService.isConfigured) {
      try {
        summary = await _cloudflareService.summarizeText(truncated);
      } catch (_) {}
    }

    if (summary.trim().isEmpty) {
      try {
        summary = await _aiRouter.executeRealtimeChat(
          prompt: 'Summarize the key academic concepts and takeaways from this webpage text:\n\n$truncated',
          systemPrompt: 'You are Sage. Produce clear, accurate study notes grounded strictly in the provided text.',
        );
      } catch (_) {
        summary = cleanText.length > 600 ? '${cleanText.substring(0, 600)}...' : cleanText;
      }
    }

    return {
      'url': url,
      'rawText': cleanText,
      'summary': summary,
    };
  }
}
