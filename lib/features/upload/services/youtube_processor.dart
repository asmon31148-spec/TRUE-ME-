import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/ai/groq_service.dart';

class YoutubeProcessor {
  final GroqService _groqService;

  YoutubeProcessor({GroqService? groqService})
      : _groqService = groqService ?? GroqService();

  /// Extracts the video ID from standard or shortened YouTube URLs.
  static String? extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:v=|\/)([0-9A-Za-z_-]{11}).*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  /// Fetches video metadata via official public oEmbed API.
  static Future<Map<String, String>> fetchVideoMetadata(String url) async {
    try {
      final oembedUrl = Uri.parse('https://www.youtube.com/oembed?url=$url&format=json');
      final res = await http.get(oembedUrl).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'title': data['title'] as String? ?? 'Lecture Video',
          'author': data['author_name'] as String? ?? 'Educator',
        };
      }
    } catch (_) {}
    return {'title': 'Lecture Video', 'author': 'Educator'};
  }

  /// Processes YouTube link into structured study notes.
  Future<String> summarizeVideoNotes({
    required String videoUrl,
    String? providedTranscript,
  }) async {
    final videoId = extractVideoId(videoUrl);
    if (videoId == null) {
      throw ArgumentError('Invalid YouTube URL: $videoUrl');
    }

    final meta = await fetchVideoMetadata(videoUrl);
    final videoTitle = meta['title']!;
    final videoAuthor = meta['author']!;

    final transcript = providedTranscript ??
        'Video Title: "$videoTitle" by $videoAuthor.\nURL: $videoUrl';

    final systemPrompt = '''
You are Sage, an expert academic note taker. Turn this lecture into clean, high-yield study notes.
Include:
1. Executive Concept Summary for: $videoTitle
2. Core Equations or Definitions
3. Step-by-Step Breakdown
4. 3 High-Yield Exam Takeaways
''';

    if (_groqService.isConfigured) {
      return await _groqService.complete8B(
        prompt: 'Content details:\n$transcript',
        systemPrompt: systemPrompt,
      );
    }

    return '# $videoTitle\nBy $videoAuthor\n\nStudy notes processed for $videoUrl';
  }
}
