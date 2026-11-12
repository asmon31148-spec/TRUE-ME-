import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

class DocxExporter {
  DocxExporter._();

  /// Generates a Microsoft Word (.docx) study summary document.
  static Uint8List createDocument({
    required String title,
    required String subject,
    required String content,
  }) {
    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(_createArchiveFile('[Content_Types].xml', contentTypesXml));

    // 2. _rels/.rels
    final rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(_createArchiveFile('_rels/.rels', rootRelsXml));

    // 3. word/document.xml
    final paragraphs = content.split('\n').map((rawLine) {
      final line = rawLine.trim().replaceAll('**', '');
      if (line.isEmpty) {
        return '<w:p/>';
      }
      if (line.startsWith('# ')) {
        return '<w:p><w:pPr><w:spacing w:before="240" w:after="100"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="32"/><w:color w:val="1E40AF"/></w:rPr><w:t>${_escapeXml(line.substring(2).trim())}</w:t></w:r></w:p>';
      }
      if (line.startsWith('## ') || line.startsWith('### ')) {
        final text = line.replaceFirst(RegExp(r'^#{2,3}\s+'), '').trim();
        return '<w:p><w:pPr><w:spacing w:before="180" w:after="80"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="111827"/></w:rPr><w:t>${_escapeXml(text)}</w:t></w:r></w:p>';
      }
      if (line.startsWith('- ') || line.startsWith('* ')) {
        return '<w:p><w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>• ${_escapeXml(line.substring(2).trim())}</w:t></w:r></w:p>';
      }
      return '<w:p><w:pPr><w:spacing w:after="100"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>${_escapeXml(line)}</w:t></w:r></w:p>';
    }).join('');

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="48"/><w:color w:val="4F46E5"/></w:rPr><w:t>${_escapeXml(title)}</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:i/><w:sz w:val="24"/><w:color w:val="6B7280"/></w:rPr><w:t>Subject: ${_escapeXml(subject)} | True Me Study Companion</w:t></w:r>
    </w:p>
    <w:p/>
    $paragraphs
  </w:body>
</w:document>''';
    archive.addFile(_createArchiveFile('word/document.xml', documentXml));

    final encoder = ZipEncoder();
    final outputBytes = encoder.encode(archive);
    return Uint8List.fromList(outputBytes!);
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
