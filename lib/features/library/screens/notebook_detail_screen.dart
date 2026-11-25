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
import '../../../features/export/widgets/export_studio_sheet.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/generation_progress_view.dart';
import '../../../shared/widgets/true_me_ui.dart';
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
        title: const Text('Rename Subject', style: AppTypography.sectionHeading),
        content: AppInput(controller: ctrl, autofocus: true, hintText: 'Subject name'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(90, 42)),
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
        title: const Text('Rename File', style: AppTypography.sectionHeading),
        content: AppInput(controller: ctrl, autofocus: true, hintText: 'File name'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(90, 42)),
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
    final String fileName = doc['fileName'] as String? ?? 'Document';
    String section = doc['section'] as String? ?? 'Notes';
    final content = doc['content'] as String? ?? '';
    final docId = doc['id'] as String? ?? '';
    final title = _notebook?['title'] as String? ?? 'Subject';
    const sections = ['Syllabus', 'Notes', 'Books', 'Previous papers'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.74,
          maxChildSize: 0.94,
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
                          Text(
                            fileName,
                            style: AppTypography.sectionHeading,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('$section · ${content.length} characters', style: AppTypography.smallLabel),
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
                      const Text('Section: ', style: AppTypography.smallLabel),
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
                const SizedBox(height: 14),
                TrueMePrimaryButton(
                  label: 'Ask Sage About This File',
                  onPressed: () {
                    Navigator.pop(ctx);
                    final q = Uri.encodeComponent('Explain the key points from "$fileName"');
                    context.push(
                      '/chat?notebookId=${widget.notebookId}&scope=${Uri.encodeComponent(title)}&prompt=$q',
                    );
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
      case 'minimalCute':
        return 'Minimal Cute';
      case 'zenPaperInk':
        return 'Zen Paper & Ink';
      case 'modernClean':
        return 'Modern High-Yield';
      case 'handwritten':
      default:
        return 'Handwritten Cornell Notebook';
    }
  }

  String _getPptxStyleDisplayName(String id) {
    switch (id) {
      case 'handwrittenNotebook':
        return 'Cornell Notebook';
      case 'zenPaperInk':
        return 'Zen Paper & Ink';
      case 'modernHighYield':
        return 'Modern High-Yield';
      case 'minimalCute':
      default:
        return 'Minimal Cute Deck';
    }
  }

  Future<void> _launchExportStudio(String format) async {
    final title = _notebook?['title'] as String? ?? 'Subject';
    final combinedText = OfflineCacheService.getNotebookCombinedText(widget.notebookId);
    if (combinedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one file or note before exporting.')),
      );
      return;
    }

    final cfg = await ExportStudioSheet.show(
      context,
      format: format,
      subjectName: title,
    );
    if (cfg == null) return;
    await _exportStudyFile(
      format: cfg.format,
      chosenStyle: cfg.styleId,
      customDocTitle: cfg.documentTitle,
      slideCount: cfg.slideCount,
    );
  }

  Future<void> _exportStudyFile({
    required String format,
    String? chosenStyle,
    String? customDocTitle,
    int slideCount = 8,
  }) async {
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
          prompt:
              'Create a structured, high-yield exam study guide summarizing these notes for "$title". Use clear markdown headings (#, ##) and bullet points (- ).\n\nNotes:\n$combinedText',
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
        final docHeading = (customDocTitle != null && customDocTitle.trim().isNotEmpty)
            ? customDocTitle.trim()
            : '$title Study Guide';
        final synthesized = await aiRouter.executeHeavyReasoning(
          prompt:
              'Create a structured, comprehensive Word study guide titled "$docHeading" for "$title". Use clear headings (#, ##) and bullet points (- ).\n\nNotes:\n$combinedText',
        );
        final docBytes = DocxExporter.createDocument(
          title: docHeading,
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
          prompt:
              'Create a $slideCount-slide study presentation for "$title" from these notes. Return ONLY a valid JSON array where each element has {"title": "Slide title", "bullets": ["concise point 1", "concise point 2", "concise point 3"]}.\n\nNotes:\n$combinedText',
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

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final title = _notebook?['title'] as String? ?? 'Subject';
    final syllabusFiles = OfflineCacheService.getNotebookDocuments(widget.notebookId, section: 'Syllabus');
    final notesFiles = OfflineCacheService.getNotebookDocuments(widget.notebookId, section: 'Notes');
    final booksFiles = OfflineCacheService.getNotebookDocuments(widget.notebookId, section: 'Books');
    final paperFiles = OfflineCacheService.getNotebookDocuments(widget.notebookId, section: 'Previous papers');
    final totalDocs = syllabusFiles.length + notesFiles.length + booksFiles.length + paperFiles.length;
    final pastel = SubjectPastelStyle.forSubject(title, isDark: isDark);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Editorial Header Bar
              TrueMeTopBar(
                title: title,
                onBack: () => context.pop(),
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz_rounded, size: 22, color: context.textPrimary),
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
                    PopupMenuItem(value: 'rename', child: Text('Rename Subject')),
                    PopupMenuItem(value: 'clear_chat', child: Text('Clear Sage Chat')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Subject', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ),

              // Pill Segmented Tab Bar: Sources | Chat | Study
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: context.borderColor),
                    boxShadow: context.cardShadow,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      gradient: AppColors.indigoButtonGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: context.textSecondary,
                    labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(text: 'Sources'),
                      Tab(text: 'Chat'),
                      Tab(text: 'Study'),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. Sources Tab
                    Column(
                      children: [
                        Expanded(
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                              _buildSectionCard('Syllabus', _filterFiles(syllabusFiles), pastel),
                              const SizedBox(height: 12),
                              _buildSectionCard('Notes', _filterFiles(notesFiles), pastel),
                              const SizedBox(height: 12),
                              _buildSectionCard('Books', _filterFiles(booksFiles), pastel),
                              const SizedBox(height: 12),
                              _buildSectionCard('Previous papers', _filterFiles(paperFiles), pastel),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: AppSecondaryButton(
                                  label: 'Write Note',
                                  height: 48,
                                  icon: const Icon(Icons.edit_note_outlined, size: 19),
                                  onPressed: () async {
                                    await context.push('/note-editor?notebookId=${widget.notebookId}');
                                    if (mounted) _loadNotebook();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TrueMePrimaryButton(
                                  label: 'Add Files',
                                  height: 48,
                                  leadingIcon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                                  onPressed: _openAddFiles,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 2. Chat Tab
                    SageChatView(
                      notebookId: widget.notebookId,
                      subject: title,
                    ),

                    // 3. Study Tab (Tools + Export Studio Launchers)
                    ListView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                        TrueMeSectionHeader(title: 'Active Learning'),
                        const SizedBox(height: 10),
                        AppListRow(
                          leading: AppIconBadge(
                            icon: Icons.summarize_outlined,
                            color: context.accentColor,
                            backgroundColor: isDark ? AppColors.darkAccentWash : AppColors.accentWash,
                          ),
                          title: 'Summary',
                          subtitle: 'Ask Sage to summarize all uploaded sources',
                          onTap: () => context.push(
                            '/chat?notebookId=${widget.notebookId}&scope=${Uri.encodeComponent(title)}&prompt=${Uri.encodeComponent('Create a comprehensive summary of all my $title sources.')}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppListRow(
                          leading: AppIconBadge(
                            icon: Icons.style_outlined,
                            color: isDark ? AppColors.darkWarning : AppColors.pastelAmberInk,
                            backgroundColor: isDark ? const Color(0xFF2B2110) : AppColors.pastelAmber,
                          ),
                          title: 'Flashcards',
                          subtitle: 'Review or generate AI cards from $title',
                          onTap: () => context.push(
                            '/flashcards?notebookId=${widget.notebookId}&subject=${Uri.encodeComponent(title)}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppListRow(
                          leading: AppIconBadge(
                            icon: Icons.quiz_outlined,
                            color: isDark ? const Color(0xFF60A5FA) : AppColors.pastelBlueInk,
                            backgroundColor: isDark ? const Color(0xFF11233D) : AppColors.pastelBlue,
                          ),
                          title: 'Quiz',
                          subtitle: 'Test yourself on your $title notes',
                          onTap: () => context.push(
                            '/quiz?notebookId=${widget.notebookId}&subject=${Uri.encodeComponent(title)}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppListRow(
                          leading: AppIconBadge(
                            icon: Icons.account_tree_outlined,
                            color: isDark ? const Color(0xFFC4B5FD) : AppColors.pastelLavenderInk,
                            backgroundColor: isDark ? const Color(0xFF241938) : AppColors.pastelLavender,
                          ),
                          title: 'Mind Map',
                          subtitle: 'Generate visual concept hierarchy with AI',
                          onTap: () => context.push(
                            '/mindmap?notebookId=${widget.notebookId}&topic=${Uri.encodeComponent(title)}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppListRow(
                          leading: AppIconBadge(
                            icon: Icons.play_circle_outline,
                            color: isDark ? AppColors.darkSuccess : AppColors.pastelGreenInk,
                            backgroundColor: isDark ? const Color(0xFF0E2922) : AppColors.pastelGreen,
                          ),
                          title: 'Audio Explainer',
                          subtitle: 'Listen to a narrated walkthrough of $title',
                          onTap: () => context.push(
                            '/explainer?notebookId=${widget.notebookId}&topic=${Uri.encodeComponent(title)}',
                          ),
                        ),
                        const SizedBox(height: 22),

                        TrueMeSectionHeader(title: 'Export Study Studio'),
                        const SizedBox(height: 10),
                        AppListRow(
                          leading: _exportingFormat == 'pdf'
                              ? const SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Center(
                                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                )
                              : AppIconBadge(
                                  icon: Icons.picture_as_pdf_outlined,
                                  color: AppColors.error,
                                  backgroundColor: isDark ? const Color(0xFF321822) : AppColors.pastelRose,
                                ),
                          title: _exportingFormat == 'pdf' ? 'Generating PDF...' : 'Export to PDF Study Sheet',
                          subtitle: _exportingFormat == 'pdf'
                              ? 'Synthesizing sources into PDF...'
                              : 'Style: ${_getPdfStyleDisplayName(OfflineCacheService.getPreferredPdfStyle())}',
                          onTap: _exportingFormat != null ? null : () => _launchExportStudio('pdf'),
                        ),
                        const SizedBox(height: 10),
                        AppListRow(
                          leading: _exportingFormat == 'docx'
                              ? const SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Center(
                                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                )
                              : AppIconBadge(
                                  icon: Icons.description_outlined,
                                  color: isDark ? const Color(0xFF60A5FA) : AppColors.pastelBlueInk,
                                  backgroundColor: isDark ? const Color(0xFF11233D) : AppColors.pastelBlue,
                                ),
                          title: _exportingFormat == 'docx' ? 'Generating Word (.docx)...' : 'Export to Word (.docx)',
                          subtitle: 'Editable study guide for Word & Docs',
                          onTap: _exportingFormat != null ? null : () => _launchExportStudio('docx'),
                        ),
                        const SizedBox(height: 10),
                        AppListRow(
                          leading: _exportingFormat == 'pptx'
                              ? const SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Center(
                                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                )
                              : AppIconBadge(
                                  icon: Icons.slideshow_outlined,
                                  color: isDark ? AppColors.darkWarning : AppColors.pastelAmberInk,
                                  backgroundColor: isDark ? const Color(0xFF2B2110) : AppColors.pastelAmber,
                                ),
                          title: _exportingFormat == 'pptx' ? 'Generating Slides (.pptx)...' : 'Export to PowerPoint (.pptx)',
                          subtitle: _exportingFormat == 'pptx'
                              ? 'Creating presentation slides...'
                              : 'Style: ${_getPptxStyleDisplayName(OfflineCacheService.getPreferredPptxStyle())}',
                          onTap: _exportingFormat != null ? null : () => _launchExportStudio('pptx'),
                        ),
                        const SizedBox(height: 24),
                      ],
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

  List<Map<String, dynamic>> _filterFiles(List<Map<String, dynamic>> files) {
    if (_sourceFilter.isEmpty) return files;
    return files
        .where((d) => (d['fileName'] as String? ?? '').toLowerCase().contains(_sourceFilter))
        .toList();
  }

  Widget _buildSectionCard(String sectionName, List<Map<String, dynamic>> files, SubjectPastelStyle pastel) {
    return TrueMeCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$sectionName (${files.length})',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              TrueMeTonalPill(
                label: 'Add',
                icon: Icons.add_rounded,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                onTap: () => _openAddFiles(initialSection: sectionName),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (files.isEmpty)
            Text('No files added yet', style: AppTypography.secondary.copyWith(color: context.textSecondary))
          else
            ...files.map((doc) {
              final fName = doc['fileName'] as String? ?? 'Document';
              final hasDrive = doc['driveFileId'] != null;
              return InkWell(
                onTap: () => _showDocumentViewer(doc),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: pastel.bgEnd,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(Icons.insert_drive_file_outlined, size: 17, color: pastel.accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: context.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TrueMeTonalPill(
                        label: hasDrive ? 'Drive' : 'Local',
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 18, color: context.textSecondary),
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
