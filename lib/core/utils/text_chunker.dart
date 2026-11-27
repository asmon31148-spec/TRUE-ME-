import '../models/ingestion_models.dart';

class TextChunk {
  final int index;
  final String content;
  final int charCount;
  final int? pageNumber;
  final String? sectionLabel;

  const TextChunk({
    required this.index,
    required this.content,
    required this.charCount,
    this.pageNumber,
    this.sectionLabel,
  });
}

class TextChunker {
  TextChunker._();

  /// Splits long text into chunks of approximately [targetChunkChars] characters
  /// (roughly 800 - 1000 tokens) with an [overlapChars] sliding window to maintain
  /// semantic coherence across boundaries.
  static List<TextChunk> splitIntoChunks(
    String text, {
    int targetChunkChars = 3500, // ~800-1000 tokens in English
    int overlapChars = 400, // ~100 tokens overlap
  }) {
    final cleanText = text.replaceAll(RegExp(r'\r\n|\r'), '\n').trim();
    if (cleanText.isEmpty) return [];

    if (cleanText.length <= targetChunkChars) {
      return [
        TextChunk(
          index: 0,
          content: cleanText,
          charCount: cleanText.length,
        ),
      ];
    }

    final List<TextChunk> chunks = [];
    int start = 0;
    int chunkIndex = 0;

    while (start < cleanText.length) {
      final prevStart = start;
      int end = start + targetChunkChars;

      if (end >= cleanText.length) {
        final chunkText = cleanText.substring(start).trim();
        if (chunkText.isNotEmpty) {
          chunks.add(
            TextChunk(
              index: chunkIndex,
              content: chunkText,
              charCount: chunkText.length,
            ),
          );
        }
        break;
      }

      // Look for natural break points (paragraph, newline, period, space)
      int breakPoint = cleanText.lastIndexOf('\n\n', end);
      if (breakPoint <= start) {
        breakPoint = cleanText.lastIndexOf('\n', end);
      }
      if (breakPoint <= start) {
        breakPoint = cleanText.lastIndexOf('. ', end);
        if (breakPoint > start) breakPoint += 1; // Include the period
      }
      if (breakPoint <= start) {
        breakPoint = cleanText.lastIndexOf(' ', end);
      }
      if (breakPoint <= start) {
        // No natural space found, hard cut
        breakPoint = end;
      }

      final chunkContent = cleanText.substring(start, breakPoint).trim();
      if (chunkContent.isNotEmpty) {
        chunks.add(
          TextChunk(
            index: chunkIndex,
            content: chunkContent,
            charCount: chunkContent.length,
          ),
        );
        chunkIndex++;
      }

      // Slide start forward, keeping the overlap while guaranteeing forward progress
      start = breakPoint - overlapChars;
      if (start <= prevStart || start <= 0) {
        start = breakPoint;
      }
    }

    return chunks;
  }

  /// Splits page-level extracted text into provenance-preserving chunks so each
  /// chunk retains the 1-based [pageNumber] and [sectionLabel] where it originated.
  static List<TextChunk> splitPagesIntoChunks(
    List<ExtractedPage> pages, {
    String? sectionLabel,
    int targetChunkChars = 3500,
    int overlapChars = 400,
  }) {
    final List<TextChunk> result = [];
    int globalIndex = 0;

    for (final page in pages) {
      if (!page.isReadable || page.text.trim().isEmpty) continue;
      final pageChunks = splitIntoChunks(
        page.text,
        targetChunkChars: targetChunkChars,
        overlapChars: overlapChars,
      );
      for (final ch in pageChunks) {
        result.add(
          TextChunk(
            index: globalIndex++,
            content: ch.content,
            charCount: ch.charCount,
            pageNumber: page.pageNumber,
            sectionLabel: sectionLabel,
          ),
        );
      }
    }

    return result;
  }
}
