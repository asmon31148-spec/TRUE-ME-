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
import '../../../core/ai/syllabus_service.dart';
import '../../../core/services/cloud_vault_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../features/export/docx_exporter.dart';
import '../../../features/export/pdf_exporter.dart';
import '../../../features/export/pptx_exporter.dart';
import '../../../features/export/widgets/export_studio_sheet.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/generation_progress_view.dart';
import '../../../shared/widgets/true_me_illustrations.dart';
import '../../../shared/widgets/true_me_ui.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/widgets/sage_chat_view.dart';
import '../../upload/widgets/add_files_sheet.dart';
import '../widgets/study_tool_sheet.dart';

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
        await SyllabusService.saveArtifact(
          notebookId: widget.notebookId,
          artifactType: 'pdf',
          title: '$title Study Guide',
          topicLabel: title,
          filePath: outFile.path,
        );

        if (CloudVaultService.isAnyVaultConnected) {
          try {
            await CloudVaultService.uploadFile(outFile, customName: fileName, subject: title, section: 'Notes');
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
        await SyllabusService.saveArtifact(
          notebookId: widget.notebookId,
          artifactType: 'docx',
          title: docHeading,
          topicLabel: title,
          filePath: outFile.path,
        );

        bool uploadedToVault = false;
        if (CloudVaultService.isAnyVaultConnected) {
          try {
            final res = await CloudVaultService.uploadFile(
              outFile,
              customName: fileName,
              subject: title,
              section: 'Notes',
            );
            uploadedToVault = res != null;
          } catch (_) {}
        }

        final openRes = await OpenFilex.open(outFile.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                openRes.type == ResultType.done
                    ? 'Saved & opened $fileName${uploadedToVault ? ' (backed up)' : ''}'
                    : 'Saved $fileName${uploadedToVault ? ' & backed up' : ''} (${openRes.message})',
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
        await SyllabusService.saveArtifact(
          notebookId: widget.notebookId,
          artifactType: 'pptx',
          title: '$title Slides',
          topicLabel: title,
          filePath: outFile.path,
        );

        bool uploadedToVault = false;
        if (CloudVaultService.isAnyVaultConnected) {
          try {
            final res = await CloudVaultService.uploadFile(
              outFile,
              customName: fileName,
              subject: title,
              section: 'Notes',
            );
            uploadedToVault = res != null;
          } catch (_) {}
        }

        final openRes = await OpenFilex.open(outFile.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                openRes.type == ResultType.done
                    ? 'Saved & opened $fileName${uploadedToVault ? ' (backed up)' : ''}'
                    : 'Saved $fileName${uploadedToVault ? ' & backed up' : ''} (${openRes.message})',
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

              // Borderless Milky Pill Segmented Tab Bar: Sources | Chat | Study
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.milkyFill,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      gradient: AppColors.indigoButtonGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
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

                    // 3. Study Tab (Redesigned Pastel Feature Cards + Export Studio Tiles)
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
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _StudyFeatureTile(
                              icon: Icons.summarize_rounded,
                              title: 'Summary',
                              subtitle: 'Key points & notes',
                              bgStart: isDark ? const Color(0xFF1D1B3B) : const Color(0xFFF3F1FF),
                              bgEnd: isDark ? const Color(0xFF26224C) : const Color(0xFFE4E0FD),
                              accent: context.accentColor,
                              onTap: () async {
                                final scope = await StudyToolSheet.show(
                                  context,
                                  notebookId: widget.notebookId,
                                  subject: title,
                                  artifactType: 'summary',
                                  toolTitle: 'Summary',
                                );
                                if (scope == null || !mounted) return;
                                final extra = scope.customInstructions.isNotEmpty
                                    ? ' Instructions: ${scope.customInstructions}'
                                    : '';
                                final src = scope.sourceFileName != null
                                    ? ' using "${scope.sourceFileName}"'
                                    : '';
                                final prompt =
                                    'Create a ${scope.depthLevel} summary for ${scope.topicLabel} in $title$src.$extra';
                                await SyllabusService.saveArtifact(
                                  notebookId: widget.notebookId,
                                  artifactType: 'summary',
                                  title: '${scope.topicLabel} Summary',
                                  nodeId: scope.nodeId,
                                  topicLabel: scope.topicLabel,
                                  depthLevel: scope.depthLevel,
                                );
                                if (!mounted) return;
                                context.push(
                                  '/chat?notebookId=${widget.notebookId}&scope=${Uri.encodeComponent(title)}&prompt=${Uri.encodeComponent(prompt)}',
                                );
                              },
                            ),
                            _StudyFeatureTile(
                              icon: Icons.style_rounded,
                              title: 'Flashcards',
                              subtitle: 'Spaced recall',
                              bgStart: isDark ? const Color(0xFF2B2110) : const Color(0xFFFFFAEB),
                              bgEnd: isDark ? const Color(0xFF382A14) : const Color(0xFFFEEEE0),
                              accent: isDark ? AppColors.darkWarning : AppColors.pastelAmberInk,
                              onTap: () => context.push(
                                '/flashcards?notebookId=${widget.notebookId}&subject=${Uri.encodeComponent(title)}',
                              ),
                            ),
                            _StudyFeatureTile(
                              icon: Icons.quiz_rounded,
                              title: 'Quiz',
                              subtitle: 'Practice questions',
                              bgStart: isDark ? const Color(0xFF11233D) : const Color(0xFFEEF7FF),
                              bgEnd: isDark ? const Color(0xFF172E50) : const Color(0xFFD9ECFE),
                              accent: isDark ? const Color(0xFF60A5FA) : AppColors.pastelBlueInk,
                              onTap: () => context.push(
                                '/quiz?notebookId=${widget.notebookId}&subject=${Uri.encodeComponent(title)}',
                              ),
                            ),
                            _StudyFeatureTile(
                              icon: Icons.hub_rounded,
                              title: 'Mind Map',
                              subtitle: 'Concept tree',
                              bgStart: isDark ? const Color(0xFF241938) : const Color(0xFFF6F1FF),
                              bgEnd: isDark ? const Color(0xFF2E2048) : const Color(0xFFEADFFD),
                              accent: isDark ? const Color(0xFFC4B5FD) : AppColors.pastelLavenderInk,
                              onTap: () async {
                                final scope = await StudyToolSheet.show(
                                  context,
                                  notebookId: widget.notebookId,
                                  subject: title,
                                  artifactType: 'mindmap',
                                  toolTitle: 'Mind Map',
                                );
                                if (scope == null || !mounted) return;
                                await SyllabusService.saveArtifact(
                                  notebookId: widget.notebookId,
                                  artifactType: 'mindmap',
                                  title: '${scope.topicLabel} Mind Map',
                                  nodeId: scope.nodeId,
                                  topicLabel: scope.topicLabel,
                                  depthLevel: scope.depthLevel,
                                );
                                if (!mounted) return;
                                context.push(
                                  '/mindmap?notebookId=${widget.notebookId}&topic=${Uri.encodeComponent(scope.topicLabel)}',
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Audio Explainer Studio Hero Banner
                        TrueMeCard(
                          borderRadius: 22,
                          padding: EdgeInsets.zero,
                          gradient: isDark ? AppColors.heroFocusDarkGradient : AppColors.heroFocusLightGradient,
                          onTap: () async {
                            final scope = await StudyToolSheet.show(
                              context,
                              notebookId: widget.notebookId,
                              subject: title,
                              artifactType: 'explainer',
                              toolTitle: 'Audio Explainer',
                            );
                            if (scope == null || !mounted) return;
                            await SyllabusService.saveArtifact(
                              notebookId: widget.notebookId,
                              artifactType: 'explainer',
                              title: '${scope.topicLabel} Explainer',
                              nodeId: scope.nodeId,
                              topicLabel: scope.topicLabel,
                              depthLevel: scope.depthLevel,
                            );
                            if (!mounted) return;
                            context.push(
                              '/explainer?notebookId=${widget.notebookId}&topic=${Uri.encodeComponent(scope.topicLabel)}',
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -12,
                                  top: 0,
                                  bottom: 0,
                                  width: 120,
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: ExplainerMicroscopePainter(isDark: isDark, pulse: 0.0),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 100, 16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.darkSurface
                                              : Colors.white.withValues(alpha: 0.90),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(Icons.headphones_rounded, color: context.accentColor),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Audio Explainer',
                                              style: AppTypography.cardTitle.copyWith(color: context.textPrimary),
                                            ),
                                            Text(
                                              'Narrated $title walkthrough',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        TrueMeSectionHeader(title: 'Export Study Studio'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ExportFormatButton(
                                label: _exportingFormat == 'pdf' ? 'Building...' : 'PDF Sheet',
                                subtitle: _getPdfStyleDisplayName(OfflineCacheService.getPreferredPdfStyle()),
                                icon: Icons.description_rounded,
                                accent: AppColors.accent,
                                bg: isDark ? AppColors.darkAccentWash : AppColors.milkyLavender,
                                isBusy: _exportingFormat == 'pdf',
                                onTap: _exportingFormat != null
                                    ? null
                                    : () async {
                                        final scope = await StudyToolSheet.show(
                                          context,
                                          notebookId: widget.notebookId,
                                          subject: title,
                                          artifactType: 'pdf',
                                          toolTitle: 'PDF Sheet',
                                        );
                                        if (scope != null && mounted) _launchExportStudio('pdf');
                                      },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ExportFormatButton(
                                label: _exportingFormat == 'docx' ? 'Building...' : 'Word (.docx)',
                                subtitle: 'Editable doc',
                                icon: Icons.article_rounded,
                                accent: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                bg: isDark ? const Color(0xFF11233D) : const Color(0xFFEAF3FF),
                                isBusy: _exportingFormat == 'docx',
                                onTap: _exportingFormat != null
                                    ? null
                                    : () async {
                                        final scope = await StudyToolSheet.show(
                                          context,
                                          notebookId: widget.notebookId,
                                          subject: title,
                                          artifactType: 'docx',
                                          toolTitle: 'Word Document',
                                        );
                                        if (scope != null && mounted) _launchExportStudio('docx');
                                      },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ExportFormatButton(
                                label: _exportingFormat == 'pptx' ? 'Building...' : 'Slides (.pptx)',
                                subtitle: _getPptxStyleDisplayName(OfflineCacheService.getPreferredPptxStyle()),
                                icon: Icons.slideshow_rounded,
                                accent: isDark ? AppColors.darkWarning : const Color(0xFFEA580C),
                                bg: isDark ? const Color(0xFF2B2110) : const Color(0xFFFFF2E6),
                                isBusy: _exportingFormat == 'pptx',
                                onTap: _exportingFormat != null
                                    ? null
                                    : () async {
                                        final scope = await StudyToolSheet.show(
                                          context,
                                          notebookId: widget.notebookId,
                                          subject: title,
                                          artifactType: 'pptx',
                                          toolTitle: 'Slides Deck',
                                        );
                                        if (scope != null && mounted) _launchExportStudio('pptx');
                                      },
                              ),
                            ),
                          ],
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

class _StudyFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgStart;
  final Color bgEnd;
  final Color accent;
  final VoidCallback onTap;

  const _StudyFeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bgStart,
    required this.bgEnd,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return TrueMeCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [bgStart, bgEnd],
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: accent),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.cardTitle.copyWith(fontSize: 16, color: context.textPrimary),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportFormatButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color bg;
  final bool isBusy;
  final VoidCallback? onTap;

  const _ExportFormatButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.bg,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TrueMeCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      color: bg,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.isDarkMode ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(13),
            ),
            child: isBusy
                ? const Center(
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Icon(icon, size: 21, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.smallLabel.copyWith(fontSize: 10.5, color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}
