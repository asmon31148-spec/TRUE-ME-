import 'package:flutter/material.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isEditing = false;
  late String _todayKey;
  late String _tomorrowKey;
  List<Map<String, dynamic>> _todayTasks = [];
  List<Map<String, dynamic>> _tomorrowTasks = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayKey = OfflineCacheService.dateKey(now);
    _tomorrowKey = OfflineCacheService.dateKey(now.add(const Duration(days: 1)));
    _loadPlans();
  }

  void _loadPlans() {
    final tCached = OfflineCacheService.getCachedStudyPlan(_todayKey);
    final tmCached = OfflineCacheService.getCachedStudyPlan(_tomorrowKey);

    setState(() {
      _todayTasks = (tCached?['sessions'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _tomorrowTasks = (tmCached?['sessions'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    });
  }

  Future<void> _savePlans() async {
    await OfflineCacheService.cacheStudyPlan(_todayKey, {
      'sessions': _todayTasks,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await OfflineCacheService.cacheStudyPlan(_tomorrowKey, {
      'sessions': _tomorrowTasks,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  void _showAddTaskSheet() {
    final subjects = OfflineCacheService.getUserSubjects();
    final notebooks = OfflineCacheService.getAllCachedNotebooks();
    final subOptions = subjects.isNotEmpty
        ? subjects
        : notebooks.map((n) => n['title'] as String? ?? 'General').toSet().toList();
    if (subOptions.isEmpty) subOptions.add('General');

    String selectedSubject = subOptions.first;
    final topicCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '25');
    String selectedType = 'quiz';
    String selectedDay = 'Today';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add task', style: AppTypography.sectionHeading),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: ['Today', 'Tomorrow'].map((day) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppChip(
                        label: day,
                        isSelected: selectedDay == day,
                        onTap: () => setSheetState(() => selectedDay = day),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                AppInput(
                  label: 'Topic',
                  hintText: 'e.g. Chapter 2 Practice',
                  controller: topicCtrl,
                ),
                const SizedBox(height: 16),
                const Text('Subject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSubject,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      items: subOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => selectedSubject = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppInput(
                        label: 'Minutes',
                        controller: durationCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border, width: 1),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedType,
                                isExpanded: true,
                                dropdownColor: AppColors.surface,
                                items: const [
                                  DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                                  DropdownMenuItem(value: 'flashcard', child: Text('Flashcards')),
                                  DropdownMenuItem(value: 'reading', child: Text('Reading')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setSheetState(() => selectedType = v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Add to $selectedDay',
                  onPressed: () async {
                    final topic = topicCtrl.text.trim();
                    final mins = int.tryParse(durationCtrl.text.trim()) ?? 25;
                    if (topic.isNotEmpty) {
                      final task = {
                        'title': topic,
                        'subject': selectedSubject,
                        'duration': mins,
                        'type': selectedType,
                        'completed': false,
                      };
                      setState(() {
                        if (selectedDay == 'Today') {
                          _todayTasks.add(task);
                        } else {
                          _tomorrowTasks.add(task);
                        }
                      });
                      await _savePlans();
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Schedule', style: AppTypography.screenTitle),
        actions: [
          TextButton(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            child: Text(_isEditing ? 'Done' : 'Edit'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            _buildDaySection('Today', _todayTasks),
            const SizedBox(height: 24),
            _buildDaySection('Tomorrow', _tomorrowTasks),
            const SizedBox(height: 24),
            AppSecondaryButton(
              label: 'Add task',
              icon: const Icon(Icons.add, size: 20),
              onPressed: _showAddTaskSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection(String dayLabel, List<Map<String, dynamic>> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dayLabel, style: AppTypography.sectionHeading),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: const Text('No tasks scheduled', style: AppTypography.secondary),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              children: List.generate(tasks.length, (i) {
                final t = tasks[i];
                final isDone = t['completed'] == true;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          if (_isEditing)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                              onPressed: () async {
                                setState(() => tasks.removeAt(i));
                                await _savePlans();
                              },
                            )
                          else
                            Checkbox(
                              value: isDone,
                              activeColor: AppColors.accent,
                              onChanged: (v) async {
                                setState(() => t['completed'] = v == true);
                                await _savePlans();
                              },
                            ),
                          const SizedBox(width: 4),
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
                                Text(t['subject'] as String? ?? '', style: AppTypography.smallLabel),
                              ],
                            ),
                          ),
                          Text('${t['duration'] ?? 20} min', style: AppTypography.smallLabel),
                        ],
                      ),
                    ),
                    if (i < tasks.length - 1) const Divider(color: AppColors.border, height: 1),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }
}
