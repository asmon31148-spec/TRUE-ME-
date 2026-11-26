import 'dart:io';
import 'dart:isolate';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
}
