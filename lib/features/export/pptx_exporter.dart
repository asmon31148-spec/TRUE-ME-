import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

enum PptxStudyStyle {
  minimalCute,         // Creative Illustrated
  handwrittenNotebook, // Minimal Editorial
  zenPaperInk,         // Professional Scientific
  modernHighYield,     // Infographic Presentation
}

class PptxSlideData {
  final String title;
  final List<String> bulletPoints;
  final String? subtitle;
  final String? tag;
  final String? takeaway;

  const PptxSlideData({
    required this.title,
    required this.bulletPoints,
    this.subtitle,
    this.tag,
    this.takeaway,
  });
}

class PptxExporter {
  PptxExporter._();

  static PptxStudyStyle fromStyleId(String? id) {
    switch ((id ?? '').toLowerCase()) {
      case 'professional_scientific':
      case 'zenpaperink':
        return PptxStudyStyle.zenPaperInk;
      case 'minimal_editorial':
      case 'handwrittennotebook':
        return PptxStudyStyle.handwrittenNotebook;
      case 'infographic_presentation':
      case 'modernhighyield':
        return PptxStudyStyle.modernHighYield;
      case 'creative_illustrated':
      case 'minimalcute':
      default:
        return PptxStudyStyle.minimalCute;
    }
  }

  /// Generates a 16:9 widescreen OpenXML PowerPoint (.pptx) presentation
  /// with 4 distinct slide design systems and adaptive non-clipping layouts.
  static Uint8List createPresentation({
    required String presentationTitle,
    required List<PptxSlideData> slides,
    PptxStudyStyle style = PptxStudyStyle.minimalCute,
  }) {
    final archive = Archive();

    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  ${List.generate(slides.length, (i) => '<Override PartName="/ppt/slides/slide${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>').join('\n  ')}
</Types>''';
    archive.addFile(_createArchiveFile('[Content_Types].xml', contentTypesXml));

    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
    archive.addFile(_createArchiveFile('_rels/.rels', rootRelsXml));

    final slideIdList = List.generate(
      slides.length,
      (i) => '<p:sldId id="${256 + i}" r:id="rId${i + 2}"/>',
    ).join('');

    // 16:9 widescreen: 12192000 x 6858000 EMU (13.333" x 7.5")
    final presentationXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
  <p:sldIdLst>$slideIdList</p:sldIdLst>
  <p:sldSz cx="12192000" cy="6858000"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''';
    archive.addFile(_createArchiveFile('ppt/presentation.xml', presentationXml));

    final presRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
  ${List.generate(slides.length, (i) => '<Relationship Id="rId${i + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i + 1}.xml"/>').join('\n  ')}
</Relationships>''';
    archive.addFile(_createArchiveFile('ppt/_rels/presentation.xml.rels', presRelsXml));

    archive.addFile(_createArchiveFile('ppt/theme/theme1.xml', _buildThemeXml(style)));

    const slideMasterXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
</p:sldMaster>''';
    archive.addFile(_createArchiveFile('ppt/slideMasters/slideMaster1.xml', slideMasterXml));

    const slideMasterRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>''';
    archive.addFile(_createArchiveFile('ppt/slideMasters/_rels/slideMaster1.xml.rels', slideMasterRelsXml));

    const slideLayoutXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
  <p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld>
</p:sldLayout>''';
    archive.addFile(_createArchiveFile('ppt/slideLayouts/slideLayout1.xml', slideLayoutXml));

    const slideLayoutRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''';
    archive.addFile(_createArchiveFile('ppt/slideLayouts/_rels/slideLayout1.xml.rels', slideLayoutRelsXml));

    for (int i = 0; i < slides.length; i++) {
      final slideXml = _buildSlideXml(slides[i], i, slides.length, presentationTitle, style);
      archive.addFile(_createArchiveFile('ppt/slides/slide${i + 1}.xml', slideXml));
      const slideRelXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''';
      archive.addFile(_createArchiveFile('ppt/slides/_rels/slide${i + 1}.xml.rels', slideRelXml));
    }

    final encoder = ZipEncoder();
    final outputBytes = encoder.encode(archive);
    return Uint8List.fromList(outputBytes!);
  }

  static String _buildSlideXml(
    PptxSlideData s,
    int index,
    int totalSlides,
    String deckTitle,
    PptxStudyStyle style,
  ) {
    final safeBullets = s.bulletPoints.isNotEmpty ? s.bulletPoints : ['Key concept summary'];
    final tagText = (s.tag != null && s.tag!.trim().isNotEmpty)
        ? s.tag!.trim()
        : 'SLIDE ${index + 1}/$totalSlides';

    // Adaptive font size so dense slides never clip
    final totalChars = safeBullets.fold<int>(0, (sum, b) => sum + b.length);
    final bodySz = totalChars > 420 ? '1300' : (totalChars > 240 ? '1450' : '1600');

    switch (style) {
      case PptxStudyStyle.minimalCute:
        // Creative Illustrated (16:9 Pastel Sakura & Lavender)
        return _renderStructured16x9Slide(
          bgHex: 'FDF2F8',
          cardHex: 'FFFFFF',
          cardBorderHex: 'FBCFE8',
          accentHex: 'DB2777',
          titleHex: '831843',
          bodyHex: '374151',
          badgeBgHex: 'FCE7F3',
          badgeText: tagText,
          title: s.title,
          bullets: safeBullets,
          bulletGlyph: '•  ',
          bodySz: bodySz,
          takeaway: s.takeaway,
          footerText: 'True Me • Creative Illustrated • ${_escapeXml(deckTitle)} (${index + 1}/$totalSlides)',
        );

      case PptxStudyStyle.zenPaperInk:
        // Professional Scientific (16:9 Clean Navy & Slate)
        return _renderStructured16x9Slide(
          bgHex: 'F8FAFC',
          cardHex: 'FFFFFF',
          cardBorderHex: 'CBD5E1',
          accentHex: '1E3A8A',
          titleHex: '0F172A',
          bodyHex: '1E293B',
          badgeBgHex: 'DBEAFE',
          badgeText: tagText,
          title: s.title,
          bullets: safeBullets,
          bulletGlyph: '▪  ',
          bodySz: bodySz,
          takeaway: s.takeaway,
          footerText: 'True Me • Professional Scientific • ${_escapeXml(deckTitle)} (${index + 1}/$totalSlides)',
        );

      case PptxStudyStyle.handwrittenNotebook:
        // Minimal Editorial (16:9 Warm Ivory & Generous Whitespace)
        return _renderStructured16x9Slide(
          bgHex: 'FDFBF7',
          cardHex: 'FFFFFF',
          cardBorderHex: 'E7E5E4',
          accentHex: '7C3AED',
          titleHex: '1C1917',
          bodyHex: '292524',
          badgeBgHex: 'F5F3FF',
          badgeText: tagText,
          title: s.title,
          bullets: safeBullets,
          bulletGlyph: '—  ',
          bodySz: bodySz,
          takeaway: s.takeaway,
          footerText: 'True Me • Minimal Editorial • ${_escapeXml(deckTitle)} (${index + 1}/$totalSlides)',
        );

      case PptxStudyStyle.modernHighYield:
        // Infographic Presentation (16:9 Dark Slate & Neon Cyan Cards)
        return _renderStructured16x9Slide(
          bgHex: '0F172A',
          cardHex: '1E293B',
          cardBorderHex: '334155',
          accentHex: '22D3EE',
          titleHex: 'F8FAFC',
          bodyHex: 'E2E8F0',
          badgeBgHex: '083344',
          badgeText: tagText,
          title: s.title,
          bullets: safeBullets,
          bulletGlyph: '▸  ',
          bodySz: bodySz,
          takeaway: s.takeaway,
          footerText: 'True Me • Infographic Presentation • ${_escapeXml(deckTitle)} (${index + 1}/$totalSlides)',
        );
    }
  }

  static String _renderStructured16x9Slide({
    required String bgHex,
    required String cardHex,
    required String cardBorderHex,
    required String accentHex,
    required String titleHex,
    required String bodyHex,
    required String badgeBgHex,
    required String badgeText,
    required String title,
    required List<String> bullets,
    required String bulletGlyph,
    required String bodySz,
    String? takeaway,
    required String footerText,
  }) {
    final bulletLinesXml = bullets.map((b) {
      return '''<a:p>
        <a:pPr marL="288000" indent="-288000"/>
        <a:r><a:rPr lang="en-US" sz="$bodySz" b="1"><a:solidFill><a:srgbClr val="$accentHex"/></a:solidFill></a:rPr><a:t>$bulletGlyph</a:t></a:r>
        <a:r><a:rPr lang="en-US" sz="$bodySz"><a:solidFill><a:srgbClr val="$bodyHex"/></a:solidFill></a:rPr><a:t>${_escapeXml(b)}</a:t></a:r>
      </a:p>
      <a:p><a:endParaRPr sz="500"/></a:p>''';
    }).join('');

    final hasTakeaway = takeaway != null && takeaway.trim().isNotEmpty;
    final bodyWidth = hasTakeaway ? '7300000' : '10300000';

    final takeawayXml = hasTakeaway
        ? '''<p:sp>
        <p:nvSpPr><p:cNvPr id="7" name="Takeaway"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="8450000" y="1950000"/><a:ext cx="2850000" cy="3900000"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 3500"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="$badgeBgHex"/></a:solidFill>
          <a:ln w="12700"><a:solidFill><a:srgbClr val="$accentHex"/></a:solidFill></a:ln>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square" lIns="140000" rIns="140000" tIns="140000" bIns="140000"/>
          <a:lstStyle/>
          <a:p><a:r><a:rPr lang="en-US" sz="1200" b="1"><a:solidFill><a:srgbClr val="$accentHex"/></a:solidFill></a:rPr><a:t>KEY TAKEAWAY</a:t></a:r></a:p>
          <a:p><a:endParaRPr sz="400"/></a:p>
          <a:p><a:r><a:rPr lang="en-US" sz="1300"><a:solidFill><a:srgbClr val="$bodyHex"/></a:solidFill></a:rPr><a:t>${_escapeXml(takeaway.trim())}</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>'''
        : '';

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg><p:bgPr><a:solidFill><a:srgbClr val="$bgHex"/></a:solidFill></p:bgPr></p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>

      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Card"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="0" y="0"/><a:ext cx="12192000" cy="6858000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
          <a:solidFill><a:srgbClr val="$cardHex"/></a:solidFill>
          <a:ln w="12700"><a:solidFill><a:srgbClr val="$cardBorderHex"/></a:solidFill></a:ln>
        </p:spPr>
      </p:sp>

      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Badge"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="880000" y="650000"/><a:ext cx="3000000" cy="340000"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 50000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="$badgeBgHex"/></a:solidFill>
        </p:spPr>
        <p:txBody>
          <a:bodyPr rtlCol="0" anchor="ctr"/>
          <a:lstStyle/>
          <a:p><a:pPr algn="ctr"/><a:r><a:rPr lang="en-US" sz="1000" b="1"><a:solidFill><a:srgbClr val="$accentHex"/></a:solidFill></a:rPr><a:t>${_escapeXml(badgeText)}</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>

      <p:sp>
        <p:nvSpPr><p:cNvPr id="4" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="880000" y="1080000"/><a:ext cx="10400000" cy="720000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square"/><a:lstStyle/>
          <a:p><a:r><a:rPr lang="en-US" sz="2400" b="1"><a:solidFill><a:srgbClr val="$titleHex"/></a:solidFill></a:rPr><a:t>${_escapeXml(title)}</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>

      <p:sp>
        <p:nvSpPr><p:cNvPr id="5" name="Bullets"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="880000" y="1950000"/><a:ext cx="$bodyWidth" cy="3900000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square" normAutofit="1"/><a:lstStyle/>
          $bulletLinesXml
        </p:txBody>
      </p:sp>

      $takeawayXml

      <p:sp>
        <p:nvSpPr><p:cNvPr id="6" name="Footer"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="880000" y="6000000"/><a:ext cx="10400000" cy="280000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p><a:r><a:rPr lang="en-US" sz="900"><a:solidFill><a:srgbClr val="$accentHex"/></a:solidFill></a:rPr><a:t>$footerText</a:t></a:r></p:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
  }

  static String _buildThemeXml(PptxStudyStyle style) {
    String accent1 = '2563EB';
    String accent2 = 'EC4899';
    if (style == PptxStudyStyle.minimalCute) {
      accent1 = 'F472B6';
      accent2 = '8B5CF6';
    } else if (style == PptxStudyStyle.handwrittenNotebook) {
      accent1 = '7C3AED';
      accent2 = '1C1917';
    } else if (style == PptxStudyStyle.zenPaperInk) {
      accent1 = '1E3A8A';
      accent2 = '0F172A';
    } else {
      accent1 = '22D3EE';
      accent2 = '0F172A';
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="TrueMeStyle">
  <a:themeElements>
    <a:clrScheme name="TrueMe">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="111827"/></a:dk2>
      <a:lt2><a:srgbClr val="F6F7F9"/></a:lt2>
      <a:accent1><a:srgbClr val="$accent1"/></a:accent1>
      <a:accent2><a:srgbClr val="$accent2"/></a:accent2>
      <a:accent3><a:srgbClr val="F59E0B"/></a:accent3>
      <a:accent4><a:srgbClr val="EF4444"/></a:accent4>
      <a:accent5><a:srgbClr val="64748B"/></a:accent5>
      <a:accent6><a:srgbClr val="$accent1"/></a:accent6>
      <a:hlink><a:srgbClr val="$accent1"/></a:hlink>
      <a:folHlink><a:srgbClr val="64748B"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="TrueMe">
      <a:majorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
      <a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="TrueMe"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="25400"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="38100"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>
  </a:themeElements>
</a:theme>''';
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
