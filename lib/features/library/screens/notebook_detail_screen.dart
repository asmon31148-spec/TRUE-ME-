import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../features/export/docx_exporter.dart';
import '../../../features/export/pdf_exporter.dart';
import '../../../features/export/pptx_exporter.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/generation_progress_view.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/widgets/sage_chat_view.dart';
import '../../upload/widgets/add_files_sheet.dart';

class NotebookDetailScreen extends ConsumerStatefulWidget {
  final String notebookId;

  const NotebookDetailScreen({super.key, required this.notebookId});

  @override
  ConsumerState<NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends ConsumerState<NotebookDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _sourceSearchCtrl = TextEditingController();
  String _sourceFilter = '';
  Map<String, dynamic>? _notebook;
  String? _exportingFormat; // 'pdf', 'docx', 'pptx'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotebook();
  }

  void _loadNotebook() {
    final nb = OfflineCacheService.getCachedNotebook(widget.notebookId);
    setState(() => _notebook = nb);
  }

  @override
  void dispose() {
    _sourceSearchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _openAddFiles({String initialSection = 'Notes'}) {
    final title = _notebook?['title'] as String? ?? 'Subject';
    AddFilesSheet.show(
      context,
      notebookId: widget.notebookId,
      subjectName: title,
      initialSection: initialSection,
      onFileAdded: _loadNotebook,
    );
  }

  void _showRenameDialog() {
    final title = _notebook?['title'] as String? ?? '';
    final ctrl = TextEditingController(text: title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ctx.borderColor),
        ),
        title: const Text('Rename subject', style: AppTypography.sectionHeading),
        content: AppInput(controller: ctrl, autofocus: true, hintText: 'Subject name'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.accentColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () async {
              await OfflineCacheService.renameNotebook(widget.notebookId, ctrl.text);
              _loadNotebook();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRenameDocDialog(String docId, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ctx.borderColor),
        ),
        title: const Text('Rename file', style: AppTypography.sectionHeading),
        content: AppInput(controller: ctrl, autofocus: true, hintText: 'File name'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.accentColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () async {
              await OfflineCacheService.updateDocumentInNotebook(
                widget.notebookId,
                docId,
                fileName: ctrl.text,
              );
              _loadNotebook();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDocumentViewer(Map<String, dynamic> doc) {
    String fileName = doc['fileName'] as String? ?? 'Document';
    String section = doc['section'] as String? ?? 'Notes';
    final content = doc['content'] as String? ?? '';
    final docId = doc['id'] as String? ?? '';
    final title = _notebook?['title'] as String? ?? 'Subject';
    const sections = ['Syllabus', 'Notes', 'Books', 'Previous papers'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          builder: (_, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fileName, style: AppTypography.sectionHeading, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('$section • ${content.length} characters', style: AppTypography.smallLabel),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: sheetCtx.textSecondary),
                      tooltip: 'Rename file',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showRenameDocDialog(docId, fileName);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      tooltip: 'Remove file',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Remove File?'),
                            content: Text('Are you sure you want to remove "$fileName" from this notebook?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await OfflineCacheService.removeDocumentFromNotebook(widget.notebookId, docId);
                          _loadNotebook();
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text('Section: ', style: AppTypography.smallLabel),
                      const SizedBox(width: 6),
                      ...sections.map((s) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: AppChip(
                            label: s,
                            isSelected: section == s,
                            onTap: () async {
                              if (s == section) return;
                              setSheetState(() => section = s);
                              await OfflineCacheService.updateDocumentInNotebook(
                                widget.notebookId,
                                docId,
                                section: s,
                              );
                              _loadNotebook();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Divider(color: ctx.borderColor, height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollCtrl,
                    child: SelectableText(
                      content.isNotEmpty ? content : 'No extracted text available.',
                      style: AppTypography.body.copyWith(height: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppPrimaryButton(
                  label: 'Ask Sage about this file',
                  onPressed: () {
                    Navigator.pop(ctx);
                    final q = Uri.encodeComponent('Explain the key points from "$fileName"');
                    context.push('/chat?notebookId=${widget.notebookId}&scope=${Uri.encodeComponent(title)}&prompt=$q');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<PptxSlideData> _parseSlidesFromAi(String raw, String fallbackTitle) {
    try {
      String cleaned = raw.trim();
      final start = cleaned.indexOf('[');
      final end = cleaned.lastIndexOf(']');
      if (start >= 0 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }
      final list = jsonDecode(cleaned) as List<dynamic>;
      final slides = <PptxSlideData>[];
      for (final item in list) {
        if (item is Map) {
          final sTitle = (item['title'] as String? ?? 'Key Concept').trim();
          final rawBullets = item['bullets'] as List? ?? item['bulletPoints'] as List? ?? [];
          final bullets = rawBullets.map((b) => b.toString().trim()).where((b) => b.isNotEmpty).toList();
          if (bullets.isNotEmpty) {
            slides.add(PptxSlideData(title: sTitle, bulletPoints: bullets));
          }
        }
      }
      if (slides.isNotEmpty) return slides;
    } catch (_) {}

    // Fallback: split markdown sections into slides
    final chunks = raw.split(RegExp(r'\n#{1,3}\s+')).where((s) => s.trim().isNotEmpty).toList();
    if (chunks.isNotEmpty) {
      return chunks.take(8).map((c) {
        final lines = c.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        final sTitle = lines.isNotEmpty ? lines.first.replaceAll('#', '').trim() : fallbackTitle;
        final bullets = lines.skip(1).take(5).map((l) => l.replaceFirst(RegExp(r'^[-*•]\s*'), '')).toList();
        return PptxSlideData(
          title: sTitle,
          bulletPoints: bullets.isNotEmpty ? bullets : ['Summary of $sTitle'],
        );
      }).toList();
    }

    return [
      PptxSlideData(
        title: fallbackTitle,
        bulletPoints: [raw.length > 250 ? raw.substring(0, 250) : raw],
      ),
    ];
  }

  String _getPdfStyleDisplayName(String id) {
    switch (id) {
      case 'handwritten':
        return '📝 Handwritten Notebook';
      case 'minimalCute':
        return '🌸 Minimal Cute';
      case 'zenPaperInk':
        return '📜 Zen Paper & Ink';
      case 'modernClean':
        return '⚡ Modern High-Yield';
      default:
        return '📝 Handwritten Notebook';
    }
  }

  String _getPptxStyleDisplayName(String id) {
    switch (id) {
      case 'minimalCute':
        return '🌸 Minimal Cute Deck';
      case 'handwrittenNotebook':
        return '📝 Cornell Notebook';
      case 'zenPaperInk':
        return '📜 Zen Paper & Ink';
      case 'modernHighYield':
        return '⚡ Modern High-Yield';
      default:
        return '🌸 Minimal Cute Deck';
    }
  }

  Future<void> _exportStudyFile(String format, {String? chosenStyle}) async {
    final title = _notebook?['title'] as String? ?? 'Study Guide';
    final combinedText = OfflineCacheService.getNotebookCombinedText(widget.notebookId);
    if (combinedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one file or note before exporting.')),
      );
      return;
    }

    setState(() => _exportingFormat = format);
    try {
      final aiRouter = ref.read(aiRouterProvider);
      final safeBase = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
      final dir = await getApplicationDocumentsDirectory();

      if (format == 'pdf') {
        final styleKey = chosenStyle ?? OfflineCacheService.getPreferredPdfStyle();
        PdfStudyStyle pdfStyle;
        if (styleKey == 'minimalCute') {
          pdfStyle = PdfStudyStyle.minimalCute;
        } else if (styleKey == 'zenPaperInk') {
          pdfStyle = PdfStudyStyle.zenPaperInk;
        } else if (styleKey == 'modernClean') {
          pdfStyle = PdfStudyStyle.modernClean;
        } else {
          pdfStyle = PdfStudyStyle.handwritten;
        }

        final synthesized = await aiRouter.executeHeavyReasoning(
          prompt: 'Create a structured, high-yield exam study guide summarizing these notes for "$title". Use clear markdown headings (#, ##) and bullet points (- ).\n\nNotes:\n$combinedText',
        );
        final pdfBytes = await PdfExporter.generateStudyGuidePdf(
          title: '$title Study Guide',
          subject: title,
          content: synthesized,
          style: pdfStyle,
        );
        final styleTag = pdfStyle == PdfStudyStyle.handwritten
            ? 'Handwritten_Notebook'
            : (pdfStyle == PdfStudyStyle.minimalCute
                ? 'Minimal_Cute'
                : (pdfStyle == PdfStudyStyle.zenPaperInk ? 'Zen_Ink' : 'Modern'));
        final fileName = '${safeBase}_${styleTag}_Study_Guide.pdf';
        final outFile = File('${dir.path}/$fileName');
        await outFile.writeAsBytes(pdfBytes, flush: true);

        if (DriveService.instance.isSignedIn) {
          try {
            await DriveService.instance.uploadFile(outFile, customName: fileName, subject: title, section: 'Notes');
          } catch (_) {}
        }

        if (mounted) {
          await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
        }
      } else if (format == 'docx') {
        final synthesized = await aiRouter.executeHeavyReasoning(
          prompt: 'Create a structured, comprehensive Word study guide for "$title". Use clear headings (#, ##) and bullet points (- ).\n\nNotes:\n$combinedText',
        );
        final docBytes = DocxExporter.createDocument(
          title: '$title Study Guide',
          subject: title,
          content: synthesized,
        );
        final fileName = '${safeBase}_Study_Guide.docx';
        final outFile = File('${dir.path}/$fileName');
        await outFile.writeAsBytes(docBytes, flush: true);

        bool uploadedToDrive = false;
        if (DriveService.instance.isSignedIn) {
          try {
            await DriveService.instance.uploadFile(outFile, customName: fileName, subject: title, section: 'Notes');
            uploadedToDrive = true;
          } catch (_) {}
        }

        final openRes = await OpenFilex.open(outFile.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                openRes.type == ResultType.done
                    ? 'Saved & opened $fileName${uploadedToDrive ? ' (synced to Drive)' : ''}'
                    : 'Saved $fileName${uploadedToDrive ? ' & synced to Drive' : ''} (${openRes.message})',
              ),
            ),
          );
        }
      } else if (format == 'pptx') {
        final styleKey = chosenStyle ?? OfflineCacheService.getPreferredPptxStyle();
        PptxStudyStyle pptxStyle;
        if (styleKey == 'handwrittenNotebook') {
          pptxStyle = PptxStudyStyle.handwrittenNotebook;
        } else if (styleKey == 'zenPaperInk') {
          pptxStyle = PptxStudyStyle.zenPaperInk;
        } else if (styleKey == 'modernHighYield') {
          pptxStyle = PptxStudyStyle.modernHighYield;
        } else {
          pptxStyle = PptxStudyStyle.minimalCute;
        }

        final rawSlides = await aiRouter.executeHeavyReasoning(
          prompt: 'Create a 6 to 8 slide study presentation for "$title" from these notes. Return ONLY a valid JSON array where each element has {"title": "Slide title", "bullets": ["concise point 1", "concise point 2", "concise point 3"]}.\n\nNotes:\n$combinedText',
        );
        final slides = _parseSlidesFromAi(rawSlides, '$title Overview');
        final pptxBytes = PptxExporter.createPresentation(
          presentationTitle: '$title Slides',
          slides: slides,
          style: pptxStyle,
        );
        final styleTag = pptxStyle == PptxStudyStyle.minimalCute
            ? 'Cute_Minimal'
            : (pptxStyle == PptxStudyStyle.handwrittenNotebook
                ? 'Handwritten_Notebook'
                : (pptxStyle == PptxStudyStyle.zenPaperInk ? 'Zen_Ink' : 'Modern'));
        final fileName = '${safeBase}_${styleTag}_Slides.pptx';
        final outFile = File('${dir.path}/$fileName');
        await outFile.writeAsBytes(pptxBytes, flush: true);

        bool uploadedToDrive = false;
        if (DriveService.instance.isSignedIn) {
          try {
            await DriveService.instance.uploadFile(outFile, customName: fileName, subject: title, section: 'Notes');
            uploadedToDrive = true;
          } catch (_) {}
        }

        final openRes = await OpenFilex.open(outFile.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                openRes.type == ResultType.done
                    ? 'Saved & opened $fileName${uploadedToDrive ? ' (synced to Drive)' : ''}'
                    : 'Saved $fileName${uploadedToDrive ? ' & synced to Drive' : ''} (${openRes.message})',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${format.toUpperCase()} generation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingFormat = null);
    }
  }

  void _showExportStylePicker(String format) {
    final isPdf = format == 'pdf';
    final currentPref = isPdf
        ? OfflineCacheService.getPreferredPdfStyle()
        : OfflineCacheService.getPreferredPptxStyle();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final options = isPdf
            ? [
                {
                  'id': 'handwritten',
                  'title': 'Handwritten Cornell Notebook',
                  'desc': 'Warm cream paper, red margin line, yellow highlighter & sticky notes',
                  'icon': Icons.edit_note_rounded,
                  'accent': const Color(0xFFFBBF24),
                  'badge': '📝 NOTEBOOK',
                },
                {
                  'id': 'minimalCute',
                  'title': 'Study-Friendly Minimal Cute',
                  'desc': 'Soft pastel Sakura palette, rounded cards, floral & sparkle chips',
                  'icon': Icons.auto_awesome,
                  'accent': const Color(0xFFF472B6),
                  'badge': '🌸 CUTE',
                },
                {
                  'id': 'zenPaperInk',
                  'title': 'Zen Paper & Sumi Ink',
                  'desc': 'Traditional Washi paper, charcoal calligraphy & Vermilion Hanko seal',
                  'icon': Icons.brush_outlined,
                  'accent': const Color(0xFFE11D48),
                  'badge': '📜 ZEN INK',
                },
                {
                  'id': 'modernClean',
                  'title': 'Modern High-Yield',
                  'desc': 'Clean executive editorial layout with blue accents and crisp typography',
                  'icon': Icons.article_outlined,
                  'accent': const Color(0xFF38BDF8),
                  'badge': '⚡ HIGH-YIELD',
                },
              ]
            : [
                {
                  'id': 'minimalCute',
                  'title': 'Study-Friendly Minimal Cute',
                  'desc': 'Pastel Sakura cards, rounded bubble containers & aesthetic pill tags',
                  'icon': Icons.auto_awesome,
                  'accent': const Color(0xFFF472B6),
                  'badge': '🌸 CUTE DECK',
                },
                {
                  'id': 'handwrittenNotebook',
                  'title': 'Handwritten Cornell Notebook',
                  'desc': 'Warm cream notebook slides, red margin line, highlighter title strip',
                  'icon': Icons.edit_note_rounded,
                  'accent': const Color(0xFFFBBF24),
                  'badge': '📝 CORNELL',
                },
                {
                  'id': 'zenPaperInk',
                  'title': 'Zen Paper & Sumi Ink',
                  'desc': 'Washi parchment slide background, Sumi charcoal & Vermilion Hanko stamps',
                  'icon': Icons.brush_outlined,
                  'accent': const Color(0xFFE11D48),
                  'badge': '📜 ZEN INK',
                },
                {
                  'id': 'modernHighYield',
                  'title': 'Modern High-Yield (Dark Deck)',
                  'desc': 'Obsidian slate presentation deck, glowing cyan accents & structured cards',
                  'icon': Icons.slideshow_outlined,
                  'accent': const Color(0xFF38BDF8),
                  'badge': '⚡ EXECUTIVE',
                },
              ];

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPdf
                          ? Colors.redAccent.withOpacity(0.15)
                          : Colors.orangeAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.slideshow_rounded,
                      color: isPdf ? Colors.redAccent : Colors.orangeAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPdf ? 'Choose PDF Study Style' : 'Choose Presentation Deck Style',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Pick an aesthetic theme for your generated study material',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...options.map((opt) {
                final id = opt['id'] as String;
                final isSelected = currentPref == id;
                final accent = opt['accent'] as Color;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: isSelected
                        ? accent.withOpacity(0.12)
                        : Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (isPdf) {
                          await OfflineCacheService.savePreferredPdfStyle(id);
                        } else {
                          await OfflineCacheService.savePreferredPptxStyle(id);
                        }
                        if (mounted) setState(() {});
                        _exportStudyFile(format, chosenStyle: id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? accent : Colors.white10,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(opt['icon'] as IconData, color: accent, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        opt['title'] as String,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? accent : null,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: accent.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          opt['badge'] as String,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: accent,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    opt['desc'] as String,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                              color: isSelected ? accent : Colors.grey[600],
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _notebook?['title'] as String? ?? 'Subject';
    final syllabusFiles = OfflineCacheService.getNotebookDocuments(widget.notebookId, section: 'Syllabus');
    final notesFiles = OfflineCacheService.getNotebookDocuments(widget.notebookId, section: 'Notes');
    final booksFiles = OfflineCacheService.getNotebookDocuments(widget.notebookId, section: 'Books');
    final paperFiles = OfflineCacheService.getNotebookDocuments(widget.notebookId, section: 'Previous papers');
    final totalDocs = syllabusFiles.length + notesFiles.length + booksFiles.length + paperFiles.length;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(title, style: AppTypography.screenTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (val) async {
              if (val == 'rename') {
                _showRenameDialog();
              } else if (val == 'clear_chat') {
                ref.read(chatProvider(widget.notebookId).notifier).clearHistory();
              } else if (val == 'delete') {
                await OfflineCacheService.deleteNotebook(widget.notebookId);
                if (mounted) context.pop();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'clear_chat', child: Text('Clear Sage chat')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete subject', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.accentColor,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: context.accentColor,
          dividerColor: context.borderColor,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Sources'),
            Tab(text: 'Chat'),
            Tab(text: 'Study'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Sources Tab
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    if (totalDocs >= 2) ...[
                      AppInput(
                        controller: _sourceSearchCtrl,
                        hintText: 'Filter files in $title...',
                        prefixIcon: Icon(Icons.search, size: 18, color: context.textSecondary),
                        onChanged: (val) => setState(() => _sourceFilter = val.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildSectionCard('Syllabus', _filterFiles(syllabusFiles)),
                    const SizedBox(height: 12),
                    _buildSectionCard('Notes', _filterFiles(notesFiles)),
                    const SizedBox(height: 12),
                    _buildSectionCard('Books', _filterFiles(booksFiles)),
                    const SizedBox(height: 12),
                    _buildSectionCard('Previous papers', _filterFiles(paperFiles)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.bgColor,
                  border: Border(top: BorderSide(color: context.borderColor, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Write note',
                        icon: const Icon(Icons.edit_note_outlined, size: 20),
                        onPressed: () async {
                          await context.push('/note-editor?notebookId=${widget.notebookId}');
                          if (mounted) _loadNotebook();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppPrimaryButton(
                        label: 'Add files',
                        icon: const Icon(Icons.add, size: 20, color: Colors.white),
                        onPressed: _openAddFiles,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. Chat Tab (Live embedded Sage Chat strictly scoped to this subject)
          SageChatView(
            notebookId: widget.notebookId,
            subject: title,
          ),

          // 3. Study Tab
          ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              if (_exportingFormat != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GenerationProgressView(
                    compact: true,
                    title: 'Generating ${_exportingFormat!.toUpperCase()} for $title',
                    stages: const [
                      'Reading subject sources...',
                      'Synthesizing structured guide with Sage...',
                      'Building document file...',
                      'Opening & syncing to Drive...',
                    ],
                  ),
                ),
              ],
              AppListRow(
                leading: const AppIconBadge(icon: Icons.summarize_outlined, size: 38, iconSize: 19),
                title: 'Summary',
                subtitle: 'Ask Sage to summarize all uploaded sources',
                onTap: () => context.push(
                  '/chat?notebookId=${widget.notebookId}&scope=${Uri.encodeComponent(title)}&prompt=${Uri.encodeComponent('Create a comprehensive summary of all my $title sources.')}',
                ),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: const AppIconBadge(icon: Icons.style_outlined, size: 38, iconSize: 19),
                title: 'Flashcards',
                subtitle: 'Review or generate AI cards from $title',
                onTap: () => context.push('/flashcards?notebookId=${widget.notebookId}&subject=${Uri.encodeComponent(title)}'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: const AppIconBadge(icon: Icons.quiz_outlined, size: 38, iconSize: 19),
                title: 'Quiz',
                subtitle: 'Test yourself on your $title notes',
                onTap: () => context.push('/quiz?notebookId=${widget.notebookId}&subject=${Uri.encodeComponent(title)}'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: const AppIconBadge(icon: Icons.account_tree_outlined, size: 38, iconSize: 19),
                title: 'Mind map',
                subtitle: 'Generate visual concept hierarchy with AI',
                onTap: () => context.push('/mindmap?notebookId=${widget.notebookId}&topic=${Uri.encodeComponent(title)}'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: const AppIconBadge(icon: Icons.play_circle_outline, size: 38, iconSize: 19),
                title: 'Audio explainer',
                subtitle: 'Listen to a narrated walkthrough of $title',
                onTap: () => context.push('/explainer?notebookId=${widget.notebookId}&topic=${Uri.encodeComponent(title)}'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: _exportingFormat == 'pdf'
                    ? const SizedBox(width: 38, height: 38, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                    : const AppIconBadge(icon: Icons.picture_as_pdf_outlined, size: 38, iconSize: 19),
                title: _exportingFormat == 'pdf' ? 'Generating PDF...' : 'Make a PDF study sheet',
                subtitle: _exportingFormat == 'pdf'
                    ? 'Synthesizing sources into PDF...'
                    : 'Style: ${_getPdfStyleDisplayName(OfflineCacheService.getPreferredPdfStyle())}',
                onTap: _exportingFormat != null ? null : () => _showExportStylePicker('pdf'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: _exportingFormat == 'docx'
                    ? const SizedBox(width: 38, height: 38, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                    : const AppIconBadge(icon: Icons.description_outlined, size: 38, iconSize: 19),
                title: _exportingFormat == 'docx' ? 'Generating Word (.docx)...' : 'Make a Word document (.docx)',
                subtitle: 'Create an editable study guide for Word / Docs',
                onTap: _exportingFormat != null ? null : () => _exportStudyFile('docx'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: _exportingFormat == 'pptx'
                    ? const SizedBox(width: 38, height: 38, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                    : const AppIconBadge(icon: Icons.slideshow_outlined, size: 38, iconSize: 19),
                title: _exportingFormat == 'pptx' ? 'Generating Slides (.pptx)...' : 'Make a PowerPoint deck (.pptx)',
                subtitle: _exportingFormat == 'pptx'
                    ? 'Creating presentation slides...'
                    : 'Style: ${_getPptxStyleDisplayName(OfflineCacheService.getPreferredPptxStyle())}',
                onTap: _exportingFormat != null ? null : () => _showExportStylePicker('pptx'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterFiles(List<Map<String, dynamic>> files) {
    if (_sourceFilter.isEmpty) return files;
    return files
        .where((d) => (d['fileName'] as String? ?? '').toLowerCase().contains(_sourceFilter))
        .toList();
  }

  Widget _buildSectionCard(String sectionName, List<Map<String, dynamic>> files) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$sectionName (${files.length})',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary),
              ),
              InkWell(
                onTap: () => _openAddFiles(initialSection: sectionName),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: context.accentColor),
                      const SizedBox(width: 2),
                      Text(
                        'Add',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.accentColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (files.isEmpty)
            const Text('No files added yet', style: AppTypography.secondary)
          else
            ...files.map((doc) {
              final fName = doc['fileName'] as String? ?? 'Document';
              final hasDrive = doc['driveFileId'] != null;
              return InkWell(
                onTap: () => _showDocumentViewer(doc),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file_outlined, size: 18, color: context.accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: context.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasDrive ? 'Drive' : 'Saved',
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: context.textSecondary),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
