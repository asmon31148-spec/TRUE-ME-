import 'dart:io';
import 'dart:isolate';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/models/ingestion_models.dart';

class PdfExtractionBundle {
  final List<ExtractedPage> pages;
  final ExtractionQualityReport report;
  final String combinedText;

  const PdfExtractionBundle({
    required this.pages,
    required this.report,
    required this.combinedText,
  });
}

class PdfProcessor {
  PdfProcessor._();

  static const int maxExtractedChars = 350000;

  /// Extracts text from a local PDF file asynchronously in a background isolate.
  /// Handles very large (100+ MB) and partially malformed PDFs gracefully without
  /// crashing the upload flow.
  static Future<String> extractText(File pdfFile) async {
    final path = pdfFile.path;
    return await Isolate.run(() async {
      final file = File(path);
      final bytes = await file.readAsBytes();

      try {
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        try {
          final PdfTextExtractor extractor = PdfTextExtractor(document);
          final int pageCount = document.pages.count;
          final buffer = StringBuffer();

          for (int i = 0; i < pageCount; i++) {
            try {
              final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
              if (pageText.isNotEmpty) {
                if (buffer.isNotEmpty) buffer.write('\n\n');
                buffer.write(pageText);
              }
            } catch (_) {
              // Skip individual corrupted/unsupported pages rather than failing the whole book.
            }
            if (buffer.length >= maxExtractedChars) break;
          }

          final result = buffer.toString().trim();
          if (result.isNotEmpty) return result;
        } finally {
          document.dispose();
        }
      } catch (_) {
        // Syncfusion can throw Fatal Error / _Error on huge or non-standard PDFs.
        // Fall through to lightweight stream text scan.
      }

      return _fallbackExtractPdfStrings(bytes);
    });
  }

  /// Lightweight fallback scanner for PDFs where Syncfusion's object/xref parser fails.
  /// Scans uncompressed PDF literal text operators `(text) Tj` safely in bounded memory.
  static String _fallbackExtractPdfStrings(List<int> bytes) {
    final buffer = StringBuffer();
    final current = StringBuffer();
    bool inParen = false;
    bool escaped = false;
    final limit = bytes.length > 40 * 1024 * 1024 ? 40 * 1024 * 1024 : bytes.length;

    for (int i = 0; i < limit; i++) {
      final b = bytes[i];
      if (!inParen) {
        if (b == 0x28) {
          // '('
          inParen = true;
          current.clear();
        }
        continue;
      }

      if (escaped) {
        escaped = false;
        if (b >= 0x20 && b <= 0x7E) current.writeCharCode(b);
        continue;
      }

      if (b == 0x5C) {
        // '\'
        escaped = true;
        continue;
      }

      if (b == 0x29) {
        // ')'
        inParen = false;
        final candidate = current.toString().trim();
        if (candidate.length >= 4 && RegExp(r'[A-Za-z]{3,}').hasMatch(candidate)) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(candidate);
          if (buffer.length >= 120000) break;
        }
        continue;
      }

      if (b >= 0x20 && b <= 0x7E) {
        if (current.length < 512) current.writeCharCode(b);
      } else if (b == 0x0A || b == 0x0D || b == 0x09) {
        if (current.length < 512) current.write(' ');
      } else {
        // Non-printable binary inside parens -> not plain text
        inParen = false;
        current.clear();
      }
    }

    return buffer.toString().trim();
  }

  /// Extracts text page by page with page numbering for citations in a background isolate.
  static Future<List<Map<String, dynamic>>> extractPages(File pdfFile) async {
    final path = pdfFile.path;
    return await Isolate.run(() async {
      final bytes = await File(path).readAsBytes();
      final List<Map<String, dynamic>> pages = [];
      try {
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        try {
          final PdfTextExtractor extractor = PdfTextExtractor(document);
          final int pageCount = document.pages.count;

          for (int i = 0; i < pageCount; i++) {
            try {
              final text = extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
              if (text.isNotEmpty) {
                pages.add({
                  'pageNumber': i + 1,
                  'text': text,
                });
              }
            } catch (_) {}
          }
        } finally {
          document.dispose();
        }
      } catch (_) {}
      return pages;
    });
  }

  /// Evaluates extraction quality across a list of pages (SAGE-001 quality gate).
  static PdfExtractionBundle buildQualityBundle(List<ExtractedPage> pages) {
    final totalPages = pages.length;
    final readablePagesList = pages.where((p) => p.isReadable).toList();
    final unreadableNumbers =
        pages.where((p) => !p.isReadable).map((p) => p.pageNumber).toList();

    final buf = StringBuffer();
    for (final p in readablePagesList) {
      if (buf.isNotEmpty) buf.write('\n\n');
      buf.write(p.text.trim());
    }
    final combinedText = buf.toString().trim();
    final charCount = combinedText.length;
    final readableCount = readablePagesList.length;
    final needsOcr = totalPages > 0 && readableCount == 0;
    final isUsable = readableCount > 0 && charCount >= 20;

    final String summary;
    if (totalPages == 0) {
      summary = 'No readable pages detected.';
    } else if (readableCount == 0) {
      summary = '0/$totalPages pages readable — scanned/image PDF requires OCR.';
    } else if (unreadableNumbers.isEmpty) {
      summary = '$readableCount/$totalPages pages readable.';
    } else {
      final preview = unreadableNumbers.take(6).join(', ');
      final suffix = unreadableNumbers.length > 6 ? ', ...' : '';
      summary =
          '$readableCount/$totalPages pages readable; unreadable pages: $preview$suffix.';
    }

    return PdfExtractionBundle(
      pages: pages,
      combinedText: combinedText,
      report: ExtractionQualityReport(
        totalPages: totalPages,
        readablePages: readableCount,
        unreadablePageNumbers: unreadableNumbers,
        charCount: charCount,
        needsOcr: needsOcr,
        isUsable: isUsable,
        summaryMessage: summary,
      ),
    );
  }

  /// Extracts every page with 1-based page provenance and a SAGE-001 quality report.
  static Future<PdfExtractionBundle> extractWithQualityReport(File pdfFile) async {
    final path = pdfFile.path;
    final pages = await Isolate.run(() async {
      final bytes = await File(path).readAsBytes();
      final List<ExtractedPage> extracted = [];
      try {
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        try {
          final PdfTextExtractor extractor = PdfTextExtractor(document);
          final int pageCount = document.pages.count;
          int totalChars = 0;

          for (int i = 0; i < pageCount; i++) {
            String text = '';
            try {
              text = extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
            } catch (_) {
              text = '';
            }
            final readable = ExtractedPage.assessReadability(text);
            if (readable && totalChars < maxExtractedChars) {
              totalChars += text.length;
            }
            extracted.add(
              ExtractedPage(
                pageNumber: i + 1,
                text: readable && totalChars <= maxExtractedChars ? text : '',
                isReadable: readable,
              ),
            );
          }
          if (extracted.isNotEmpty) return extracted;
        } finally {
          document.dispose();
        }
      } catch (_) {}

      final fallback = _fallbackExtractPdfStrings(bytes);
      final readable = ExtractedPage.assessReadability(fallback);
      return [
        ExtractedPage(
          pageNumber: 1,
          text: readable ? fallback : '',
          isReadable: readable,
        ),
      ];
    });

    return buildQualityBundle(pages);
  }
}
