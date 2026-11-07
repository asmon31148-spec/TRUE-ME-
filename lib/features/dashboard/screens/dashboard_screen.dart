import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/achievement_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../widgets/mastery_chart.dart';
import '../widgets/streak_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final badges = AchievementService.getInitialBadges();

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
            // Streak Card Component
            const StreakCard(streakDays: 7),
            const SizedBox(height: 24),

            // Weekly Velocity Chart Component
            const MasteryChart(),
            const SizedBox(height: 28),

            const Text('Subject Mastery Levels', style: AppTypography.headlineMedium),
            const SizedBox(height: 14),

            _buildMasteryBar('Computer Science', 0.85, AppColors.primary, '85% (Advanced)'),
            const SizedBox(height: 12),
            _buildMasteryBar('Calculus & Linear Algebra', 0.74, AppColors.accent, '74% (Proficient)'),
            const SizedBox(height: 12),
            _buildMasteryBar('Physics Dynamics', 0.62, AppColors.secondary, '62% (Needs Practice)'),
            const SizedBox(height: 28),

            // Achievement Badges
            const Text('Achievement Milestones', style: AppTypography.headlineMedium),
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: badges.length,
                itemBuilder: (context, idx) {
                  final b = badges[idx];
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      borderRadius: 18,
                      surfaceColor: b.isUnlocked
                          ? AppColors.primary.withOpacity(0.2)
                          : Colors.white.withOpacity(0.04),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(b.icon, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 6),
                          Text(
                            b.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            b.isUnlocked ? 'UNLOCKED' : 'LOCKED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: b.isUnlocked ? AppColors.accentCyan : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
