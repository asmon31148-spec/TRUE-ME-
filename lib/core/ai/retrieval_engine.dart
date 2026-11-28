import '../models/document_chunk_model.dart';
import '../services/offline_cache_service.dart';
import '../services/supabase_service.dart';
import '../utils/text_chunker.dart';
import 'rag_service.dart';

/// A single retrieved passage with full provenance & relevance explanation (SAGE-002).
class EvidencePassage {
  final String fileName;
  final String? sectionLabel;
  final int? pageNumber;
  final int chunkIndex;
  final String content;
  final double score;
  final String retrievalMethod; // 'vector', 'lexical', 'hybrid'
  final String relevanceReason;

  const EvidencePassage({
    required this.fileName,
    this.sectionLabel,
    this.pageNumber,
    required this.chunkIndex,
    required this.content,
    required this.score,
    required this.retrievalMethod,
    required this.relevanceReason,
  });

  String get provenanceLabel {
    final parts = <String>[fileName];
    if (sectionLabel != null && sectionLabel!.isNotEmpty) {
      parts.add(sectionLabel!);
    }
    if (pageNumber != null) {
      parts.add('p.$pageNumber');
    } else {
      parts.add('Chunk #${chunkIndex + 1}');
    }
    return parts.join(' · ');
  }
}

/// Structured evidence bundle returned by [RetrievalEngine] (SAGE-002).
class EvidenceBundle {
  final String query;
  final List<EvidencePassage> passages;
  final List<String> decomposedSubQueries;
  final bool hasSufficientEvidence;
  final String diagnosticNote;

  const EvidenceBundle({
    required this.query,
    required this.passages,
    this.decomposedSubQueries = const [],
    required this.hasSufficientEvidence,
    required this.diagnosticNote,
  });

  List<String> get formattedExcerpts => passages
      .map((p) => '[Source: ${p.provenanceLabel} | ${p.relevanceReason}]\n${p.content}')
      .toList();

  String? get primaryCitation =>
      passages.isNotEmpty ? passages.first.provenanceLabel : null;
}

/// SAGE-002 Intelligent Retrieval & Evidence Engine:
/// Combines vector + lexical retrieval, query decomposition, minimum relevance
/// thresholds (rejecting zero-score junk), deduplication, and source diversity.
class RetrievalEngine {
  final RagService _ragService;

  RetrievalEngine({RagService? ragService})
      : _ragService = ragService ?? RagService();

  static const double minVectorSimilarity = 0.25;

  /// Decomposes compound student queries into focused sub-queries.
  static List<String> decomposeQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final parts = trimmed
        .split(RegExp(r'\b(?:and|vs\.?|versus|compared to)\b|[?;]', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.length >= 4)
        .toList();
    if (parts.length <= 1) return [trimmed];
    return [trimmed, ...parts.take(3)];
  }

  static Set<String> extractQueryTerms(String query) {
    const stopWords = {
      'the', 'is', 'are', 'was', 'were', 'what', 'which', 'how', 'why', 'when',
      'who', 'where', 'this', 'that', 'these', 'those', 'with', 'from', 'for',
      'into', 'about', 'explain', 'define', 'give', 'make', 'create', 'notes',
      'please', 'can', 'you', 'your', 'our', 'and', 'or', 'of', 'in', 'to', 'a', 'an',
    };
    return query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.length >= 2 && !stopWords.contains(w))
        .toSet();
  }

  /// LangGraph-style query-rewrite helper: strips conversational filler and
  /// returns a broader keyword query when the first retrieval pass yields nothing.
  static String? broadenQuery(String query) {
    final terms = extractQueryTerms(query).toList();
    if (terms.isEmpty) return null;
    final broadened = terms.take(6).join(' ');
    if (broadened.isEmpty || broadened.toLowerCase() == query.trim().toLowerCase()) {
      return null;
    }
    return broadened;
  }

  /// Hybrid retrieval with strict subject isolation (`notebookId`), relevance
  /// threshold gating, deduplication, and source diversity.
  Future<EvidenceBundle> retrieveEvidence({
    required String query,
    required String userId,
    required String? notebookId,
    String? sectionFilter,
    int topK = 5,
    List<Map<String, dynamic>>? overrideLocalDocs,
  }) async {
    if (notebookId == null || notebookId.trim().isEmpty) {
      return EvidenceBundle(
        query: query,
        passages: const [],
        decomposedSubQueries: decomposeQuery(query),
        hasSufficientEvidence: false,
        diagnosticNote: 'No subject notebook scoped; skipping subject-specific retrieval.',
      );
    }

    final subQueries = decomposeQuery(query);
    final queryTerms = extractQueryTerms(query);
    final Map<String, EvidencePassage> deduped = {};

    // 1. Hybrid semantic + keyword retrieval (Supabase pgvector + FTS RRF) with 3.5s timeout
    // Skip cloud RPC completely when offline/unauthenticated (0ms delay!)
    if (SupabaseService.instance.isCloudReady || overrideLocalDocs == null) {
      try {
        if (SupabaseService.instance.isCloudReady) {
          final vectorChunks = await _ragService
              .retrieveContext(
                query: query,
                userId: userId,
                notebookId: notebookId,
                topK: topK + 2,
              )
              .timeout(const Duration(milliseconds: 3500),
                  onTimeout: () => <DocumentChunkModel>[]);

          for (final c in vectorChunks) {
            if (c.similarity > 0 && c.similarity < minVectorSimilarity) continue;
            final fName = c.fileName ?? 'Notebook';
            if (sectionFilter != null &&
                sectionFilter.isNotEmpty &&
                c.sectionLabel != null &&
                c.sectionLabel!.toLowerCase() != sectionFilter.toLowerCase()) {
              continue;
            }
            final key = '$fName::${c.chunkIndex}';
            deduped[key] = EvidencePassage(
              fileName: fName,
              sectionLabel: c.sectionLabel,
              pageNumber: c.pageNumber,
              chunkIndex: c.chunkIndex,
              content: c.content,
              score: c.similarity > 0 ? c.similarity : 0.55,
              retrievalMethod: 'vector',
              relevanceReason: c.similarity > 0
                  ? 'Semantic match (${(c.similarity * 100).toStringAsFixed(0)}%)'
                  : 'Semantic match',
            );
          }
        }
      } catch (_) {
        // Fall back to lexical retrieval over local verified documents
      }
    }

    // 2. Lexical retrieval over local notebook documents (skipping unreadable/empty docs)
    final localDocs = overrideLocalDocs ??
        OfflineCacheService.getNotebookDocuments(notebookId, section: sectionFilter);

    for (final doc in localDocs) {
      final content = (doc['content'] as String? ?? '').trim();
      if (content.length < 20) continue;
      final fName = doc['fileName'] as String? ?? 'Document';
      final section = doc['section'] as String? ?? 'Notes';

      final chunks = TextChunker.splitIntoChunks(
        content,
        targetChunkChars: 2500,
        overlapChars: 250,
      );
      for (final ch in chunks) {
        final lower = ch.content.toLowerCase();
        int matched = 0;
        for (final term in queryTerms) {
          if (lower.contains(term)) matched++;
        }
        if (matched == 0) continue; // Reject zero-score chunks!

        final lexicalScore = queryTerms.isEmpty
            ? 0.0
            : (matched / queryTerms.length).clamp(0.0, 1.0);
        if (lexicalScore < 0.15 && matched < 2) continue;

        final key = '$fName::${ch.index}';
        final existing = deduped[key];
        if (existing != null) {
          final hybridScore = (existing.score * 0.65 + lexicalScore * 0.35).clamp(0.0, 1.0);
          deduped[key] = EvidencePassage(
            fileName: existing.fileName,
            sectionLabel: existing.sectionLabel ?? section,
            pageNumber: existing.pageNumber,
            chunkIndex: existing.chunkIndex,
            content: existing.content,
            score: hybridScore,
            retrievalMethod: 'hybrid',
            relevanceReason:
                'Hybrid match ($matched/${queryTerms.length} terms, ${existing.relevanceReason})',
          );
        } else {
          deduped[key] = EvidencePassage(
            fileName: fName,
            sectionLabel: section,
            pageNumber: ch.pageNumber,
            chunkIndex: ch.index,
            content: ch.content,
            score: lexicalScore,
            retrievalMethod: 'lexical',
            relevanceReason: 'Matched $matched/${queryTerms.length} query terms',
          );
        }
      }
    }

    // 2.5 LangGraph-style Query-Rewrite Retry Loop if first pass yielded no hits
    String? retriedQuery;
    if (deduped.isEmpty) {
      final broader = broadenQuery(query);
      if (broader != null) {
        retriedQuery = broader;
        final broaderTerms = extractQueryTerms(broader);
        if (SupabaseService.instance.isCloudReady) {
          try {
            final retryChunks = await _ragService
                .retrieveContext(
                  query: broader,
                  userId: userId,
                  notebookId: notebookId,
                  topK: topK + 2,
                )
                .timeout(const Duration(milliseconds: 2500),
                    onTimeout: () => <DocumentChunkModel>[]);
            for (final c in retryChunks) {
              if (c.similarity > 0 && c.similarity < minVectorSimilarity) continue;
              final fName = c.fileName ?? 'Notebook';
              final key = '$fName::${c.chunkIndex}';
              deduped[key] = EvidencePassage(
                fileName: fName,
                sectionLabel: c.sectionLabel,
                pageNumber: c.pageNumber,
                chunkIndex: c.chunkIndex,
                content: c.content,
                score: (c.similarity > 0 ? c.similarity : 0.50) * 0.92,
                retrievalMethod: 'hybrid',
                relevanceReason: 'Broadened query retry ("$broader")',
              );
            }
          } catch (_) {}
        }
        for (final doc in localDocs) {
          final content = (doc['content'] as String? ?? '').trim();
          if (content.length < 20) continue;
          final fName = doc['fileName'] as String? ?? 'Document';
          final section = doc['section'] as String? ?? 'Notes';
          final chunks = TextChunker.splitIntoChunks(
            content,
            targetChunkChars: 2500,
            overlapChars: 250,
          );
          for (final ch in chunks) {
            final lower = ch.content.toLowerCase();
            int matched = 0;
            for (final term in broaderTerms) {
              if (lower.contains(term)) matched++;
            }
            if (matched == 0) continue;
            final key = '$fName::${ch.index}';
            deduped.putIfAbsent(
              key,
              () => EvidencePassage(
                fileName: fName,
                sectionLabel: section,
                pageNumber: ch.pageNumber,
                chunkIndex: ch.index,
                content: ch.content,
                score: (matched / broaderTerms.length).clamp(0.15, 0.85),
                retrievalMethod: 'lexical',
                relevanceReason: 'Broadened retry ($matched/${broaderTerms.length} terms)',
              ),
            );
          }
        }
      }
    }

    // 3. Rank + enforce source diversity (max 2 chunks per single file when others exist)
    final ranked = deduped.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final List<EvidencePassage> diverse = [];
    final Map<String, int> perFileCount = {};
    for (final p in ranked) {
      final count = perFileCount[p.fileName] ?? 0;
      if (count >= 2 && ranked.length > topK) continue;
      diverse.add(p);
      perFileCount[p.fileName] = count + 1;
      if (diverse.length >= topK) break;
    }

    // Fill remaining slots if diversity cap left room
    if (diverse.length < topK) {
      for (final p in ranked) {
        if (!diverse.contains(p)) {
          diverse.add(p);
          if (diverse.length >= topK) break;
        }
      }
    }

    final sufficient = diverse.isNotEmpty;
    return EvidenceBundle(
      query: query,
      passages: diverse,
      decomposedSubQueries: [
        ...subQueries,
        if (retriedQuery != null && retriedQuery.isNotEmpty) retriedQuery,
      ],
      hasSufficientEvidence: sufficient,
      diagnosticNote: sufficient
          ? (retriedQuery != null
              ? 'Retrieved ${diverse.length} passage(s) via broadened query retry ("$retriedQuery").'
              : 'Retrieved ${diverse.length} verified passage(s) across ${perFileCount.length} source(s).')
          : 'No uploaded passages met the relevance threshold for this query.',
    );
  }
}
