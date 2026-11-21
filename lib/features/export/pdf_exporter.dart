import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/flashcard_model.dart';

enum PdfStudyStyle {
  handwritten, // Handwritten Cornell notebook with ruled margins, pastel highlighters, sticky notes
  minimalCute, // Study-friendly minimal cute with pastel sakura/matcha cards & pill badges
  zenPaperInk, // Zen Washi parchment, Sumi calligraphy ink & Vermilion Hanko seal
  modernClean, // Executive high-yield exam review
}

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

  // ---------------------------------------------------------------------------
  // CONTENT PARSER & STYLER
  // ---------------------------------------------------------------------------
  static List<pw.Widget> _buildFormattedContent(String rawContent, PdfStudyStyle style) {
    final lines = _sanitize(rawContent).split('\n');
    final widgets = <pw.Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      final cleanText = line.replaceAll('**', '');

      // H3 - Subtopic Heading
      if (cleanText.startsWith('### ')) {
        final title = cleanText.substring(4).trim();
        widgets.add(_buildHeading3(title, style));
      }
      // H2 - Section Heading
      else if (cleanText.startsWith('## ')) {
        final title = cleanText.substring(3).trim();
        widgets.add(_buildHeading2(title, style));
      }
      // H1 - Major Unit Heading
      else if (cleanText.startsWith('# ')) {
        final title = cleanText.substring(2).trim();
        widgets.add(_buildHeading1(title, style));
      }
      // Bullet Point
      else if (cleanText.startsWith('- ') || cleanText.startsWith('* ')) {
        final bulletText = cleanText.substring(2).trim();
        widgets.add(_buildBullet(bulletText, style));
      }
      // Sticky Callout / Exam Alert (e.g. Note:, Tip:, Core idea:)
      else if (cleanText.toLowerCase().startsWith('note:') ||
          cleanText.toLowerCase().startsWith('tip:') ||
          cleanText.toLowerCase().startsWith('exam alert:') ||
          cleanText.toLowerCase().startsWith('warning:')) {
        widgets.add(_buildStickyCallout(cleanText, style));
      }
      // Standard Paragraph
      else {
        widgets.add(_buildParagraph(cleanText, style));
      }
    }
    return widgets;
  }

  // ---------------------------------------------------------------------------
  // STYLED ELEMENTS BUILDERS
  // ---------------------------------------------------------------------------
  static pw.Widget _buildHeading1(String text, PdfStudyStyle style) {
    switch (style) {
      case PdfStudyStyle.handwritten:
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FEF08A'), // Pastel yellow highlighter
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#1E293B'),
            ),
          ),
        );

      case PdfStudyStyle.minimalCute:
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FCE7F3'), // Pastel Sakura pink
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColor.fromHex('#FBCFE8'), width: 1),
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('✿ ', style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#EC4899'))),
              pw.Text(
                text,
                style: pw.TextStyle(
                  fontSize: 13.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#831843'),
                ),
              ),
            ],
          ),
        );

      case PdfStudyStyle.zenPaperInk:
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
          padding: const pw.EdgeInsets.only(bottom: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColor.fromHex('#1C1917'), width: 1.2),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                text,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1C1917'),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#DC2626'),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Text(
                  '印',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
                ),
              ),
            ],
          ),
        );

      case PdfStudyStyle.modernClean:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0F172A'),
            ),
          ),
        );
    }
  }

  static pw.Widget _buildHeading2(String text, PdfStudyStyle style) {
    switch (style) {
      case PdfStudyStyle.handwritten:
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#BBF7D0'), // Pastel mint highlighter
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#064E3B'),
            ),
          ),
        );

      case PdfStudyStyle.minimalCute:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Row(
            children: [
              pw.Container(
                width: 6,
                height: 6,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F472B6'),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                text,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#BE185D'),
                ),
              ),
            ],
          ),
        );

      case PdfStudyStyle.zenPaperInk:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#292524'),
            ),
          ),
        );

      case PdfStudyStyle.modernClean:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#1E3A8A'),
            ),
          ),
        );
    }
  }

  static pw.Widget _buildHeading3(String text, PdfStudyStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: style == PdfStudyStyle.minimalCute
              ? PdfColor.fromHex('#7C3AED')
              : (style == PdfStudyStyle.zenPaperInk
                  ? PdfColor.fromHex('#DC2626')
                  : PdfColor.fromHex('#334155')),
        ),
      ),
    );
  }

  static pw.Widget _buildBullet(String text, PdfStudyStyle style) {
    pw.Widget bulletIcon;
    switch (style) {
      case PdfStudyStyle.handwritten:
        bulletIcon = pw.Container(
          margin: const pw.EdgeInsets.only(top: 3, right: 6),
          width: 5,
          height: 5,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#EAB308'),
            shape: pw.BoxShape.circle,
          ),
        );
        break;
      case PdfStudyStyle.minimalCute:
        bulletIcon = pw.Container(
          margin: const pw.EdgeInsets.only(top: 3, right: 6),
          width: 5,
          height: 5,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#EC4899'),
            borderRadius: pw.BorderRadius.circular(2),
          ),
        );
        break;
      case PdfStudyStyle.zenPaperInk:
        bulletIcon = pw.Container(
          margin: const pw.EdgeInsets.only(top: 4, right: 6),
          width: 4,
          height: 4,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#DC2626'),
            shape: pw.BoxShape.circle,
          ),
        );
        break;
      case PdfStudyStyle.modernClean:
        bulletIcon = pw.Container(
          margin: const pw.EdgeInsets.only(top: 4, right: 6),
          width: 4,
          height: 4,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#2563EB'),
            shape: pw.BoxShape.circle,
          ),
        );
        break;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8, bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          bulletIcon,
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 9.5,
                lineSpacing: 1.6,
                color: style == PdfStudyStyle.zenPaperInk
                    ? PdfColor.fromHex('#1C1917')
                    : PdfColor.fromHex('#334155'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStickyCallout(String text, PdfStudyStyle style) {
    final bgColor = style == PdfStudyStyle.handwritten
        ? PdfColor.fromHex('#FEF9C3') // Sticky note yellow
        : (style == PdfStudyStyle.minimalCute
            ? PdfColor.fromHex('#FDF2F8') // Cute Sakura pink
            : PdfColor.fromHex('#F4F1EA'));

    final borderColor = style == PdfStudyStyle.handwritten
        ? PdfColor.fromHex('#FACC15')
        : (style == PdfStudyStyle.minimalCute
            ? PdfColor.fromHex('#FBCFE8')
            : PdfColor.fromHex('#E7E3D9'));

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(style == PdfStudyStyle.minimalCute ? 10 : 4),
        border: pw.Border.all(color: borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (style == PdfStudyStyle.handwritten) ...[
            pw.Container(
              width: 32,
              height: 4,
              margin: const pw.EdgeInsets.only(bottom: 6),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FDE047'), // Tape strip
                borderRadius: pw.BorderRadius.circular(1),
              ),
            ),
          ],
          pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#1E293B'),
              lineSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildParagraph(String text, PdfStudyStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9.5,
          lineSpacing: 1.6,
          color: style == PdfStudyStyle.zenPaperInk
              ? PdfColor.fromHex('#1C1917')
              : PdfColor.fromHex('#334155'),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN STUDY GUIDE PDF GENERATOR WITH STYLE THEMES
  // ---------------------------------------------------------------------------
  static Future<Uint8List> generateStudyGuidePdf({
    required String title,
    required String subject,
    required String content,
    List<String> keyTakeaways = const [],
    PdfStudyStyle style = PdfStudyStyle.handwritten,
  }) async {
    final pdf = pw.Document();
    final safeTitle = _sanitize(title);
    final safeSubject = _sanitize(subject);
    final contentWidgets = _buildFormattedContent(content, style);

    // Style-specific colors & backgrounds
    PdfColor pageBgColor = PdfColors.white;
    pw.EdgeInsets pageMargin = const pw.EdgeInsets.all(32);

    if (style == PdfStudyStyle.handwritten) {
      pageBgColor = PdfColor.fromHex('#FDFBF7'); // Warm cream notebook paper
      pageMargin = const pw.EdgeInsets.fromLTRB(40, 28, 28, 28);
    } else if (style == PdfStudyStyle.minimalCute) {
      pageBgColor = PdfColor.fromHex('#FCF9F9'); // Sakura cream
      pageMargin = const pw.EdgeInsets.all(28);
    } else if (style == PdfStudyStyle.zenPaperInk) {
      pageBgColor = PdfColor.fromHex('#FBF9F5'); // Washi parchment
      pageMargin = const pw.EdgeInsets.all(32);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pageMargin,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pageMargin,
          buildBackground: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(
                color: pageBgColor,
                child: style == PdfStudyStyle.handwritten
                    ? pw.Stack(
                        children: [
                          // Red/Coral Cornell vertical margin line
                          pw.Positioned(
                            left: 32,
                            top: 0,
                            bottom: 0,
                            child: pw.Container(
                              width: 1,
                              color: PdfColor.fromHex('#FCA5A5'),
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          },
        ),
        build: (pw.Context context) {
          return [
            // Header Banner
            _buildHeaderBanner(safeTitle, safeSubject, style),
            pw.SizedBox(height: 16),

            // Key Takeaways (Sticky Note Box)
            if (keyTakeaways.isNotEmpty) ...[
              _buildKeyTakeawaysBox(keyTakeaways, style),
              pw.SizedBox(height: 16),
            ],

            // Content Body
            ...contentWidgets,

            pw.SizedBox(height: 20),
            // Footer Note
            _buildFooterStamp(safeSubject, style),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeaderBanner(String title, String subject, PdfStudyStyle style) {
    switch (style) {
      case PdfStudyStyle.handwritten:
        return pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 1.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CORNELL STUDY NOTEBOOK',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#94A3B8'),
                        fontSize: 8,
                        letterSpacing: 1.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F172A'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FEF08A'), // Highlighter badge
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  subject.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#713F12'),
                  ),
                ),
              ),
            ],
          ),
        );

      case PdfStudyStyle.minimalCute:
        return pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFF5F7'),
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: PdfColor.fromHex('#FBCFE8'), width: 1),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#FCE7F3'),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Text(
                        '✿ STUDY-FRIENDLY GUIDE ✿',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#DB2777'),
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#831843'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F472B6'),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  subject,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
        );

      case PdfStudyStyle.zenPaperInk:
        return pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColor.fromHex('#1C1917'), width: 1.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'TRUE ME • SCHOLAR ARCHIVE',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#78716C'),
                      fontSize: 8,
                      letterSpacing: 2.0,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1C1917'),
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#DC2626'),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  '印 $subject',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
        );

      case PdfStudyStyle.modernClean:
        return pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColor.fromHex('#2563EB'), width: 2),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EXAM REVISION GUIDE',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#2563EB'),
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0F172A'),
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EFF6FF'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  subject.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1D4ED8'),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  static pw.Widget _buildKeyTakeawaysBox(List<String> takeaways, PdfStudyStyle style) {
    final bgColor = style == PdfStudyStyle.handwritten
        ? PdfColor.fromHex('#FEF9C3') // Sticky note
        : (style == PdfStudyStyle.minimalCute
            ? PdfColor.fromHex('#F0FDF4') // Matcha
            : PdfColor.fromHex('#F4F1EA'));

    final borderColor = style == PdfStudyStyle.handwritten
        ? PdfColor.fromHex('#FACC15')
        : (style == PdfStudyStyle.minimalCute
            ? PdfColor.fromHex('#BBF7D0')
            : PdfColor.fromHex('#E7E3D9'));

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(style == PdfStudyStyle.minimalCute ? 10 : 6),
        border: pw.Border.all(color: borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                style == PdfStudyStyle.minimalCute ? '✿ KEY EXAM TAKEAWAYS' : '📌 HIGH-YIELD EXAM TAKEAWAYS',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: style == PdfStudyStyle.minimalCute
                      ? PdfColor.fromHex('#166534')
                      : PdfColor.fromHex('#854D0E'),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          ...takeaways.map(
            (t) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Expanded(
                    child: pw.Text(
                      _sanitize(t),
                      style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#1F2937')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooterStamp(String subject, PdfStudyStyle style) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            style == PdfStudyStyle.minimalCute
                ? '🌸 True Me • Study-Friendly Notes'
                : (style == PdfStudyStyle.handwritten
                    ? '📓 Cornell Study Sheet • Verified Notes'
                    : 'True Me AI Study Platform'),
            style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
          ),
          pw.Text(
            'Subject: $subject',
            style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
          ),
        ],
      ),
    );
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
