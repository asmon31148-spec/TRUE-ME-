import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/document_chunk_model.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isNotEmpty && anonKey.isNotEmpty) {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
    }
  }

  /// Inserts a document chunk with its 768-dimensional Gemini embedding.
  Future<void> insertChunk({
    required String userId,
    required String notebookId,
    required String fileName,
    required int chunkIndex,
    required String content,
    required List<double> embedding,
  }) async {
    await _client.from('document_chunks').insert({
      'user_id': userId,
      'notebook_id': notebookId,
      'file_name': fileName,
      'chunk_index': chunkIndex,
      'content': content,
      'embedding': embedding,
    });
  }

  /// Performs vector similarity search via PostgreSQL RPC `match_document_chunks`.
  Future<List<DocumentChunkModel>> searchSimilarChunks({
    required List<double> queryEmbedding,
    int matchCount = 5,
    String? userId,
    String? notebookId,
  }) async {
    final response = await _client.rpc(
      'match_document_chunks',
      params: {
        'query_embedding': queryEmbedding,
        'match_count': matchCount,
        'filter_user_id': userId,
        'filter_notebook_id': notebookId,
      },
    );

    final rawList = response as List<dynamic>? ?? [];
    return rawList
        .map((item) => DocumentChunkModel.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Registers user file reference.
  Future<void> registerUserFile({
    required String userId,
    required String notebookId,
    required String fileName,
    required String fileType,
    required String driveFileId,
    required int sizeBytes,
    required int chunkCount,
  }) async {
    await _client.from('user_files').insert({
      'user_id': userId,
      'notebook_id': notebookId,
      'file_name': fileName,
      'file_type': fileType,
      'drive_file_id': driveFileId,
      'size_bytes': sizeBytes,
      'processed': true,
      'chunk_count': chunkCount,
    });
  }
}
