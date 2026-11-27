import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/true_me_ui.dart';
import '../services/document_parser_service.dart';

/// Native In-App Document Viewer for PDF, Word (DOCX), and PowerPoint (PPTX).
/// Opens inside TRUE ME by default; external apps are only an optional fallback menu action.
class DocumentViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const DocumentViewerScreen({
    super.key,
    required this.filePath,
    this.title,
  });

  static Future<void> open(
    BuildContext context, {
    required String filePath,
    String? title,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(filePath: filePath, title: title),
      ),
    );
  }

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _isLoading = true;
  String? _error;
  ParsedDocFormat _format = ParsedDocFormat.unknown;
  Uint8List? _bytes;

  // PDF state
  final List<Uint8List> _pdfPages = [];
  int _currentPdfPage = 1;
  final ScrollController _pdfScrollCtrl = ScrollController();

  // DOCX state
  List<ParsedDocxBlock> _docxBlocks = [];
  double _docxScale = 1.0;

  // PPTX state
  List<ParsedPptxSlide> _pptxSlides = [];
  double _pptxAspectRatio = 16 / 9;
  int _currentSlideIdx = 0;
  final PageController _slidePageCtrl = PageController();

  // Shared UI state
  bool _fullScreen = false;
  bool _showSearch = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _pdfScrollCtrl.dispose();
    _slidePageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _error = 'File not found on device.';
        });
        return;
      }

      final size = await file.length();
      if (size == 0) {
        setState(() {
          _isLoading = false;
          _error = 'Document file is empty (0 bytes).';
        });
        return;
      }
      if (size > DocumentParserService.maxSupportedBytes) {
        setState(() {
          _isLoading = false;
          _error = 'File exceeds 150 MB in-app viewer limit. Use Open Externally.';
        });
        return;
      }

      final bytes = await file.readAsBytes();
      final fmt = DocumentParserService.detectFormat(bytes, widget.filePath);
      if (fmt == ParsedDocFormat.unknown) {
        setState(() {
          _isLoading = false;
          _error = 'Unsupported, corrupted, or password-protected document format.';
        });
        return;
      }

      _bytes = bytes;
      _format = fmt;

      if (fmt == ParsedDocFormat.pdf) {
        await for (final page in Printing.raster(bytes, dpi: 150)) {
          final png = await page.toPng();
          if (!mounted) return;
          setState(() {
            _pdfPages.add(png);
            _isLoading = false;
          });
        }
        if (_pdfPages.isEmpty && mounted) {
          setState(() {
            _isLoading = false;
            _error = 'PDF has no renderable pages or is password-protected.';
          });
        }
      } else if (fmt == ParsedDocFormat.docx) {
        _docxBlocks = DocumentParserService.parseDocx(bytes);
        if (mounted) setState(() => _isLoading = false);
      } else if (fmt == ParsedDocFormat.pptx) {
        _pptxSlides = DocumentParserService.parsePptx(bytes);
        _pptxAspectRatio = DocumentParserService.parsePptxAspectRatio(bytes);
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not render document: $e';
        });
      }
    }
  }

  Future<void> _openExternally() async {
    final res = await OpenFilex.open(widget.filePath);
    if (mounted && res.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No external app available (${res.message}).')),
      );
    }
  }

  Future<void> _shareFile() async {
    if (_bytes != null && _format == ParsedDocFormat.pdf) {
      final name = widget.filePath.split(Platform.pathSeparator).last;
      await Printing.sharePdf(bytes: _bytes!, filename: name);
    } else {
      await _openExternally();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    final formatBadge = _format == ParsedDocFormat.pdf
        ? 'PDF'
        : (_format == ParsedDocFormat.docx
            ? 'DOCX'
            : (_format == ParsedDocFormat.pptx ? 'PPTX' : 'DOC'));

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (!_fullScreen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Row(
                    children: [
                      TrueMeCircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.cardTitle.copyWith(color: context.textPrimary),
                            ),
                            Text(
                              _subtitleText(formatBadge),
                              style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (_format == ParsedDocFormat.docx || _format == ParsedDocFormat.pptx)
                        TrueMeCircleIconButton(
                          icon: _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                          tooltip: 'Search',
                          onPressed: () => setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) {
                              _searchQuery = '';
                              _searchCtrl.clear();
                            }
                          }),
                        ),
                      const SizedBox(width: 6),
                      TrueMeCircleIconButton(
                        icon: Icons.fullscreen_rounded,
                        tooltip: 'Full Screen',
                        onPressed: () => setState(() => _fullScreen = true),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: context.textPrimary),
                        onSelected: (val) {
                          if (val == 'share') _shareFile();
                          if (val == 'external') _openExternally();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'share', child: Text('Share / Print')),
                          PopupMenuItem(value: 'external', child: Text('Open in external app')),
                        ],
                      ),
                    ],
                  ),
                ),

              if (_showSearch && !_fullScreen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      setState(() {
                        _searchQuery = v.trim().toLowerCase();
                        _currentSlideIdx = 0;
                      });
                      if (_format == ParsedDocFormat.pptx && _slidePageCtrl.hasClients) {
                        _slidePageCtrl.jumpToPage(0);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search inside document...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: context.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                    ),
                  ),
                ),

              Expanded(
                child: Stack(
                  children: [
                    _buildBody(),
                    if (_fullScreen)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: TrueMeCircleIconButton(
                          icon: Icons.fullscreen_exit_rounded,
                          tooltip: 'Exit Full Screen',
                          onPressed: () => setState(() => _fullScreen = false),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleText(String badge) {
    if (_format == ParsedDocFormat.pdf && _pdfPages.isNotEmpty) {
      return '$badge · Page $_currentPdfPage / ${_pdfPages.length}';
    }
    if (_format == ParsedDocFormat.pptx && _pptxSlides.isNotEmpty) {
      if (_searchQuery.isNotEmpty) {
        return '$badge · Filtered Search (${_pptxSlides.length} total slides)';
      }
      final safeIdx = _currentSlideIdx.clamp(0, _pptxSlides.length - 1);
      return '$badge · Slide ${_pptxSlides[safeIdx].index} / ${_pptxSlides.length}';
    }
    if (_format == ParsedDocFormat.docx) {
      return '$badge · Semantic Reader';
    }
    return '$badge · In-App Reader';
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: TrueMeCard(
            borderRadius: 22,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 42, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.secondary.copyWith(color: context.textPrimary),
                ),
                const SizedBox(height: 16),
                TrueMePrimaryButton(
                  label: 'Try External App',
                  onPressed: _openExternally,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading && _pdfPages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_format) {
      case ParsedDocFormat.pdf:
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (_pdfPages.isNotEmpty && n.metrics.maxScrollExtent > 0) {
              final ratio = (n.metrics.pixels / n.metrics.maxScrollExtent).clamp(0.0, 1.0);
              final page = (ratio * (_pdfPages.length - 1)).round() + 1;
              if (page != _currentPdfPage) {
                setState(() => _currentPdfPage = page);
              }
            }
            return false;
          },
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: ListView.builder(
              controller: _pdfScrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              itemCount: _pdfPages.length,
              itemBuilder: (_, idx) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TrueMeCard(
                  borderRadius: 12,
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_pdfPages[idx], fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        );

      case ParsedDocFormat.docx:
        final filtered = _searchQuery.isEmpty
            ? _docxBlocks
            : _docxBlocks
                .where((b) =>
                    b.text.toLowerCase().contains(_searchQuery) ||
                    b.rows.any((r) => r.any((c) => c.toLowerCase().contains(_searchQuery))))
                .toList();

        return Column(
          children: [
            if (!_fullScreen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_out_rounded, size: 20),
                      onPressed: () => setState(() => _docxScale = (_docxScale - 0.1).clamp(0.85, 1.45)),
                    ),
                    Text('${(_docxScale * 100).round()}%', style: AppTypography.smallLabel),
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded, size: 20),
                      onPressed: () => setState(() => _docxScale = (_docxScale + 0.1).clamp(0.85, 1.45)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No matching text for "$_searchQuery".'
                            : 'No readable content found.',
                        style: AppTypography.secondary.copyWith(color: context.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
                      itemCount: filtered.length,
                      itemBuilder: (_, idx) => _buildDocxBlock(filtered[idx]),
                    ),
            ),
          ],
        );

      case ParsedDocFormat.pptx:
        final slides = _searchQuery.isEmpty
            ? _pptxSlides
            : _pptxSlides
                .where((s) =>
                    s.title.toLowerCase().contains(_searchQuery) ||
                    s.bullets.any((b) => b.toLowerCase().contains(_searchQuery)))
                .toList();
        if (slides.isEmpty) {
          return Center(
            child: Text(
              'No slides match "$_searchQuery".',
              style: AppTypography.secondary.copyWith(color: context.textSecondary),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _slidePageCtrl,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _currentSlideIdx = i),
                itemBuilder: (_, idx) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _pptxAspectRatio,
                      child: _buildSlideCard(slides[idx]),
                    ),
                  ),
                ),
              ),
            ),
            if (!_fullScreen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      label: const Text('Previous'),
                      onPressed: _currentSlideIdx > 0
                          ? () => _slidePageCtrl.previousPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              )
                          : null,
                    ),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Match ${_currentSlideIdx.clamp(0, slides.length - 1) + 1}/${slides.length} · Deck ${slides[_currentSlideIdx.clamp(0, slides.length - 1)].index}/${_pptxSlides.length}'
                          : 'Slide ${slides[_currentSlideIdx.clamp(0, slides.length - 1)].index} / ${_pptxSlides.length}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      label: const Text('Next'),
                      onPressed: _currentSlideIdx < slides.length - 1
                          ? () => _slidePageCtrl.nextPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              )
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        );

      case ParsedDocFormat.unknown:
        return const SizedBox.shrink();
    }
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.length != 6) return null;
    final parsed = int.tryParse('FF$hex', radix: 16);
    return parsed != null ? Color(parsed) : null;
  }

  Widget _buildDocxBlock(ParsedDocxBlock b) {
    final accent = _parseHexColor(b.accentHex) ?? context.accentColor;
    final fill = _parseHexColor(b.fillHex);

    switch (b.kind) {
      case 'title':
        final titleColor = _parseHexColor(b.accentHex) ?? context.textPrimary;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: fill != null ? const EdgeInsets.all(14) : EdgeInsets.zero,
          decoration: fill != null
              ? BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12))
              : null,
          child: SelectableText(
            b.text,
            style: AppTypography.editorialHero.copyWith(
              fontSize: 23 * _docxScale,
              color: titleColor,
            ),
          ),
        );
      case 'heading1':
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: SelectableText(
            b.text,
            style: AppTypography.sectionHeading.copyWith(
              fontSize: 18.5 * _docxScale,
              color: accent,
            ),
          ),
        );
      case 'heading2':
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: SelectableText(
            b.text,
            style: TextStyle(
              fontSize: 16 * _docxScale,
              fontWeight: FontWeight.w700,
              color: _parseHexColor(b.accentHex) ?? context.textPrimary,
            ),
          ),
        );
      case 'callout':
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fill ?? context.surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: SelectableText(
            b.text,
            style: TextStyle(
              fontSize: 14 * _docxScale,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: context.textPrimary,
            ),
          ),
        );
      case 'bullet':
        return Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(fontSize: 15 * _docxScale, color: context.accentColor)),
              Expanded(
                child: SelectableText(
                  b.text,
                  style: TextStyle(
                    fontSize: 14.5 * _docxScale,
                    height: 1.5,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'table':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: context.borderColor),
              children: b.rows
                  .map(
                    (row) => TableRow(
                      children: row
                          .map(
                            (cell) => Padding(
                              padding: const EdgeInsets.all(8),
                              child: SelectableText(
                                cell,
                                style: TextStyle(fontSize: 13.5 * _docxScale, color: context.textPrimary),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SelectableText(
            b.text,
            style: TextStyle(
              fontSize: 14.5 * _docxScale,
              height: 1.55,
              color: context.textPrimary,
            ),
          ),
        );
    }
  }

  Widget _buildSlideCard(ParsedPptxSlide slide) {
    Color? parsedBg;
    if (slide.backgroundHex != null && slide.backgroundHex!.length == 6) {
      final hexVal = int.tryParse('FF${slide.backgroundHex}', radix: 16);
      if (hexVal != null) parsedBg = Color(hexVal);
    }
    final bgColor = parsedBg ?? context.surfaceColor;
    final isDarkSlide = bgColor.computeLuminance() < 0.35;
    final fg = isDarkSlide ? Colors.white : const Color(0xFF1E1B3A);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: isDarkSlide ? const Color(0xFF334155) : context.borderColor,
          width: 1,
        ),
        boxShadow: context.cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SLIDE ${slide.index}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: fg.withValues(alpha: 0.65),
                ),
              ),
              Icon(Icons.slideshow_rounded, size: 18, color: fg.withValues(alpha: 0.55)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            slide.title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: slide.bullets
                  .map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(fontSize: 15, color: fg)),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(fontSize: 14.5, height: 1.4, color: fg.withValues(alpha: 0.92)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
