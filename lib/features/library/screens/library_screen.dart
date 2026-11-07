import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

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
            icon: const Icon(Icons.notifications_none, color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
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
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, color: AppColors.accentCyan, size: 14),
                            SizedBox(width: 6),
                            Text(
                              "SAGE'S MORNING BRIEF",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '45 days to Finals',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '"Hey Alex! Calculus Eigenvalues decay is down 18%. Let\'s spend 20 mins reviewing flashcards today."',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GlassButton(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        isPrimary: true,
                        child: const Text('Start Daily Plan (45m)'),
                        onPressed: () => context.go('/planner'),
                      ),
                      const SizedBox(width: 12),
                      GlassButton(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Text('Voice Tutor'),
                        onPressed: () => context.go('/voice-tutor'),
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
                  label: 'Adaptive Quiz',
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
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18, color: AppColors.primaryLight),
                  label: const Text('New', style: TextStyle(color: AppColors.primaryLight)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notebooks List
            _buildNotebookCard(
              context,
              title: 'Operating Systems & Concurrency',
              subject: 'Computer Science',
              fileCount: 4,
              color: const Color(0xFF6366F1),
              tags: ['Deadlocks', 'Semaphores', 'Virtual Memory'],
            ),
            const SizedBox(height: 12),
            _buildNotebookCard(
              context,
              title: 'Multivariable Calculus & Linear Algebra',
              subject: 'Mathematics',
              fileCount: 6,
              color: const Color(0xFF06B6D4),
              tags: ['Eigenvalues', 'Stokes Theorem', 'Jacobians'],
            ),
            const SizedBox(height: 12),
            _buildNotebookCard(
              context,
              title: 'Classical Mechanics & Wave Dynamics',
              subject: 'Physics',
              fileCount: 3,
              color: const Color(0xFF8B5CF6),
              tags: ['Lagrangian', 'Harmonic Oscillator'],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () {},
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text('Import Note / PDF', style: TextStyle(color: Colors.white)),
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  '#$t',
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
