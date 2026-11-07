import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Mastery Dashboard',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak Card
            GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              surfaceGradient: const LinearGradient(
                colors: [Color(0x33F59E0B), Color(0x1A0F172A)],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.warning.withOpacity(0.2),
                    ),
                    child: const Icon(Icons.local_fire_department, color: AppColors.warning, size: 36),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('7 Day Streak!', style: AppTypography.displayMedium),
                        const SizedBox(height: 4),
                        Text(
                          'You have studied 340 minutes this week. Keep up the momentum!',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text('Subject Mastery Levels', style: AppTypography.headlineMedium),
            const SizedBox(height: 14),

            _buildMasteryBar('Computer Science', 0.85, AppColors.primary, '85% (Advanced)'),
            const SizedBox(height: 12),
            _buildMasteryBar('Calculus & Linear Algebra', 0.74, AppColors.accent, '74% (Proficient)'),
            const SizedBox(height: 12),
            _buildMasteryBar('Physics Dynamics', 0.62, AppColors.secondary, '62% (Needs Practice)'),
            const SizedBox(height: 28),

            // Sage Decay Alerts
            const Text("Sage's Decay Warnings", style: AppTypography.headlineMedium),
            const SizedBox(height: 12),
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              surfaceColor: Colors.white.withOpacity(0.04),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Eigenvalues Mastery Decaying', style: AppTypography.titleLarge),
                        Text(
                          'Last reviewed 5 days ago. Reviewing 10 flashcards will restore mastery to 90%.',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMasteryBar(String title, double value, Color color, String status) {
    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTypography.titleLarge.copyWith(fontSize: 15)),
              Text(
                status,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
