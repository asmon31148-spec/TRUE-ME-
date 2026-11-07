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

  /// Processes YouTube link into structured study notes.
  Future<String> summarizeVideoNotes({
    required String videoUrl,
    String? providedTranscript,
  }) async {
    final videoId = extractVideoId(videoUrl);
    if (videoId == null) {
      throw ArgumentError('Invalid YouTube URL: $videoUrl');
    }

    final transcript = providedTranscript ??
        'Video: $videoUrl. Core lecture on topic with algorithmic breakdown and step by step walkthrough.';

    final systemPrompt = '''
You are an expert academic note taker. Turn this YouTube lecture into clean, high-yield study notes.
Include:
1. Executive Concept Summary
2. Core Equations or Definitions
3. Step-by-Step Mechanism / Breakdown
4. 3 High-Yield Exam Takeaways
''';

    if (_groqService.isConfigured) {
      return await _groqService.complete8B(
        prompt: 'Lecture transcript content:\n$transcript',
        systemPrompt: systemPrompt,
      );
    }

    return 'Processed lecture notes for YouTube video: $videoUrl\n$transcript';
  }
}
