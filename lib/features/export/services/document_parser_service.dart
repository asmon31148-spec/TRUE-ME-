import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

enum ParsedDocFormat { pdf, docx, pptx, unknown }

class ParsedDocxBlock {
  final String kind; // 'title' | 'heading1' | 'heading2' | 'bullet' | 'paragraph' | 'table'
  final String text;
  final List<List<String>> rows;

  const ParsedDocxBlock({
    required this.kind,
    this.text = '',
    this.rows = const [],
  });
}

class ParsedPptxSlide {
  final int index;
  final String title;
  final List<String> bullets;
  final String? backgroundHex;

  const ParsedPptxSlide({
    required this.index,
    required this.title,
    required this.bullets,
    this.backgroundHex,
  });
}

/// Validates file headers (magic bytes) and parses OpenXML DOCX / PPTX packages
/// offline in pure Dart for native in-app viewing without modifying original files.
class DocumentParserService {
  DocumentParserService._();

  static const int maxSupportedBytes = 150 * 1024 * 1024; // 150 MB safety cap

  static ParsedDocFormat detectFormat(Uint8List bytes, String filePath) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46) {
      return ParsedDocFormat.pdf;
    }

    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);
        final names = archive.files.map((f) => f.name).toSet();
        if (names.any((n) => n == 'word/document.xml')) return ParsedDocFormat.docx;
        if (names.any((n) => n.startsWith('ppt/slides/slide'))) return ParsedDocFormat.pptx;
      } catch (_) {}
    }

    final lower = filePath.toLowerCase();
    if (lower.endsWith('.pdf')) return ParsedDocFormat.unknown; // Missing %PDF magic
    return ParsedDocFormat.unknown;
  }

  static String _unescapeXml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  static List<ParsedDocxBlock> parseDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      throw const FormatException('Invalid DOCX: missing word/document.xml');
    }

    final xml = utf8.decode(docFile.content as List<int>, allowMalformed: true);
    final blocks = <ParsedDocxBlock>[];

    // Extract tables & paragraphs in order
    final tokenRegex = RegExp(r'<w:tbl\b[\s\S]*?</w:tbl>|<w:p\b[\s\S]*?</w:p>');
    for (final match in tokenRegex.allMatches(xml)) {
      final chunk = match.group(0) ?? '';
      if (chunk.startsWith('<w:tbl')) {
        final rows = <List<String>>[];
        for (final rowMatch in RegExp(r'<w:tr\b[\s\S]*?</w:tr>').allMatches(chunk)) {
          final cells = <String>[];
          for (final cellMatch in RegExp(r'<w:tc\b[\s\S]*?</w:tc>').allMatches(rowMatch.group(0)!)) {
            final text = RegExp(r'<w:t\b[^>]*>([\s\S]*?)</w:t>')
                .allMatches(cellMatch.group(0)!)
                .map((m) => _unescapeXml(m.group(1) ?? ''))
                .join(' ')
                .trim();
            cells.add(text);
          }
          if (cells.isNotEmpty) rows.add(cells);
        }
        if (rows.isNotEmpty) {
          blocks.add(ParsedDocxBlock(kind: 'table', rows: rows));
        }
        continue;
      }

      final text = RegExp(r'<w:t\b[^>]*>([\s\S]*?)</w:t>')
          .allMatches(chunk)
          .map((m) => _unescapeXml(m.group(1) ?? ''))
          .join('')
          .trim();
      if (text.isEmpty) continue;

      final sizeMatch = RegExp(r'<w:sz\s+w:val="(\d+)"').firstMatch(chunk);
      final sz = sizeMatch != null ? int.tryParse(sizeMatch.group(1)!) ?? 22 : 22;
      final isHeadingStyle = RegExp(r'Heading1|Title', caseSensitive: false).hasMatch(chunk);
      final isSubHeadingStyle = RegExp(r'Heading2|Heading3', caseSensitive: false).hasMatch(chunk);

      if (sz >= 40 || (isHeadingStyle && blocks.isEmpty)) {
        blocks.add(ParsedDocxBlock(kind: 'title', text: text));
      } else if (sz >= 30 || isHeadingStyle) {
        blocks.add(ParsedDocxBlock(kind: 'heading1', text: text));
      } else if (sz >= 25 || isSubHeadingStyle) {
        blocks.add(ParsedDocxBlock(kind: 'heading2', text: text));
      } else if (text.startsWith('•') || text.startsWith('- ') || chunk.contains('<w:numPr>')) {
        blocks.add(
          ParsedDocxBlock(
            kind: 'bullet',
            text: text.replaceFirst(RegExp(r'^[•\-]\s*'), ''),
          ),
        );
      } else {
        blocks.add(ParsedDocxBlock(kind: 'paragraph', text: text));
      }
    }

    return blocks;
  }

  static List<ParsedPptxSlide> parsePptx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final slideFiles = archive.files
        .where((f) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name))
        .toList()
      ..sort((a, b) {
        final na = int.tryParse(RegExp(r'(\d+)').firstMatch(a.name)?.group(1) ?? '0') ?? 0;
        final nb = int.tryParse(RegExp(r'(\d+)').firstMatch(b.name)?.group(1) ?? '0') ?? 0;
        return na.compareTo(nb);
      });

    if (slideFiles.isEmpty) {
      throw const FormatException('Invalid PPTX: no slides found');
    }

    final slides = <ParsedPptxSlide>[];
    for (int i = 0; i < slideFiles.length; i++) {
      final xml = utf8.decode(slideFiles[i].content as List<int>, allowMalformed: true);
      final bgMatch = RegExp(r'<p:bg>[\s\S]*?<a:srgbClr\s+val="([0-9A-Fa-f]{6})"').firstMatch(xml);
      final bgHex = bgMatch?.group(1);

      final paragraphs = <String>[];
      for (final pMatch in RegExp(r'<a:p\b[\s\S]*?</a:p>').allMatches(xml)) {
        final text = RegExp(r'<a:t\b[^>]*>([\s\S]*?)</a:t>')
            .allMatches(pMatch.group(0)!)
            .map((m) => _unescapeXml(m.group(1) ?? ''))
            .join('')
            .trim();
        if (text.isNotEmpty &&
            !RegExp(r'^(?:[✦⚡].*)?SLIDE\s+\d+/\d+.*$').hasMatch(text)) {
          paragraphs.add(text);
        }
      }

      final title = paragraphs.isNotEmpty ? paragraphs.first : 'Slide ${i + 1}';
      final bullets = paragraphs.length > 1 ? paragraphs.sublist(1) : const <String>[];

      slides.add(
        ParsedPptxSlide(
          index: i + 1,
          title: title,
          bullets: bullets,
          backgroundHex: bgHex,
        ),
      );
    }

    return slides;
  }

  static double parsePptxAspectRatio(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final pres = archive.files.where((f) => f.name == 'ppt/presentation.xml').firstOrNull;
      if (pres != null) {
        final xml = utf8.decode(pres.content as List<int>, allowMalformed: true);
        final m = RegExp(r'<p:sldSz\s+cx="(\d+)"\s+cy="(\d+)"').firstMatch(xml);
        if (m != null) {
          final cx = double.tryParse(m.group(1)!) ?? 0;
          final cy = double.tryParse(m.group(2)!) ?? 0;
          if (cx > 0 && cy > 0) return cx / cy;
        }
      }
    } catch (_) {}
    return 16 / 9;
  }
}
