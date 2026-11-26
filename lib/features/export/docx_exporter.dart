import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

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

  /// Generates a styled Microsoft Word (.docx) OpenXML study document.
  static Uint8List createDocument({
    required String title,
    required String subject,
    required String content,
    DocxStudyStyle style = DocxStudyStyle.elegantAcademicNotes,
  }) {
    final archive = Archive();

    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(_createArchiveFile('[Content_Types].xml', contentTypesXml));

    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(_createArchiveFile('_rels/.rels', rootRelsXml));

    final palette = _paletteFor(style);
    final paragraphs = content.split('\n').map((rawLine) {
      final line = rawLine.trim().replaceAll('**', '');
      if (line.isEmpty) return '<w:p/>';

      if (line.startsWith('# ')) {
        final heading = _escapeXml(line.substring(2).trim());
        return '<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="4" w:color="${palette.accent}"/></w:pBdr><w:spacing w:before="260" w:after="110"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="${palette.headingFont}" w:hAnsi="${palette.headingFont}"/><w:b/><w:sz w:val="32"/><w:color w:val="${palette.accent}"/></w:rPr><w:t>$heading</w:t></w:r></w:p>';
      }
      if (line.startsWith('## ') || line.startsWith('### ')) {
        final text = _escapeXml(line.replaceFirst(RegExp(r'^#{2,3}\s+'), '').trim());
        return '<w:p><w:pPr><w:spacing w:before="180" w:after="80"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="${palette.headingFont}" w:hAnsi="${palette.headingFont}"/><w:b/><w:sz w:val="26"/><w:color w:val="${palette.subHeading}"/></w:rPr><w:t>$text</w:t></w:r></w:p>';
      }
      if (line.toLowerCase().startsWith('note:') || line.toLowerCase().startsWith('exam alert:')) {
        return '<w:p><w:pPr><w:shd w:val="clear" w:color="auto" w:fill="${palette.calloutBg}"/><w:ind w:left="220" w:right="220"/><w:spacing w:before="100" w:after="100"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="${palette.bodyFont}" w:hAnsi="${palette.bodyFont}"/><w:b/><w:sz w:val="22"/><w:color w:val="${palette.bodyText}"/></w:rPr><w:t>${_escapeXml(line)}</w:t></w:r></w:p>';
      }
      if (line.startsWith('- ') || line.startsWith('* ')) {
        final bullet = _escapeXml(line.substring(2).trim());
        return '<w:p><w:pPr><w:ind w:left="360"/><w:spacing w:after="70"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="${palette.bodyFont}" w:hAnsi="${palette.bodyFont}"/><w:sz w:val="22"/><w:color w:val="${palette.bodyText}"/></w:rPr><w:t>• $bullet</w:t></w:r></w:p>';
      }
      return '<w:p><w:pPr><w:spacing w:after="110" w:line="276" w:lineRule="auto"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="${palette.bodyFont}" w:hAnsi="${palette.bodyFont}"/><w:sz w:val="22"/><w:color w:val="${palette.bodyText}"/></w:rPr><w:t>${_escapeXml(line)}</w:t></w:r></w:p>';
    }).join('');

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:shd w:val="clear" w:color="auto" w:fill="${palette.bannerBg}"/><w:jc w:val="center"/><w:spacing w:before="120" w:after="80"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="${palette.headingFont}" w:hAnsi="${palette.headingFont}"/><w:b/><w:sz w:val="46"/><w:color w:val="${palette.accent}"/></w:rPr><w:t>${_escapeXml(title)}</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:after="160"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="${palette.bodyFont}" w:hAnsi="${palette.bodyFont}"/><w:i/><w:sz w:val="22"/><w:color w:val="6B7280"/></w:rPr><w:t>Subject: ${_escapeXml(subject)} · ${_escapeXml(palette.label)} · TRUE ME</w:t></w:r>
    </w:p>
    $paragraphs
  </w:body>
</w:document>''';
    archive.addFile(_createArchiveFile('word/document.xml', documentXml));

    final encoder = ZipEncoder();
    final outputBytes = encoder.encode(archive);
    return Uint8List.fromList(outputBytes!);
  }

  static _DocxPalette _paletteFor(DocxStudyStyle style) {
    switch (style) {
      case DocxStudyStyle.professionalResearchReport:
        return const _DocxPalette(
          label: 'Professional Research Report',
          accent: '1E3A8A',
          subHeading: '0F172A',
          bodyText: '1E293B',
          bannerBg: 'EFF6FF',
          calloutBg: 'F1F5F9',
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
