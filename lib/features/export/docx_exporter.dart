import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'models/structured_study_document.dart';

enum DocxStudyStyle {
  elegantAcademicNotes,
  professionalResearchReport,
  cuteCreativeNotes,
  modernMinimal,
}

class DocxExporter {
  DocxExporter._();

  static DocxStudyStyle fromStyleId(String? id) {
    switch ((id ?? '').toLowerCase()) {
      case 'professional_research_report':
        return DocxStudyStyle.professionalResearchReport;
      case 'cute_creative_notes':
        return DocxStudyStyle.cuteCreativeNotes;
      case 'modern_minimal':
        return DocxStudyStyle.modernMinimal;
      default:
        return DocxStudyStyle.elegantAcademicNotes;
    }
  }

  /// Generates a styled Microsoft Word (.docx) OpenXML study document
  /// with semantic Word styles (`word/styles.xml`), page margins, keepNext headings,
  /// and real OpenXML `<w:tbl>` tables.
  static Uint8List createDocument({
    required String title,
    required String subject,
    required String content,
    StructuredStudyDocument? structuredDoc,
    DocxStudyStyle style = DocxStudyStyle.elegantAcademicNotes,
  }) {
    final archive = Archive();
    final palette = _paletteFor(style);

    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    archive.addFile(_createArchiveFile('[Content_Types].xml', contentTypesXml));

    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(_createArchiveFile('_rels/.rels', rootRelsXml));

    const docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    archive.addFile(_createArchiveFile('word/_rels/document.xml.rels', docRelsXml));

    archive.addFile(_createArchiveFile('word/styles.xml', _buildStylesXml(palette)));

    final bodyXml = structuredDoc != null
        ? _buildFromStructured(structuredDoc, palette, style)
        : _buildFromMarkdown(content, palette);

    final bannerTextColor =
        style == DocxStudyStyle.professionalResearchReport ? 'FFFFFF' : palette.accent;
    final subtitleColor =
        style == DocxStudyStyle.professionalResearchReport ? 'DBEAFE' : '6B7280';

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Title"/>
        <w:shd w:val="clear" w:color="auto" w:fill="${palette.bannerBg}"/>
        <w:jc w:val="${style == DocxStudyStyle.modernMinimal ? 'left' : 'center'}"/>
        <w:spacing w:before="140" w:after="60"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="${palette.headingFont}" w:hAnsi="${palette.headingFont}"/>
          <w:b/>
          <w:sz w:val="44"/>
          <w:color w:val="$bannerTextColor"/>
        </w:rPr>
        <w:t>${_escapeXml(title)}</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:pPr>
        <w:shd w:val="clear" w:color="auto" w:fill="${palette.bannerBg}"/>
        <w:jc w:val="${style == DocxStudyStyle.modernMinimal ? 'left' : 'center'}"/>
        <w:spacing w:after="200"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="${palette.bodyFont}" w:hAnsi="${palette.bodyFont}"/>
          <w:i/>
          <w:sz w:val="20"/>
          <w:color w:val="$subtitleColor"/>
        </w:rPr>
        <w:t>Subject: ${_escapeXml(subject)} · ${_escapeXml(palette.label)} · TRUE ME</w:t>
      </w:r>
    </w:p>
    $bodyXml
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>
    </w:sectPr>
  </w:body>
</w:document>''';
    archive.addFile(_createArchiveFile('word/document.xml', documentXml));

    final encoder = ZipEncoder();
    final outputBytes = encoder.encode(archive);
    return Uint8List.fromList(outputBytes!);
  }

  static String _buildFromStructured(
    StructuredStudyDocument doc,
    _DocxPalette p,
    DocxStudyStyle style,
  ) {
    final buf = StringBuffer();
    if (doc.executiveSummary.isNotEmpty) {
      buf.write(_h1('Overview', p));
      buf.write(_para(doc.executiveSummary, p));
    }
    if (doc.learningObjectives.isNotEmpty) {
      buf.write(_h2('Learning Objectives', p));
      for (final obj in doc.learningObjectives) {
        buf.write(_bullet(obj, p));
      }
    }

    for (int i = 0; i < doc.sections.length; i++) {
      final s = doc.sections[i];
      final prefix = style == DocxStudyStyle.professionalResearchReport ? '${i + 1}. ' : '';
      buf.write(_h1('$prefix${s.heading}', p));
      if (s.body.isNotEmpty) {
        buf.write(_para(s.body, p));
      }
      for (final d in s.definitions) {
        buf.write(_callout('Definition: $d', p));
      }
      for (final kp in s.keyPoints) {
        buf.write(_bullet(kp, p));
      }
      for (final ex in s.examples) {
        buf.write(_callout('Example: $ex', p));
      }
      if (s.processSteps.isNotEmpty) {
        buf.write(_h2('Process Flow', p));
        for (int k = 0; k < s.processSteps.length; k++) {
          buf.write(_bullet('Step ${k + 1}: ${s.processSteps[k]}', p));
        }
      }
      if (s.tableRows.isNotEmpty) {
        buf.write(_table(s.tableRows, p));
      }
      if (s.calloutWarning != null && s.calloutWarning!.isNotEmpty) {
        buf.write(_callout('Exam Alert: ${s.calloutWarning!}', p));
      }
    }

    if (doc.takeaways.isNotEmpty) {
      buf.write(_h1('Key Takeaways', p));
      for (final t in doc.takeaways) {
        buf.write(_bullet(t, p));
      }
    }
    if (doc.sourceReferences.isNotEmpty) {
      buf.write(_h2('Sources', p));
      for (final ref in doc.sourceReferences) {
        buf.write(_bullet(ref, p));
      }
    }
    if (doc.uncertaintyNote != null && doc.uncertaintyNote!.isNotEmpty) {
      buf.write(_callout('Note: ${doc.uncertaintyNote!}', p));
    }
    return buf.toString();
  }

  static String _buildFromMarkdown(String content, _DocxPalette p) {
    final buf = StringBuffer();
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim().replaceAll('**', '');
      if (line.isEmpty) {
        buf.write('<w:p/>');
        continue;
      }
      if (line.startsWith('# ')) {
        buf.write(_h1(line.substring(2).trim(), p));
      } else if (RegExp(r'^#{2,6}\s+').hasMatch(line)) {
        buf.write(_h2(line.replaceFirst(RegExp(r'^#{2,6}\s+'), '').trim(), p));
      } else if (line.toLowerCase().startsWith('note:') ||
          line.toLowerCase().startsWith('exam alert:')) {
        buf.write(_callout(line, p));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        buf.write(_bullet(line.substring(2).trim(), p));
      } else {
        buf.write(_para(line, p));
      }
    }
    return buf.toString();
  }

  static String _h1(String text, _DocxPalette p) =>
      '<w:p><w:pPr><w:pStyle w:val="Heading1"/><w:keepNext/><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="4" w:color="${p.accent}"/></w:pBdr><w:spacing w:before="260" w:after="110"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="${p.headingFont}" w:hAnsi="${p.headingFont}"/><w:b/><w:sz w:val="30"/><w:color w:val="${p.accent}"/></w:rPr><w:t>${_escapeXml(text)}</w:t></w:r></w:p>';

  static String _h2(String text, _DocxPalette p) =>
      '<w:p><w:pPr><w:pStyle w:val="Heading2"/><w:keepNext/><w:spacing w:before="180" w:after="80"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="${p.headingFont}" w:hAnsi="${p.headingFont}"/><w:b/><w:sz w:val="25"/><w:color w:val="${p.subHeading}"/></w:rPr><w:t>${_escapeXml(text)}</w:t></w:r></w:p>';

  static String _callout(String text, _DocxPalette p) =>
      '<w:p><w:pPr><w:shd w:val="clear" w:color="auto" w:fill="${p.calloutBg}"/><w:pBdr><w:left w:val="single" w:sz="18" w:space="8" w:color="${p.accent}"/></w:pBdr><w:ind w:left="220" w:right="220"/><w:spacing w:before="100" w:after="100"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="${p.bodyFont}" w:hAnsi="${p.bodyFont}"/><w:b/><w:sz w:val="22"/><w:color w:val="${p.bodyText}"/></w:rPr><w:t>${_escapeXml(text)}</w:t></w:r></w:p>';

  static String _bullet(String text, _DocxPalette p) =>
      '<w:p><w:pPr><w:ind w:left="360"/><w:spacing w:after="70"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="${p.bodyFont}" w:hAnsi="${p.bodyFont}"/><w:sz w:val="22"/><w:color w:val="${p.bodyText}"/></w:rPr><w:t>• ${_escapeXml(text)}</w:t></w:r></w:p>';

  static String _para(String text, _DocxPalette p) =>
      '<w:p><w:pPr><w:spacing w:after="110" w:line="276" w:lineRule="auto"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="${p.bodyFont}" w:hAnsi="${p.bodyFont}"/><w:sz w:val="22"/><w:color w:val="${p.bodyText}"/></w:rPr><w:t>${_escapeXml(text)}</w:t></w:r></w:p>';

  static String _table(List<List<String>> rows, _DocxPalette p) {
    final rowsXml = rows.asMap().entries.map((entry) {
      final isHeader = entry.key == 0;
      final cellsXml = entry.value.map((cell) {
        final fill = isHeader ? p.calloutBg : 'FFFFFF';
        return '<w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="$fill"/></w:tcPr><w:p><w:r><w:rPr><w:rFonts w:ascii="${p.bodyFont}" w:hAnsi="${p.bodyFont}"/>${isHeader ? '<w:b/>' : ''}<w:sz w:val="20"/><w:color w:val="${p.bodyText}"/></w:rPr><w:t>${_escapeXml(cell)}</w:t></w:r></w:p></w:tc>';
      }).join('');
      return '<w:tr>$cellsXml</w:tr>';
    }).join('');

    return '<w:tbl><w:tblPr><w:tblW w:w="9638" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="4" w:color="CBD5E1"/><w:bottom w:val="single" w:sz="4" w:color="CBD5E1"/><w:insideH w:val="single" w:sz="4" w:color="E2E8F0"/><w:insideV w:val="single" w:sz="4" w:color="E2E8F0"/></w:tblBorders></w:tblPr>$rowsXml</w:tbl><w:p/>';
  }

  static String _buildStylesXml(_DocxPalette p) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr><w:rFonts w:ascii="${p.bodyFont}" w:hAnsi="${p.bodyFont}"/><w:sz w:val="22"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:basedOn w:val="Normal"/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:keepNext/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:keepNext/></w:pPr>
  </w:style>
</w:styles>''';
  }

  static _DocxPalette _paletteFor(DocxStudyStyle style) {
    switch (style) {
      case DocxStudyStyle.professionalResearchReport:
        return const _DocxPalette(
          label: 'Professional Research Report',
          accent: '1E3A8A',
          subHeading: '0F172A',
          bodyText: '1E293B',
          bannerBg: '1E3A8A',
          calloutBg: 'EFF6FF',
          headingFont: 'Georgia',
          bodyFont: 'Calibri',
        );
      case DocxStudyStyle.cuteCreativeNotes:
        return const _DocxPalette(
          label: 'Cute Creative Notes',
          accent: '7C3AED',
          subHeading: 'BE185D',
          bodyText: '312E81',
          bannerBg: 'FDF2F8',
          calloutBg: 'F5F3FF',
          headingFont: 'Trebuchet MS',
          bodyFont: 'Calibri',
        );
      case DocxStudyStyle.modernMinimal:
        return const _DocxPalette(
          label: 'Modern Minimal',
          accent: '0F172A',
          subHeading: '334155',
          bodyText: '1F2937',
          bannerBg: 'F8FAFC',
          calloutBg: 'F1F5F9',
          headingFont: 'Arial',
          bodyFont: 'Arial',
        );
      case DocxStudyStyle.elegantAcademicNotes:
        return const _DocxPalette(
          label: 'Elegant Academic Notes',
          accent: '4338CA',
          subHeading: '1E1B4B',
          bodyText: '1F2937',
          bannerBg: 'EEF2FF',
          calloutBg: 'FAF5FF',
          headingFont: 'Georgia',
          bodyFont: 'Georgia',
        );
    }
  }

  static ArchiveFile _createArchiveFile(String path, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(path, bytes.length, bytes);
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

class _DocxPalette {
  final String label;
  final String accent;
  final String subHeading;
  final String bodyText;
  final String bannerBg;
  final String calloutBg;
  final String headingFont;
  final String bodyFont;

  const _DocxPalette({
    required this.label,
    required this.accent,
    required this.subHeading,
    required this.bodyText,
    required this.bannerBg,
    required this.calloutBg,
    required this.headingFont,
    required this.bodyFont,
  });
}
