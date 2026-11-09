import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late String _todayKey;
  List<Map<String, dynamic>> _tasks = [];
  late DateTime _deadline;
  int _daysLeft = 21;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _deadline = OfflineCacheService.getTargetExamDate();
    _daysLeft = _deadline.difference(now).inDays.clamp(0, 999);
    _loadPlan();
  }

  void _loadPlan() {
    final cached = OfflineCacheService.getCachedStudyPlan(_todayKey);
    if (cached != null && cached['sessions'] is List && (cached['sessions'] as List).isNotEmpty) {
      final list = cached['sessions'] as List;
      _tasks = list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } else {
      // Seed plan dynamically based on student's actual subjects
      final subjects = OfflineCacheService.getUserSubjects();
      final primarySub = subjects.isNotEmpty ? subjects.first : 'Microbiology';

      _tasks = [
        {
          'title': 'Bacterial cell structure',
          'subject': primarySub,
          'duration': 20,
          'completed': false,
          'type': 'reading',
        },
        {
          'title': 'Microbial growth curve',
          'subject': primarySub,
          'duration': 20,
          'completed': false,
          'type': 'flashcard',
        },
        {
          'title': 'Sterilization methods',
          'subject': primarySub,
          'duration': 25,
          'completed': false,
          'type': 'quiz',
        },
        {
          'title': 'Previous paper: Unit 2',
          'subject': primarySub,
          'duration': 25,
          'completed': false,
          'type': 'quiz',
        },
      ];
      _savePlan();
    }
    setState(() {});
  }

  void _savePlan() {
    OfflineCacheService.cacheStudyPlan(_todayKey, {
      'sessions': _tasks,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index]['completed'] = !(_tasks[index]['completed'] == true);
      _savePlan();
    });
  }

  void _startNextTask() {
    final firstUnfinished = _tasks.firstWhere(
      (t) => t['completed'] != true,
      orElse: () => _tasks.first,
    );

    final type = firstUnfinished['type'] as String? ?? 'reading';
    if (type == 'quiz') {
      context.go('/quiz');
    } else if (type == 'flashcard') {
      context.go('/flashcards');
    } else {
      context.go('/practice');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _tasks.fold<int>(0, (sum, t) => sum + (t['duration'] as int? ?? 20));
    final completedCount = _tasks.where((t) => t['completed'] == true).length;
    final progress = _tasks.isNotEmpty ? completedCount / _tasks.length : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Today', style: AppTypography.screenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 22),
            tooltip: 'Ask Sage',
            onPressed: () => context.push('/chat'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, size: 24),
            tooltip: 'Account',
            onPressed: () => context.push('/account'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Deadline Strip
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Syllabus deadline: $_daysLeft days left',
                          style: AppTypography.secondary,
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: AppTypography.smallLabel.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppProgressBar(value: progress),
                    const SizedBox(height: 24),

                    // Today's Plan Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Today's plan, $totalMinutes min",
                                style: AppTypography.sectionHeading,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_tasks.isEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Add your syllabus to get a plan',
                                style: AppTypography.secondary,
                              ),
                            ),
                          ] else ...[
                            ..._tasks.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final task = entry.value;
                              final isDone = task['completed'] == true;

                              return InkWell(
                                onTap: () => _toggleTask(idx),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: isDone,
                                          activeColor: AppColors.accent,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          side: const BorderSide(color: AppColors.border, width: 1.5),
                                          onChanged: (_) => _toggleTask(idx),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task['title'] as String,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                decoration: isDone ? TextDecoration.lineThrough : null,
                                                color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              task['subject'] as String,
                                              style: AppTypography.smallLabel,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${task['duration']} min',
                                        style: AppTypography.secondary,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/schedule'),
                        child: const Text('See full schedule'),
                      ),
                    ),
                    const SizedBox(height: 80), // spacing for pinned button
                  ],
                ),
              ),
            ),

            // Pinned Primary "Start" Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: AppPrimaryButton(
                label: 'Start',
                onPressed: _tasks.isNotEmpty ? _startNextTask : () => context.go('/library'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
