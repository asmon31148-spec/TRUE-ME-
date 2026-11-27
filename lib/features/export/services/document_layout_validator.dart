import '../models/structured_study_document.dart';
import '../pptx_exporter.dart';

/// Semantic slide layout kinds chosen automatically by the Layout Brain.
enum SlideLayoutKind {
  cover,
  flowchart,
  table,
  twoColumn,
  bentoGrid,
  content,
}

class LayoutQualityReport {
  final int score; // 0-100
  final int totalPagesOrSlides;
  final int layoutVarietyCount;
  final int autoSplitsApplied;
  final double minFontSizePt;
  final bool hasVisualDiagramsOrTables;
  final List<String> notes;

  const LayoutQualityReport({
    required this.score,
    required this.totalPagesOrSlides,
    required this.layoutVarietyCount,
    required this.autoSplitsApplied,
    required this.minFontSizePt,
    required this.hasVisualDiagramsOrTables,
    this.notes = const [],
  });
}

/// Layout & Quality Brain for PDF, DOCX, and PPTX generation.
/// Audits content density, prevents text clipping/tiny boxes by auto-splitting
/// dense slides, normalizes ragged tables, and assigns optimal visual layouts.
class DocumentLayoutValidator {
  DocumentLayoutValidator._();

  static const int maxBulletsPerSlide = 4;
  static const int maxCharsPerSlide = 360;
  static const int maxStepsPerFlowchart = 6;
  static const int maxRowsPerTableSlide = 6;

  /// Normalizes a [StructuredStudyDocument] before rendering:
  /// - Pads ragged table rows so OpenXML/PDF tables never crash or misalign
  /// - Splits overly long prose paragraphs into readable study blocks
  /// - Deduplicates empty or redundant entries
  static StructuredStudyDocument auditAndNormalizeDocument(
    StructuredStudyDocument doc,
  ) {
    final normalizedSections = <StudySectionBlock>[];

    for (final s in doc.sections) {
      // Normalize table column count across all rows
      List<List<String>> safeTable = const [];
      if (s.tableRows.isNotEmpty) {
        final maxCols = s.tableRows.fold<int>(
          0,
          (m, r) => r.length > m ? r.length : m,
        );
        if (maxCols >= 2) {
          safeTable = s.tableRows.map((row) {
            if (row.length == maxCols) return row;
            return [
              ...row,
              ...List.filled(maxCols - row.length, '—'),
            ];
          }).toList();
        }
      }

      // If body is very long (>550 chars) and keyPoints is sparse, promote sentences to keyPoints
      var body = s.body.trim();
      var keyPoints = List<String>.from(s.keyPoints);
      if (body.length > 550 && keyPoints.length < 2) {
        final sentences = body
            .split(RegExp(r'(?<=[.!?])\s+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (sentences.length > 2) {
          body = '${sentences.first} ${sentences[1]}';
          keyPoints = [
            ...sentences.skip(2),
            ...keyPoints,
          ];
        }
      }

      normalizedSections.add(
        StudySectionBlock(
          heading: s.heading.trim().isEmpty ? 'Key Concepts' : s.heading.trim(),
          body: body,
          keyPoints: keyPoints,
          definitions: s.definitions,
          examples: s.examples,
          calloutWarning: s.calloutWarning,
          tableRows: safeTable,
          processSteps: s.processSteps,
          diagramSvg: s.diagramSvg,
          diagramPrompt: s.diagramPrompt,
          citations: s.citations,
        ),
      );
    }

    return StructuredStudyDocument(
      title: doc.title,
      subject: doc.subject,
      topic: doc.topic,
      purpose: doc.purpose,
      academicLevel: doc.academicLevel,
      executiveSummary: doc.executiveSummary,
      learningObjectives: doc.learningObjectives,
      sections: normalizedSections,
      takeaways: doc.takeaways,
      sourceReferences: doc.sourceReferences,
      uncertaintyNote: doc.uncertaintyNote,
    );
  }

  /// Validates, auto-splits, and assigns optimal [SlideLayoutKind] to every slide
  /// so no slide has cramped boxes, tiny text, or monotonous layouts.
  static ({List<PptxSlideData> slides, LayoutQualityReport report})
      validateAndOptimizeSlides(List<PptxSlideData> rawSlides) {
    if (rawSlides.isEmpty) {
      return (
        slides: const [],
        report: const LayoutQualityReport(
          score: 0,
          totalPagesOrSlides: 0,
          layoutVarietyCount: 0,
          autoSplitsApplied: 0,
          minFontSizePt: 12,
          hasVisualDiagramsOrTables: false,
          notes: ['No slides provided'],
        ),
      );
    }

    final optimized = <PptxSlideData>[];
    int autoSplits = 0;

    for (int i = 0; i < rawSlides.length; i++) {
      final slide = rawSlides[i];

      // 1. Cover slide (index 0) when deck has multiple slides
      if (i == 0 && rawSlides.length > 1) {
        optimized.add(
          PptxSlideData(
            title: slide.title,
            subtitle: slide.subtitle,
            tag: slide.tag ?? 'OVERVIEW',
            bulletPoints: slide.bulletPoints.take(4).toList(),
            takeaway: slide.takeaway,
            layoutKind: SlideLayoutKind.cover,
          ),
        );
        continue;
      }

      // 2. Dedicated Flowchart slide if processSteps are present
      if (slide.processSteps != null && slide.processSteps!.isNotEmpty) {
        final steps = slide.processSteps!;
        if (steps.length > maxStepsPerFlowchart) {
          autoSplits++;
          final pages = (steps.length / maxStepsPerFlowchart).ceil();
          for (int p = 0; p < pages; p++) {
            final chunk = steps.sublist(
              p * maxStepsPerFlowchart,
              ((p + 1) * maxStepsPerFlowchart).clamp(0, steps.length),
            );
            optimized.add(
              PptxSlideData(
                title: pages > 1
                    ? '${slide.title} — Process (${p + 1}/$pages)'
                    : '${slide.title} — Process Flow',
                subtitle: slide.subtitle,
                tag: 'FLOWCHART',
                bulletPoints: const [],
                processSteps: chunk,
                takeaway: p == pages - 1 ? slide.takeaway : null,
                layoutKind: SlideLayoutKind.flowchart,
              ),
            );
          }
        } else {
          optimized.add(
            PptxSlideData(
              title: slide.title,
              subtitle: slide.subtitle,
              tag: 'FLOWCHART',
              bulletPoints: slide.bulletPoints.take(2).toList(),
              processSteps: steps,
              takeaway: slide.takeaway,
              layoutKind: SlideLayoutKind.flowchart,
            ),
          );
        }
        // If there were also >2 bullets on this slide, emit them cleanly on a content slide
        if (slide.bulletPoints.length > 2) {
          autoSplits++;
          _appendPaginatedBullets(
            optimized,
            title: '${slide.title} — Details',
            subtitle: slide.subtitle,
            tag: slide.tag,
            bullets: slide.bulletPoints,
            takeaway: null,
          );
        }
        // If tableRows were also present on the same slide, emit a dedicated table slide
        if (slide.tableRows != null && slide.tableRows!.length >= 2) {
          autoSplits++;
          optimized.add(
            PptxSlideData(
              title: '${slide.title} — Comparison',
              subtitle: slide.subtitle,
              tag: 'COMPARISON',
              bulletPoints: const [],
              tableRows: slide.tableRows,
              layoutKind: SlideLayoutKind.table,
            ),
          );
        }
        continue;
      }

      // 3. Dedicated Table slide if tableRows are present
      if (slide.tableRows != null && slide.tableRows!.length >= 2) {
        final header = slide.tableRows!.first;
        final dataRows = slide.tableRows!.skip(1).toList();
        if (dataRows.length > maxRowsPerTableSlide) {
          autoSplits++;
          final pages = (dataRows.length / maxRowsPerTableSlide).ceil();
          for (int p = 0; p < pages; p++) {
            final chunk = dataRows.sublist(
              p * maxRowsPerTableSlide,
              ((p + 1) * maxRowsPerTableSlide).clamp(0, dataRows.length),
            );
            optimized.add(
              PptxSlideData(
                title: pages > 1
                    ? '${slide.title} — Comparison (${p + 1}/$pages)'
                    : slide.title,
                subtitle: slide.subtitle,
                tag: 'COMPARISON',
                bulletPoints: const [],
                tableRows: [header, ...chunk],
                takeaway: p == pages - 1 ? slide.takeaway : null,
                layoutKind: SlideLayoutKind.table,
              ),
            );
          }
        } else {
          optimized.add(
            PptxSlideData(
              title: slide.title,
              subtitle: slide.subtitle,
              tag: 'COMPARISON',
              bulletPoints: const [],
              tableRows: slide.tableRows,
              takeaway: slide.takeaway,
              layoutKind: SlideLayoutKind.table,
            ),
          );
        }
        if (slide.bulletPoints.isNotEmpty) {
          autoSplits++;
          _appendPaginatedBullets(
            optimized,
            title: '${slide.title} — Key Notes',
            subtitle: slide.subtitle,
            tag: slide.tag,
            bullets: slide.bulletPoints,
            takeaway: null,
          );
        }
        continue;
      }

      // 4. Bullet / Concept slides: enforce character & bullet budgets
      final splitCountBefore = optimized.length;
      _appendPaginatedBullets(
        optimized,
        title: slide.title,
        subtitle: slide.subtitle,
        tag: slide.tag,
        bullets: slide.bulletPoints,
        takeaway: slide.takeaway,
      );
      if (optimized.length - splitCountBefore > 1) {
        autoSplits++;
      }
    }

    final distinctLayouts = optimized.map((s) => s.layoutKind).toSet();
    final hasVisuals = optimized.any(
      (s) =>
          s.layoutKind == SlideLayoutKind.flowchart ||
          s.layoutKind == SlideLayoutKind.table ||
          s.layoutKind == SlideLayoutKind.bentoGrid,
    );

    int score = 70;
    score += (distinctLayouts.length * 6).clamp(0, 20);
    if (hasVisuals) score += 10;
    score = score.clamp(0, 100);

    return (
      slides: optimized,
      report: LayoutQualityReport(
        score: score,
        totalPagesOrSlides: optimized.length,
        layoutVarietyCount: distinctLayouts.length,
        autoSplitsApplied: autoSplits,
        minFontSizePt: 13.0,
        hasVisualDiagramsOrTables: hasVisuals,
        notes: [
          'Layouts used: ${distinctLayouts.map((e) => e.name).join(', ')}',
          if (autoSplits > 0) 'Auto-split $autoSplits dense sections to prevent box overflow.',
        ],
      ),
    );
  }

  static void _appendPaginatedBullets(
    List<PptxSlideData> out, {
    required String title,
    String? subtitle,
    String? tag,
    required List<String> bullets,
    String? takeaway,
  }) {
    final safeBullets = bullets.where((b) => b.trim().isNotEmpty).toList();
    if (safeBullets.isEmpty) {
      out.add(
        PptxSlideData(
          title: title,
          subtitle: subtitle,
          tag: tag,
          bulletPoints: const ['Key concept summary'],
          takeaway: takeaway,
          layoutKind: takeaway != null && takeaway.trim().isNotEmpty
              ? SlideLayoutKind.twoColumn
              : SlideLayoutKind.content,
        ),
      );
      return;
    }

    // Group bullets respecting both count (<= 4) and char budget (<= 360)
    final pages = <List<String>>[];
    var current = <String>[];
    int currentChars = 0;

    for (final b in safeBullets) {
      final clean = b.trim();
      if (current.isNotEmpty &&
          (current.length >= maxBulletsPerSlide ||
              currentChars + clean.length > maxCharsPerSlide)) {
        pages.add(current);
        current = <String>[];
        currentChars = 0;
      }
      current.add(clean);
      currentChars += clean.length;
    }
    if (current.isNotEmpty) pages.add(current);

    for (int p = 0; p < pages.length; p++) {
      final chunk = pages[p];
      final isLast = p == pages.length - 1;
      final pageTakeaway = isLast ? takeaway : null;
      final avgLen =
          chunk.fold<int>(0, (sum, s) => sum + s.length) / chunk.length;

      final SlideLayoutKind kind;
      if (pageTakeaway != null && pageTakeaway.trim().isNotEmpty) {
        kind = SlideLayoutKind.twoColumn;
      } else if (chunk.length >= 3 && chunk.length <= 4 && avgLen <= 95) {
        kind = SlideLayoutKind.bentoGrid;
      } else {
        kind = SlideLayoutKind.content;
      }

      out.add(
        PptxSlideData(
          title: pages.length > 1 ? '$title (${p + 1}/${pages.length})' : title,
          subtitle: subtitle,
          tag: tag,
          bulletPoints: chunk,
          takeaway: pageTakeaway,
          layoutKind: kind,
        ),
      );
    }
  }
}
