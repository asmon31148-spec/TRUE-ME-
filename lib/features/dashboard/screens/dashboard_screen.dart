import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/achievement_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../widgets/mastery_chart.dart';
import '../widgets/streak_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final badges = AchievementService.getInitialBadges();
    final subjects = OfflineCacheService.getUserSubjects();
    final streak = OfflineCacheService.getCurrentStreak();
    final weeklyMins = OfflineCacheService.getWeeklyStudyMinutes().map((e) => e.toDouble()).toList();
    final attempts = OfflineCacheService.getQuizAttempts();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Mastery Dashboard',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
          onPressed: () => context.go('/today'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreakCard(streakDays: streak),
            const SizedBox(height: 24),

            MasteryChart(weeklyMinutes: weeklyMins),
            const SizedBox(height: 28),

            const Text('Subject Mastery Levels', style: AppTypography.sectionHeading),
            const SizedBox(height: 14),

            ...subjects.map((subj) {
              final subAttempts = attempts.where(
                (a) => (a['subject'] as String? ?? '').toLowerCase() == subj.toLowerCase(),
              ).toList();
              final double pct = subAttempts.isEmpty
                  ? 0.0
                  : subAttempts
                          .map((a) => ((a['percentage'] as num? ?? 0) / 100.0))
                          .reduce((a, b) => a + b) /
                      subAttempts.length;
              final label = subAttempts.isEmpty ? 'No quizzes yet' : '${(pct * 100).round()}%';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMasteryBar(subj, pct, AppColors.accent, label),
              );
            }),
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
