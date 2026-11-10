import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../features/export/pdf_exporter.dart';
import '../../../shared/widgets/app_components.dart';
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
  bool _isGeneratingPdf = false;

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
                        await OfflineCacheService.removeDocumentFromNotebook(widget.notebookId, docId);
                        _loadNotebook();
                        if (ctx.mounted) Navigator.pop(ctx);
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

  Future<void> _exportRealPdf() async {
    final title = _notebook?['title'] as String? ?? 'Study Guide';
    final combinedText = OfflineCacheService.getNotebookCombinedText(widget.notebookId);
    if (combinedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one file or note before exporting a PDF.')),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);
    try {
      final aiRouter = ref.read(aiRouterProvider);
      final synthesized = await aiRouter.executeHeavyReasoning(
        prompt: 'Create a structured, high-yield exam study guide summarizing these notes for "$title". Use clear sections and bullet points.\n\nNotes:\n$combinedText',
      );

      final pdfBytes = await PdfExporter.generateStudyGuidePdf(
        title: '$title Study Guide',
        subject: title,
        content: synthesized,
      );

      if (mounted) {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: '${title.replaceAll(' ', '_')}_Study_Guide.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF generation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
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
              } else if (val == 'delete') {
                await OfflineCacheService.deleteNotebook(widget.notebookId);
                if (mounted) context.pop();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
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
          indicatorSize: TabBarIndicatorSize.tab,
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

          // 2. Chat Tab (Grounded directly in this subject's uploaded sources)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ask Sage about $title', style: AppTypography.sectionHeading),
                const SizedBox(height: 6),
                Text(
                  totalDocs > 0
                      ? 'Grounded in your $totalDocs uploaded source${totalDocs == 1 ? '' : 's'}.'
                      : 'Add files in Sources so Sage can cite your syllabus and notes directly.',
                  style: AppTypography.secondary,
                ),
                const SizedBox(height: 20),
                const Text('Quick actions', style: AppTypography.smallLabel),
                const SizedBox(height: 8),
                AppListRow(
                  leading: Icon(Icons.summarize_outlined, size: 20, color: context.accentColor),
                  title: 'Summarize my $title sources',
                  onTap: () => context.push(
                    '/chat?notebookId=${widget.notebookId}&scope=${Uri.encodeComponent(title)}&prompt=${Uri.encodeComponent('Summarize the key concepts from my $title notes.')}',
                  ),
                ),
                const SizedBox(height: 8),
                AppListRow(
                  leading: Icon(Icons.lightbulb_outline, size: 20, color: context.accentColor),
                  title: 'Explain important exam topics',
                  onTap: () => context.push(
                    '/chat?notebookId=${widget.notebookId}&scope=${Uri.encodeComponent(title)}&prompt=${Uri.encodeComponent('What are the most important exam topics in $title?')}',
                  ),
                ),
                const Spacer(),
                AppPrimaryButton(
                  label: 'Open Sage Chat',
                  onPressed: () => context.push(
                    '/chat?notebookId=${widget.notebookId}&scope=${Uri.encodeComponent(title)}',
                  ),
                ),
              ],
            ),
          ),

          // 3. Study Tab
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              AppListRow(
                leading: Icon(Icons.summarize_outlined, size: 22, color: context.textPrimary),
                title: 'Summary',
                subtitle: 'Ask Sage to summarize all uploaded sources',
                onTap: () => context.push(
                  '/chat?notebookId=${widget.notebookId}&scope=${Uri.encodeComponent(title)}&prompt=${Uri.encodeComponent('Create a comprehensive summary of all my $title sources.')}',
                ),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: Icon(Icons.style_outlined, size: 22, color: context.textPrimary),
                title: 'Flashcards',
                subtitle: 'Review or generate AI cards from $title',
                onTap: () => context.push('/flashcards?notebookId=${widget.notebookId}&subject=${Uri.encodeComponent(title)}'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: Icon(Icons.quiz_outlined, size: 22, color: context.textPrimary),
                title: 'Quiz',
                subtitle: 'Test yourself on your $title notes',
                onTap: () => context.push('/quiz?notebookId=${widget.notebookId}&subject=${Uri.encodeComponent(title)}'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: Icon(Icons.account_tree_outlined, size: 22, color: context.textPrimary),
                title: 'Mind map',
                subtitle: 'Generate visual concept hierarchy with AI',
                onTap: () => context.push('/mindmap?notebookId=${widget.notebookId}&topic=${Uri.encodeComponent(title)}'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: Icon(Icons.play_circle_outline, size: 22, color: context.textPrimary),
                title: 'Audio explainer',
                subtitle: 'Listen to a narrated walkthrough of $title',
                onTap: () => context.push('/explainer?notebookId=${widget.notebookId}&topic=${Uri.encodeComponent(title)}'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: _isGeneratingPdf
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.picture_as_pdf_outlined, size: 22, color: context.textPrimary),
                title: _isGeneratingPdf ? 'Generating PDF...' : 'Make a PDF study sheet',
                subtitle: 'Synthesize sources into a shareable PDF guide',
                onTap: _isGeneratingPdf ? null : _exportRealPdf,
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
