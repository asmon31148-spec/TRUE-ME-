import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
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
  @override
  void initState() {
    super.initState();
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
            onPressed: () {},
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
                  const Text('Operating Systems & Calculus Focus', style: AppTypography.headlineMedium),
                  const SizedBox(height: 6),
                  const Text(
                    'Sage scheduled 2 review sessions today to prevent forgetting curve decay on deadlocks and eigenvalues.',
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

            // Quick Actions Strip
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
                TextButton.icon(
                  onPressed: () => context.go('/upload'),
                  icon: const Icon(Icons.add, size: 18, color: AppColors.accentCyan),
                  label: const Text('New', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notebook Cards
            _buildNotebookCard(
              context,
              title: 'Operating Systems & Concurrency',
              subject: 'Computer Science',
              fileCount: 4,
              color: AppColors.primary,
              tags: ['Deadlocks', 'Semaphores', 'Virtual Memory'],
            ),
            const SizedBox(height: 14),
            _buildNotebookCard(
              context,
              title: 'Multivariable Calculus & Linear Algebra',
              subject: 'Mathematics',
              fileCount: 3,
              color: AppColors.accent,
              tags: ['Eigenvalues', 'Stokes Theorem', 'Vector Fields'],
            ),
            const SizedBox(height: 14),
            _buildNotebookCard(
              context,
              title: 'Quantum Mechanics & Wave Theory',
              subject: 'Physics',
              fileCount: 5,
              color: AppColors.secondary,
              tags: ['Schrödinger Eq', 'Hamiltonian', 'State Vectors'],
            ),
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
            children: [
              Icon(icon, color: AppColors.accentCyan, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
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
    required String title,
    required String subject,
    required int fileCount,
    required Color color,
    required List<String> tags,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      onTap: () => context.go('/notebook/1'),
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
                  letterSpacing: 1.0,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '$fileCount files',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: AppTypography.titleLarge),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  t,
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
