import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/rag_service.dart';
import '../../../core/ai/syllabus_service.dart';
import '../../../core/models/ingestion_models.dart';
import '../../../core/services/ingestion_job_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../features/export/screens/document_viewer_screen.dart';
import '../../../features/export/services/generation_job_service.dart';
import '../../../features/export/widgets/style_picker_sheet.dart';
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
  String _artifactFilter = 'all'; // 'all', 'pdf', 'docx', 'pptx'
  bool _showAllArtifacts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotebook();
    IngestionJobService.addCompletionListener(_onIngestionComplete);
  }

  void _onIngestionComplete() {
    if (mounted) _loadNotebook();
  }

  void _loadNotebook() {
    final nb = OfflineCacheService.getCachedNotebook(widget.notebookId);
    setState(() => _notebook = nb);
  }

  @override
  void dispose() {
    IngestionJobService.removeCompletionListener(_onIngestionComplete);
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

  Future<void> _promptRenameArtifact(String artId, String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final newName = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Rename Study Material', style: AppTypography.sectionHeading),
        content: AppInput(controller: ctrl, autofocus: true, hintText: 'New title'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(90, 42)),
            onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await SyllabusService.renameArtifact(widget.notebookId, artId, newName);
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmDeleteArtifact(String artId, String title, String subject) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Study Material?'),
        content: Text(
          'Delete "$title"? This removes it from your Study Library, device storage, and MEGA Vault if backed up.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SyllabusService.deleteArtifact(widget.notebookId, artId, subject: subject);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "$title"')),
        );
      }
    }
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
                          await RagService().deleteDocumentChunks(
                            userId: OfflineCacheService.getUserId(),
                            notebookId: widget.notebookId,
                            fileName: fileName,
                          ).catchError((_) {});
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
                if (doc['ingestionStatus'] != null || doc['qualityReport'] != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: ctx.bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ctx.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Index Status: ${IngestionStatus.fromString(doc['ingestionStatus'] as String?).displayLabel}'
                                '${doc['chunksVerified'] != null ? ' · ${doc['chunksVerified']} chunks verified' : ''}',
                                style: AppTypography.smallLabel.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: ctx.textPrimary,
                                ),
                              ),
                            ),
                            if (content.trim().length >= 20)
                              TextButton.icon(
                                onPressed: () async {
                                  final res = await RagService().ingestDocumentWithVerification(
                                    userId: OfflineCacheService.getUserId(),
                                    notebookId: widget.notebookId,
                                    fileName: fileName,
                                    fullText: content,
                                    sectionLabel: section,
                                  );
                                  await OfflineCacheService.updateDocumentIngestionState(
                                    widget.notebookId,
                                    docId,
                                    ingestionStatus: res.status.name,
                                    chunksCount: res.chunksCreated,
                                    chunksVerified: res.chunksVerified,
                                    ingestionError: res.errorMessage,
                                  );
                                  _loadNotebook();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 15),
                                label: const Text('Re-index'),
                              ),
                          ],
                        ),
                        if (doc['qualityReport'] is Map &&
                            ((doc['qualityReport']['summaryMessage'] as String? ?? '').isNotEmpty))
                          Text(
                            doc['qualityReport']['summaryMessage'] as String,
                            style: AppTypography.smallLabel.copyWith(color: ctx.textSecondary),
                          ),
                        if ((doc['ingestionError'] as String? ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              doc['ingestionError'] as String,
                              style: AppTypography.smallLabel.copyWith(color: AppColors.error),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
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

  Future<void> _launchExportStudio(
    String format, {
    StudyToolScopeSelection? scope,
  }) async {
    final title = _notebook?['title'] as String? ?? 'Subject';
    final scopedText = (scope != null && (scope.sourceDocId != null || scope.sourceFileName != null))
        ? OfflineCacheService.getNotebookDocumentText(
            widget.notebookId,
            docId: scope.sourceDocId,
            fileName: scope.sourceFileName,
          )
        : OfflineCacheService.getNotebookCombinedText(widget.notebookId);

    if (scopedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No readable text in the selected source. Add notes or run OCR first.')),
      );
      return;
    }

    final style = await StylePickerSheet.show(context, format: format);
    if (style == null || !mounted) return;
    await _exportStudyFile(
      format: format,
      chosenStyle: style.id,
      customDocTitle: scope?.topicLabel.isNotEmpty == true ? scope!.topicLabel : '$title Study Guide',
      scopedText: scopedText,
      nodeId: scope?.nodeId,
      depthLevel: scope?.depthLevel ?? 'Course Level',
    );
  }

  Future<void> _exportStudyFile({
    required String format,
    String? chosenStyle,
    String? customDocTitle,
    String? scopedText,
    String? nodeId,
    String depthLevel = 'Course Level',
  }) async {
    final title = _notebook?['title'] as String? ?? 'Study Guide';
    final combinedText = scopedText ?? OfflineCacheService.getNotebookCombinedText(widget.notebookId);
    if (combinedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one file or note before exporting.')),
      );
      return;
    }

    setState(() => _exportingFormat = format);
    try {
      final aiRouter = ref.read(aiRouterProvider);
      final styleKey = chosenStyle ??
          (format == 'pptx'
              ? OfflineCacheService.getPreferredPptxStyle()
              : (format == 'docx'
                  ? 'elegant_academic_notes'
                  : OfflineCacheService.getPreferredPdfStyle()));

      final result = await GenerationJobService.runDurableJob(
        aiRouter: aiRouter,
        format: format,
        styleId: styleKey,
        subject: title,
        topic: customDocTitle ?? title,
        scopeLabel: customDocTitle ?? 'Full Subject Sources',
        notebookId: widget.notebookId,
        sourceContext: combinedText,
        nodeId: nodeId,
        depthLevel: depthLevel,
      );

      if (mounted && result != null) {
        await DocumentViewerScreen.open(
          context,
          filePath: result.filePath,
          title: result.title,
        );
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
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.all(3.5),
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
                              ValueListenableBuilder<List<IngestionJob>>(
                                valueListenable: IngestionJobService.jobsNotifier,
                                builder: (ctx, jobs, _) {
                                  final active = jobs
                                      .where((j) =>
                                          j.notebookId == widget.notebookId &&
                                          (j.status == IngestionJobStage.queued ||
                                              j.status == IngestionJobStage.running))
                                      .toList();
                                  if (active.isEmpty) return const SizedBox.shrink();
                                  final job = active.first;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TrueMeCard(
                                      borderRadius: 16,
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  value: job.progress > 0 ? job.progress : null,
                                                  color: context.accentColor,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  job.stageLabel,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: context.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${(job.progress * 100).round()}%',
                                                style: AppTypography.smallLabel.copyWith(
                                                  color: context.accentColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: job.progress,
                                              minHeight: 5,
                                              backgroundColor: context.borderColor.withValues(alpha: 0.4),
                                              color: context.accentColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
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
                        ValueListenableBuilder<List<GenerationJob>>(
                          valueListenable: GenerationJobService.jobsNotifier,
                          builder: (ctx, jobs, _) {
                            final running = jobs.where((j) =>
                                j.notebookId == widget.notebookId &&
                                j.status == GenerationJobStatus.running).toList();
                            final failed = jobs.where((j) =>
                                j.notebookId == widget.notebookId &&
                                j.status == GenerationJobStatus.failed).toList();

                            if (running.isEmpty && failed.isEmpty && _exportingFormat == null) {
                              return const SizedBox.shrink();
                            }
                            if (running.isNotEmpty || _exportingFormat != null) {
                              final job = running.isNotEmpty ? running.first : null;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: GenerationProgressView(
                                  compact: true,
                                  title: job != null
                                      ? 'Generating ${job.format.toUpperCase()} · ${job.topic}'
                                      : 'Generating ${(_exportingFormat ?? 'doc').toUpperCase()} for $title',
                                  realStageIndex: job?.stageIndex ?? 0,
                                  realTotalStages: 7,
                                  realStageLabel: job?.stageLabel ?? 'Starting durable background job...',
                                  realProgress: job?.progress,
                                ),
                              );
                            }
                            final lastFailed = failed.first;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: TrueMeCard(
                                borderRadius: 16,
                                padding: const EdgeInsets.all(12),
                                borderColor: AppColors.error.withValues(alpha: 0.45),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${lastFailed.format.toUpperCase()} interrupted: ${lastFailed.topic}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                          ),
                                          Text(
                                            lastFailed.errorMessage ?? lastFailed.stageLabel,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TrueMeTonalPill(
                                      label: 'Retry',
                                      onTap: () => GenerationJobService.retryJob(
                                        lastFailed,
                                        ref.read(aiRouterProvider),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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
                                        if (scope != null && mounted) _launchExportStudio('pdf', scope: scope);
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
                                        if (scope != null && mounted) _launchExportStudio('docx', scope: scope);
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
                                        if (scope != null && mounted) _launchExportStudio('pptx', scope: scope);
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Builder(
                          builder: (ctx) {
                            final allArtifacts = SyllabusService.getArtifacts(widget.notebookId);
                            if (allArtifacts.isEmpty) return const SizedBox.shrink();
                            final pdfCount = allArtifacts
                                .where((a) => (a['artifactType']?.toString().toLowerCase() ?? '') == 'pdf')
                                .length;
                            final docxCount = allArtifacts
                                .where((a) => (a['artifactType']?.toString().toLowerCase() ?? '') == 'docx')
                                .length;
                            final pptxCount = allArtifacts
                                .where((a) => (a['artifactType']?.toString().toLowerCase() ?? '') == 'pptx')
                                .length;
                            final filteredArtifacts = _artifactFilter == 'all'
                                ? allArtifacts
                                : allArtifacts
                                    .where((a) =>
                                        (a['artifactType']?.toString().toLowerCase() ?? '') ==
                                        _artifactFilter)
                                    .toList();
                            final visibleArtifacts = _showAllArtifacts
                                ? filteredArtifacts
                                : filteredArtifacts.take(3).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TrueMeSectionHeader(
                                  title: 'Saved Study Materials (${allArtifacts.length})',
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    for (final entry in <(String, String, int)>[
                                      ('all', 'All', allArtifacts.length),
                                      if (pdfCount > 0) ('pdf', 'PDF', pdfCount),
                                      if (docxCount > 0) ('docx', 'Word', docxCount),
                                      if (pptxCount > 0) ('pptx', 'Slides', pptxCount),
                                    ])
                                      ChoiceChip(
                                        label: Text('${entry.$2} (${entry.$3})'),
                                        selected: _artifactFilter == entry.$1,
                                        selectedColor: context.accentColor.withValues(alpha: 0.16),
                                        onSelected: (_) => setState(() {
                                          _artifactFilter = entry.$1;
                                          _showAllArtifacts = false;
                                        }),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...visibleArtifacts.map((art) {
                                  final artId = art['id']?.toString() ??
                                      art['documentId']?.toString() ??
                                      '';
                                  final artTitle = art['title']?.toString() ?? 'Study Material';
                                  final artType = (art['artifactType']?.toString() ?? 'doc').toUpperCase();
                                  final path = art['filePath']?.toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: TrueMeCard(
                                      borderRadius: 16,
                                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                                      onTap: () async {
                                        if (path != null && File(path).existsSync()) {
                                          await DocumentViewerScreen.open(
                                            context,
                                            filePath: path,
                                            title: artTitle,
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('$artTitle ($artType)')),
                                          );
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          TrueMeTonalPill(
                                            label: artType,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  artTitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: context.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  art['topicLabel']?.toString() ?? title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: AppTypography.smallLabel
                                                      .copyWith(color: context.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert_rounded,
                                                size: 18, color: context.textSecondary),
                                            onSelected: (val) async {
                                              if (artId.isEmpty) return;
                                              if (val == 'rename') {
                                                await _promptRenameArtifact(artId, artTitle);
                                              } else if (val == 'delete') {
                                                await _confirmDeleteArtifact(artId, artTitle, title);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'rename',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 17),
                                                    SizedBox(width: 8),
                                                    Text('Rename'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline_rounded,
                                                        size: 17, color: AppColors.error),
                                                    SizedBox(width: 8),
                                                    Text('Delete',
                                                        style: TextStyle(color: AppColors.error)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                if (filteredArtifacts.length > 3)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          setState(() => _showAllArtifacts = !_showAllArtifacts),
                                      icon: Icon(
                                        _showAllArtifacts
                                            ? Icons.expand_less_rounded
                                            : Icons.expand_more_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _showAllArtifacts
                                            ? 'Show less'
                                            : 'Show all (${filteredArtifacts.length})',
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
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
              final rawStatus = doc['ingestionStatus'] as String?;
              final ingStatus = rawStatus != null
                  ? IngestionStatus.fromString(rawStatus)
                  : ((doc['content'] as String? ?? '').trim().length >= 20
                      ? IngestionStatus.partial
                      : IngestionStatus.needsOcr);
              final statusColor = ingStatus == IngestionStatus.searchable
                  ? AppColors.success
                  : (ingStatus == IngestionStatus.failed || ingStatus == IngestionStatus.needsOcr
                      ? AppColors.error
                      : context.accentColor);
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: context.textPrimary),
                            ),
                            Text(
                              ingStatus.displayLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
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
