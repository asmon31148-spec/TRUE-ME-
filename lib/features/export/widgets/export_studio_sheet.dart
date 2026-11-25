import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_illustrations.dart';
import '../../../shared/widgets/true_me_ui.dart';

class ExportStudioConfig {
  final String format; // 'pdf', 'docx', 'pptx'
  final String styleId;
  final String documentTitle;
  final int slideCount;

  const ExportStudioConfig({
    required this.format,
    required this.styleId,
    required this.documentTitle,
    required this.slideCount,
  });
}

class ExportStudioSheet extends StatefulWidget {
  final String format; // 'pdf', 'docx', 'pptx'
  final String subjectName;

  const ExportStudioSheet({
    super.key,
    required this.format,
    required this.subjectName,
  });

  static Future<ExportStudioConfig?> show(
    BuildContext context, {
    required String format,
    required String subjectName,
  }) {
    return showModalBottomSheet<ExportStudioConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExportStudioSheet(
        format: format,
        subjectName: subjectName,
      ),
    );
  }

  @override
  State<ExportStudioSheet> createState() => _ExportStudioSheetState();
}

class _ExportStudioSheetState extends State<ExportStudioSheet> {
  late String _selectedStyle;
  late final TextEditingController _titleCtrl;
  int _slideCount = 8;

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.format == 'pdf'
        ? OfflineCacheService.getPreferredPdfStyle()
        : OfflineCacheService.getPreferredPptxStyle();
    _titleCtrl = TextEditingController(text: '${widget.subjectName} Study Guide');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    if (widget.format == 'pdf') {
      await OfflineCacheService.savePreferredPdfStyle(_selectedStyle);
    } else if (widget.format == 'pptx') {
      await OfflineCacheService.savePreferredPptxStyle(_selectedStyle);
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      ExportStudioConfig(
        format: widget.format,
        styleId: _selectedStyle,
        documentTitle: _titleCtrl.text.trim().isNotEmpty
            ? _titleCtrl.text.trim()
            : '${widget.subjectName} Study Guide',
        slideCount: _slideCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.format == 'pdf';
    final isWord = widget.format == 'docx';
    final isPptx = widget.format == 'pptx';

    final String headerTitle = isPdf
        ? 'Export to PDF'
        : (isWord ? 'Export to Word' : 'Export to PowerPoint');
    final IconData headerIcon = isPdf
        ? Icons.description_rounded
        : (isWord ? Icons.article_rounded : Icons.slideshow_rounded);
    final Color headerTint = isPdf
        ? AppColors.accent
        : (isWord ? const Color(0xFF2563EB) : const Color(0xFFEA580C));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      maxChildSize: 0.94,
      minChildSize: 0.6,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: TrueMeAmbientBackground(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Top Header Bar matching Reference Image 1 Panels 2–4
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      TrueMeCircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        size: 40,
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          headerTitle,
                          textAlign: TextAlign.center,
                          style: AppTypography.screenTitle.copyWith(
                            fontSize: 21,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: headerTint.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(headerIcon, size: 20, color: headerTint),
                      ),
                    ],
                  ),
                ),

                // Content Body
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                    children: [
                      if (isPdf) ...[
                        Text(
                          '• Choose a style for your study sheet',
                          style: AppTypography.secondary.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.90,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _StyleGridCard(
                              id: 'handwritten',
                              title: 'Handwritten\nCornell Notebook',
                              isSelected: _selectedStyle == 'handwritten',
                              previewType: _PreviewKind.cornell,
                              onTap: () => setState(() => _selectedStyle = 'handwritten'),
                            ),
                            _StyleGridCard(
                              id: 'minimalCute',
                              title: 'Minimal Cute',
                              isSelected: _selectedStyle == 'minimalCute',
                              previewType: _PreviewKind.minimalCute,
                              onTap: () => setState(() => _selectedStyle = 'minimalCute'),
                            ),
                            _StyleGridCard(
                              id: 'zenPaperInk',
                              title: 'Zen Paper & Ink',
                              isSelected: _selectedStyle == 'zenPaperInk',
                              previewType: _PreviewKind.zenInk,
                              onTap: () => setState(() => _selectedStyle = 'zenPaperInk'),
                            ),
                            _StyleGridCard(
                              id: 'modernClean',
                              title: 'Modern High-Yield',
                              isSelected: _selectedStyle == 'modernClean',
                              previewType: _PreviewKind.modernHighYield,
                              onTap: () => setState(() => _selectedStyle = 'modernClean'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _InfoCalloutBanner(
                          icon: Icons.auto_awesome_rounded,
                          text: 'A beautifully formatted study sheet synthesized from your notes.',
                        ),
                      ] else if (isWord) ...[
                        // Live Word Document Outline Card with Botanical Margin Motif matching Ref Img 1 Panel 3
                        TrueMeCard(
                          borderRadius: 22,
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: BotanicalCornerPainter(isDark: context.isDarkMode),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 18, 42, 18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _titleCtrl.text.trim().isNotEmpty
                                            ? _titleCtrl.text.trim()
                                            : '${widget.subjectName} Study Guide',
                                        style: AppTypography.sectionHeading.copyWith(
                                          fontSize: 18,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const _OutlineItem(
                                        heading: '1. Core Foundations',
                                        bullets: ['Key definitions & terms', 'Foundational principles'],
                                      ),
                                      const SizedBox(height: 8),
                                      _OutlineItem(
                                        heading: '2. ${widget.subjectName} Breakdown',
                                        bullets: const ['High-yield concepts', 'Exam summary points'],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        AppInput(
                          label: 'Document Title',
                          hintText: '${widget.subjectName} Study Guide',
                          controller: _titleCtrl,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Subject',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TrueMeCard(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          showShadow: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.subjectName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(Icons.menu_book_rounded, size: 18, color: context.accentColor),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _InfoCalloutBanner(
                          icon: Icons.info_outline_rounded,
                          text: 'An editable structured study guide in DOCX format.',
                        ),
                      ] else if (isPptx) ...[
                        Center(
                          child: Text(
                            'Choose a presentation style',
                            style: AppTypography.secondary.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.90,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _StyleGridCard(
                              id: 'minimalCute',
                              title: 'Minimal Cute\nDeck',
                              isSelected: _selectedStyle == 'minimalCute',
                              previewType: _PreviewKind.cuteDeck,
                              onTap: () => setState(() => _selectedStyle = 'minimalCute'),
                            ),
                            _StyleGridCard(
                              id: 'handwrittenNotebook',
                              title: 'Cornell Notebook',
                              isSelected: _selectedStyle == 'handwrittenNotebook',
                              previewType: _PreviewKind.cornell,
                              onTap: () => setState(() => _selectedStyle = 'handwrittenNotebook'),
                            ),
                            _StyleGridCard(
                              id: 'zenPaperInk',
                              title: 'Zen Paper & Ink',
                              isSelected: _selectedStyle == 'zenPaperInk',
                              previewType: _PreviewKind.zenInk,
                              onTap: () => setState(() => _selectedStyle = 'zenPaperInk'),
                            ),
                            _StyleGridCard(
                              id: 'modernHighYield',
                              title: 'Modern High-Yield',
                              isSelected: _selectedStyle == 'modernHighYield',
                              previewType: _PreviewKind.chartDeck,
                              onTap: () => setState(() => _selectedStyle = 'modernHighYield'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Slide Count Switcher: < 8 slides >
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TrueMeCircleIconButton(
                              icon: Icons.chevron_left_rounded,
                              size: 40,
                              onPressed: () {
                                if (_slideCount > 5) setState(() => _slideCount--);
                              },
                            ),
                            const SizedBox(width: 24),
                            Text(
                              '$_slideCount slides',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 24),
                            TrueMeCircleIconButton(
                              icon: Icons.chevron_right_rounded,
                              size: 40,
                              onPressed: () {
                                if (_slideCount < 12) setState(() => _slideCount++);
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Primary CTA Footer
                Padding(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.of(context).padding.bottom + 16),
                  child: TrueMePrimaryButton(
                    label: isPdf
                        ? 'Generate PDF'
                        : (isWord ? 'Generate Word (.docx)' : 'Generate PowerPoint (.pptx)'),
                    leadingIcon: Icon(headerIcon, size: 19, color: Colors.white),
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PreviewKind { cornell, minimalCute, zenInk, modernHighYield, cuteDeck, chartDeck }

class _StyleGridCard extends StatelessWidget {
  final String id;
  final String title;
  final bool isSelected;
  final _PreviewKind previewType;
  final VoidCallback onTap;

  const _StyleGridCard({
    required this.id,
    required this.title,
    required this.isSelected,
    required this.previewType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TrueMeCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(10),
      borderColor: isSelected ? context.accentColor : null,
      borderWidth: isSelected ? 2.0 : 0.0,
      onTap: onTap,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _buildPreviewArtwork(),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: isSelected ? context.accentColor : context.textPrimary,
                ),
              ),
            ],
          ),
          if (isSelected)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AppColors.indigoButtonGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.30),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewArtwork() {
    switch (previewType) {
      case _PreviewKind.cornell:
        return const ExportStyleMiniPreview(kind: 'cornell');
      case _PreviewKind.minimalCute:
        return const ExportStyleMiniPreview(kind: 'minimalCute');
      case _PreviewKind.zenInk:
        return const ExportStyleMiniPreview(kind: 'zenInk');
      case _PreviewKind.modernHighYield:
        return const ExportStyleMiniPreview(kind: 'modernHighYield');
      case _PreviewKind.cuteDeck:
        return const ExportStyleMiniPreview(kind: 'cuteDeck');
      case _PreviewKind.chartDeck:
        return const ExportStyleMiniPreview(kind: 'chartDeck');
    }
  }
}

class _OutlineItem extends StatelessWidget {
  final String heading;
  final List<String> bullets;

  const _OutlineItem({required this.heading, required this.bullets});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary),
        ),
        const SizedBox(height: 3),
        ...bullets.map(
          (b) => Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 2),
            child: Text('• $b', style: AppTypography.smallLabel.copyWith(color: context.textSecondary)),
          ),
        ),
      ],
    );
  }
}

class _InfoCalloutBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoCalloutBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return TrueMeCard(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: isDark ? AppColors.darkAccentWash : AppColors.accentWash,
      borderColor: context.accentColor.withValues(alpha: 0.2),
      showShadow: false,
      child: Row(
        children: [
          Icon(icon, size: 19, color: context.accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.secondary.copyWith(
                fontSize: 13,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
