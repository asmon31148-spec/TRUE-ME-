import '../models/document_chunk_model.dart';
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

  /// Full ingestion pipeline: Text -> 1000-token Chunks -> Gemini Embeddings -> Supabase pgvector.
  Future<int> ingestDocument({
    required String userId,
    required String notebookId,
    required String fileName,
    required String fullText,
  }) async {
    // 1. Split into overlapping chunks
    final chunks = TextChunker.splitIntoChunks(fullText);
    if (chunks.isEmpty) return 0;

    // 2. Generate embeddings and store in pgvector
    for (final chunk in chunks) {
      final embedding = await _geminiService.generateEmbedding(chunk.content);

      await _supabaseService.insertChunk(
        userId: userId,
        notebookId: notebookId,
        fileName: fileName,
        chunkIndex: chunk.index,
        content: chunk.content,
        embedding: embedding,
      );
    }

    return chunks.length;
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

    // 2. Retrieve top-K most similar chunks from pgvector
    return await _supabaseService.searchSimilarChunks(
      queryEmbedding: queryEmbedding,
      matchCount: topK,
      userId: userId,
      notebookId: notebookId,
    );
  }
}
