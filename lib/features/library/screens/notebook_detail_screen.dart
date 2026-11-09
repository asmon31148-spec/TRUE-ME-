import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../upload/widgets/add_files_sheet.dart';

class NotebookDetailScreen extends StatefulWidget {
  final String notebookId;

  const NotebookDetailScreen({super.key, required this.notebookId});

  @override
  State<NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends State<NotebookDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic>? _notebook;

  // 4 Standard sections in fixed order
  final List<String> _syllabusFiles = ['Microbiology_syllabus.pdf'];
  final List<String> _notesFiles = ['Lecture_01_intro.pdf', 'Gram_stain_notes.pdf'];
  final List<String> _booksFiles = ['Prescott_Microbiology.pdf', 'Jawetz_Microbiology.pdf'];
  final List<String> _paperFiles = ['Microbio_2023_QP.pdf', 'Microbio_2022_QP.pdf'];

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
    _tabController.dispose();
    super.dispose();
  }

  void _openAddFiles() {
    final title = _notebook?['title'] as String? ?? 'Subject';
    AddFilesSheet.show(
      context,
      subjectName: title,
      onFileAdded: (fileName, section) {
        setState(() {
          if (section == 'Syllabus') _syllabusFiles.add(fileName);
          if (section == 'Notes') _notesFiles.add(fileName);
          if (section == 'Books') _booksFiles.add(fileName);
          if (section == 'Previous papers') _paperFiles.add(fileName);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _notebook?['title'] as String? ?? 'Microbiology';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: AppTypography.screenTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (val) {
              if (val == 'delete') {
                OfflineCacheService.deleteNotebook(widget.notebookId);
                context.pop();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'remove', child: Text('Remove from app')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete from app and Drive', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
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
                    _buildSectionCard('Syllabus', _syllabusFiles),
                    const SizedBox(height: 12),
                    _buildSectionCard('Notes', _notesFiles),
                    const SizedBox(height: 12),
                    _buildSectionCard('Books', _booksFiles),
                    const SizedBox(height: 12),
                    _buildSectionCard('Previous papers', _paperFiles),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Pinned Primary "Add files" Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: AppPrimaryButton(
                  label: 'Add files',
                  onPressed: _openAddFiles,
                ),
              ),
            ],
          ),

          // 2. Chat Tab (Limited to this subject)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'Ask Sage about $title',
                    style: AppTypography.sectionHeading,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Answers are grounded directly in your syllabus and notes.',
                    textAlign: TextAlign.center,
                    style: AppTypography.secondary,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 160,
                    child: AppPrimaryButton(
                      label: 'Open Chat',
                      onPressed: () => context.push('/chat?subject=$title'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Study Tab
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              AppListRow(
                leading: const Icon(Icons.summarize_outlined, size: 22, color: AppColors.textPrimary),
                title: 'Summary',
                subtitle: 'Key concepts across all sources',
                onTap: () => context.push('/chat?prompt=Summarize%20$title'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: const Icon(Icons.style_outlined, size: 22, color: AppColors.textPrimary),
                title: 'Flashcards',
                subtitle: 'Active recall for $title',
                onTap: () => context.push('/flashcards'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: const Icon(Icons.quiz_outlined, size: 22, color: AppColors.textPrimary),
                title: 'Quiz',
                subtitle: 'Practice questions from your notes',
                onTap: () => context.push('/quiz'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: const Icon(Icons.account_tree_outlined, size: 22, color: AppColors.textPrimary),
                title: 'Mind map',
                subtitle: 'Visual concept hierarchy',
                onTap: () => context.push('/mindmap'),
              ),
              const SizedBox(height: 10),
              AppListRow(
                leading: const Icon(Icons.picture_as_pdf_outlined, size: 22, color: AppColors.textPrimary),
                title: 'Make a PDF',
                subtitle: 'Export formatted study sheet',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Study sheet PDF generated in True Me folder.')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String sectionName, List<String> files) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$sectionName (${files.length} ${files.length == 1 ? 'file' : 'files'})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              if (files.length > 3)
                Text('See all', style: AppTypography.smallLabel.copyWith(color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 10),
          if (files.isEmpty)
            const Text('No files yet', style: AppTypography.secondary)
          else
            ...files.take(3).map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Synced',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
