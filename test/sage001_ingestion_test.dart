import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trueme/core/ai/gemini_service.dart';
import 'package:trueme/core/ai/rag_service.dart';
import 'package:trueme/core/models/document_chunk_model.dart';
import 'package:trueme/core/models/ingestion_models.dart';
import 'package:trueme/core/services/offline_cache_service.dart';
import 'package:trueme/core/services/supabase_service.dart';
import 'package:trueme/core/utils/text_chunker.dart';
import 'package:trueme/features/upload/services/pdf_processor.dart';

class _FakeGeminiService extends GeminiService {
  @override
  Future<List<double>> generateEmbedding(String text) async {
    return List<double>.filled(768, 0.01);
  }
}

class _FakeSupabaseService extends SupabaseService {
  final bool cloudReady;
  final bool simulateVerificationZero;
  final List<Map<String, dynamic>> storedChunks = [];
  int deleteCalls = 0;

  _FakeSupabaseService({
    this.cloudReady = true,
    this.simulateVerificationZero = false,
  });

  @override
  bool get isCloudReady => cloudReady;

  @override
  Future<void> deleteChunksForFile({
    required String userId,
    required String notebookId,
    required String fileName,
  }) async {
    deleteCalls++;
    storedChunks.removeWhere(
      (c) =>
          c['user_id'] == userId &&
          c['notebook_id'] == notebookId &&
          c['file_name'] == fileName,
    );
  }

  @override
  Future<void> insertChunk({
    required String userId,
    required String notebookId,
    required String fileName,
    required int chunkIndex,
    required String content,
    required List<double> embedding,
    int? pageNumber,
    String? sectionLabel,
  }) async {
    storedChunks.add({
      'user_id': userId,
      'notebook_id': notebookId,
      'file_name': fileName,
      'chunk_index': chunkIndex,
      'content': content,
      'page_number': pageNumber,
      'section_label': sectionLabel,
    });
  }

  @override
  Future<int> verifyChunksPersisted({
    required String userId,
    required String notebookId,
    required String fileName,
  }) async {
    if (simulateVerificationZero) return 0;
    return storedChunks
        .where(
          (c) =>
              c['user_id'] == userId &&
              c['notebook_id'] == notebookId &&
              c['file_name'] == fileName,
        )
        .length;
  }
}

void main() {
  group('SAGE-001 Reliable Source Ingestion & Indexing', () {
    test('Quality gate handles selectable-text PDF and mixed unreadable pages', () {
      final pages = [
        const ExtractedPage(
          pageNumber: 1,
          text: 'Chapter 1: Fungi cell walls contain chitin and glucans.',
          isReadable: true,
        ),
        const ExtractedPage(
          pageNumber: 2,
          text: '',
          isReadable: false,
        ),
        const ExtractedPage(
          pageNumber: 3,
          text: 'Ascomycota produce ascospores inside an ascus.',
          isReadable: true,
        ),
      ];

      final bundle = PdfProcessor.buildQualityBundle(pages);
      expect(bundle.report.totalPages, 3);
      expect(bundle.report.readablePages, 2);
      expect(bundle.report.unreadablePageNumbers, [2]);
      expect(bundle.report.isUsable, isTrue);
      expect(bundle.report.needsOcr, isFalse);
      expect(bundle.report.summaryMessage, contains('2/3 pages readable'));
    });

    test('Quality gate flags scanned/image-only PDF as needsOcr and unusable', () {
      final scannedPages = [
        const ExtractedPage(pageNumber: 1, text: '', isReadable: false),
        const ExtractedPage(pageNumber: 2, text: '   ', isReadable: false),
      ];

      final bundle = PdfProcessor.buildQualityBundle(scannedPages);
      expect(bundle.report.totalPages, 2);
      expect(bundle.report.readablePages, 0);
      expect(bundle.report.unreadablePageNumbers, [1, 2]);
      expect(bundle.report.isUsable, isFalse);
      expect(bundle.report.needsOcr, isTrue);
    });

    test('Provenance-preserving chunker retains pageNumber and sectionLabel', () {
      final pages = [
        const ExtractedPage(
          pageNumber: 1,
          text: 'Page one explains Basidiomycota sexual reproduction.',
          isReadable: true,
        ),
        const ExtractedPage(pageNumber: 2, text: '', isReadable: false),
        const ExtractedPage(
          pageNumber: 3,
          text: 'Page three covers Zygomycota and sporangiospores.',
          isReadable: true,
        ),
      ];

      final chunks = TextChunker.splitPagesIntoChunks(
        pages,
        sectionLabel: 'Notes',
      );
      expect(chunks.length, 2);
      expect(chunks[0].pageNumber, 1);
      expect(chunks[0].sectionLabel, 'Notes');
      expect(chunks[1].pageNumber, 3);
      expect(chunks[1].sectionLabel, 'Notes');
    });

    test('RagService ingests idempotently with provenance and post-write verification', () async {
      final fakeSupa = _FakeSupabaseService(cloudReady: true);
      final rag = RagService(
        geminiService: _FakeGeminiService(),
        supabaseService: fakeSupa,
      );

      final pages = [
        const ExtractedPage(
          pageNumber: 1,
          text: 'Fungi are heterotrophic eukaryotes with chitin cell walls.',
          isReadable: true,
        ),
        const ExtractedPage(
          pageNumber: 2,
          text: 'Mycorrhizae form symbiotic associations with plant roots.',
          isReadable: true,
        ),
      ];

      final res1 = await rag.ingestDocumentWithVerification(
        userId: 'user_1',
        notebookId: 'nb_bio',
        fileName: 'fungi_notes.pdf',
        pages: pages,
        sectionLabel: 'Notes',
      );
      expect(res1.status, IngestionStatus.searchable);
      expect(res1.chunksCreated, 2);
      expect(res1.chunksVerified, 2);
      expect(fakeSupa.storedChunks.length, 2);
      expect(fakeSupa.storedChunks.first['page_number'], 1);
      expect(fakeSupa.storedChunks.first['section_label'], 'Notes');

      // Re-index same file -> must replace stale chunks without duplicating
      final res2 = await rag.ingestDocumentWithVerification(
        userId: 'user_1',
        notebookId: 'nb_bio',
        fileName: 'fungi_notes.pdf',
        pages: pages,
        sectionLabel: 'Notes',
      );
      expect(res2.status, IngestionStatus.searchable);
      expect(fakeSupa.deleteCalls, 2);
      expect(fakeSupa.storedChunks.length, 2);
    });

    test('RagService reports failed when verification finds 0 chunks and partial when offline', () async {
      final zeroVerifySupa = _FakeSupabaseService(
        cloudReady: true,
        simulateVerificationZero: true,
      );
      final ragFail = RagService(
        geminiService: _FakeGeminiService(),
        supabaseService: zeroVerifySupa,
      );
      final failRes = await ragFail.ingestDocumentWithVerification(
        userId: 'user_1',
        notebookId: 'nb_bio',
        fileName: 'notes.pdf',
        fullText: 'Sufficiently long text content for chunking and verification.',
      );
      expect(failRes.status, IngestionStatus.failed);
      expect(failRes.errorMessage, contains('Verification query returned 0'));

      final offlineSupa = _FakeSupabaseService(cloudReady: false);
      final ragOffline = RagService(
        geminiService: _FakeGeminiService(),
        supabaseService: offlineSupa,
      );
      final partialRes = await ragOffline.ingestDocumentWithVerification(
        userId: 'user_1',
        notebookId: 'nb_bio',
        fileName: 'notes.pdf',
        fullText: 'Sufficiently long text content for chunking while offline.',
      );
      expect(partialRes.status, IngestionStatus.partial);
      expect(partialRes.chunksVerified, 0);
    });

    test('OfflineCacheService persists truthful ingestion state and DocumentChunkModel maps provenance', () async {
      final tempDir = Directory.systemTemp.createTempSync('trueme_sage001_');
      Hive.init(tempDir.path);
      if (!Hive.isBoxOpen(OfflineCacheService.notebooksBox)) {
        await Hive.openBox(OfflineCacheService.notebooksBox);
      }
      try {
        await OfflineCacheService.cacheNotebook('nb_test', {
          'id': 'nb_test',
          'title': 'Botany',
          'documents': [
            {
              'id': 'doc_1',
              'fileName': 'fungi.pdf',
              'section': 'Notes',
              'content': 'Fungi lecture notes...',
            }
          ],
        });

        await OfflineCacheService.updateDocumentIngestionState(
          'nb_test',
          'doc_1',
          ingestionStatus: IngestionStatus.searchable.name,
          chunksCount: 4,
          chunksVerified: 4,
        );

        final docs = OfflineCacheService.getNotebookDocuments('nb_test');
        expect(docs.first['ingestionStatus'], 'searchable');
        expect(docs.first['chunksVerified'], 4);

        final chunk = DocumentChunkModel.fromMap({
          'id': 'c1',
          'user_id': 'u1',
          'notebook_id': 'nb_test',
          'file_name': 'fungi.pdf',
          'chunk_index': 0,
          'content': 'Sample',
          'page_number': 7,
          'section_label': 'Notes',
        });
        expect(chunk.pageNumber, 7);
        expect(chunk.sectionLabel, 'Notes');
      } finally {
        await Hive.close();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    });
  });
}
