import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/flashcard_model.dart';
import 'models/structured_study_document.dart';

enum PdfStudyStyle {
  handwritten, // Handwritten Notes (Cornell 2-column notebook + ruled lines)
  minimalCute, // Cute Aesthetic (Pastel sakura/mint rounded cards)
  zenPaperInk, // Vintage Academic (Warm parchment + serif + archival frame)
  modernClean, // Modern Academic (Navy hero banner + crisp grid + tables)
}

class PdfExporter {
  PdfExporter._();

  static PdfStudyStyle fromStyleId(String? id) {
    switch ((id ?? '').toLowerCase()) {
      case 'vintage_academic':
      case 'zenpaperink':
        return PdfStudyStyle.zenPaperInk;
      case 'cute_aesthetic':
      case 'minimalcute':
        return PdfStudyStyle.minimalCute;
      case 'modern_academic':
      case 'modernclean':
        return PdfStudyStyle.modernClean;
      case 'handwritten_notes':
      case 'handwritten':
      default:
        return PdfStudyStyle.handwritten;
    }
  }

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
        .replaceAll('**', '')
        .replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]'), '');
  }

  static pw.ThemeData _themeFor(PdfStudyStyle style) {
    switch (style) {
      case PdfStudyStyle.zenPaperInk:
        return pw.ThemeData.withFont(
          base: pw.Font.times(),
          bold: pw.Font.timesBold(),
          italic: pw.Font.timesItalic(),
          boldItalic: pw.Font.timesBoldItalic(),
        );
      case PdfStudyStyle.handwritten:
      case PdfStudyStyle.minimalCute:
      case PdfStudyStyle.modernClean:
        return pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
          boldItalic: pw.Font.helveticaBoldOblique(),
        );
    }
  }

  static Future<Uint8List> generateStudyGuidePdf({
    required String title,
    required String subject,
    required String content,
    List<String> keyTakeaways = const [],
    StructuredStudyDocument? structuredDoc,
    PdfStudyStyle style = PdfStudyStyle.handwritten,
  }) async {
    final pdf = pw.Document(theme: _themeFor(style));
    final safeTitle = _sanitize(title);
    final safeSubject = _sanitize(subject);

    final bodyWidgets = structuredDoc != null
        ? _buildFromStructured(structuredDoc, style)
        : _buildFormattedContent(content, style);

    final effectiveTakeaways = keyTakeaways.isNotEmpty
        ? keyTakeaways
        : (structuredDoc?.takeaways ?? const []);

    PdfColor pageBgColor = PdfColors.white;
    pw.EdgeInsets pageMargin = const pw.EdgeInsets.fromLTRB(32, 28, 32, 34);

    if (style == PdfStudyStyle.handwritten) {
      pageBgColor = PdfColor.fromHex('#FDFBF7');
      pageMargin = const pw.EdgeInsets.fromLTRB(44, 28, 28, 34);
    } else if (style == PdfStudyStyle.minimalCute) {
      pageBgColor = PdfColor.fromHex('#FFF5F7');
      pageMargin = const pw.EdgeInsets.fromLTRB(28, 28, 28, 34);
    } else if (style == PdfStudyStyle.zenPaperInk) {
      pageBgColor = PdfColor.fromHex('#FBF9F5');
      pageMargin = const pw.EdgeInsets.fromLTRB(36, 34, 36, 38);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pageMargin,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pageMargin,
          theme: _themeFor(style),
          buildBackground: (pw.Context ctx) => _buildPageBackground(style, pageBgColor),
        ),
        footer: (pw.Context ctx) => _buildPageFooter(safeSubject, style, ctx),
        build: (pw.Context ctx) {
          return [
            _buildHeaderBanner(safeTitle, safeSubject, style),
            pw.SizedBox(height: 14),
            if (effectiveTakeaways.isNotEmpty) ...[
              _buildKeyTakeawaysBox(effectiveTakeaways, style),
              pw.SizedBox(height: 14),
            ],
            ...bodyWidgets,
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPageBackground(PdfStudyStyle style, PdfColor bg) {
    if (style == PdfStudyStyle.handwritten) {
      return pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(
          color: bg,
          child: pw.Stack(
            children: [
              // Ruled notebook horizontal lines
              pw.Column(
                children: List.generate(
                  34,
                  (_) => pw.Container(
                    height: 24,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColor.fromHex('#E2E8F0'),
                          width: 0.45,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Red vertical Cornell margin line
              pw.Positioned(
                left: 34,
                top: 0,
                bottom: 0,
                child: pw.Container(
                  width: 1.2,
                  color: PdfColor.fromHex('#FCA5A5'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (style == PdfStudyStyle.zenPaperInk) {
      return pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(
          color: bg,
          padding: const pw.EdgeInsets.all(16),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#D6D3D1'), width: 1),
            ),
          ),
        ),
      );
    }

    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Container(color: bg),
    );
  }

  static List<pw.Widget> _buildFromStructured(
    StructuredStudyDocument doc,
    PdfStudyStyle style,
  ) {
    final widgets = <pw.Widget>[];

    if (doc.executiveSummary.isNotEmpty) {
      widgets.add(_buildHeading1('Overview', style));
      widgets.add(_buildParagraph(_sanitize(doc.executiveSummary), style));
    }

    if (doc.learningObjectives.isNotEmpty) {
      widgets.add(_buildHeading2('Learning Objectives', style));
      for (final obj in doc.learningObjectives) {
        widgets.add(_buildBullet(_sanitize(obj), style));
      }
    }

    for (int i = 0; i < doc.sections.length; i++) {
      final s = doc.sections[i];
      final headingText = style == PdfStudyStyle.modernClean
          ? '${i + 1}. ${_sanitize(s.heading)}'
          : _sanitize(s.heading);

      if (style == PdfStudyStyle.handwritten) {
        // Cornell 2-column block: Cue/Definitions on left, Detailed Notes on right
        widgets.add(_buildHeading1(headingText, style));
        final cueItems = <String>[
          ...s.definitions.map(_sanitize),
          if (s.calloutWarning != null && s.calloutWarning!.isNotEmpty)
            'Alert: ${_sanitize(s.calloutWarning!)}',
        ];
        final noteItems = <pw.Widget>[
          if (s.body.isNotEmpty) _buildParagraph(_sanitize(s.body), style),
          ...s.keyPoints.map((k) => _buildBullet(_sanitize(k), style)),
          ...s.examples.map((e) => _buildStickyCallout('Example: ${_sanitize(e)}', style)),
          ...s.processSteps.asMap().entries.map(
                (e) => _buildBullet('Step ${e.key + 1}: ${_sanitize(e.value)}', style),
              ),
          if (s.tableRows.isNotEmpty) _buildPdfTable(s.tableRows, style),
        ];

        widgets.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Container(
                  padding: const pw.EdgeInsets.only(right: 10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      right: pw.BorderSide(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CUES & TERMS',
                        style: pw.TextStyle(
                          font: pw.Font.courierBold(),
                          fontSize: 7.5,
                          color: PdfColor.fromHex('#B91C1C'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (cueItems.isEmpty)
                        pw.Text(
                          'Key concepts ->',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColor.fromHex('#64748B'),
                            fontStyle: pw.FontStyle.italic,
                          ),
                        )
                      else
                        ...cueItems.map(
                          (c) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Text(
                              c,
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#1E293B'),
                                lineSpacing: 3.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                flex: 7,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: noteItems,
                ),
              ),
            ],
          ),
        );
        widgets.add(pw.SizedBox(height: 10));
        continue;
      }

      widgets.add(_buildHeading1(headingText, style));
      if (s.body.isNotEmpty) {
        widgets.add(_buildParagraph(_sanitize(s.body), style));
      }
      for (final d in s.definitions) {
        widgets.add(_buildStickyCallout('Definition: ${_sanitize(d)}', style));
      }
      for (final k in s.keyPoints) {
        widgets.add(_buildBullet(_sanitize(k), style));
      }
      for (final ex in s.examples) {
        widgets.add(_buildStickyCallout('Example: ${_sanitize(ex)}', style));
      }
      if (s.processSteps.isNotEmpty) {
        widgets.add(_buildHeading3('Process Flow', style));
        for (int p = 0; p < s.processSteps.length; p++) {
          widgets.add(_buildBullet('Step ${p + 1}: ${_sanitize(s.processSteps[p])}', style));
        }
      }
      if (s.tableRows.isNotEmpty) {
        widgets.add(_buildPdfTable(s.tableRows, style));
      }
      if (s.calloutWarning != null && s.calloutWarning!.isNotEmpty) {
        widgets.add(_buildStickyCallout('Exam Alert: ${_sanitize(s.calloutWarning!)}', style));
      }
    }

    if (doc.sourceReferences.isNotEmpty) {
      widgets.add(_buildHeading2('Sources', style));
      for (final ref in doc.sourceReferences) {
        widgets.add(_buildBullet(_sanitize(ref), style));
      }
    }
    if (doc.uncertaintyNote != null && doc.uncertaintyNote!.isNotEmpty) {
      widgets.add(_buildStickyCallout('Coverage Note: ${_sanitize(doc.uncertaintyNote!)}', style));
    }

    return widgets;
  }

  static List<pw.Widget> _buildFormattedContent(String rawContent, PdfStudyStyle style) {
    final lines = _sanitize(rawContent).split('\n');
    final widgets = <pw.Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      if (RegExp(r'^#{3,6}\s+').hasMatch(line)) {
        widgets.add(_buildHeading3(line.replaceFirst(RegExp(r'^#{3,6}\s+'), '').trim(), style));
      } else if (line.startsWith('## ')) {
        widgets.add(_buildHeading2(line.substring(3).trim(), style));
      } else if (line.startsWith('# ')) {
        widgets.add(_buildHeading1(line.substring(2).trim(), style));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(_buildBullet(line.substring(2).trim(), style));
      } else if (RegExp(r'^\d+\.\s+').hasMatch(line)) {
        widgets.add(_buildBullet(line, style));
      } else if (line.toLowerCase().startsWith('note:') ||
          line.toLowerCase().startsWith('tip:') ||
          line.toLowerCase().startsWith('exam alert:') ||
          line.toLowerCase().startsWith('warning:')) {
        widgets.add(_buildStickyCallout(line, style));
      } else {
        widgets.add(_buildParagraph(line, style));
      }
    }
    return widgets;
  }

  static pw.Widget _buildPdfTable(List<List<String>> rows, PdfStudyStyle style) {
    final safeRows = rows.map((r) => r.map(_sanitize).toList()).toList();
    if (safeRows.isEmpty) return pw.SizedBox();
    final headerBg = style == PdfStudyStyle.minimalCute
        ? PdfColor.fromHex('#FCE7F3')
        : (style == PdfStudyStyle.zenPaperInk
            ? PdfColor.fromHex('#EFECE6')
            : PdfColor.fromHex('#EFF6FF'));

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.TableHelper.fromTextArray(
        headers: safeRows.first,
        data: safeRows.length > 1 ? safeRows.sublist(1) : const [],
        headerStyle: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#0F172A'),
        ),
        headerDecoration: pw.BoxDecoration(color: headerBg),
        cellStyle: pw.TextStyle(
          fontSize: 9,
          color: PdfColor.fromHex('#334155'),
        ),
        border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.7),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      ),
    );
  }

  static pw.Widget _buildHeading1(String text, PdfStudyStyle style) {
    switch (style) {
      case PdfStudyStyle.handwritten:
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FEF08A'),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 13.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#1E293B'),
            ),
          ),
        );

      case PdfStudyStyle.minimalCute:
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FCE7F3'),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColor.fromHex('#FBCFE8'), width: 1),
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: 7,
                height: 7,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EC4899'),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 7),
              pw.Text(
                text,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#831843'),
                ),
              ),
            ],
          ),
        );

      case PdfStudyStyle.zenPaperInk:
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
          padding: const pw.EdgeInsets.only(bottom: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColor.fromHex('#57534E'), width: 1.0),
            ),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#1C1917'),
            ),
          ),
        );

      case PdfStudyStyle.modernClean:
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
          padding: const pw.EdgeInsets.only(left: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColor.fromHex('#2563EB'), width: 3),
            ),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 14.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0F172A'),
            ),
          ),
        );
    }
  }

  static pw.Widget _buildHeading2(String text, PdfStudyStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: style == PdfStudyStyle.minimalCute
              ? PdfColor.fromHex('#BE185D')
              : (style == PdfStudyStyle.zenPaperInk
                  ? PdfColor.fromHex('#7C2D12')
                  : PdfColor.fromHex('#1E3A8A')),
        ),
      ),
    );
  }

  static pw.Widget _buildHeading3(String text, PdfStudyStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#334155'),
        ),
      ),
    );
  }

  static pw.Widget _buildBullet(String text, PdfStudyStyle style) {
    final dotColor = switch (style) {
      PdfStudyStyle.handwritten => PdfColor.fromHex('#EAB308'),
      PdfStudyStyle.minimalCute => PdfColor.fromHex('#EC4899'),
      PdfStudyStyle.zenPaperInk => PdfColor.fromHex('#7C2D12'),
      PdfStudyStyle.modernClean => PdfColor.fromHex('#2563EB'),
    };
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 6, bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 4, right: 6),
            width: 4.5,
            height: 4.5,
            decoration: pw.BoxDecoration(color: dotColor, shape: pw.BoxShape.circle),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 10,
                lineSpacing: 4.0,
                color: PdfColor.fromHex('#1E293B'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStickyCallout(String text, PdfStudyStyle style) {
    final bgColor = switch (style) {
      PdfStudyStyle.handwritten => PdfColor.fromHex('#FEF9C3'),
      PdfStudyStyle.minimalCute => PdfColor.fromHex('#F5F3FF'),
      PdfStudyStyle.zenPaperInk => PdfColor.fromHex('#F5F0E6'),
      PdfStudyStyle.modernClean => PdfColor.fromHex('#EFF6FF'),
    };
    final borderColor = switch (style) {
      PdfStudyStyle.handwritten => PdfColor.fromHex('#FACC15'),
      PdfStudyStyle.minimalCute => PdfColor.fromHex('#DDD6FE'),
      PdfStudyStyle.zenPaperInk => PdfColor.fromHex('#A8A29E'),
      PdfStudyStyle.modernClean => PdfColor.fromHex('#93C5FD'),
    };

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 5),
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(style == PdfStudyStyle.minimalCute ? 10 : 4),
        border: pw.Border.all(color: borderColor, width: 0.9),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1E293B'),
          lineSpacing: 3.5,
        ),
      ),
    );
  }

  static pw.Widget _buildParagraph(String text, PdfStudyStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          lineSpacing: 4.2,
          color: PdfColor.fromHex('#1E293B'),
        ),
      ),
    );
  }

  static pw.Widget _buildHeaderBanner(String title, String subject, PdfStudyStyle style) {
    switch (style) {
      case PdfStudyStyle.handwritten:
        return pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#94A3B8'), width: 1.2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CORNELL STUDY NOTEBOOK',
                      style: pw.TextStyle(
                        font: pw.Font.courierBold(),
                        color: PdfColor.fromHex('#64748B'),
                        fontSize: 8.5,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(title, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FEF08A'),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(subject.toUpperCase(), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
        );

      case PdfStudyStyle.minimalCute:
        return pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FCE7F3'),
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: PdfColor.fromHex('#F9A8D4'), width: 1),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CUTE AESTHETIC STUDY GUIDE',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#DB2777')),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(title, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#831843'))),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EC4899'),
                  borderRadius: pw.BorderRadius.circular(16),
                ),
                child: pw.Text(subject, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
            ],
          ),
        );

      case PdfStudyStyle.zenPaperInk:
        return pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#44403C'), width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('VINTAGE ACADEMIC ARCHIVE', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#78716C'), letterSpacing: 1.5)),
                    pw.SizedBox(height: 4),
                    pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1C1917'))),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#7C2D12'), borderRadius: pw.BorderRadius.circular(2)),
                child: pw.Text(subject, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
            ],
          ),
        );

      case PdfStudyStyle.modernClean:
        return pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#0F172A'),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MODERN ACADEMIC REVIEW', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#93C5FD'))),
                    pw.SizedBox(height: 4),
                    pw.Text(title, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2563EB'), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text(subject.toUpperCase(), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
            ],
          ),
        );
    }
  }

  static pw.Widget _buildKeyTakeawaysBox(List<String> takeaways, PdfStudyStyle style) {
    final bgColor = style == PdfStudyStyle.handwritten
        ? PdfColor.fromHex('#FEF9C3')
        : (style == PdfStudyStyle.minimalCute ? PdfColor.fromHex('#ECFDF5') : PdfColor.fromHex('#F8FAFC'));
    final borderColor = style == PdfStudyStyle.handwritten
        ? PdfColor.fromHex('#FACC15')
        : (style == PdfStudyStyle.minimalCute ? PdfColor.fromHex('#A7F3D0') : PdfColor.fromHex('#CBD5E1'));

    return pw.Container(
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('KEY EXAM TAKEAWAYS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
          pw.SizedBox(height: 6),
          ...takeaways.map(
            (t) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text('- ${_sanitize(t)}', style: pw.TextStyle(fontSize: 9.5, lineSpacing: 3.0)),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPageFooter(String subject, PdfStudyStyle style, pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('#CBD5E1'), width: 0.6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('TRUE ME · $subject', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#64748B'))),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#64748B'))),
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
        build: (pw.Context context) => [
          pw.Text('Flashcard Review Sheet: ${_sanitize(deckTitle)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          ...cards.map((card) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text(_sanitize(card.front), style: const pw.TextStyle(fontSize: 10))),
                    pw.SizedBox(width: 12),
                    pw.Expanded(flex: 6, child: pw.Text(_sanitize(card.back), style: const pw.TextStyle(fontSize: 10))),
                  ],
                ),
              )),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<void> printPdf(Uint8List bytes, {String name = 'Study_Guide'}) async {
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes, name: name);
  }
}
