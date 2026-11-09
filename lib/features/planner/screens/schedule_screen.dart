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
  late List<Map<String, dynamic>> _todayTasks;
  late List<Map<String, dynamic>> _tomorrowTasks;

  @override
  void initState() {
    super.initState();
    final subjects = OfflineCacheService.getUserSubjects();
    final pSub = subjects.isNotEmpty ? subjects.first : 'Microbiology';
    final sSub = subjects.length > 1 ? subjects[1] : pSub;

    _todayTasks = [
      {'title': 'Bacterial cell structure', 'subject': pSub, 'duration': 20, 'completed': true},
      {'title': 'Microbial growth curve', 'subject': pSub, 'duration': 20, 'completed': false},
      {'title': 'Sterilization methods', 'subject': pSub, 'duration': 25, 'completed': false},
      {'title': 'Previous paper: Unit 2', 'subject': pSub, 'duration': 25, 'completed': false},
    ];

    _tomorrowTasks = [
      {'title': 'Bacterial genetics review', 'subject': pSub, 'duration': 30, 'completed': false},
      {'title': 'Enzyme kinetics problem set', 'subject': sSub, 'duration': 25, 'completed': false},
      {'title': 'Unit 3 Flashcards', 'subject': pSub, 'duration': 15, 'completed': false},
    ];
  }

  void _showAddTaskSheet() {
    final subjects = OfflineCacheService.getUserSubjects();
    String selectedSubject = subjects.isNotEmpty ? subjects.first : 'General';
    final topicCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '20');
    String selectedType = 'Quiz';

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
                const SizedBox(height: 16),
                AppInput(
                  label: 'Topic',
                  hintText: 'e.g. Gram stain procedure',
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
                      items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
                                items: ['Reading', 'Flashcards', 'Quiz']
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                    .toList(),
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
                  label: 'Add task',
                  onPressed: () {
                    final topic = topicCtrl.text.trim();
                    if (topic.isEmpty) return;
                    final dur = int.tryParse(durationCtrl.text.trim()) ?? 20;

                    setState(() {
                      _todayTasks.add({
                        'title': topic,
                        'subject': selectedSubject,
                        'duration': dur,
                        'completed': false,
                      });
                    });
                    Navigator.pop(ctx);
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
          IconButton(
            icon: const Icon(Icons.add, size: 24),
            tooltip: 'Add task',
            onPressed: _showAddTaskSheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildDayGroup('Today', _todayTasks),
          const SizedBox(height: 24),
          _buildDayGroup('Tomorrow', _tomorrowTasks),
        ],
      ),
    );
  }

  Widget _buildDayGroup(String dayLabel, List<Map<String, dynamic>> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dayLabel, style: AppTypography.sectionHeading),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: tasks.asMap().entries.map((entry) {
              final idx = entry.key;
              final task = entry.value;
              final isDone = task['completed'] == true;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        if (_isEditing) ...[
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                            onPressed: () => setState(() => tasks.removeAt(idx)),
                          ),
                        ] else ...[
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: isDone,
                              activeColor: AppColors.accent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              side: const BorderSide(color: AppColors.border, width: 1.5),
                              onChanged: (val) => setState(() => task['completed'] = val ?? false),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
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
                              Text(task['subject'] as String, style: AppTypography.smallLabel),
                            ],
                          ),
                        ),
                        Text('${task['duration']} min', style: AppTypography.secondary),
                      ],
                    ),
                  ),
                  if (idx < tasks.length - 1)
                    const Divider(color: AppColors.border, height: 1, indent: 14, endIndent: 14),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
