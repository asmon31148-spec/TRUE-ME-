import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late String _todayKey;
  late String _tomorrowKey;
  List<Map<String, dynamic>> _tasks = [];
  late DateTime _deadline;
  int _daysLeft = 30;
  bool _isGeneratingPlan = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayKey = OfflineCacheService.dateKey(now);
    _tomorrowKey = OfflineCacheService.dateKey(now.add(const Duration(days: 1)));
    _loadPlan();
  }

  void _loadPlan() {
    final now = DateTime.now();
    _deadline = OfflineCacheService.getTargetExamDate();
    _daysLeft = _deadline.difference(now).inDays.clamp(0, 999);

    final cached = OfflineCacheService.getCachedStudyPlan(_todayKey);
    if (cached != null && cached['sessions'] is List) {
      final list = cached['sessions'] as List;
      _tasks = list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } else {
      _tasks = [];
    }
    setState(() {});
  }

  Future<void> _savePlan() async {
    await OfflineCacheService.cacheStudyPlan(_todayKey, {
      'sessions': _tasks,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _generateAiPlan() async {
    final subjects = OfflineCacheService.getUserSubjects();
    final notebooks = OfflineCacheService.getAllCachedNotebooks();
    final subNames = subjects.isNotEmpty
        ? subjects
        : notebooks.map((n) => n['title'] as String? ?? 'Study').toList();

    if (subNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one subject in Library first.')),
      );
      context.go('/library');
      return;
    }

    setState(() => _isGeneratingPlan = true);

    try {
      final buffer = StringBuffer();
      for (final nb in notebooks.take(3)) {
        final txt = OfflineCacheService.getNotebookCombinedText(nb['id'] as String, maxChars: 3000);
        if (txt.isNotEmpty) {
          buffer.writeln('Subject: ${nb['title']}');
          buffer.writeln(txt);
        }
      }

      final aiRouter = ref.read(aiRouterProvider);
      final jsonStr = await aiRouter.generateStudyPlan(
        subjects: subNames,
        daysLeft: _daysLeft,
        syllabusContext: buffer.toString(),
      );

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final todayList = (data['today'] as List? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['completed'] = false;
        return m;
      }).toList();

      final tomorrowList = (data['tomorrow'] as List? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['completed'] = false;
        return m;
      }).toList();

      if (todayList.isNotEmpty) {
        _tasks = todayList;
        await _savePlan();
      }
      if (tomorrowList.isNotEmpty) {
        await OfflineCacheService.cacheStudyPlan(_tomorrowKey, {
          'sessions': tomorrowList,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPlan = false);
    }
  }

  Future<void> _toggleTask(int index) async {
    final wasCompleted = _tasks[index]['completed'] == true;
    setState(() {
      _tasks[index]['completed'] = !wasCompleted;
    });
    await _savePlan();

    if (!wasCompleted) {
      final mins = (_tasks[index]['duration'] as num? ?? 20).toInt();
      final sub = _tasks[index]['subject'] as String? ?? 'Study';
      final title = _tasks[index]['title'] as String? ?? 'Task';
      await OfflineCacheService.logStudySession(
        activity: 'task',
        subject: sub,
        title: title,
        minutes: mins,
      );
    }
  }

  void _startNextTask() {
    if (_tasks.isEmpty) return;
    final firstUnfinished = _tasks.firstWhere(
      (t) => t['completed'] != true,
      orElse: () => _tasks.first,
    );

    final type = (firstUnfinished['type'] as String? ?? 'reading').toLowerCase();
    final subject = Uri.encodeComponent(firstUnfinished['subject'] as String? ?? '');
    final topic = Uri.encodeComponent(firstUnfinished['title'] as String? ?? '');

    if (type == 'quiz') {
      context.push('/quiz?subject=$subject&topic=$topic');
    } else if (type == 'flashcard') {
      context.push('/flashcards?subject=$subject');
    } else {
      context.push('/chat?scope=$subject&prompt=${Uri.encodeComponent('Help me study: ${firstUnfinished['title']} ($subject)')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _tasks.fold<int>(0, (sum, t) => sum + ((t['duration'] as num? ?? 20).toInt()));
    final completedCount = _tasks.where((t) => t['completed'] == true).length;
    final progress = _tasks.isNotEmpty ? completedCount / _tasks.length : 0.0;
    final userName = OfflineCacheService.getUserName();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(userName != 'Student' ? 'Today • $userName' : 'Today', style: AppTypography.screenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 22),
            tooltip: 'Ask Sage',
            onPressed: () => context.push('/chat'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, size: 24),
            tooltip: 'Account',
            onPressed: () async {
              await context.push('/account');
              if (mounted) _loadPlan();
            },
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
                          'Exam deadline: $_daysLeft ${_daysLeft == 1 ? 'day' : 'days'} left',
                          style: AppTypography.secondary,
                        ),
                        if (_tasks.isNotEmpty)
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: AppTypography.smallLabel.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppProgressBar(value: progress),
                    const SizedBox(height: 20),

                    if (_isGeneratingPlan) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            CircularProgressIndicator(color: AppColors.accent),
                            SizedBox(height: 16),
                            Text('Sage is creating your study plan from your subjects & notes...', textAlign: TextAlign.center, style: AppTypography.secondary),
                          ],
                        ),
                      ),
                    ] else if (_tasks.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('No study tasks for today yet', style: AppTypography.sectionHeading),
                            const SizedBox(height: 6),
                            const Text(
                              'Generate an AI study plan from your subjects and uploaded syllabus, or add your own tasks.',
                              style: AppTypography.secondary,
                            ),
                            const SizedBox(height: 16),
                            AppPrimaryButton(
                              label: 'Generate plan with Sage',
                              icon: const Icon(Icons.auto_awesome_outlined, size: 18, color: Colors.white),
                              onPressed: _generateAiPlan,
                            ),
                            const SizedBox(height: 10),
                            AppSecondaryButton(
                              label: 'Add task manually',
                              onPressed: () async {
                                await context.push('/schedule');
                                if (mounted) _loadPlan();
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
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
                                Text("Today's plan, $totalMinutes min", style: AppTypography.sectionHeading),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
                                  tooltip: 'Regenerate with Sage',
                                  onPressed: _generateAiPlan,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(_tasks.length, (i) {
                              final t = _tasks[i];
                              final isDone = t['completed'] == true;
                              return InkWell(
                                onTap: () => _toggleTask(i),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: isDone,
                                          onChanged: (_) => _toggleTask(i),
                                          activeColor: AppColors.accent,
                                          side: const BorderSide(color: AppColors.border, width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t['title'] as String? ?? 'Task',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: isDone ? AppColors.textMuted : AppColors.textPrimary,
                                                decoration: isDone ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                            Text(
                                              t['subject'] as String? ?? 'General',
                                              style: AppTypography.smallLabel,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${t['duration'] ?? 20} min', style: AppTypography.smallLabel),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            await context.push('/schedule');
                            if (mounted) _loadPlan();
                          },
                          child: const Text('See full schedule'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_tasks.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: AppPrimaryButton(
                  label: completedCount == _tasks.length ? 'All tasks done • Practice more' : 'Start next task',
                  onPressed: _startNextTask,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
