import 'package:flutter/material.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/glass_card.dart';

class StreakCard extends StatelessWidget {
  final int streakDays;
  final List<bool> pastSevenDays;

  const StreakCard({
    super.key,
    this.streakDays = 7,
    this.pastSevenDays = const [true, true, true, true, true, true, true],
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      surfaceGradient: const LinearGradient(
        colors: [Color(0x33F59E0B), Color(0x1A0F172A)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warning.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withOpacity(0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: AppColors.warning,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$streakDays Day Streak!', style: AppTypography.displayMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Consistency is compounding your retention.',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final isDone = i < pastSevenDays.length && pastSevenDays[i];
              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? AppColors.warning
                          : Colors.white.withOpacity(0.06),
                      border: Border.all(
                        color: isDone
                            ? AppColors.warning
                            : Colors.white.withOpacity(0.12),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isDone ? Icons.check : Icons.circle,
                        size: isDone ? 18 : 6,
                        color: isDone ? Colors.black : Colors.white24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    days[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDone ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
