import 'dart:convert';

class PollinationsService {
  PollinationsService._();

  static const String _baseUrl = 'https://image.pollinations.ai/prompt';

  /// Generates a direct image URL for study diagrams and flashcards.
  /// No API key or credit card required — 100% free and unlimited.
  static String getImageUrl({
    required String prompt,
    int width = 800,
    int height = 600,
    String model = 'flux',
    bool noLogo = true,
    int? seed,
  }) {
    final cleanPrompt = Uri.encodeComponent(
      'clear scientific diagram or concept visual for university study: $prompt, high resolution, minimalist, clean educational illustration',
    );

    final buffer = StringBuffer('$_baseUrl/$cleanPrompt?width=$width&height=$height&model=$model');
    if (noLogo) buffer.write('&nologo=true');
    if (seed != null) buffer.write('&seed=$seed');

    return buffer.toString();
  }
}
