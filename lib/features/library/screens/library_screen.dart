import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/update_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _studentName = 'Student';
  List<String> _userSubjects = ['Computer Science', 'Calculus', 'Physics'];
  List<Map<String, dynamic>> _notebooks = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNotebooks();
    // Check for in-app updates automatically in background
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final updateInfo = await UpdateService().checkForUpdate();
        if (updateInfo != null && updateInfo.hasUpdate && mounted) {
          UpdateService.showUpdateDialog(context: context, info: updateInfo);
        }
      } catch (_) {}
    });
  }

  void _loadUserData() {
    final name = OfflineCacheService.getUserName();
    final subs = OfflineCacheService.getUserSubjects();
    setState(() {
      _studentName = name;
      if (subs.isNotEmpty) _userSubjects = subs;
    });
  }

  void _loadNotebooks() {
    final list = OfflineCacheService.getAllCachedNotebooks();
    setState(() {
      _notebooks = list;
    });
  }

  void _showCreateNotebookDialog() {
    final titleController = TextEditingController();
    final subjectController = TextEditingController(text: _userSubjects.isNotEmpty ? _userSubjects.first : 'Computer Science');
    final tagController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Create Smart Notebook', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Notebook Title (e.g. Distributed Systems)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Subject (e.g. CS, Mathematics)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tags (comma-separated)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final title = titleController.text.trim();
              final subject = subjectController.text.trim();
              if (title.isEmpty) return;

              final tags = tagController.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();

              final newNotebook = {
                'id': 'nb_${DateTime.now().millisecondsSinceEpoch}',
                'userId': 'local_user',
                'title': title,
                'subject': subject.isNotEmpty ? subject : 'General',
                'colorValue': 0xFF06B6D4,
                'tags': tags.isNotEmpty ? tags : ['Study Notes'],
                'fileRefs': <String>[],
                'createdAt': DateTime.now().toIso8601String(),
                'lastModified': DateTime.now().toIso8601String(),
              };

              await OfflineCacheService.cacheNotebook(newNotebook['id'] as String, newNotebook);
              if (mounted) {
                Navigator.pop(ctx);
                _loadNotebooks();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Created notebook "$title"'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog() {
    final examDate = OfflineCacheService.getTargetExamDate();
    final daysRemaining = examDate.difference(DateTime.now()).inDays;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: AppColors.accentCyan),
            SizedBox(width: 10),
            Text('Study Notifications', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm, color: AppColors.warning),
              title: const Text('Exam Countdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('$daysRemaining days until your target exam date.', style: const TextStyle(color: Colors.white70)),
            ),
            const Divider(color: Colors.white12),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.psychology, color: AppColors.accentCyan),
              title: Text('Forgetting Curve Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('12 flashcards are due today for optimal retention.', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.accentCyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'True Me',
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.sageGlowGradient,
          ),
          child: const Icon(Icons.school, size: 20, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: AppColors.accentCyan),
            tooltip: 'Account Center',
            onPressed: () => context.push('/account-center'),
          ),
          IconButton(
            icon: const Icon(Icons.system_update_alt_rounded, color: AppColors.accentCyan),
            tooltip: 'Check for Updates',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Checking for latest True Me updates...'),
                  duration: Duration(seconds: 1),
                  backgroundColor: AppColors.surface,
                ),
              );
              final info = await UpdateService().checkForUpdate();
              if (!mounted) return;
              if (info != null && info.hasUpdate) {
                UpdateService.showUpdateDialog(context: context, info: info);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 True Me is up to date!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white70),
            tooltip: 'Notifications',
            onPressed: _showNotificationsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sage Daily Mission Glass Card
            GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              surfaceGradient: const LinearGradient(
                colors: [Color(0x336366F1), Color(0x1A0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'SAGE DAILY MISSION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.bolt, color: AppColors.warning, size: 18),
                      const SizedBox(width: 4),
                      const Text(
                        'Streak: 7 Days',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Hey $_studentName! 👋', style: AppTypography.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Sage scheduled 2 review sessions today to prevent forgetting curve decay on ${_userSubjects.take(2).join(" & ")}.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          height: 40,
                          isPrimary: true,
                          child: const Text(
                            'Daily Plan',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => context.go('/planner'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GlassButton(
                          height: 40,
                          child: const Text(
                            'Voice Tutor',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => context.go('/voice-tutor'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Quick Actions Strip (Responsive with FittedBox to eliminate overflow)
            Row(
              children: [
                _buildQuickAction(
                  context,
                  icon: Icons.chat_bubble_outline,
                  label: 'AI Chat',
                  route: '/chat',
                ),
                _buildQuickAction(
                  context,
                  icon: Icons.style_outlined,
                  label: 'Flashcards',
                  route: '/flashcards',
                ),
                _buildQuickAction(
                  context,
                  icon: Icons.quiz_outlined,
                  label: 'Quiz',
                  route: '/quiz',
                ),
                _buildQuickAction(
                  context,
                  icon: Icons.insights_outlined,
                  label: 'Dashboard',
                  route: '/dashboard',
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Smart Notebooks Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Smart Notebooks', style: AppTypography.headlineMedium),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/upload'),
                      icon: const Icon(Icons.file_upload_outlined, size: 16, color: AppColors.accentCyan),
                      label: const Text('Import', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    TextButton.icon(
                      onPressed: _showCreateNotebookDialog,
                      icon: const Icon(Icons.add, size: 18, color: AppColors.accentCyan),
                      label: const Text('New', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dynamic Notebook Cards from Hive Cache
            if (_notebooks.isEmpty) ...[
              GlassCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 20,
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.auto_stories_outlined, size: 48, color: Colors.white54),
                      const SizedBox(height: 12),
                      const Text('No notebooks yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Tap "+ New" or "Import" to add study materials.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 14),
                      GlassButton(
                        isPrimary: true,
                        child: const Text('Create First Notebook'),
                        onPressed: _showCreateNotebookDialog,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ..._notebooks.map((nb) {
                final id = nb['id'] as String? ?? '1';
                final title = nb['title'] as String? ?? 'Untitled';
                final subject = nb['subject'] as String? ?? 'General';
                final colorVal = (nb['colorValue'] as num?)?.toInt() ?? 0xFF6366F1;
                final tags = List<String>.from(nb['tags'] ?? const []);
                final files = List<String>.from(nb['fileRefs'] ?? const []);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildNotebookCard(
                    context,
                    notebookId: id,
                    title: title,
                    subject: subject,
                    fileCount: files.isNotEmpty ? files.length : (tags.length + 1),
                    color: Color(colorVal),
                    tags: tags,
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.go(route),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.accentCyan, size: 24),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotebookCard(
    BuildContext context, {
    required String notebookId,
    required String title,
    required String subject,
    required int fileCount,
    required Color color,
    required List<String> tags,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      onTap: () => context.go('/notebook/$notebookId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.6), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                subject.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '$fileCount files',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTypography.titleLarge),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
