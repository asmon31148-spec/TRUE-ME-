import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
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

  final List<Map<String, dynamic>> _files = const [
    {
      'title': 'Chapter 3 — Process Synchronization & Mutexes.pdf',
      'size': '4.2 MB',
      'pages': 42,
      'chunks': 86,
      'type': 'pdf',
    },
    {
      'title': 'Lecture 7 — Deadlock Prevention & Bankers Algorithm.m4a',
      'size': '18.4 MB',
      'duration': '48 mins',
      'chunks': 64,
      'type': 'audio',
    },
    {
      'title': 'Whiteboard Photo — Readers-Writers Lock Diagram.jpg',
      'size': '2.1 MB',
      'chunks': 12,
      'type': 'image',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Operating Systems',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
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
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _files.length,
                  itemBuilder: (context, idx) {
                    final f = _files[idx];
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
                              f['type'] == 'pdf'
                                  ? Icons.picture_as_pdf
                                  : f['type'] == 'audio'
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
                                  f['title'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleLarge.copyWith(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${f['size']} • ${f['chunks']} vector chunks indexed',
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
                      const Text('48 Cards in this Notebook', style: AppTypography.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('12 cards are due for SM-2 review today.', style: AppTypography.bodySmall),
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
                      const Text('Chat with Operating Systems', style: AppTypography.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('All 3 documents grounded with pgvector embeddings.', style: AppTypography.bodySmall),
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
