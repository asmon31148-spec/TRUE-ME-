import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/ai/ai_router.dart';

class YoutubeProcessor {
  final AiRouter _aiRouter;

  YoutubeProcessor({AiRouter? aiRouter}) : _aiRouter = aiRouter ?? AiRouter();

  /// Extracts the 11-char video ID from standard, shorts, or youtu.be URLs.
  static String? extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:v=|\/|youtu\.be\/)([0-9A-Za-z_-]{11})(?:[?&/]|$)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  /// Fetches video metadata via official public oEmbed API.
  static Future<Map<String, String>> fetchVideoMetadata(String url) async {
    try {
      final oembedUrl = Uri.parse('https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json');
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

  /// Fetches real closed captions / subtitles via YouTube InnerTube Android API
  /// (with watch-page fallback).
  static Future<String?> fetchCaptions(String videoId) async {
    List<dynamic>? tracks;

    // 1. InnerTube Android player endpoint (returns active timedtext URLs)
    try {
      final playerRes = await http
          .post(
            Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14)',
            },
            body: jsonEncode({
              'context': {
                'client': {
                  'clientName': 'ANDROID',
                  'clientVersion': '20.10.38',
                  'hl': 'en',
                  'gl': 'US',
                },
              },
              'videoId': videoId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (playerRes.statusCode == 200) {
        final data = jsonDecode(playerRes.body);
        final renderer = data['captions']?['playerCaptionsTracklistRenderer'];
        if (renderer is Map && renderer['captionTracks'] is List) {
          tracks = renderer['captionTracks'] as List<dynamic>;
        }
      }
    } catch (_) {}

    // 2. Watch-page fallback if InnerTube didn't yield tracks
    if (tracks == null || tracks.isEmpty) {
      try {
        final watchRes = await http.get(
          Uri.parse('https://www.youtube.com/watch?v=$videoId'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        ).timeout(const Duration(seconds: 15));

        if (watchRes.statusCode == 200) {
          final match = RegExp(r'"captionTracks":(\[.*?\])').firstMatch(watchRes.body);
          if (match != null) {
            tracks = jsonDecode(match.group(1)!) as List<dynamic>;
          }
        }
      } catch (_) {}
    }

    if (tracks == null || tracks.isEmpty) return null;

    try {
      // Prefer English manual track, then English auto-generated, then first track
      Map<String, dynamic> selectedTrack = Map<String, dynamic>.from(tracks.first as Map);
      for (final t in tracks) {
        final m = Map<String, dynamic>.from(t as Map);
        final lang = (m['languageCode'] as String? ?? '').toLowerCase();
        if (lang.startsWith('en')) {
          selectedTrack = m;
          if (m['kind'] != 'asr') break;
        }
      }

      final baseUrl = selectedTrack['baseUrl'] as String?;
      if (baseUrl == null || baseUrl.isEmpty) return null;

      final capRes = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14)',
        },
      ).timeout(const Duration(seconds: 15));

      if (capRes.statusCode != 200 || capRes.body.trim().isEmpty) return null;

      // Strip XML <p>/<text> tags and decode basic HTML entities
      var text = capRes.body.replaceAll(RegExp(r'<[^>]*>'), ' ');
      text = text
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&apos;', "'")
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      return text.isNotEmpty ? text : null;
    } catch (_) {
      return null;
    }
  }

  /// Processes YouTube link into grounded study notes ONLY when real transcript/captions exist.
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

    final transcript = (providedTranscript != null && providedTranscript.trim().isNotEmpty)
        ? providedTranscript.trim()
        : await fetchCaptions(videoId);

    if (transcript == null || transcript.isEmpty) {
      return 'Video: $videoTitle (by $videoAuthor)\nURL: $videoUrl\n\nNo closed captions or transcript tracks are available for this YouTube video. To avoid generating inaccurate or fabricated notes, please paste the lecture transcript or upload slides directly.';
    }

    final trimmedTranscript = transcript.length > 15000 ? transcript.substring(0, 15000) : transcript;

    final systemPrompt = '''
You are Sage, an academic study assistant. Turn ONLY the provided transcript into structured study notes.
Do not invent facts not mentioned in the transcript.
Include:
1. Summary for: $videoTitle
2. Key Concepts & Definitions
3. Important Equations or Steps (if present)
4. 3 Exam Takeaways
''';

    try {
      return await _aiRouter.executeHeavyReasoning(
        prompt: 'Video Title: $videoTitle by $videoAuthor\n\nTranscript:\n$trimmedTranscript',
        systemPrompt: systemPrompt,
      );
    } catch (_) {
      return 'Video: $videoTitle (by $videoAuthor)\n\nTranscript Extract:\n$trimmedTranscript';
    }
  }
}
