import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/ai/syllabus_service.dart';
import '../../../core/services/cloud_vault_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../docx_exporter.dart';
import '../models/structured_study_document.dart';
import '../pdf_exporter.dart';
import '../pptx_exporter.dart';
import 'document_parser_service.dart';
import 'document_pipeline_service.dart';

class GeneratedDocumentResult {
  final String documentId;
  final String notebookId;
  final String format;
  final String styleId;
  final String title;
  final String filePath;
  final int fileSize;
  final int? slideCount;
  final StructuredStudyDocument structuredDoc;

  const GeneratedDocumentResult({
    required this.documentId,
    required this.notebookId,
    required this.format,
    required this.styleId,
    required this.title,
    required this.filePath,
    required this.fileSize,
    this.slideCount,
    required this.structuredDoc,
  });
}

/// Unified Document Generation Service shared by BOTH Study Library and Sage Chat.
/// Ensures one pipeline, one 12-style system, output QA validation, and idempotent persistence.
class DocumentGenerationService {
  DocumentGenerationService._();

  static const String styleVersion = 'v2';

  /// Detects an explicit style requested by the USER (never scans AI output).
  /// Returns a canonical [StylePickerSheet] ID, or `null` if the user did not specify one.
  static String? detectExplicitStyleId(String userPrompt, String format) {
    final q = userPrompt.toLowerCase();
    switch (format.toLowerCase()) {
      case 'pdf':
        if (q.contains('handwritten') || q.contains('cornell')) return 'handwritten_notes';
        if (q.contains('vintage') || q.contains('parchment') || q.contains('zen')) {
          return 'vintage_academic';
        }
        if (q.contains('cute') || q.contains('pastel') || q.contains('aesthetic')) {
          return 'cute_aesthetic';
        }
        if (q.contains('modern academic')) return 'modern_academic';
        return null;
      case 'docx':
        if (q.contains('elegant')) return 'elegant_academic_notes';
        if (q.contains('research report') || q.contains('professional')) {
          return 'professional_research_report';
        }
        if (q.contains('cute') || q.contains('creative')) return 'cute_creative_notes';
        if (q.contains('modern minimal')) return 'modern_minimal';
        return null;
      case 'pptx':
        if (q.contains('creative') || q.contains('illustrated')) return 'creative_illustrated';
        if (q.contains('scientific') || q.contains('professional')) {
          return 'professional_scientific';
        }
        if (q.contains('minimal') || q.contains('editorial')) return 'minimal_editorial';
        if (q.contains('infographic') || q.contains('dark')) return 'infographic_presentation';
        return null;
      default:
        return null;
    }
  }

  /// Resolves a valid notebookId so Chat-generated documents are NEVER lost when notebookId is null.
  static Future<String> resolveTargetNotebookId({
    String? notebookId,
    String? subject,
  }) async {
    if (notebookId != null && notebookId.trim().isNotEmpty) {
      return notebookId.trim();
    }
    final all = OfflineCacheService.getAllCachedNotebooks();
    if (subject != null && subject.trim().isNotEmpty) {
      final lower = subject.trim().toLowerCase();
      for (final nb in all) {
        if ((nb['title'] as String? ?? '').trim().toLowerCase() == lower) {
          final id = nb['id']?.toString() ?? '';
          if (id.isNotEmpty) return id;
        }
      }
    }
    for (final nb in all) {
      if ((nb['title'] as String? ?? '').trim().toLowerCase() == 'general study') {
        final id = nb['id']?.toString() ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    final created = await OfflineCacheService.createNotebook(
      title: (subject != null && subject.trim().isNotEmpty) ? subject.trim() : 'General Study',
      icon: '📚',
      colorHex: '#4F46E5',
    );
    return created['id'].toString();
  }

  static Future<GeneratedDocumentResult> generateAndSave({
    required AiRouter aiRouter,
    required String format, // 'pdf' | 'docx' | 'pptx'
    required String styleId,
    required String subject,
    required String topic,
    String? notebookId,
    String? sourceContext,
    String? nodeId,
    String? sourceChatId,
    String purpose = 'Exam & Course Study Guide',
    String depthLevel = 'Course Level',
    String customInstructions = '',
    String? idempotencyKey,
  }) async {
    final targetNbId = await resolveTargetNotebookId(
      notebookId: notebookId,
      subject: subject,
    );

    final effectiveContext = (sourceContext != null && sourceContext.trim().isNotEmpty)
        ? sourceContext.trim()
        : OfflineCacheService.getNotebookCombinedText(targetNbId, maxChars: 120000);

    final structuredDoc = await DocumentPipelineService.generateStructuredDocument(
      aiRouter: aiRouter,
      subject: subject,
      topic: topic,
      sourceContext: effectiveContext,
      purpose: purpose,
      depthLevel: depthLevel,
      customInstructions: customInstructions,
    );

    final safeBase = subject.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final docId = idempotencyKey ?? 'doc_${format}_${DateTime.now().millisecondsSinceEpoch}';
    final dir = await getApplicationDocumentsDirectory();

    late final Uint8List bytes;
    late final String fileName;
    int? slideCount;

    if (format == 'pdf') {
      await OfflineCacheService.savePreferredPdfStyle(styleId);
      final pdfStyle = PdfExporter.fromStyleId(styleId);
      bytes = await PdfExporter.generateStudyGuidePdf(
        title: structuredDoc.title,
        subject: subject,
        content: structuredDoc.toStructuredMarkdown(),
        keyTakeaways: structuredDoc.takeaways,
        structuredDoc: structuredDoc,
        style: pdfStyle,
      );
      fileName = '${safeBase}_${styleId}_Guide.pdf';
    } else if (format == 'docx') {
      final docxStyle = DocxExporter.fromStyleId(styleId);
      bytes = DocxExporter.createDocument(
        title: structuredDoc.title,
        subject: subject,
        content: structuredDoc.toStructuredMarkdown(),
        structuredDoc: structuredDoc,
        style: docxStyle,
      );
      fileName = '${safeBase}_${styleId}_Notes.docx';
    } else {
      await OfflineCacheService.savePreferredPptxStyle(styleId);
      final pptxStyle = PptxExporter.fromStyleId(styleId);
      final slides = DocumentPipelineService.toSlideDeck(structuredDoc);
      slideCount = slides.length;
      bytes = PptxExporter.createPresentation(
        presentationTitle: structuredDoc.title,
        slides: slides,
        style: pptxStyle,
      );
      fileName = '${safeBase}_${styleId}_Slides.pptx';
    }

    // Output QA Gate: verify magic bytes & non-empty payload before saving/marking ready
    final expectedFmt = format == 'pdf'
        ? ParsedDocFormat.pdf
        : (format == 'docx' ? ParsedDocFormat.docx : ParsedDocFormat.pptx);
    final detected = DocumentParserService.detectFormat(bytes, fileName);
    if (bytes.isEmpty || detected != expectedFmt) {
      throw StateError('Generated $format failed integrity verification ($detected).');
    }

    final outFile = File('${dir.path}/$fileName');
    await outFile.writeAsBytes(bytes, flush: true);

    await SyllabusService.saveArtifact(
      documentId: docId,
      notebookId: targetNbId,
      artifactType: format,
      title: structuredDoc.title,
      nodeId: nodeId,
      topicLabel: structuredDoc.topic,
      depthLevel: depthLevel,
      styleId: styleId,
      styleVersion: styleVersion,
      filePath: outFile.path,
      fileSize: bytes.length,
      slideCount: slideCount,
      generationState: 'ready',
      sourceChatId: sourceChatId,
      sourceRefs: structuredDoc.sourceReferences,
      contentJson: structuredDoc.toMap(),
    );

    if (CloudVaultService.isAnyVaultConnected) {
      try {
        await CloudVaultService.uploadFile(
          outFile,
          customName: fileName,
          subject: subject,
          section: 'Notes',
        );
      } catch (_) {}
    }

    return GeneratedDocumentResult(
      documentId: docId,
      notebookId: targetNbId,
      format: format,
      styleId: styleId,
      title: structuredDoc.title,
      filePath: outFile.path,
      fileSize: bytes.length,
      slideCount: slideCount,
      structuredDoc: structuredDoc,
    );
  }
}
