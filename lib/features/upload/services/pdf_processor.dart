import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfProcessor {
  PdfProcessor._();

  /// Extracts text from a local PDF file.
  static Future<String> extractText(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    try {
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String extractedText = extractor.extractText();
      return extractedText.trim();
    } finally {
      document.dispose();
    }
  }

  /// Extracts text page by page with page numbering for citations.
  static Future<List<Map<String, dynamic>>> extractPages(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final List<Map<String, dynamic>> pages = [];

    try {
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final int pageCount = document.pages.count;

      for (int i = 0; i < pageCount; i++) {
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (text.trim().isNotEmpty) {
          pages.add({
            'pageNumber': i + 1,
            'text': text.trim(),
          });
        }
      }
      return pages;
    } finally {
      document.dispose();
    }
  }
}
