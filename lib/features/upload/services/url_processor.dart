import 'package:http/http.dart' as http;
import '../../../core/ai/cloudflare_service.dart';

class UrlProcessor {
  final CloudflareService _cloudflareService;

  UrlProcessor({CloudflareService? cloudflareService})
      : _cloudflareService = cloudflareService ?? CloudflareService();

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
    );

    if (response.statusCode != 200) {
      throw StateError('Failed to fetch URL: HTTP ${response.statusCode}');
    }

    final rawHtml = response.body;

    // Strip scripts, styles, and tags
    var cleanText = rawHtml.replaceAll(RegExp(r'<script[\s\S]*?</script>'), ' ');
    cleanText = cleanText.replaceAll(RegExp(r'<style[\s\S]*?</style>'), ' ');
    cleanText = cleanText.replaceAll(RegExp(r'<[^>]*>'), ' ');
    cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Summarize with Cloudflare Workers AI
    String summary = '';
    if (_cloudflareService.isConfigured) {
      try {
        summary = await _cloudflareService.summarizeText(cleanText);
      } catch (_) {
        summary = cleanText.length > 500 ? cleanText.substring(0, 500) : cleanText;
      }
    }

    return {
      'url': url,
      'rawText': cleanText,
      'summary': summary,
    };
  }
}
