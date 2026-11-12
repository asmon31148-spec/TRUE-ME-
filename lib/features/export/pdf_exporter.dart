import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/flashcard_model.dart';

class PdfExporter {
  PdfExporter._();

  static String _sanitize(String text) {
    return text
        .replaceAll('•', '-')
        .replaceAll('→', '->')
        .replaceAll('←', '<-')
        .replaceAll('—', '--')
        .replaceAll('–', '-')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('≤', '<=')
        .replaceAll('≥', '>=')
        .replaceAll('≠', '!=')
        .replaceAll('×', 'x')
        .replaceAll('÷', '/')
        .replaceAll('…', '...')
        .replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]'), '');
  }

  static List<pw.Widget> _buildFormattedContent(String rawContent) {
    final lines = _sanitize(rawContent).split('\n');
    final widgets = <pw.Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      final cleanText = line.replaceAll('**', '');
      if (cleanText.startsWith('### ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
            child: pw.Text(
              cleanText.substring(4).trim(),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo700,
              ),
            ),
          ),
        );
      } else if (cleanText.startsWith('## ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
            child: pw.Text(
              cleanText.substring(3).trim(),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
          ),
        );
      } else if (cleanText.startsWith('# ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
            child: pw.Text(
              cleanText.substring(2).trim(),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo800,
              ),
            ),
          ),
        );
      } else if (cleanText.startsWith('- ') || cleanText.startsWith('* ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('- ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo600)),
                pw.Expanded(
                  child: pw.Text(
                    cleanText.substring(2).trim(),
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.8, color: PdfColors.grey800),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              cleanText,
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.8, color: PdfColors.grey800),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  /// Generates and previews a study guide PDF.
  static Future<Uint8List> generateStudyGuidePdf({
    required String title,
    required String subject,
    required String content,
    List<String> keyTakeaways = const [],
  }) async {
    final pdf = pw.Document();
    final safeTitle = _sanitize(title);
    final safeSubject = _sanitize(subject);
    final contentWidgets = _buildFormattedContent(content);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.indigo600, width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TRUE ME STUDY GUIDE',
                          style: pw.TextStyle(
                            color: PdfColors.indigo600,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          safeTitle,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.indigo50,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      safeSubject.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Key Takeaways if available
            if (keyTakeaways.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'KEY TAKEAWAYS FOR EXAMS',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    ...keyTakeaways.map(
                      (t) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('- ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Expanded(
                              child: pw.Text(
                                _sanitize(t),
                                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Content body (paginated paragraph by paragraph)
            ...contentWidgets,
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Exports flashcard decks to a printable 2-column study sheet.
  static Future<Uint8List> generateFlashcardSheetPdf({
    required String deckTitle,
    required List<FlashcardModel> cards,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Text(
              'Flashcard Review Sheet: $deckTitle',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            ...cards.map((card) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'QUESTION',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.indigo600,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(card.front, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 1,
                      height: 40,
                      color: PdfColors.grey200,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 12),
                    ),
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ANSWER',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(card.back, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Directly invokes print / share sheet on device.
  static Future<void> printPdf(Uint8List bytes, {String name = 'Study_Guide'}) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: name,
    );
  }
}
