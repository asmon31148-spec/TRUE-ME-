/// Truthful lifecycle states for source ingestion & indexing (SAGE-001).
enum IngestionStatus {
  pending,
  extracting,
  chunking,
  embedding,
  verifying,
  searchable,
  partial,
  needsOcr,
  failed;

  static IngestionStatus fromString(String? raw) {
    return IngestionStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => IngestionStatus.pending,
    );
  }

  String get displayLabel {
    switch (this) {
      case IngestionStatus.pending:
        return 'Pending';
      case IngestionStatus.extracting:
        return 'Extracting';
      case IngestionStatus.chunking:
        return 'Chunking';
      case IngestionStatus.embedding:
        return 'Indexing';
      case IngestionStatus.verifying:
        return 'Verifying';
      case IngestionStatus.searchable:
        return 'Searchable';
      case IngestionStatus.partial:
        return 'Partial';
      case IngestionStatus.needsOcr:
        return 'Needs OCR';
      case IngestionStatus.failed:
        return 'Index Failed';
    }
  }
}

/// Page-level extraction output preserving 1-based page provenance.
class ExtractedPage {
  final int pageNumber;
  final String text;
  final bool isReadable;
  final bool usedOcr;

  const ExtractedPage({
    required this.pageNumber,
    required this.text,
    required this.isReadable,
    this.usedOcr = false,
  });

  static bool assessReadability(String text) {
    final trimmed = text.trim();
    if (trimmed.length < 20) return false;
    final alnumCount = RegExp(r'[A-Za-z0-9]').allMatches(trimmed).length;
    return alnumCount >= 10;
  }
}

/// Quality gate report produced during source extraction.
class ExtractionQualityReport {
  final int totalPages;
  final int readablePages;
  final List<int> unreadablePageNumbers;
  final int charCount;
  final bool needsOcr;
  final bool isUsable;
  final String summaryMessage;

  const ExtractionQualityReport({
    required this.totalPages,
    required this.readablePages,
    required this.unreadablePageNumbers,
    required this.charCount,
    required this.needsOcr,
    required this.isUsable,
    required this.summaryMessage,
  });

  Map<String, dynamic> toMap() => {
        'totalPages': totalPages,
        'readablePages': readablePages,
        'unreadablePageNumbers': unreadablePageNumbers,
        'charCount': charCount,
        'needsOcr': needsOcr,
        'isUsable': isUsable,
        'summaryMessage': summaryMessage,
      };

  factory ExtractionQualityReport.fromMap(Map<String, dynamic> map) {
    return ExtractionQualityReport(
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 0,
      readablePages: (map['readablePages'] as num?)?.toInt() ?? 0,
      unreadablePageNumbers: (map['unreadablePageNumbers'] as List? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      charCount: (map['charCount'] as num?)?.toInt() ?? 0,
      needsOcr: map['needsOcr'] == true,
      isUsable: map['isUsable'] == true,
      summaryMessage: map['summaryMessage'] as String? ?? '',
    );
  }
}

/// Typed exception for ingestion pipeline failures (never swallowed).
class IngestionException implements Exception {
  final String stage;
  final String message;
  final bool isRetryable;

  const IngestionException({
    required this.stage,
    required this.message,
    this.isRetryable = true,
  });

  @override
  String toString() => 'IngestionException($stage): $message';
}

/// Result returned after chunking, embedding, persistence, and verification.
class IngestionResult {
  final IngestionStatus status;
  final int chunksCreated;
  final int chunksVerified;
  final String? errorMessage;
  final DateTime completedAt;

  const IngestionResult({
    required this.status,
    required this.chunksCreated,
    required this.chunksVerified,
    this.errorMessage,
    required this.completedAt,
  });
}
