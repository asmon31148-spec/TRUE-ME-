import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'services/document_layout_validator.dart';

enum PptxStudyStyle {
  minimalCute,         // Pastel Floral (Creative Illustrated)
  modernHighYield,     // Dark Neon (Infographic Presentation)
  zenPaperInk,         // Modern Business (Professional Scientific)
  handwrittenNotebook, // Creative Infographic (Minimal Editorial)
}

class PptxSlideData {
  final String title;
  final List<String> bulletPoints;
  final String? subtitle;
  final String? tag;
  final String? takeaway;
  final List<List<String>>? tableRows;
  final List<String>? processSteps;
  final SlideLayoutKind layoutKind;

  const PptxSlideData({
    required this.title,
    required this.bulletPoints,
    this.subtitle,
    this.tag,
    this.takeaway,
    this.tableRows,
    this.processSteps,
    this.layoutKind = SlideLayoutKind.content,
  });
}

class _PptxThemeSpec {
  final String label;
  final String bgHex;
  final String cardHex;
  final String cardBorderHex;
  final String accentHex;
  final String accent2Hex;
  final String accent3Hex;
  final String titleHex;
  final String bodyHex;
  final String mutedHex;
  final String badgeBgHex;
  final String tableHeaderHex;
  final String tableAltRowHex;
  final String headingFont;
  final String bodyFont;
  final String bulletGlyph;

  const _PptxThemeSpec({
    required this.label,
    required this.bgHex,
    required this.cardHex,
    required this.cardBorderHex,
    required this.accentHex,
    required this.accent2Hex,
    required this.accent3Hex,
    required this.titleHex,
    required this.bodyHex,
    required this.mutedHex,
    required this.badgeBgHex,
    required this.tableHeaderHex,
    required this.tableAltRowHex,
    required this.headingFont,
    required this.bodyFont,
    required this.bulletGlyph,
  });
}

class PptxExporter {
  PptxExporter._();

  static const int slideW = 12192000; // 13.333" (16:9)
  static const int slideH = 6858000;  // 7.5"    (16:9)

  static PptxStudyStyle fromStyleId(String? id) {
    switch ((id ?? '').toLowerCase()) {
      case 'dark_neon':
      case 'infographic_presentation':
      case 'modernhighyield':
        return PptxStudyStyle.modernHighYield;
      case 'modern_business':
      case 'professional_scientific':
      case 'zenpaperink':
        return PptxStudyStyle.zenPaperInk;
      case 'creative_infographic':
      case 'minimal_editorial':
      case 'handwrittennotebook':
        return PptxStudyStyle.handwrittenNotebook;
      case 'pastel_floral':
      case 'creative_illustrated':
      case 'minimalcute':
      default:
        return PptxStudyStyle.minimalCute;
    }
  }

  static _PptxThemeSpec _themeSpecFor(PptxStudyStyle style) {
    switch (style) {
      case PptxStudyStyle.minimalCute:
        return const _PptxThemeSpec(
          label: 'Pastel Floral',
          bgHex: 'FFF7FA',
          cardHex: 'FFFFFF',
          cardBorderHex: 'FBCFE8',
          accentHex: 'DB2777',
          accent2Hex: 'A855F7',
          accent3Hex: '14B8A6',
          titleHex: '831843',
          bodyHex: '374151',
          mutedHex: '9D174D',
          badgeBgHex: 'FCE7F3',
          tableHeaderHex: 'DB2777',
          tableAltRowHex: 'FDF2F8',
          headingFont: 'Georgia',
          bodyFont: 'Trebuchet MS',
          bulletGlyph: '✿  ',
        );
      case PptxStudyStyle.modernHighYield:
        return const _PptxThemeSpec(
          label: 'Dark Neon',
          bgHex: '090E1C',
          cardHex: '131C35',
          cardBorderHex: '25335A',
          accentHex: '22D3EE',
          accent2Hex: 'E879F9',
          accent3Hex: '38BDF8',
          titleHex: 'F8FAFC',
          bodyHex: 'E2E8F0',
          mutedHex: '94A3B8',
          badgeBgHex: '0E293B',
          tableHeaderHex: '0891B2',
          tableAltRowHex: '1A2542',
          headingFont: 'Segoe UI',
          bodyFont: 'Segoe UI',
          bulletGlyph: '▸  ',
        );
      case PptxStudyStyle.zenPaperInk:
        return const _PptxThemeSpec(
          label: 'Modern Business',
          bgHex: 'F8FAFC',
          cardHex: 'FFFFFF',
          cardBorderHex: 'CBD5E1',
          accentHex: '1D4ED8',
          accent2Hex: '0F172A',
          accent3Hex: '0284C7',
          titleHex: '0F172A',
          bodyHex: '1E293B',
          mutedHex: '475569',
          badgeBgHex: 'DBEAFE',
          tableHeaderHex: '1E3A8A',
          tableAltRowHex: 'EFF6FF',
          headingFont: 'Calibri',
          bodyFont: 'Calibri',
          bulletGlyph: '▪  ',
        );
      case PptxStudyStyle.handwrittenNotebook:
        return const _PptxThemeSpec(
          label: 'Creative Infographic',
          bgHex: 'F0F9FF',
          cardHex: 'FFFFFF',
          cardBorderHex: 'BAE6FD',
          accentHex: '0284C7',
          accent2Hex: 'F59E0B',
          accent3Hex: '6366F1',
          titleHex: '0C4A6E',
          bodyHex: '1E293B',
          mutedHex: '0369A1',
          badgeBgHex: 'E0F2FE',
          tableHeaderHex: '0284C7',
          tableAltRowHex: 'F0F9FF',
          headingFont: 'Segoe UI',
          bodyFont: 'Segoe UI',
          bulletGlyph: '●  ',
        );
    }
  }

  /// Generates a 16:9 widescreen OpenXML PowerPoint (.pptx) presentation
  /// with 4 distinct visual design systems, 6 smart layouts (Cover, Flowchart,
  /// Table, Two-Column, Bento Grid, Content), and automated layout optimization.
  static Uint8List createPresentation({
    required String presentationTitle,
    required List<PptxSlideData> slides,
    PptxStudyStyle style = PptxStudyStyle.minimalCute,
    Uint8List? backgroundImageBytes,
  }) {
    final validated = DocumentLayoutValidator.validateAndOptimizeSlides(slides);
    final effectiveSlides = validated.slides.isNotEmpty ? validated.slides : slides;
    final spec = _themeSpecFor(style);
    final archive = Archive();
    final hasBgImage = backgroundImageBytes != null && backgroundImageBytes.isNotEmpty;

    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-officedocument.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  ${hasBgImage ? '<Default Extension="png" ContentType="image/png"/>' : ''}
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  ${List.generate(effectiveSlides.length, (i) => '<Override PartName="/ppt/slides/slide${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>').join('\n  ')}
</Types>''';
    archive.addFile(_createArchiveFile('[Content_Types].xml', contentTypesXml));

    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
    archive.addFile(_createArchiveFile('_rels/.rels', rootRelsXml));

    final slideIdList = List.generate(
      effectiveSlides.length,
      (i) => '<p:sldId id="${256 + i}" r:id="rId${i + 2}"/>',
    ).join('');

    final presentationXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
  <p:sldIdLst>$slideIdList</p:sldIdLst>
  <p:sldSz cx="$slideW" cy="$slideH"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''';
    archive.addFile(_createArchiveFile('ppt/presentation.xml', presentationXml));

    final presRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
  ${List.generate(effectiveSlides.length, (i) => '<Relationship Id="rId${i + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i + 1}.xml"/>').join('\n  ')}
</Relationships>''';
    archive.addFile(_createArchiveFile('ppt/_rels/presentation.xml.rels', presRelsXml));

    archive.addFile(_createArchiveFile('ppt/theme/theme1.xml', _buildThemeXml(spec)));

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

    if (hasBgImage) {
      archive.addFile(
        ArchiveFile('ppt/media/theme_bg.png', backgroundImageBytes.length, backgroundImageBytes),
      );
    }

    for (int i = 0; i < effectiveSlides.length; i++) {
      final slideXml = _buildSlideXml(
        effectiveSlides[i],
        i,
        effectiveSlides.length,
        presentationTitle,
        style,
        spec,
        hasBgImage: hasBgImage,
      );
      archive.addFile(_createArchiveFile('ppt/slides/slide${i + 1}.xml', slideXml));
      final slideRelXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  ${hasBgImage ? '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/theme_bg.png"/>' : ''}
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
    _PptxThemeSpec spec, {
    bool hasBgImage = false,
  }) {
    final tagText = (s.tag != null && s.tag!.trim().isNotEmpty)
        ? s.tag!.trim()
        : 'SLIDE ${index + 1}/$totalSlides';
    final footerText = 'TRUE ME · ${spec.label} · ${_escapeXml(deckTitle)} (${index + 1}/$totalSlides)';

    final bgPicXml = hasBgImage
        ? '''<p:pic>
        <p:nvPicPr><p:cNvPr id="89" name="ThemeBg"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>
        <p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
        <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$slideW" cy="$slideH"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>
      </p:pic>'''
        : '';
    final decorXml = hasBgImage
        ? bgPicXml
        : _buildThemeDecor(style, spec, isCover: s.layoutKind == SlideLayoutKind.cover);
    final String bodyXml;

    switch (s.layoutKind) {
      case SlideLayoutKind.cover:
        bodyXml = _buildCoverBody(s, spec);
        break;
      case SlideLayoutKind.flowchart:
        bodyXml = _buildFlowchartBody(s, spec, tagText, footerText);
        break;
      case SlideLayoutKind.table:
        bodyXml = _buildTableBody(s, spec, tagText, footerText);
        break;
      case SlideLayoutKind.twoColumn:
        bodyXml = _buildTwoColumnBody(s, spec, tagText, footerText);
        break;
      case SlideLayoutKind.bentoGrid:
        bodyXml = _buildBentoGridBody(s, spec, tagText, footerText);
        break;
      case SlideLayoutKind.content:
        bodyXml = _buildStandardContentBody(s, spec, tagText, footerText);
        break;
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg><p:bgPr><a:solidFill><a:srgbClr val="${spec.bgHex}"/></a:solidFill></p:bgPr></p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      $decorXml
      $bodyXml
    </p:spTree>
  </p:cSld>
</p:sld>''';
  }

  static String _buildThemeDecor(
    PptxStudyStyle style,
    _PptxThemeSpec spec, {
    required bool isCover,
  }) {
    switch (style) {
      case PptxStudyStyle.minimalCute:
        // Pastel Floral: soft corner botanical circles & top accent ribbon
        return '''
        <p:sp>
          <p:nvSpPr><p:cNvPr id="90" name="Decor1"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="-650000" y="-650000"/><a:ext cx="2300000" cy="2300000"/></a:xfrm>
            <a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>
            <a:solidFill><a:srgbClr val="FCE7F3"/></a:solidFill>
          </p:spPr>
        </p:sp>
        <p:sp>
          <p:nvSpPr><p:cNvPr id="91" name="Decor2"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="10600000" y="5100000"/><a:ext cx="2400000" cy="2400000"/></a:xfrm>
            <a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>
            <a:solidFill><a:srgbClr val="EDE9FE"/></a:solidFill>
          </p:spPr>
        </p:sp>
        <p:sp>
          <p:nvSpPr><p:cNvPr id="92" name="Decor3"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="11200000" y="-400000"/><a:ext cx="1400000" cy="1400000"/></a:xfrm>
            <a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>
            <a:solidFill><a:srgbClr val="CCFBF1"/></a:solidFill>
          </p:spPr>
        </p:sp>''';

      case PptxStudyStyle.modernHighYield:
        // Dark Neon: glowing neon corner orbs & top cyan/magenta neon strip
        return '''
        <p:sp>
          <p:nvSpPr><p:cNvPr id="90" name="NeonTop"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="0" y="0"/><a:ext cx="$slideW" cy="85000"/></a:xfrm>
            <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
            <a:solidFill><a:srgbClr val="${spec.accentHex}"/></a:solidFill>
          </p:spPr>
        </p:sp>
        <p:sp>
          <p:nvSpPr><p:cNvPr id="91" name="Orb1"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="9800000" y="-900000"/><a:ext cx="3200000" cy="3200000"/></a:xfrm>
            <a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>
            <a:solidFill><a:srgbClr val="1E1B4B"/></a:solidFill>
            <a:ln w="19050"><a:solidFill><a:srgbClr val="${spec.accent2Hex}"/></a:solidFill></a:ln>
          </p:spPr>
        </p:sp>
        <p:sp>
          <p:nvSpPr><p:cNvPr id="92" name="Orb2"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="-700000" y="5300000"/><a:ext cx="2100000" cy="2100000"/></a:xfrm>
            <a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>
            <a:solidFill><a:srgbClr val="083344"/></a:solidFill>
            <a:ln w="12700"><a:solidFill><a:srgbClr val="${spec.accentHex}"/></a:solidFill></a:ln>
          </p:spPr>
        </p:sp>''';

      case PptxStudyStyle.zenPaperInk:
        // Modern Business: bold corporate blue left rail & right geometric accent
        final sideW = isCover ? '3400000' : '220000';
        return '''
        <p:sp>
          <p:nvSpPr><p:cNvPr id="90" name="CorpBar"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="0" y="0"/><a:ext cx="$sideW" cy="$slideH"/></a:xfrm>
            <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
            <a:solidFill><a:srgbClr val="${spec.accentHex}"/></a:solidFill>
          </p:spPr>
        </p:sp>
        <p:sp>
          <p:nvSpPr><p:cNvPr id="91" name="CorpAccent"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="$sideW" y="0"/><a:ext cx="70000" cy="$slideH"/></a:xfrm>
            <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
            <a:solidFill><a:srgbClr val="${spec.accent3Hex}"/></a:solidFill>
          </p:spPr>
        </p:sp>''';

      case PptxStudyStyle.handwrittenNotebook:
        // Creative Infographic: vibrant sky-blue top banner & warm amber accent bar
        final bannerH = isCover ? '2400000' : '1150000';
        return '''
        <p:sp>
          <p:nvSpPr><p:cNvPr id="90" name="InfoBanner"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="0" y="0"/><a:ext cx="$slideW" cy="$bannerH"/></a:xfrm>
            <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
            <a:solidFill><a:srgbClr val="${spec.accentHex}"/></a:solidFill>
          </p:spPr>
        </p:sp>
        <p:sp>
          <p:nvSpPr><p:cNvPr id="91" name="InfoGold"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="0" y="$bannerH"/><a:ext cx="$slideW" cy="65000"/></a:xfrm>
            <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
            <a:solidFill><a:srgbClr val="${spec.accent2Hex}"/></a:solidFill>
          </p:spPr>
        </p:sp>''';
    }
  }

  static String _buildCoverBody(PptxSlideData s, _PptxThemeSpec spec) {
    final isInfoBanner = spec.label == 'Creative Infographic';
    final isCorpLeft = spec.label == 'Modern Business';
    final leftX = isCorpLeft ? 3900000 : 880000;
    final boxW = isCorpLeft ? 7500000 : 10432000;
    final titleColor = isInfoBanner ? 'FFFFFF' : spec.titleHex;
    final subColor = isInfoBanner ? 'E0F2FE' : spec.mutedHex;

    final objectives = s.bulletPoints.take(3).toList();
    final objCardsXml = StringBuffer();
    if (objectives.isNotEmpty) {
      final cardCount = objectives.length;
      final gap = 240000;
      final cardW = ((boxW - gap * (cardCount - 1)) / cardCount).round();
      for (int i = 0; i < cardCount; i++) {
        final cx = leftX + i * (cardW + gap);
        objCardsXml.write('''
        <p:sp>
          <p:nvSpPr><p:cNvPr id="${20 + i}" name="ObjCard$i"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="$cx" y="4250000"/><a:ext cx="$cardW" cy="1750000"/></a:xfrm>
            <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 6000"/></a:avLst></a:prstGeom>
            <a:solidFill><a:srgbClr val="${spec.cardHex}"/></a:solidFill>
            <a:ln w="12700"><a:solidFill><a:srgbClr val="${spec.cardBorderHex}"/></a:solidFill></a:ln>
          </p:spPr>
          <p:txBody>
            <a:bodyPr wrap="square" lIns="160000" rIns="160000" tIns="150000" bIns="140000"/>
            <a:lstStyle/>
            <a:p><a:r><a:rPr lang="en-US" sz="1100" b="1"><a:latin typeface="${spec.headingFont}"/><a:solidFill><a:srgbClr val="${spec.accentHex}"/></a:solidFill></a:rPr><a:t>FOCUS 0${i + 1}</a:t></a:r></a:p>
            <a:p><a:endParaRPr sz="400"/></a:p>
            <a:p><a:r><a:rPr lang="en-US" sz="1300"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="${spec.bodyHex}"/></a:solidFill></a:rPr><a:t>${_escapeXml(objectives[i])}</a:t></a:r></a:p>
          </p:txBody>
        </p:sp>''');
      }
    }

    return '''
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Badge"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="$leftX" y="550000"/><a:ext cx="3100000" cy="360000"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 50000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="${spec.badgeBgHex}"/></a:solidFill>
        </p:spPr>
        <p:txBody>
          <a:bodyPr anchor="ctr"/><a:lstStyle/>
          <a:p><a:pPr algn="ctr"/><a:r><a:rPr lang="en-US" sz="1100" b="1"><a:latin typeface="${spec.headingFont}"/><a:solidFill><a:srgbClr val="${spec.accentHex}"/></a:solidFill></a:rPr><a:t>${_escapeXml(spec.label.toUpperCase())}</a:t></a:r></p:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="4" name="CoverTitle"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="$leftX" y="1020000"/><a:ext cx="$boxW" cy="1150000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square" normAutofit="1"/><a:lstStyle/>
          <a:p><a:r><a:rPr lang="en-US" sz="3400" b="1"><a:latin typeface="${spec.headingFont}"/><a:solidFill><a:srgbClr val="$titleColor"/></a:solidFill></a:rPr><a:t>${_escapeXml(s.title)}</a:t></a:r></p:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="5" name="CoverSubtitle"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="$leftX" y="2650000"/><a:ext cx="$boxW" cy="600000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square"/><a:lstStyle/>
          <a:p><a:r><a:rPr lang="en-US" sz="1800"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="$subColor"/></a:solidFill></a:rPr><a:t>${_escapeXml(s.subtitle ?? 'Structured Study Presentation')}</a:t></a:r></p:p>
        </p:txBody>
      </p:sp>
      $objCardsXml''';
  }

  static String _buildHeaderAndFooter(
    PptxSlideData s,
    _PptxThemeSpec spec,
    String tagText,
    String footerText,
  ) {
    final isInfoBanner = spec.label == 'Creative Infographic';
    final titleColor = isInfoBanner ? 'FFFFFF' : spec.titleHex;
    final titleY = isInfoBanner ? 420000 : 620000;
    final badgeY = isInfoBanner ? 110000 : 240000;

    return '''
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Badge"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="680000" y="$badgeY"/><a:ext cx="2400000" cy="300000"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 50000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="${spec.badgeBgHex}"/></a:solidFill>
        </p:spPr>
        <p:txBody>
          <a:bodyPr anchor="ctr"/><a:lstStyle/>
          <a:p><a:pPr algn="ctr"/><a:r><a:rPr lang="en-US" sz="1000" b="1"><a:latin typeface="${spec.headingFont}"/><a:solidFill><a:srgbClr val="${spec.accentHex}"/></a:solidFill></a:rPr><a:t>${_escapeXml(tagText)}</a:t></a:r></p:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="4" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="680000" y="$titleY"/><a:ext cx="10832000" cy="660000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square" normAutofit="1"/><a:lstStyle/>
          <a:p><a:r><a:rPr lang="en-US" sz="2400" b="1"><a:latin typeface="${spec.headingFont}"/><a:solidFill><a:srgbClr val="$titleColor"/></a:solidFill></a:rPr><a:t>${_escapeXml(s.title)}</a:t></a:r></p:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="6" name="Footer"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="680000" y="6380000"/><a:ext cx="10832000" cy="260000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p><a:r><a:rPr lang="en-US" sz="950"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="${spec.mutedHex}"/></a:solidFill></a:rPr><a:t>$footerText</a:t></a:r></p:p>
        </p:txBody>
      </p:sp>''';
  }

  static String _buildFlowchartBody(
    PptxSlideData s,
    _PptxThemeSpec spec,
    String tagText,
    String footerText,
  ) {
    final steps = s.processSteps ?? const [];
    final buf = StringBuffer();
    buf.write(_buildHeaderAndFooter(s, spec, tagText, footerText));

    if (steps.isNotEmpty) {
      final cols = steps.length <= 3 ? steps.length : 3;
      final rows = (steps.length / cols).ceil();
      const startX = 680000;
      const totalW = 10832000;
      const arrowW = 360000;
      const gapW = 90000;
      final nodeW = ((totalW - (cols - 1) * (arrowW + gapW * 2)) / cols).round();
      final startY = rows == 1 ? 2300000 : 1650000;
      final nodeH = rows == 1 ? 2600000 : 1950000;
      const rowGap = 420000;

      for (int i = 0; i < steps.length; i++) {
        final r = i ~/ cols;
        final c = i % cols;
        final x = startX + c * (nodeW + arrowW + gapW * 2);
        final y = startY + r * (nodeH + rowGap);
        final stepAccent = i.isEven ? spec.accentHex : spec.accent2Hex;

        buf.write('''
        <p:sp>
          <p:nvSpPr><p:cNvPr id="${30 + i * 2}" name="FlowNode$i"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
          <p:spPr>
            <a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$nodeW" cy="$nodeH"/></a:xfrm>
            <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 6000"/></a:avLst></a:prstGeom>
            <a:solidFill><a:srgbClr val="${spec.cardHex}"/></a:solidFill>
            <a:ln w="19050"><a:solidFill><a:srgbClr val="$stepAccent"/></a:solidFill></a:ln>
          </p:spPr>
          <p:txBody>
            <a:bodyPr wrap="square" lIns="160000" rIns="160000" tIns="150000" bIns="140000" normAutofit="1"/>
            <a:lstStyle/>
            <a:p><a:r><a:rPr lang="en-US" sz="1200" b="1"><a:latin typeface="${spec.headingFont}"/><a:solidFill><a:srgbClr val="$stepAccent"/></a:solidFill></a:rPr><a:t>STEP ${i + 1}</a:t></a:r></p:p>
            <a:p><a:endParaRPr sz="400"/></a:p>
            <a:p><a:r><a:rPr lang="en-US" sz="1450"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="${spec.bodyHex}"/></a:solidFill></a:rPr><a:t>${_escapeXml(steps[i])}</a:t></a:r></p:p>
          </p:txBody>
        </p:sp>''');

        // Draw directional arrow to next node in row
        if (c < cols - 1 && i < steps.length - 1) {
          final ax = x + nodeW + gapW;
          final ay = y + (nodeH ~/ 2) - 160000;
          buf.write('''
          <p:sp>
            <p:nvSpPr><p:cNvPr id="${31 + i * 2}" name="Arrow$i"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
            <p:spPr>
              <a:xfrm><a:off x="$ax" y="$ay"/><a:ext cx="$arrowW" cy="320000"/></a:xfrm>
              <a:prstGeom prst="rightArrow"><a:avLst/></a:prstGeom>
              <a:solidFill><a:srgbClr val="${spec.accentHex}"/></a:solidFill>
            </p:spPr>
          </p:sp>''');
        }
      }
    }

    return buf.toString();
  }

  static String _buildTableBody(
    PptxSlideData s,
    _PptxThemeSpec spec,
    String tagText,
    String footerText,
  ) {
    final rows = s.tableRows ?? const [];
    final buf = StringBuffer();
    buf.write(_buildHeaderAndFooter(s, spec, tagText, footerText));
    if (rows.isEmpty) return buf.toString();

    final colCount = rows.first.length.clamp(1, 8);
    const tblW = 10832000;
    final colW = (tblW / colCount).round();
    final rowH = (4400000 / rows.length).round().clamp(420000, 760000);

    final gridCols = List.generate(colCount, (_) => '<a:gridCol w="$colW"/>').join('');
    final trXml = StringBuffer();
    for (int r = 0; r < rows.length; r++) {
      final isHeader = r == 0;
      final fill = isHeader
          ? spec.tableHeaderHex
          : (r.isOdd ? spec.cardHex : spec.tableAltRowHex);
      final textHex = isHeader ? 'FFFFFF' : spec.bodyHex;
      final cells = StringBuffer();
      for (int c = 0; c < colCount; c++) {
        final cellText = c < rows[r].length ? rows[r][c] : '';
        cells.write('''
        <a:tc>
          <a:txBody>
            <a:bodyPr anchor="ctr" lIns="100000" rIns="100000" tIns="60000" bIns="60000"/>
            <a:lstStyle/>
            <a:p><a:r><a:rPr lang="en-US" sz="${isHeader ? '1350' : '1250'}" b="${isHeader ? '1' : '0'}"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="$textHex"/></a:solidFill></a:rPr><a:t>${_escapeXml(cellText)}</a:t></a:r></p:p>
          </a:txBody>
          <a:tcPr>
            <a:solidFill><a:srgbClr val="$fill"/></a:solidFill>
            <a:lnL w="6350"><a:solidFill><a:srgbClr val="${spec.cardBorderHex}"/></a:solidFill></a:lnL>
            <a:lnR w="6350"><a:solidFill><a:srgbClr val="${spec.cardBorderHex}"/></a:solidFill></a:lnR>
            <a:lnT w="6350"><a:solidFill><a:srgbClr val="${spec.cardBorderHex}"/></a:solidFill></a:lnT>
            <a:lnB w="6350"><a:solidFill><a:srgbClr val="${spec.cardBorderHex}"/></a:solidFill></a:lnB>
          </a:tcPr>
        </a:tc>''');
      }
      trXml.write('<a:tr h="$rowH">$cells</a:tr>');
    }

    buf.write('''
      <p:graphicFrame>
        <p:nvGraphicFramePr><p:cNvPr id="40" name="ComparisonTable"/><p:cNvGraphicFramePr><a:graphicFrameLocks noGrp="1"/></p:cNvGraphicFramePr><p:nvPr/></p:nvGraphicFramePr>
        <p:xfrm><a:off x="680000" y="1550000"/><a:ext cx="$tblW" cy="${rowH * rows.length}"/></p:xfrm>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">
            <a:tbl>
              <a:tblPr firstRow="1" bandRow="1"/>
              <a:tblGrid>$gridCols</a:tblGrid>
              $trXml
            </a:tbl>
          </a:graphicData>
        </a:graphic>
      </p:graphicFrame>''');

    return buf.toString();
  }

  static String _buildTwoColumnBody(
    PptxSlideData s,
    _PptxThemeSpec spec,
    String tagText,
    String footerText,
  ) {
    final bullets = s.bulletPoints.isNotEmpty ? s.bulletPoints : const ['Key concept summary'];
    final totalChars = bullets.fold<int>(0, (sum, b) => sum + b.length);
    final bodySz = totalChars > 260 ? '1400' : '1550';

    final bulletLinesXml = bullets.map((b) {
      return '''<a:p>
        <a:pPr marL="288000" indent="-288000"/>
        <a:r><a:rPr lang="en-US" sz="$bodySz" b="1"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="${spec.accentHex}"/></a:solidFill></a:rPr><a:t>${spec.bulletGlyph}</a:t></a:r>
        <a:r><a:rPr lang="en-US" sz="$bodySz"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="${spec.bodyHex}"/></a:solidFill></a:rPr><a:t>${_escapeXml(b)}</a:t></a:r>
      </a:p>
      <a:p><a:endParaRPr sz="450"/></a:p>''';
    }).join('');

    final takeawayText = (s.takeaway ?? '').trim();

    return '''
      ${_buildHeaderAndFooter(s, spec, tagText, footerText)}
      <p:sp>
        <p:nvSpPr><p:cNvPr id="5" name="MainCard"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="680000" y="1550000"/><a:ext cx="6850000" cy="4500000"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 4000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="${spec.cardHex}"/></a:solidFill>
          <a:ln w="12700"><a:solidFill><a:srgbClr val="${spec.cardBorderHex}"/></a:solidFill></a:ln>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square" lIns="220000" rIns="220000" tIns="200000" bIns="180000" normAutofit="1"/>
          <a:lstStyle/>
          $bulletLinesXml
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="7" name="Takeaway"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="7800000" y="1550000"/><a:ext cx="3712000" cy="4500000"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 5000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="${spec.badgeBgHex}"/></a:solidFill>
          <a:ln w="19050"><a:solidFill><a:srgbClr val="${spec.accent2Hex}"/></a:solidFill></a:ln>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square" lIns="200000" rIns="200000" tIns="220000" bIns="200000" normAutofit="1"/>
          <a:lstStyle/>
          <a:p><a:r><a:rPr lang="en-US" sz="1300" b="1"><a:latin typeface="${spec.headingFont}"/><a:solidFill><a:srgbClr val="${spec.accent2Hex}"/></a:solidFill></a:rPr><a:t>KEY TAKEAWAY</a:t></a:r></a:p>
          <a:p><a:endParaRPr sz="500"/></a:p>
          <a:p><a:r><a:rPr lang="en-US" sz="1500"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="${spec.bodyHex}"/></a:solidFill></a:rPr><a:t>${_escapeXml(takeawayText)}</a:t></a:r></p:p>
        </p:txBody>
      </p:sp>''';
  }

  static String _buildBentoGridBody(
    PptxSlideData s,
    _PptxThemeSpec spec,
    String tagText,
    String footerText,
  ) {
    final bullets = s.bulletPoints.take(4).toList();
    final buf = StringBuffer();
    buf.write(_buildHeaderAndFooter(s, spec, tagText, footerText));

    const startX = 680000;
    const startY = 1550000;
    const totalW = 10832000;
    const totalH = 4500000;
    const gap = 240000;
    final cardW = ((totalW - gap) / 2).round();
    final cardH = bullets.length <= 2 ? totalH : ((totalH - gap) / 2).round();

    for (int i = 0; i < bullets.length; i++) {
      final r = i ~/ 2;
      final c = i % 2;
      final x = startX + c * (cardW + gap);
      final y = startY + r * (cardH + gap);
      final cardAccent = i == 0
          ? spec.accentHex
          : (i == 1 ? spec.accent2Hex : (i == 2 ? spec.accent3Hex : spec.accentHex));

      buf.write('''
      <p:sp>
        <p:nvSpPr><p:cNvPr id="${50 + i}" name="Bento$i"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$cardW" cy="$cardH"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 5000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="${spec.cardHex}"/></a:solidFill>
          <a:ln w="15875"><a:solidFill><a:srgbClr val="$cardAccent"/></a:solidFill></a:ln>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square" lIns="200000" rIns="200000" tIns="180000" bIns="160000" normAutofit="1"/>
          <a:lstStyle/>
          <a:p><a:r><a:rPr lang="en-US" sz="1200" b="1"><a:latin typeface="${spec.headingFont}"/><a:solidFill><a:srgbClr val="$cardAccent"/></a:solidFill></a:rPr><a:t>POINT 0${i + 1}</a:t></a:r></p:p>
          <a:p><a:endParaRPr sz="400"/></a:p>
          <a:p><a:r><a:rPr lang="en-US" sz="1500"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="${spec.bodyHex}"/></a:solidFill></a:rPr><a:t>${_escapeXml(bullets[i])}</a:t></a:r></p:p>
        </p:txBody>
      </p:sp>''');
    }

    return buf.toString();
  }

  static String _buildStandardContentBody(
    PptxSlideData s,
    _PptxThemeSpec spec,
    String tagText,
    String footerText,
  ) {
    final bullets = s.bulletPoints.isNotEmpty ? s.bulletPoints : const ['Key concept summary'];
    final totalChars = bullets.fold<int>(0, (sum, b) => sum + b.length);
    final bodySz = totalChars > 300 ? '1450' : '1650';

    final bulletLinesXml = bullets.map((b) {
      return '''<a:p>
        <a:pPr marL="300000" indent="-300000"/>
        <a:r><a:rPr lang="en-US" sz="$bodySz" b="1"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="${spec.accentHex}"/></a:solidFill></a:rPr><a:t>${spec.bulletGlyph}</a:t></a:r>
        <a:r><a:rPr lang="en-US" sz="$bodySz"><a:latin typeface="${spec.bodyFont}"/><a:solidFill><a:srgbClr val="${spec.bodyHex}"/></a:solidFill></a:rPr><a:t>${_escapeXml(b)}</a:t></a:r>
      </a:p>
      <a:p><a:endParaRPr sz="500"/></a:p>''';
    }).join('');

    return '''
      ${_buildHeaderAndFooter(s, spec, tagText, footerText)}
      <p:sp>
        <p:nvSpPr><p:cNvPr id="5" name="ContentCard"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="680000" y="1550000"/><a:ext cx="10832000" cy="4500000"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 3500"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="${spec.cardHex}"/></a:solidFill>
          <a:ln w="12700"><a:solidFill><a:srgbClr val="${spec.cardBorderHex}"/></a:solidFill></a:ln>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square" lIns="260000" rIns="260000" tIns="220000" bIns="200000" normAutofit="1"/>
          <a:lstStyle/>
          $bulletLinesXml
        </p:txBody>
      </p:sp>''';
  }

  static String _buildThemeXml(_PptxThemeSpec spec) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="TrueMe_${_escapeXml(spec.label)}">
  <a:themeElements>
    <a:clrScheme name="TrueMe">
      <a:dk1><a:srgbClr val="${spec.titleHex}"/></a:dk1>
      <a:lt1><a:srgbClr val="${spec.bgHex}"/></a:lt1>
      <a:dk2><a:srgbClr val="${spec.bodyHex}"/></a:dk2>
      <a:lt2><a:srgbClr val="${spec.cardHex}"/></a:lt2>
      <a:accent1><a:srgbClr val="${spec.accentHex}"/></a:accent1>
      <a:accent2><a:srgbClr val="${spec.accent2Hex}"/></a:accent2>
      <a:accent3><a:srgbClr val="${spec.accent3Hex}"/></a:accent3>
      <a:accent4><a:srgbClr val="EF4444"/></a:accent4>
      <a:accent5><a:srgbClr val="${spec.mutedHex}"/></a:accent5>
      <a:accent6><a:srgbClr val="${spec.accentHex}"/></a:accent6>
      <a:hlink><a:srgbClr val="${spec.accentHex}"/></a:hlink>
      <a:folHlink><a:srgbClr val="${spec.mutedHex}"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="TrueMe">
      <a:majorFont><a:latin typeface="${spec.headingFont}"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
      <a:minorFont><a:latin typeface="${spec.bodyFont}"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
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
