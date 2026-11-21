import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

enum PptxStudyStyle {
  minimalCute,       // Study-friendly minimal cute with soft Sakura & Lavender cards, aesthetic pill badges
  handwrittenNotebook, // Cornell notebook lined paper, yellow highlighter bar, sticky notes
  zenPaperInk,       // Japanese Washi parchment, Sumi calligraphy ink, Vermilion Hanko seal
  modernHighYield,   // Executive dark slate & glowing cyan cards
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

  /// Assembles an OpenXML PowerPoint (.pptx) file with selectable study aesthetic styles.
  static Uint8List createPresentation({
    required String presentationTitle,
    required List<PptxSlideData> slides,
    PptxStudyStyle style = PptxStudyStyle.minimalCute,
  }) {
    final archive = Archive();

    // 1. [Content_Types].xml
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

    // 2. _rels/.rels
    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
    archive.addFile(_createArchiveFile('_rels/.rels', rootRelsXml));

    // 3. ppt/presentation.xml
    final slideIdList = List.generate(
      slides.length,
      (i) => '<p:sldId id="${256 + i}" r:id="rId${i + 2}"/>',
    ).join('');

    final presentationXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
  <p:sldIdLst>$slideIdList</p:sldIdLst>
  <p:sldSz cx="9144000" cy="6858000"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''';
    archive.addFile(_createArchiveFile('ppt/presentation.xml', presentationXml));

    // 4. ppt/_rels/presentation.xml.rels
    final presRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
  ${List.generate(slides.length, (i) => '<Relationship Id="rId${i + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i + 1}.xml"/>').join('\n  ')}
</Relationships>''';
    archive.addFile(_createArchiveFile('ppt/_rels/presentation.xml.rels', presRelsXml));

    // 5. Theme XML
    final themeXml = _buildThemeXml(style);
    archive.addFile(_createArchiveFile('ppt/theme/theme1.xml', themeXml));

    // SlideMaster and SlideLayout
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

    // 6. Generate Individual Styled Slides
    for (int i = 0; i < slides.length; i++) {
      final s = slides[i];
      final slideXml = _buildSlideXml(s, i, slides.length, presentationTitle, style);
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

  // ---------------------------------------------------------------------------
  // SLIDE XML BUILDER WITH RICH STYLES
  // ---------------------------------------------------------------------------
  static String _buildSlideXml(
    PptxSlideData s,
    int index,
    int totalSlides,
    String deckTitle,
    PptxStudyStyle style,
  ) {
    switch (style) {
      case PptxStudyStyle.minimalCute:
        return _buildMinimalCuteSlide(s, index, totalSlides, deckTitle);
      case PptxStudyStyle.handwrittenNotebook:
        return _buildHandwrittenSlide(s, index, totalSlides, deckTitle);
      case PptxStudyStyle.zenPaperInk:
        return _buildZenSlide(s, index, totalSlides, deckTitle);
      case PptxStudyStyle.modernHighYield:
        return _buildModernSlide(s, index, totalSlides, deckTitle);
    }
  }

  // ---------------------------------------------------------------------------
  // 1. MINIMAL CUTE SLIDE (Pastel Sakura & Lavender with rounded cards)
  // ---------------------------------------------------------------------------
  static String _buildMinimalCuteSlide(
    PptxSlideData s,
    int index,
    int totalSlides,
    String deckTitle,
  ) {
    final safeBullets = s.bulletPoints.isNotEmpty ? s.bulletPoints : ['Key concept summary point'];
    final bulletLinesXml = safeBullets.map((b) {
      return '''<a:p>
        <a:pPr marL="288000" indent="-288000"/>
        <a:r>
          <a:rPr lang="en-US" sz="1500" b="1">
            <a:solidFill><a:srgbClr val="EC4899"/></a:solidFill>
          </a:rPr>
          <a:t>✿  </a:t>
        </a:r>
        <a:r>
          <a:rPr lang="en-US" sz="1500">
            <a:solidFill><a:srgbClr val="374151"/></a:solidFill>
          </a:rPr>
          <a:t>${_escapeXml(b)}</a:t>
        </a:r>
      </a:p>
      <a:p><a:endParaRPr sz="600"/></a:p>''';
    }).join('');

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg>
      <p:bgPr>
        <a:solidFill><a:srgbClr val="FDF2F8"/></a:solidFill>
      </p:bgPr>
    </p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>

      <!-- Main White Rounded Card Container -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Card"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="548640" y="457200"/><a:ext cx="8046720" cy="5943600"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 2000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>
          <a:ln w="25400"><a:solidFill><a:srgbClr val="FBCFE8"/></a:solidFill></a:ln>
        </p:spPr>
      </p:sp>

      <!-- Pill Badge: STUDY CARD -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="PillBadge"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="822960" y="731520"/><a:ext cx="2743200" cy="365760"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 50000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="FCE7F3"/></a:solidFill>
          <a:ln w="9525"><a:solidFill><a:srgbClr val="F472B6"/></a:solidFill></a:ln>
        </p:spPr>
        <p:txBody>
          <a:bodyPr rtlCol="0" anchor="ctr"/>
          <a:lstStyle/>
          <a:p>
            <a:pPr algn="ctr"/>
            <a:r>
              <a:rPr lang="en-US" sz="1000" b="1">
                <a:solidFill><a:srgbClr val="DB2777"/></a:solidFill>
              </a:rPr>
              <a:t>✦ SAGE STUDY DECK • SLIDE ${index + 1}/$totalSlides ✦</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>

      <!-- Title -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="4" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="822960" y="1188720"/><a:ext cx="7500000" cy="731520"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p>
            <a:r>
              <a:rPr lang="en-US" sz="2400" b="1">
                <a:solidFill><a:srgbClr val="831843"/></a:solidFill>
              </a:rPr>
              <a:t>${_escapeXml(s.title)}</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>

      <!-- Bullets Body -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="5" name="Bullets"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="822960" y="2011680"/><a:ext cx="7500000" cy="3800000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          $bulletLinesXml
        </p:txBody>
      </p:sp>

      <!-- Cute Footer Bar -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="6" name="Footer"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="822960" y="5943600"/><a:ext cx="7500000" cy="274320"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p>
            <a:r>
              <a:rPr lang="en-US" sz="900">
                <a:solidFill><a:srgbClr val="F472B6"/></a:solidFill>
              </a:rPr>
              <a:t>🌸 True Me • Minimal Cute Study Series • ${_escapeXml(deckTitle)}</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
  }

  // ---------------------------------------------------------------------------
  // 2. HANDWRITTEN CORNELL NOTEBOOK SLIDE
  // ---------------------------------------------------------------------------
  static String _buildHandwrittenSlide(
    PptxSlideData s,
    int index,
    int totalSlides,
    String deckTitle,
  ) {
    final safeBullets = s.bulletPoints.isNotEmpty ? s.bulletPoints : ['Key concept note'];
    final bulletLinesXml = safeBullets.map((b) {
      return '''<a:p>
        <a:pPr marL="288000" indent="-288000"/>
        <a:r>
          <a:rPr lang="en-US" sz="1500" b="1">
            <a:solidFill><a:srgbClr val="CA8A04"/></a:solidFill>
          </a:rPr>
          <a:t>[✔]  </a:t>
        </a:r>
        <a:r>
          <a:rPr lang="en-US" sz="1500">
            <a:solidFill><a:srgbClr val="1E293B"/></a:solidFill>
          </a:rPr>
          <a:t>${_escapeXml(b)}</a:t>
        </a:r>
      </a:p>
      <a:p><a:endParaRPr sz="600"/></a:p>''';
    }).join('');

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg>
      <p:bgPr>
        <a:solidFill><a:srgbClr val="FDFBF7"/></a:solidFill>
      </p:bgPr>
    </p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>

      <!-- Cornell Left Red Margin Line -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="MarginLine"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="1000000" y="0"/><a:ext cx="25400" cy="6858000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
          <a:solidFill><a:srgbClr val="FCA5A5"/></a:solidFill>
        </p:spPr>
      </p:sp>

      <!-- Yellow Highlighter Behind Title -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Highlighter"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="1200000" y="550000"/><a:ext cx="6500000" cy="700000"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 2000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="FEF08A"/></a:solidFill>
        </p:spPr>
      </p:sp>

      <!-- Title Text -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="4" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="1300000" y="600000"/><a:ext cx="6300000" cy="600000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p>
            <a:r>
              <a:rPr lang="en-US" sz="2400" b="1">
                <a:solidFill><a:srgbClr val="0F172A"/></a:solidFill>
              </a:rPr>
              <a:t>${_escapeXml(s.title)}</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>

      <!-- Bullets Content -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="5" name="Content"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="1300000" y="1600000"/><a:ext cx="5200000" cy="4200000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          $bulletLinesXml
        </p:txBody>
      </p:sp>

      <!-- Sticky Note on Right Side -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="6" name="StickyNote"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="6700000" y="1600000"/><a:ext cx="2000000" cy="3000000"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 2000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="FEF9C3"/></a:solidFill>
          <a:ln w="19050"><a:solidFill><a:srgbClr val="FACC15"/></a:solidFill></a:ln>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p>
            <a:r>
              <a:rPr lang="en-US" sz="1100" b="1">
                <a:solidFill><a:srgbClr val="854D0E"/></a:solidFill>
              </a:rPr>
              <a:t>📌 EXAM KEYNOTE</a:t>
            </a:r>
          </a:p>
          <a:p><a:endParaRPr sz="400"/></a:p>
          <a:p>
            <a:r>
              <a:rPr lang="en-US" sz="1000">
                <a:solidFill><a:srgbClr val="713F12"/></a:solidFill>
              </a:rPr>
              <a:t>Active recall: test this concept without looking at notes.</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>

      <!-- Notebook Bottom Label -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="7" name="Footer"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="1300000" y="6200000"/><a:ext cx="7000000" cy="300000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p>
            <a:r>
              <a:rPr lang="en-US" sz="900">
                <a:solidFill><a:srgbClr val="94A3B8"/></a:solidFill>
              </a:rPr>
              <a:t>📓 Cornell Handwritten Study Sheet • Slide ${index + 1}/$totalSlides • ${_escapeXml(deckTitle)}</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
  }

  // ---------------------------------------------------------------------------
  // 3. ZEN PAPER & INK SLIDE
  // ---------------------------------------------------------------------------
  static String _buildZenSlide(
    PptxSlideData s,
    int index,
    int totalSlides,
    String deckTitle,
  ) {
    final safeBullets = s.bulletPoints.isNotEmpty ? s.bulletPoints : ['Key concept summary point'];
    final bulletLinesXml = safeBullets.map((b) {
      return '''<a:p>
        <a:pPr marL="288000" indent="-288000"/>
        <a:r>
          <a:rPr lang="en-US" sz="1500" b="1">
            <a:solidFill><a:srgbClr val="DC2626"/></a:solidFill>
          </a:rPr>
          <a:t>•  </a:t>
        </a:r>
        <a:r>
          <a:rPr lang="en-US" sz="1500">
            <a:solidFill><a:srgbClr val="1C1917"/></a:solidFill>
          </a:rPr>
          <a:t>${_escapeXml(b)}</a:t>
        </a:r>
      </a:p>
      <a:p><a:endParaRPr sz="600"/></a:p>''';
    }).join('');

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg>
      <p:bgPr>
        <a:solidFill><a:srgbClr val="FBF9F5"/></a:solidFill>
      </p:bgPr>
    </p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>

      <!-- Vermilion Seal Stamp -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Hanko"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="685800" y="600000"/><a:ext cx="365760" cy="365760"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
          <a:solidFill><a:srgbClr val="DC2626"/></a:solidFill>
        </p:spPr>
        <p:txBody>
          <a:bodyPr rtlCol="0" anchor="ctr"/>
          <a:lstStyle/>
          <a:p>
            <a:pPr algn="ctr"/>
            <a:r>
              <a:rPr lang="en-US" sz="1000" b="1">
                <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>
              </a:rPr>
              <a:t>印</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>

      <!-- Title -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="1200000" y="480000"/><a:ext cx="7000000" cy="731520"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p>
            <a:r>
              <a:rPr lang="en-US" sz="2600" b="1">
                <a:solidFill><a:srgbClr val="1C1917"/></a:solidFill>
              </a:rPr>
              <a:t>${_escapeXml(s.title)}</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>

      <!-- Calligraphic Divider -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="4" name="Divider"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="685800" y="1300000"/><a:ext cx="7772400" cy="19050"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
          <a:solidFill><a:srgbClr val="E7E3D9"/></a:solidFill>
        </p:spPr>
      </p:sp>

      <!-- Bullets Body -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="5" name="Bullets"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="685800" y="1600000"/><a:ext cx="7772400" cy="4200000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          $bulletLinesXml
        </p:txBody>
      </p:sp>

      <!-- Zen Footer -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="6" name="Footer"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="685800" y="6100000"/><a:ext cx="7772400" cy="274320"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p>
            <a:r>
              <a:rPr lang="en-US" sz="900">
                <a:solidFill><a:srgbClr val="A8A29E"/></a:solidFill>
              </a:rPr>
              <a:t>True Me • Zen Paper &amp; Ink • Slide ${index + 1}/$totalSlides</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
  }

  // ---------------------------------------------------------------------------
  // 4. MODERN HIGH-YIELD DARK SLATE SLIDE
  // ---------------------------------------------------------------------------
  static String _buildModernSlide(
    PptxSlideData s,
    int index,
    int totalSlides,
    String deckTitle,
  ) {
    final safeBullets = s.bulletPoints.isNotEmpty ? s.bulletPoints : ['Key concept summary point'];
    final bulletLinesXml = safeBullets.map((b) {
      return '''<a:p>
        <a:pPr marL="288000" indent="-288000"/>
        <a:r>
          <a:rPr lang="en-US" sz="1500" b="1">
            <a:solidFill><a:srgbClr val="06B6D4"/></a:solidFill>
          </a:rPr>
          <a:t>▸  </a:t>
        </a:r>
        <a:r>
          <a:rPr lang="en-US" sz="1500">
            <a:solidFill><a:srgbClr val="E2E8F0"/></a:solidFill>
          </a:rPr>
          <a:t>${_escapeXml(b)}</a:t>
        </a:r>
      </a:p>
      <a:p><a:endParaRPr sz="600"/></a:p>''';
    }).join('');

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg>
      <p:bgPr>
        <a:solidFill><a:srgbClr val="0F172A"/></a:solidFill>
      </p:bgPr>
    </p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>

      <!-- Dark Slate Card Container -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Card"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="548640" y="457200"/><a:ext cx="8046720" cy="5943600"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 2000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="1E293B"/></a:solidFill>
          <a:ln w="25400"><a:solidFill><a:srgbClr val="334155"/></a:solidFill></a:ln>
        </p:spPr>
      </p:sp>

      <!-- Pill Badge -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Badge"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="822960" y="731520"/><a:ext cx="2200000" cy="320000"/></a:xfrm>
          <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 50000"/></a:avLst></a:prstGeom>
          <a:solidFill><a:srgbClr val="083344"/></a:solidFill>
          <a:ln w="9525"><a:solidFill><a:srgbClr val="06B6D4"/></a:solidFill></a:ln>
        </p:spPr>
        <p:txBody>
          <a:bodyPr rtlCol="0" anchor="ctr"/>
          <a:lstStyle/>
          <a:p>
            <a:pPr algn="ctr"/>
            <a:r>
              <a:rPr lang="en-US" sz="1000" b="1">
                <a:solidFill><a:srgbClr val="22D3EE"/></a:solidFill>
              </a:rPr>
              <a:t>⚡ HIGH YIELD • SLIDE ${index + 1}/$totalSlides</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>

      <!-- Title -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="4" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="822960" y="1188720"/><a:ext cx="7500000" cy="731520"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          <a:p>
            <a:r>
              <a:rPr lang="en-US" sz="2400" b="1">
                <a:solidFill><a:srgbClr val="F8FAFC"/></a:solidFill>
              </a:rPr>
              <a:t>${_escapeXml(s.title)}</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>

      <!-- Bullets Body -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="5" name="Bullets"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="822960" y="2011680"/><a:ext cx="7500000" cy="3800000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/><a:lstStyle/>
          $bulletLinesXml
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
  }

  // ---------------------------------------------------------------------------
  // THEME COLOR XML BUILDER
  // ---------------------------------------------------------------------------
  static String _buildThemeXml(PptxStudyStyle style) {
    String accent1 = '2563EB';
    String accent2 = 'EC4899';
    if (style == PptxStudyStyle.minimalCute) {
      accent1 = 'F472B6';
      accent2 = '8B5CF6';
    } else if (style == PptxStudyStyle.handwrittenNotebook) {
      accent1 = 'EAB308';
      accent2 = 'FCA5A5';
    } else if (style == PptxStudyStyle.zenPaperInk) {
      accent1 = 'DC2626';
      accent2 = '1C1917';
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
