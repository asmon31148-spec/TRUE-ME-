import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadNotebookData();
  }

  void _loadNotebookData() {
    final nb = OfflineCacheService.getCachedNotebook(widget.notebookId);
    setState(() {
      _notebook = nb;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Notebook', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this notebook? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await OfflineCacheService.deleteNotebook(widget.notebookId);
              if (mounted) {
                Navigator.pop(ctx);
                context.go('/library');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _notebook?['title'] as String? ?? 'Notebook Details';
    final subject = _notebook?['subject'] as String? ?? 'Study';
    final files = List<String>.from(_notebook?['fileRefs'] ?? const []);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: title,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppColors.surface,
            onSelected: (val) {
              if (val == 'import') {
                context.go('/upload');
              } else if (val == 'delete') {
                _confirmDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.add_to_photos, size: 18, color: AppColors.accentCyan),
                    SizedBox(width: 8),
                    Text('Add Document', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete Notebook', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Tab bar in glass container
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Documents'),
                Tab(text: 'Flashcards'),
                Tab(text: 'AI Chat'),
                Tab(text: 'Explainer'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Documents Tab
                files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.description_outlined, size: 48, color: Colors.white38),
                            const SizedBox(height: 12),
                            const Text('No documents added yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('Import lecture slides, PDFs, or photos into this notebook.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 16),
                            GlassButton(
                              isPrimary: true,
                              child: const Text('Add Document / Notes'),
                              onPressed: () => context.go('/upload'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: files.length,
                        itemBuilder: (context, idx) {
                          final fName = files[idx];
                          final isPdf = fName.toLowerCase().endsWith('.pdf');
                          final isAudio = fName.toLowerCase().endsWith('.m4a') || fName.toLowerCase().endsWith('.mp3');

                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            borderRadius: 18,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isPdf
                                        ? Icons.picture_as_pdf
                                        : isAudio
                                            ? Icons.mic
                                            : Icons.image,
                                    color: AppColors.accentCyan,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.titleLarge.copyWith(fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Grounded in local pgvector embeddings',
                                        style: AppTypography.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_horiz, color: Colors.white70),
                                  color: AppColors.surface,
                                  onSelected: (action) {
                                    if (action == 'chat') context.go('/chat');
                                    if (action == 'quiz') context.go('/quiz');
                                    if (action == 'cards') context.go('/flashcards');
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'chat',
                                      child: Text('Ask AI with this Doc', style: TextStyle(color: Colors.white)),
                                    ),
                                    const PopupMenuItem(
                                      value: 'quiz',
                                      child: Text('Generate Quiz', style: TextStyle(color: Colors.white)),
                                    ),
                                    const PopupMenuItem(
                                      value: 'cards',
                                      child: Text('Generate Flashcards', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // Flashcards Tab Preview
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.style_outlined, size: 54, color: AppColors.primaryLight),
                      const SizedBox(height: 16),
                      Text('Flashcard Decks for $subject', style: AppTypography.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('SuperMemo SM-2 spaced repetition active.', style: AppTypography.bodySmall),
                      const SizedBox(height: 20),
                      GlassButton(
                        isPrimary: true,
                        child: const Text('Start Review Session'),
                        onPressed: () => context.go('/flashcards'),
                      ),
                    ],
                  ),
                ),

                // AI Chat Tab Preview
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.psychology, size: 54, color: AppColors.accentCyan),
                      const SizedBox(height: 16),
                      Text('Chat with $title', style: AppTypography.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('Grounded in your lecture notes with citations.', style: AppTypography.bodySmall),
                      const SizedBox(height: 20),
                      GlassButton(
                        isPrimary: true,
                        child: const Text('Open Notebook RAG Chat'),
                        onPressed: () => context.go('/chat'),
                      ),
                    ],
                  ),
                ),

                // Explainer Tab Preview
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.movie_creation_outlined, size: 54, color: AppColors.secondary),
                      const SizedBox(height: 16),
                      const Text('10-Min Concept Video', style: AppTypography.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('Generates Flutter animated timelines + speech narration.', style: AppTypography.bodySmall),
                      const SizedBox(height: 20),
                      GlassButton(
                        isPrimary: true,
                        child: const Text('Watch Explainer Video'),
                        onPressed: () => context.go('/explainer'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
