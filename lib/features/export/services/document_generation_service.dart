import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/ai/pollinations_service.dart';
import '../../../core/ai/smai/memory_event_service.dart';
import '../../../core/ai/smai/smai_models.dart';
import '../../../core/ai/syllabus_service.dart';
import '../../../core/models/flashcard_model.dart';
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
        if (q.contains('elegant') || q.contains('classic')) return 'elegant_academic_notes';
        if (q.contains('corporate') || q.contains('research report') || q.contains('professional')) {
          return 'corporate_professional';
        }
        if (q.contains('creative') || q.contains('cute')) return 'creative_academic';
        if (q.contains('modern minimal')) return 'modern_minimal';
        return null;
      case 'pptx':
        if (q.contains('pastel') || q.contains('floral') || q.contains('creative illustrated')) {
          return 'pastel_floral';
        }
        if (q.contains('infographic presentation')) {
          return 'infographic_presentation';
        }
        if (q.contains('neon') || q.contains('dark')) {
          return 'dark_neon';
        }
        if (q.contains('business') || q.contains('scientific') || q.contains('professional')) {
          return 'modern_business';
        }
        if (q.contains('infographic') || q.contains('minimal') || q.contains('editorial')) {
          return 'creative_infographic';
        }
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
    final resolvedTitle = (subject != null && subject.trim().isNotEmpty)
        ? subject.trim()
        : 'General Study';
    final created = await OfflineCacheService.createNotebook(
      title: resolvedTitle,
      subject: resolvedTitle,
      colorValue: 0xFF4F46E5,
    );
    return created['id'].toString();
  }

  static bool isUnreadableSourcePlaceholder(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    return t.contains('No selectable text could be extracted automatically') ||
        t.contains('No selectable text found; consider using Photo OCR');
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
    bool requireSourceGrounding = false,
    void Function(int stageIndex, String stageLabel)? onStageChanged,
    void Function(double progress, String stageLabel)? onProgressChanged,
  }) async {
    onStageChanged?.call(0, 'Understanding request & selected scope...');
    onProgressChanged?.call(0.08, 'Understanding request & selected scope...');
    final targetNbId = await resolveTargetNotebookId(
      notebookId: notebookId,
      subject: subject,
    );

    onStageChanged?.call(1, 'Loading selected syllabus & source material...');
    onProgressChanged?.call(0.18, 'Loading selected syllabus & source material...');
    final effectiveContext = (sourceContext != null && sourceContext.trim().isNotEmpty)
        ? sourceContext.trim()
        : OfflineCacheService.getNotebookCombinedText(targetNbId, maxChars: 120000);

    if (requireSourceGrounding && isUnreadableSourcePlaceholder(effectiveContext)) {
      throw StateError(
        'Selected source has no readable text (likely a scanned PDF). '
        'Use Photo OCR or add readable notes before generating a source-grounded document.',
      );
    }

    onStageChanged?.call(2, 'Extracting, chunking & analyzing source content...');
    onProgressChanged?.call(0.28, 'Extracting, chunking & analyzing source content...');

    final syllabusUnits = SyllabusService.getSyllabusNodes(targetNbId)
        .where((n) => n['nodeType'] == 'unit')
        .map((n) => n['title']?.toString() ?? '')
        .where((t) => t.trim().isNotEmpty)
        .toList();
    final lowerTopic = topic.toLowerCase();
    final isBroadSemesterScope = syllabusUnits.length >= 2 &&
        (lowerTopic == subject.toLowerCase() ||
            lowerTopic.contains('semester') ||
            lowerTopic.contains('syllabus') ||
            lowerTopic.contains('all unit') ||
            lowerTopic.contains('full ') ||
            lowerTopic.contains('complete '));

    final structuredDoc = isBroadSemesterScope
        ? await DocumentPipelineService.generateMultiUnitDocument(
            aiRouter: aiRouter,
            subject: subject,
            topic: topic,
            unitTitles: syllabusUnits,
            sourceContext: effectiveContext,
            purpose: purpose,
            depthLevel: depthLevel,
            customInstructions: customInstructions,
            onUnitProgress: (done, total, unitName) {
              final pct = 0.28 + (0.30 * (done / total));
              onProgressChanged?.call(pct, 'Synthesizing Unit $done/$total: $unitName...');
            },
          )
        : await DocumentPipelineService.generateStructuredDocument(
            aiRouter: aiRouter,
            subject: subject,
            topic: topic,
            sourceContext: effectiveContext,
            purpose: purpose,
            depthLevel: depthLevel,
            customInstructions: customInstructions,
            onChunkProgress: (done, total) {
              final pct = 0.28 + (0.28 * (done / total));
              onProgressChanged?.call(pct, 'Analyzing segment $done/$total...');
            },
          );

    onStageChanged?.call(3, 'Building & validating learning content...');
    onProgressChanged?.call(0.62, 'Building & validating learning content...');
    final safeBase = subject.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final rawTopicSlug = topic
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final safeTopic = rawTopicSlug.isEmpty
        ? 'Topic'
        : (rawTopicSlug.length > 28 ? rawTopicSlug.substring(0, 28) : rawTopicSlug);
    final docId = idempotencyKey ?? 'doc_${format}_${DateTime.now().millisecondsSinceEpoch}';
    final uniqueSuffix = docId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final dir = await getApplicationDocumentsDirectory();

    late final Uint8List bytes;
    late final String fileName;
    int? slideCount;

    onStageChanged?.call(4, 'Applying selected document design ($styleId)...');
    onProgressChanged?.call(0.75, 'Applying selected document design ($styleId)...');
    if (format == 'pdf') {
      await OfflineCacheService.savePreferredPdfStyle(styleId);
      final pdfStyle = PdfExporter.fromStyleId(styleId);
      final diagramImages = await _fetchSectionDiagrams(structuredDoc, pdfStyle);
      bytes = await PdfExporter.generateStudyGuidePdf(
        title: structuredDoc.title,
        subject: subject,
        content: structuredDoc.toStructuredMarkdown(),
        keyTakeaways: structuredDoc.takeaways,
        structuredDoc: structuredDoc,
        style: pdfStyle,
        sectionDiagramImages: diagramImages,
      );
      fileName = '${safeBase}_${safeTopic}_${styleId}_${uniqueSuffix}_Guide.pdf';
    } else if (format == 'docx') {
      final docxStyle = DocxExporter.fromStyleId(styleId);
      final diagramImages = await _fetchSectionDiagrams(
        structuredDoc,
        PdfStudyStyle.modernClean,
        allowEvenWithSvg: true,
      );
      bytes = DocxExporter.createDocument(
        title: structuredDoc.title,
        subject: subject,
        content: structuredDoc.toStructuredMarkdown(),
        structuredDoc: structuredDoc,
        style: docxStyle,
        sectionDiagramImages: diagramImages,
      );
      fileName = '${safeBase}_${safeTopic}_${styleId}_${uniqueSuffix}_Notes.docx';
    } else {
      await OfflineCacheService.savePreferredPptxStyle(styleId);
      final pptxStyle = PptxExporter.fromStyleId(styleId);
      final slides = DocumentPipelineService.toSlideDeck(structuredDoc);
      slideCount = slides.length;
      final bgBytes = await _loadPptxBackgroundAsset(pptxStyle);
      final sectionDiagrams = await _fetchSectionDiagrams(
        structuredDoc,
        PdfStudyStyle.modernClean,
        allowEvenWithSvg: true,
      );
      final slideDiagrams = _mapSectionDiagramsToSlides(structuredDoc, slides, sectionDiagrams);
      bytes = PptxExporter.createPresentation(
        presentationTitle: structuredDoc.title,
        slides: slides,
        style: pptxStyle,
        backgroundImageBytes: bgBytes,
        slideDiagramImages: slideDiagrams,
      );
      fileName = '${safeBase}_${safeTopic}_${styleId}_${uniqueSuffix}_Slides.pptx';
    }

    onStageChanged?.call(5, 'Rendering & checking final file...');
    onProgressChanged?.call(0.88, 'Rendering & checking final file...');
    // Output QA Gate: verify magic bytes, non-empty payload, and structural parseability
    final expectedFmt = format == 'pdf'
        ? ParsedDocFormat.pdf
        : (format == 'docx' ? ParsedDocFormat.docx : ParsedDocFormat.pptx);
    final detected = DocumentParserService.detectFormat(bytes, fileName);
    if (bytes.isEmpty || detected != expectedFmt) {
      throw StateError('Generated $format failed integrity verification ($detected).');
    }
    if (expectedFmt == ParsedDocFormat.docx && DocumentParserService.parseDocx(bytes).isEmpty) {
      throw StateError('Generated DOCX failed structural content verification.');
    }
    if (expectedFmt == ParsedDocFormat.pptx && DocumentParserService.parsePptx(bytes).isEmpty) {
      throw StateError('Generated PPTX failed structural slide verification.');
    }

    onStageChanged?.call(6, 'Saving artifact to Study Library...');
    onProgressChanged?.call(0.95, 'Saving artifact to Study Library...');
    final outFile = File('${dir.path}/$fileName');
    await outFile.writeAsBytes(bytes, flush: true);

    String? uploadedVaultId;
    if (CloudVaultService.isAnyVaultConnected) {
      try {
        final cloudRes = await CloudVaultService.uploadFile(
          outFile,
          customName: fileName,
          subject: subject,
          section: 'Notes',
        );
        uploadedVaultId = cloudRes?.fileId;
      } catch (_) {}
    }

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
      vaultId: uploadedVaultId,
      sourceChatId: sourceChatId,
      sourceRefs: structuredDoc.sourceReferences,
      contentJson: structuredDoc.toMap(),
    );

    unawaited(
      MemoryEventService.capture(
        eventType: SmaiEventType.studyArtifactCreated,
        idempotencyKey: 'art_$docId',
        subjectId: targetNbId,
        nodeId: nodeId,
        provenanceRefs: structuredDoc.sourceReferences,
        payload: {
          'documentId': docId,
          'format': format,
          'styleId': styleId,
          'title': structuredDoc.title,
          'topic': structuredDoc.topic,
          if (sourceChatId != null) 'sourceChatId': sourceChatId,
          if (uploadedVaultId != null) 'vaultId': uploadedVaultId,
        },
        searchText: '$subject ${structuredDoc.topic} ${structuredDoc.title} $format',
      ).catchError((_) => LearningEvent(
            id: '',
            userId: '',
            eventType: SmaiEventType.studyArtifactCreated,
            idempotencyKey: 'err',
            occurredAt: DateTime.now(),
          )),
    );

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

  static Future<Uint8List?> _loadPptxBackgroundAsset(PptxStudyStyle style) async {
    final assetPath = switch (style) {
      PptxStudyStyle.minimalCute => 'assets/styles/pptx_pastel_floral.png',
      PptxStudyStyle.modernHighYield => 'assets/styles/pptx_dark_neon.png',
      PptxStudyStyle.zenPaperInk => 'assets/styles/pptx_modern_business.png',
      PptxStudyStyle.handwrittenNotebook => 'assets/styles/pptx_creative_infographic.png',
    };
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<int, Uint8List>> _fetchSectionDiagrams(
    StructuredStudyDocument doc,
    PdfStudyStyle style, {
    bool allowEvenWithSvg = false,
  }) async {
    final result = <int, Uint8List>{};
    final styleCue = switch (style) {
      PdfStudyStyle.handwritten => 'hand-drawn ink pen sketch on cream notebook paper',
      PdfStudyStyle.minimalCute => 'cute pastel illustrated study diagram on white background',
      PdfStudyStyle.zenPaperInk => 'vintage archival scientific ink illustration on parchment',
      PdfStudyStyle.modernClean => 'clean modern academic textbook vector diagram on white',
    };

    int fetched = 0;
    for (int i = 0; i < doc.sections.length && fetched < 2; i++) {
      final s = doc.sections[i];
      if (!allowEvenWithSvg && s.diagramSvg != null && s.diagramSvg!.contains('<svg')) continue;
      final prompt = s.diagramPrompt?.trim() ?? '';
      if (prompt.isEmpty) continue;

      try {
        final url = PollinationsService.getImageUrl(
          prompt: '$prompt, $styleCue',
          width: 768,
          height: 512,
        );
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200 && resp.bodyBytes.length > 1000) {
          result[i] = resp.bodyBytes;
          fetched++;
        }
      } catch (_) {
        // Non-blocking fallback
      }
    }
    return result;
  }

  static Map<int, Uint8List> _mapSectionDiagramsToSlides(
    StructuredStudyDocument doc,
    List<PptxSlideData> slides,
    Map<int, Uint8List> sectionDiagrams,
  ) {
    final mapped = <int, Uint8List>{};
    if (sectionDiagrams.isEmpty) return mapped;
    for (final entry in sectionDiagrams.entries) {
      if (entry.key >= doc.sections.length) continue;
      final heading = doc.sections[entry.key].heading.toLowerCase();
      for (int sIdx = 1; sIdx < slides.length; sIdx++) {
        if (slides[sIdx].title.toLowerCase().contains(heading)) {
          mapped[sIdx] = entry.value;
          break;
        }
      }
    }
    return mapped;
  }

  /// Compound Multi-Feature Generator: composes Mind Map or Quiz generation
  /// directly into a verified PDF/DOCX/PPTX artifact saved in Study Library.
  static Future<GeneratedDocumentResult> generateCompoundArtifact({
    required AiRouter aiRouter,
    required String primaryTool, // 'mindmap' | 'quiz'
    required String outputFormat, // 'pdf' | 'docx' | 'pptx'
    required String styleId,
    required String subject,
    required String topic,
    String? notebookId,
    String? sourceChatId,
  }) async {
    final targetNbId = await resolveTargetNotebookId(
      notebookId: notebookId,
      subject: subject,
    );
    final sourceText = OfflineCacheService.getNotebookCombinedText(
      targetNbId,
      maxChars: 14000,
    );

    if (primaryTool == 'mindmap') {
      final rawJson = await aiRouter.generateMindmap(
        topic: '$subject: $topic',
        content: sourceText,
      );
      final data = AiRouter.parseJsonObject(rawJson);
      final rootTitle = (data['root'] as String? ?? '$topic Mind Map').trim();
      final branches = (data['branches'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (outputFormat == 'pdf') {
        final pdfStyle = PdfExporter.fromStyleId(styleId);
        final bytes = await PdfExporter.generateMindmapPdf(
          title: rootTitle,
          subject: subject,
          mindmapData: data,
          style: pdfStyle,
        );
        final dir = await getApplicationDocumentsDirectory();
        final docId = 'doc_mindmap_pdf_${DateTime.now().millisecondsSinceEpoch}';
        final safeSub = subject.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
        final fileName = '${safeSub}_MindMap_$docId.pdf';
        final outFile = File('${dir.path}/$fileName');
        await outFile.writeAsBytes(bytes, flush: true);

        String? uploadedVaultId;
        if (CloudVaultService.isAnyVaultConnected) {
          try {
            final res = await CloudVaultService.uploadFile(
              outFile,
              customName: fileName,
              subject: subject,
              section: 'Notes',
            );
            uploadedVaultId = res?.fileId;
          } catch (_) {}
        }

        final structuredDoc = StructuredStudyDocument(
          title: '$rootTitle — Mind Map',
          subject: subject,
          topic: topic,
          purpose: 'Visual Mind Map PDF',
          academicLevel: 'Course Level',
          executiveSummary: 'Visual concept map covering ${branches.length} branches of $rootTitle.',
          sections: branches
              .map((b) => StudySectionBlock(
                    heading: (b['title'] as String? ?? 'Branch').trim(),
                    body: (b['summary'] as String? ?? '').trim(),
                    keyPoints: (b['children'] as List? ?? [])
                        .whereType<Map>()
                        .map((c) => '${c['title']}: ${c['summary'] ?? ''}')
                        .toList(),
                  ))
              .toList(),
        );

        await SyllabusService.saveArtifact(
          documentId: docId,
          notebookId: targetNbId,
          artifactType: 'pdf',
          title: structuredDoc.title,
          topicLabel: topic,
          styleId: styleId,
          styleVersion: styleVersion,
          filePath: outFile.path,
          fileSize: bytes.length,
          generationState: 'ready',
          vaultId: uploadedVaultId,
          sourceChatId: sourceChatId,
          contentJson: data,
        );

        unawaited(
          MemoryEventService.capture(
            eventType: SmaiEventType.studyArtifactCreated,
            idempotencyKey: 'art_$docId',
            subjectId: targetNbId,
            payload: {
              'documentId': docId,
              'format': 'pdf',
              'primaryTool': 'mindmap',
              'title': structuredDoc.title,
              'topic': topic,
              if (sourceChatId != null) 'sourceChatId': sourceChatId,
            },
            searchText: '$subject $topic mind map pdf',
          ).catchError((_) => LearningEvent(
                id: '',
                userId: '',
                eventType: SmaiEventType.studyArtifactCreated,
                idempotencyKey: 'err',
                occurredAt: DateTime.now(),
              )),
        );

        return GeneratedDocumentResult(
          documentId: docId,
          notebookId: targetNbId,
          format: 'pdf',
          styleId: styleId,
          title: structuredDoc.title,
          filePath: outFile.path,
          fileSize: bytes.length,
          structuredDoc: structuredDoc,
        );
      }

      // DOCX or PPTX export of Mind Map
      final markdownBuf = StringBuffer('# $rootTitle — Mind Map\n\n');
      for (final b in branches) {
        markdownBuf.writeln('## ${b['title']}');
        if ((b['summary'] as String? ?? '').isNotEmpty) {
          markdownBuf.writeln(b['summary']);
        }
        for (final c in (b['children'] as List? ?? []).whereType<Map>()) {
          markdownBuf.writeln('- **${c['title']}**: ${c['summary'] ?? ''}');
        }
        markdownBuf.writeln();
      }
      return generateAndSave(
        aiRouter: aiRouter,
        format: outputFormat,
        styleId: styleId,
        subject: subject,
        topic: '$topic Mind Map',
        notebookId: targetNbId,
        sourceContext: markdownBuf.toString(),
        sourceChatId: sourceChatId,
      );
    }

    if (primaryTool == 'flashcards') {
      final rawFc = await aiRouter.generateFlashcards(
        content: sourceText.isNotEmpty
            ? 'Topic: $subject ($topic)\n\n$sourceText'
            : 'Core exam concepts for $subject ($topic).',
        count: 14,
      );
      final fcData = AiRouter.parseJsonObject(rawFc);
      final rawCards = (fcData['cards'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final cards = List.generate(rawCards.length, (i) {
        final c = rawCards[i];
        return FlashcardModel(
          id: 'fc_$i',
          front: c['front']?.toString() ?? 'Question ${i + 1}',
          back: c['back']?.toString() ?? '',
          nextReviewDate: DateTime.now(),
        );
      });

      if (outputFormat == 'pdf') {
        final bytes = await PdfExporter.generateFlashcardSheetPdf(
          deckTitle: '$subject — $topic',
          cards: cards,
        );
        final dir = await getApplicationDocumentsDirectory();
        final docId = 'doc_fc_pdf_${DateTime.now().millisecondsSinceEpoch}';
        final safeSub = subject.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
        final fileName = '${safeSub}_Flashcards_$docId.pdf';
        final outFile = File('${dir.path}/$fileName');
        await outFile.writeAsBytes(bytes, flush: true);

        String? uploadedVaultId;
        if (CloudVaultService.isAnyVaultConnected) {
          try {
            final res = await CloudVaultService.uploadFile(
              outFile,
              customName: fileName,
              subject: subject,
              section: 'Notes',
            );
            uploadedVaultId = res?.fileId;
          } catch (_) {}
        }

        final structuredDoc = StructuredStudyDocument(
          title: '$topic — Flashcard Sheet',
          subject: subject,
          topic: topic,
          purpose: 'Active Recall Flashcards PDF',
          academicLevel: 'Course Level',
          executiveSummary: '${cards.length} active-recall flashcards for $subject ($topic).',
          sections: [
            StudySectionBlock(
              heading: 'Flashcard Q&A Pairs',
              body: 'Review each prompt and recall the answer before checking.',
              keyPoints: cards.map((c) => '${c.front} -> ${c.back}').toList(),
            ),
          ],
        );

        await SyllabusService.saveArtifact(
          documentId: docId,
          notebookId: targetNbId,
          artifactType: 'pdf',
          title: structuredDoc.title,
          topicLabel: topic,
          styleId: styleId,
          styleVersion: styleVersion,
          filePath: outFile.path,
          fileSize: bytes.length,
          generationState: 'ready',
          vaultId: uploadedVaultId,
          sourceChatId: sourceChatId,
          contentJson: fcData,
        );

        return GeneratedDocumentResult(
          documentId: docId,
          notebookId: targetNbId,
          format: 'pdf',
          styleId: styleId,
          title: structuredDoc.title,
          filePath: outFile.path,
          fileSize: bytes.length,
          structuredDoc: structuredDoc,
        );
      }

      final fcBuf = StringBuffer('# $topic — Active Recall Flashcards\n\n');
      for (int i = 0; i < cards.length; i++) {
        fcBuf.writeln('## Card ${i + 1}');
        fcBuf.writeln('**Q:** ${cards[i].front}');
        fcBuf.writeln('**A:** ${cards[i].back}\n');
      }
      return generateAndSave(
        aiRouter: aiRouter,
        format: outputFormat,
        styleId: styleId,
        subject: subject,
        topic: '$topic Flashcards',
        notebookId: targetNbId,
        sourceContext: fcBuf.toString(),
        sourceChatId: sourceChatId,
      );
    }

    // Quiz -> PDF/DOCX/PPTX
    final rawQuiz = await aiRouter.generateQuiz(
      content: sourceText.isNotEmpty
          ? 'Topic: $subject ($topic)\n\n$sourceText'
          : 'Core exam concepts for $subject ($topic).',
      count: 8,
    );
    final quizData = AiRouter.parseJsonObject(rawQuiz);
    final questions = (quizData['questions'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final quizBuf = StringBuffer('# $topic — Practice Quiz & Answer Key\n\n');
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      quizBuf.writeln('## Question ${i + 1}');
      quizBuf.writeln(q['question']?.toString() ?? '');
      final opts = (q['options'] as List? ?? []).map((o) => o.toString()).toList();
      for (int j = 0; j < opts.length; j++) {
        quizBuf.writeln('- ${String.fromCharCode(65 + j)}) ${opts[j]}');
      }
      final ansIdx = (q['correctOptionIndex'] as num?)?.toInt() ?? 0;
      final ansLetter = String.fromCharCode(65 + ansIdx.clamp(0, 3));
      quizBuf.writeln('Answer: $ansLetter — ${q['explanation'] ?? ''}\n');
    }

    return generateAndSave(
      aiRouter: aiRouter,
      format: outputFormat,
      styleId: styleId,
      subject: subject,
      topic: '$topic Quiz',
      notebookId: targetNbId,
      sourceContext: quizBuf.toString(),
      sourceChatId: sourceChatId,
    );
  }
}
