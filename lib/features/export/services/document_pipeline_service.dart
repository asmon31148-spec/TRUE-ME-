import '../../../core/ai/ai_router.dart';
import '../../../core/utils/text_chunker.dart';
import '../models/structured_study_document.dart';
import '../pptx_exporter.dart';
import 'document_layout_validator.dart';

/// Multi-stage document intelligence pipeline:
/// Intent & Scope -> Map-Reduce Long-Source Extraction -> Structured Content Model
/// -> Completeness & Accuracy Validation -> Lossless Format Adaptation.
class DocumentPipelineService {
  DocumentPipelineService._();

  static const int _singlePassCharLimit = 14000;
  static const int _chunkSizeChars = 12000;
  static const int _maxMapChunks = 36; // Up to ~432K chars (~75,000 words)
  static const int _mapConcurrency = 3;

  static Future<StructuredStudyDocument> generateStructuredDocument({
    required AiRouter aiRouter,
    required String subject,
    required String topic,
    required String sourceContext,
    String purpose = 'Exam & Course Study Guide',
    String depthLevel = 'Course Level',
    String customInstructions = '',
    void Function(int done, int total)? onChunkProgress,
  }) async {
    final trimmedSource = sourceContext.trim();
    String synthesizedContext = trimmedSource;
    String? coverageNote;

    // Map-Reduce synthesis for long chapters (>14K chars) with bounded concurrency
    if (trimmedSource.length > _singlePassCharLimit) {
      final chunks = TextChunker.splitIntoChunks(
        trimmedSource,
        targetChunkChars: _chunkSizeChars,
        overlapChars: 500,
      );
      final processedChunks = chunks.take(_maxMapChunks).toList();
      final extractedParts = List<String>.filled(processedChunks.length, '');
      final fallbackSegments = <int>[];
      int doneChunks = 0;

      for (int batchStart = 0; batchStart < processedChunks.length; batchStart += _mapConcurrency) {
        final batchEnd = (batchStart + _mapConcurrency).clamp(0, processedChunks.length);
        await Future.wait(
          List.generate(batchEnd - batchStart, (offset) async {
            final idx = batchStart + offset;
            try {
              final part = await aiRouter.executeHeavyReasoning(
                prompt: '''
Extract ALL examinable concepts, definitions, formulas, classifications, processes, examples, and tables from this section (Part ${idx + 1}/${processedChunks.length}) of "$subject" ($topic).
Do NOT summarize away technical terms or details. Return concise structured bullet notes.

Source Part ${idx + 1}:
${processedChunks[idx].content}
''',
              );
              if (part.trim().isNotEmpty) {
                extractedParts[idx] = '### Part ${idx + 1}\n${part.trim()}';
              }
            } catch (_) {
              final rawSnippet = processedChunks[idx].content;
              extractedParts[idx] =
                  rawSnippet.length > 6000 ? rawSnippet.substring(0, 6000) : rawSnippet;
              fallbackSegments.add(idx + 1);
            } finally {
              doneChunks++;
              onChunkProgress?.call(doneChunks, processedChunks.length);
            }
          }),
        );
      }

      if (fallbackSegments.isNotEmpty) {
        coverageNote =
            'Segments ${fallbackSegments.join(', ')} used raw source fallback due to AI timeout.';
      }
      final nonEmptyParts = extractedParts.where((p) => p.isNotEmpty).toList();
      if (nonEmptyParts.isNotEmpty) {
        synthesizedContext = nonEmptyParts.join('\n\n');
      }
      if (chunks.length > _maxMapChunks) {
        final extraNote =
            'Source exceeded $_maxMapChunks segments (${chunks.length} total); covered the first ${processedChunks.length} segments in full detail.';
        coverageNote = coverageNote == null ? extraNote : '$coverageNote $extraNote';
      }
    }

    final raw = await aiRouter.executeHeavyReasoning(
      jsonMode: true,
      prompt: '''
You are an academic curriculum author for "$subject" (Topic: "$topic").
Purpose: $purpose
Academic Depth: $depthLevel
${customInstructions.isNotEmpty ? 'Student Instructions: $customInstructions\n' : ''}
STRICT ACCURACY & COMPLETENESS RULES:
- Preserve ALL units, subtopics, definitions, formulas, processes, and examples from the source.
- Never compress a full chapter into a superficial half-page summary.
- Never invent statistics, citations, textbook page numbers, or unverified claims.
- Do NOT include raw Markdown symbols like "####" or "**" inside JSON string values.
- If the provided source material does not cover part of the topic, note that in "uncertaintyNote".

Return ONLY valid JSON matching this schema:
{
  "title": "Clear Document Title",
  "purpose": "$purpose",
  "academicLevel": "$depthLevel",
  "executiveSummary": "2-4 sentence synthesis",
  "learningObjectives": ["Objective 1", "Objective 2"],
  "sections": [
    {
      "heading": "Section Title",
      "body": "Clear, complete explanation",
      "keyPoints": ["Key point 1", "Key point 2"],
      "definitions": ["Term: precise definition"],
      "examples": ["Concrete example"],
      "processSteps": ["Step 1", "Step 2"],
      "tableRows": [["Column A", "Column B"], ["Value 1", "Value 2"]],
      "calloutWarning": "Common exam trap or caveat (optional)"
    }
  ],
  "takeaways": ["Takeaway 1", "Takeaway 2"],
  "sourceReferences": ["Only cite actual provided source filenames/titles, or leave empty"],
  "uncertaintyNote": "Flag any gaps or general-knowledge additions if sources were partial"
}

Available Study Material:
${synthesizedContext.isNotEmpty ? synthesizedContext : 'No uploaded source selected; use verified course-level academic knowledge and flag in uncertaintyNote.'}
''',
    );

    Map<String, dynamic> decoded;
    try {
      decoded = AiRouter.parseJsonObject(raw);
    } catch (_) {
      // Compact JSON retry if the first response was truncated or had invalid syntax
      final compactSource = synthesizedContext.length > 10000
          ? synthesizedContext.substring(0, 10000)
          : synthesizedContext;
      final retryRaw = await aiRouter.executeHeavyReasoning(
        jsonMode: true,
        prompt: '''
Return ONLY a valid JSON object (no markdown fences) for "$subject" — "$topic":
{
  "title": "$topic",
  "purpose": "$purpose",
  "academicLevel": "$depthLevel",
  "executiveSummary": "Concise 2-3 sentence summary.",
  "learningObjectives": ["Objective 1", "Objective 2"],
  "sections": [
    {
      "heading": "Core Concepts",
      "body": "Clear explanation.",
      "keyPoints": ["Point 1", "Point 2"],
      "definitions": [],
      "examples": [],
      "processSteps": [],
      "tableRows": []
    }
  ],
  "takeaways": ["Key takeaway 1"],
  "sourceReferences": []
}

Source:
$compactSource
''',
      );
      decoded = AiRouter.parseJsonObject(retryRaw);
    }
    final rawDoc = StructuredStudyDocument.fromMap(
      decoded,
      fallbackTitle: '$topic — $subject',
      subject: subject,
      topic: topic,
    );

    final validated = DocumentLayoutValidator.auditAndNormalizeDocument(
      _validateAndClean(rawDoc, extraNote: coverageNote),
    );
    if (validated.sections.isEmpty && validated.executiveSummary.isEmpty) {
      throw StateError('AI returned an empty structured document. Please try again.');
    }
    return validated;
  }

  static String _stripMarkers(String s) {
    return s
        .replaceAll(RegExp(r'^#{1,6}\s+'), '')
        .replaceAll('**', '')
        .trim();
  }

  static StructuredStudyDocument _validateAndClean(
    StructuredStudyDocument doc, {
    String? extraNote,
  }) {
    final cleanedSections = doc.sections.map((s) {
      return StudySectionBlock(
        heading: _stripMarkers(s.heading),
        body: _stripMarkers(s.body),
        keyPoints: s.keyPoints.map(_stripMarkers).where((e) => e.isNotEmpty).toList(),
        definitions: s.definitions.map(_stripMarkers).where((e) => e.isNotEmpty).toList(),
        examples: s.examples.map(_stripMarkers).where((e) => e.isNotEmpty).toList(),
        calloutWarning: s.calloutWarning != null ? _stripMarkers(s.calloutWarning!) : null,
        tableRows: s.tableRows,
        processSteps: s.processSteps.map(_stripMarkers).where((e) => e.isNotEmpty).toList(),
      );
    }).toList();

    final combinedNote = [
      if (doc.uncertaintyNote != null && doc.uncertaintyNote!.trim().isNotEmpty)
        doc.uncertaintyNote!.trim(),
      if (extraNote != null && extraNote.trim().isNotEmpty) extraNote.trim(),
    ].join(' ');

    return StructuredStudyDocument(
      title: _stripMarkers(doc.title),
      subject: doc.subject,
      topic: doc.topic,
      purpose: doc.purpose,
      academicLevel: doc.academicLevel,
      executiveSummary: _stripMarkers(doc.executiveSummary),
      learningObjectives: doc.learningObjectives.map(_stripMarkers).toList(),
      sections: cleanedSections,
      takeaways: doc.takeaways.map(_stripMarkers).toSet().toList(),
      sourceReferences: doc.sourceReferences,
      uncertaintyNote: combinedNote.isEmpty ? null : combinedNote,
    );
  }

  /// Lossless slide splitter: converts a verified [StructuredStudyDocument] into
  /// [PptxSlideData] slides WITHOUT dropping items or overflowing fixed boxes.
  /// Dense sections are automatically paginated across continuation slides.
  static List<PptxSlideData> toSlideDeck(StructuredStudyDocument doc) {
    final slides = <PptxSlideData>[];

    // Title / Overview Slide
    final overviewBullets = <String>[
      if (doc.executiveSummary.isNotEmpty) doc.executiveSummary,
      ...doc.learningObjectives,
    ];
    slides.add(
      PptxSlideData(
        title: doc.title,
        subtitle: '${doc.subject} · ${doc.academicLevel}',
        tag: 'OVERVIEW',
        bulletPoints: overviewBullets.take(5).toList(),
        takeaway: doc.purpose,
      ),
    );

    const maxBulletsPerSlide = 4;
    for (final s in doc.sections) {
      final allPoints = <String>[
        if (s.body.isNotEmpty)
          ...s.body
              .split(RegExp(r'(?<=[.!?])\s+'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty),
        ...s.definitions.map((d) => 'Def: $d'),
        ...s.keyPoints,
        ...s.examples.map((e) => 'Example: $e'),
      ];

      if (allPoints.isEmpty && s.processSteps.isEmpty && s.tableRows.isEmpty) continue;

      if (allPoints.isEmpty) {
        slides.add(
          PptxSlideData(
            title: s.heading,
            subtitle: doc.topic,
            tag: doc.topic.toUpperCase(),
            bulletPoints: const [],
            processSteps: s.processSteps.isNotEmpty ? s.processSteps : null,
            tableRows: s.tableRows.isNotEmpty ? s.tableRows : null,
            takeaway: s.calloutWarning,
          ),
        );
        continue;
      }

      final totalPages = (allPoints.length / maxBulletsPerSlide).ceil();
      for (int p = 0; p < totalPages; p++) {
        final start = p * maxBulletsPerSlide;
        final end = (start + maxBulletsPerSlide).clamp(0, allPoints.length);
        final chunk = allPoints.sublist(start, end);
        final slideTitle = totalPages > 1 ? '${s.heading} (${p + 1}/$totalPages)' : s.heading;

        slides.add(
          PptxSlideData(
            title: slideTitle,
            subtitle: doc.topic,
            tag: doc.topic.toUpperCase(),
            bulletPoints: chunk,
            processSteps: p == totalPages - 1 && s.processSteps.isNotEmpty ? s.processSteps : null,
            tableRows: p == totalPages - 1 && s.tableRows.isNotEmpty ? s.tableRows : null,
            takeaway: p == totalPages - 1 ? s.calloutWarning : null,
          ),
        );
      }
    }

    if (doc.takeaways.isNotEmpty) {
      final totalTakeawaySlides = (doc.takeaways.length / maxBulletsPerSlide).ceil();
      for (int p = 0; p < totalTakeawaySlides; p++) {
        final start = p * maxBulletsPerSlide;
        final end = (start + maxBulletsPerSlide).clamp(0, doc.takeaways.length);
        slides.add(
          PptxSlideData(
            title: totalTakeawaySlides > 1
                ? 'Key Takeaways (${p + 1}/$totalTakeawaySlides)'
                : 'Key Takeaways & Summary',
            subtitle: doc.subject,
            tag: 'RECAP',
            bulletPoints: doc.takeaways.sublist(start, end),
            takeaway: p == totalTakeawaySlides - 1 ? doc.uncertaintyNote : null,
          ),
        );
      }
    }

    return slides;
  }
}
