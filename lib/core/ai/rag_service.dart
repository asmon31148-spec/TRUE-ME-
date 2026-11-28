import '../models/document_chunk_model.dart';
import '../models/ingestion_models.dart';
import '../services/supabase_service.dart';
import '../utils/text_chunker.dart';
import 'gemini_service.dart';

class RagService {
  final GeminiService _geminiService;
  final SupabaseService _supabaseService;

  RagService({
    GeminiService? geminiService,
    SupabaseService? supabaseService,
  })  : _geminiService = geminiService ?? GeminiService(),
        _supabaseService = supabaseService ?? SupabaseService();

  /// Truthful, idempotent SAGE-001 ingestion pipeline:
  /// Pages/Text -> Provenance Chunks -> Delete Stale -> Gemini Embeddings -> Supabase -> Verification Query.
  Future<IngestionResult> ingestDocumentWithVerification({
    required String userId,
    required String notebookId,
    required String fileName,
    String? fullText,
    List<ExtractedPage>? pages,
    String? sectionLabel,
    void Function(IngestionStatus status)? onStage,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      onStage?.call(IngestionStatus.chunking);
      final List<TextChunk> chunks;
      if (pages != null && pages.isNotEmpty) {
        chunks = TextChunker.splitPagesIntoChunks(
          pages,
          sectionLabel: sectionLabel,
        );
      } else {
        final rawChunks = TextChunker.splitIntoChunks(fullText ?? '');
        chunks = rawChunks
            .map((c) => TextChunk(
                  index: c.index,
                  content: c.content,
                  charCount: c.charCount,
                  sectionLabel: sectionLabel,
                ))
            .toList();
      }

      if (chunks.isEmpty) {
        return IngestionResult(
          status: IngestionStatus.needsOcr,
          chunksCreated: 0,
          chunksVerified: 0,
          errorMessage: 'No readable text chunks could be created from this source.',
          completedAt: DateTime.now(),
        );
      }

      if (!_supabaseService.isCloudReady) {
        return IngestionResult(
          status: IngestionStatus.partial,
          chunksCreated: chunks.length,
          chunksVerified: 0,
          errorMessage:
              'Saved locally (${chunks.length} chunks ready). Cloud vector indexing requires sign-in and network.',
          completedAt: DateTime.now(),
        );
      }

      onStage?.call(IngestionStatus.embedding);
      // Generate embeddings in true batch calls (up to 40 chunks per HTTP call)
      // to avoid 502/429 bursts. If cloud embeddings fail, fall back gracefully
      // to partial local keyword/BM25 indexing so the book remains searchable.
      const batchSize = 40;
      final preparedRows = List<Map<String, dynamic>?>.filled(chunks.length, null);
      int completedCount = 0;

      try {
        for (int start = 0; start < chunks.length; start += batchSize) {
          final end = (start + batchSize).clamp(0, chunks.length);
          final batchChunks = chunks.sublist(start, end);
          final embeddings = await _geminiService.generateBatchEmbeddings(
            batchChunks.map((c) => c.content).toList(),
          );
          if (embeddings.length != batchChunks.length) {
            throw IngestionException(
              stage: 'embedding',
              message: 'Batch embedding count mismatch: expected ${batchChunks.length}, got ${embeddings.length}',
            );
          }
          for (int offset = 0; offset < batchChunks.length; offset++) {
            final idx = start + offset;
            final chunk = batchChunks[offset];
            final embedding = embeddings[offset];
            if (embedding.length != 768) {
              throw IngestionException(
                stage: 'embedding',
                message: 'Embedding dimension mismatch: expected 768, got ${embedding.length}',
              );
            }
            preparedRows[idx] = {
              'user_id': userId,
              'notebook_id': notebookId,
              'file_name': fileName,
              'chunk_index': chunk.index,
              'content': chunk.content,
              'embedding': embedding,
              if (chunk.pageNumber != null) 'page_number': chunk.pageNumber,
              if (chunk.sectionLabel != null) 'section_label': chunk.sectionLabel,
            };
          }
          completedCount = end;
          onProgress?.call(completedCount, chunks.length);
        }
      } catch (embedErr) {
        onStage?.call(IngestionStatus.partial);
        return IngestionResult(
          status: IngestionStatus.partial,
          chunksCreated: chunks.length,
          chunksVerified: 0,
          errorMessage:
              'Saved locally (${chunks.length} chunks searchable via keyword/BM25). Cloud vector sync skipped: $embedErr',
          completedAt: DateTime.now(),
        );
      }

      // Idempotent replace: delete stale chunks only after all embeddings succeeded,
      // then insert via batch (or per-chunk if batch is overridden in tests/legacy).
      await _supabaseService.deleteChunksForFile(
        userId: userId,
        notebookId: notebookId,
        fileName: fileName,
      );

      final rows = preparedRows.whereType<Map<String, dynamic>>().toList();
      if (_supabaseService.isCloudReady &&
          _supabaseService.clientOrNull != null) {
        await _supabaseService.insertChunksBatch(rows);
      } else {
        for (int i = 0; i < chunks.length; i++) {
          final chunk = chunks[i];
          final emb = rows[i]['embedding'] as List<double>;
          await _supabaseService.insertChunk(
            userId: userId,
            notebookId: notebookId,
            fileName: fileName,
            chunkIndex: chunk.index,
            content: chunk.content,
            embedding: emb,
            pageNumber: chunk.pageNumber,
            sectionLabel: chunk.sectionLabel,
          );
        }
      }

      onStage?.call(IngestionStatus.verifying);
      final verifiedCount = await _supabaseService.verifyChunksPersisted(
        userId: userId,
        notebookId: notebookId,
        fileName: fileName,
      );

      if (verifiedCount <= 0) {
        return IngestionResult(
          status: IngestionStatus.failed,
          chunksCreated: chunks.length,
          chunksVerified: 0,
          errorMessage: 'Verification query returned 0 persisted chunks in cloud index.',
          completedAt: DateTime.now(),
        );
      }

      if (verifiedCount < chunks.length) {
        return IngestionResult(
          status: IngestionStatus.partial,
          chunksCreated: chunks.length,
          chunksVerified: verifiedCount,
          errorMessage:
              'Partial index: $verifiedCount of ${chunks.length} chunks verified in cloud index.',
          completedAt: DateTime.now(),
        );
      }

      return IngestionResult(
        status: IngestionStatus.searchable,
        chunksCreated: chunks.length,
        chunksVerified: verifiedCount,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      return IngestionResult(
        status: IngestionStatus.failed,
        chunksCreated: 0,
        chunksVerified: 0,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  /// Legacy convenience wrapper returning verified chunk count.
  Future<int> ingestDocument({
    required String userId,
    required String notebookId,
    required String fileName,
    required String fullText,
  }) async {
    final res = await ingestDocumentWithVerification(
      userId: userId,
      notebookId: notebookId,
      fileName: fileName,
      fullText: fullText,
    );
    if (res.status == IngestionStatus.failed) {
      throw IngestionException(
        stage: 'ingestion',
        message: res.errorMessage ?? 'Ingestion failed',
      );
    }
    return res.chunksVerified > 0 ? res.chunksVerified : res.chunksCreated;
  }

  Future<void> deleteDocumentChunks({
    required String userId,
    required String notebookId,
    required String fileName,
  }) async {
    await _supabaseService.deleteChunksForFile(
      userId: userId,
      notebookId: notebookId,
      fileName: fileName,
    );
  }

  /// Grounded retrieval: Query -> Gemini Embedding -> Cosine Similarity Search.
  Future<List<DocumentChunkModel>> retrieveContext({
    required String query,
    required String userId,
    String? notebookId,
    int topK = 5,
  }) async {
    // 1. Embed query
    final queryEmbedding = await _geminiService.generateEmbedding(query);
    if (queryEmbedding.length != 768) {
      throw StateError('Query embedding dimension mismatch: expected 768, got ${queryEmbedding.length}');
    }

    // 2. Retrieve top-K most similar chunks using hybrid search (pgvector + FTS RRF)
    return await _supabaseService.searchSimilarChunks(
      queryEmbedding: queryEmbedding,
      queryText: query,
      matchCount: topK,
      userId: userId,
      notebookId: notebookId,
    );
  }

  /// Formats retrieved chunks with explicit source citations and low-evidence
  /// disclosure for grounded generation (RAG-02).
  static String formatGroundedContextWithCitations(List<DocumentChunkModel> chunks) {
    if (chunks.isEmpty) {
      return '[NO_MATCHING_STUDY_CHUNKS] No direct matches were found in the student\'s uploaded material. '
          'Disclose clearly if answering from general knowledge.';
    }
    final buffer = StringBuffer();
    for (final c in chunks) {
      buffer.writeln('[Source: ${c.fileName} | Chunk #${c.chunkIndex}]');
      buffer.writeln(c.content.trim());
      buffer.writeln();
    }
    return buffer.toString().trim();
  }
}
