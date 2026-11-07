class DocumentChunkModel {
  final String id;
  final String userId;
  final String notebookId;
  final String? fileName;
  final int chunkIndex;
  final String content;
  final double similarity; // Computed cosine similarity for search results

  const DocumentChunkModel({
    required this.id,
    required this.userId,
    required this.notebookId,
    this.fileName,
    required this.chunkIndex,
    required this.content,
    this.similarity = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'notebook_id': notebookId,
      'file_name': fileName,
      'chunk_index': chunkIndex,
      'content': content,
    };
  }

  factory DocumentChunkModel.fromMap(Map<String, dynamic> map) {
    return DocumentChunkModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      notebookId: map['notebook_id']?.toString() ?? '',
      fileName: map['file_name']?.toString(),
      chunkIndex: (map['chunk_index'] as num?)?.toInt() ?? 0,
      content: map['content']?.toString() ?? '',
      similarity: (map['similarity'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
