import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final List<Map<String, dynamic>> _planSessions = [
    {
      'subject': 'Calculus',
      'topic': 'Eigenvalues & Diagonalization Practice',
      'type': 'flashcard',
      'duration': 20,
      'completed': true,
      'priority': 'High (Decay -18%)',
    },
    {
      'subject': 'Operating Systems',
      'topic': 'Bankers Algorithm & Deadlock Avoidance',
      'type': 'quiz',
      'duration': 15,
      'completed': false,
      'priority': 'Medium',
    },
    {
      'subject': 'Physics',
      'topic': 'Harmonic Oscillator Damping equations',
      'type': 'reading',
      'duration': 25,
      'completed': false,
      'priority': 'Scheduled',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final completedCount = _planSessions.where((s) => s['completed'] == true).length;
    final totalMinutes = _planSessions.fold<int>(0, (sum, s) => sum + (s['duration'] as int));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: "Today's Study Plan",
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
            // Daily Progress Summary Card
            GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              surfaceGradient: const LinearGradient(
                colors: [Color(0x3306B6D4), Color(0x1A0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Target: 60 Minutes', style: AppTypography.titleLarge),
                      Text(
                        '$completedCount of ${_planSessions.length} sessions done',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.accentCyan),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: completedCount / _planSessions.length,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sage scheduled $totalMinutes minutes targeting your weakest mastery topics before your exam in 45 days.',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text('Actionable Tasks', style: AppTypography.headlineMedium),
            const SizedBox(height: 14),

            ..._planSessions.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final bool isDone = s['completed'];

              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Row(
                  children: [
                    Checkbox(
                      value: isDone,
                      activeColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      onChanged: (val) {
                        setState(() {
                          s['completed'] = val ?? false;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                s['subject'].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  s['priority'],
                                  style: const TextStyle(fontSize: 9, color: AppColors.accentCyan),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s['topic'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone ? AppColors.textMuted : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${s['duration']}m',
                      style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            GlassButton(
              isPrimary: true,
              width: double.infinity,
              child: const Text('Add Custom Session'),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
