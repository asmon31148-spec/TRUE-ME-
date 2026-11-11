import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  static const List<String> _shortWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> _priorities = ['High', 'Normal', 'Low'];

  bool _groupBySubject = false;
  bool _isGenerating = false;
  int _selectedDayOffset = 0;

  late final List<DateTime> _weekDates;
  late final List<String> _weekKeys;
  final Map<String, List<Map<String, dynamic>>> _tasksByDate = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekDates = List.generate(7, (i) => now.add(Duration(days: i)));
    _weekKeys = _weekDates.map(OfflineCacheService.dateKey).toList();
    _loadWeekPlans();
  }

  void _loadWeekPlans() {
    setState(() {
      for (final key in _weekKeys) {
        final cached = OfflineCacheService.getCachedStudyPlan(key);
        _tasksByDate[key] = (cached?['sessions'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    });
  }

  Future<void> _saveDatePlan(String key) async {
    await OfflineCacheService.cacheStudyPlan(key, {
      'sessions': _tasksByDate[key] ?? [],
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  String _dayTabLabel(int offset) {
    if (offset == 0) return 'Today';
    if (offset == 1) return 'Tom';
    final d = _weekDates[offset];
    return '${_shortWeekdays[d.weekday - 1]} ${d.day}';
  }

  String _dayFullLabel(int offset) {
    final d = _weekDates[offset];
    final wd = _shortWeekdays[d.weekday - 1];
    if (offset == 0) return 'Today · $wd ${d.day}';
    if (offset == 1) return 'Tomorrow · $wd ${d.day}';
    return '$wd, ${d.day}/${d.month}';
  }

  List<String> _availableSubjects() {
    final subjects = OfflineCacheService.getUserSubjects();
    final notebooks = OfflineCacheService.getAllCachedNotebooks();
    final list = subjects.isNotEmpty
        ? List<String>.from(subjects)
        : notebooks.map((n) => n['title'] as String? ?? 'General').toSet().toList();
    if (list.isEmpty) list.add('General');
    return list;
  }

  Future<void> _generateWithSage() async {
    final subjects = _availableSubjects();
    final notebooks = OfflineCacheService.getAllCachedNotebooks();
    if (notebooks.isEmpty && OfflineCacheService.getUserSubjects().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one subject in Library first.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final buffer = StringBuffer();
      for (final nb in notebooks.take(3)) {
        final txt = OfflineCacheService.getNotebookCombinedText(nb['id'] as String, maxChars: 2500);
        if (txt.isNotEmpty) {
          buffer.writeln('Subject: ${nb['title']}');
          buffer.writeln(txt);
        }
      }
      final daysLeft = OfflineCacheService.daysUntil(OfflineCacheService.getTargetExamDate()).clamp(1, 365);
      final jsonStr = await ref.read(aiRouterProvider).generateStudyPlan(
            subjects: subjects,
            daysLeft: daysLeft,
            syllabusContext: buffer.toString(),
          );
      final data = AiRouter.parseJsonObject(jsonStr);
      final todayList = (data['today'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)..['completed'] = false)
          .toList();
      final tomorrowList = (data['tomorrow'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)..['completed'] = false)
          .toList();

      if (todayList.isNotEmpty) {
        _tasksByDate[_weekKeys[0]] = todayList;
        await _saveDatePlan(_weekKeys[0]);
      }
      if (tomorrowList.isNotEmpty) {
        _tasksByDate[_weekKeys[1]] = tomorrowList;
        await _saveDatePlan(_weekKeys[1]);
      }
      if (mounted) _loadWeekPlans();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate schedule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showTaskSheet({String? editDateKey, int? editIndex}) {
    final isEdit = editDateKey != null && editIndex != null;
    final existing = isEdit ? _tasksByDate[editDateKey]![editIndex] : null;

    final subOptions = _availableSubjects();
    final existingSub = existing?['subject'] as String?;
    if (existingSub != null && existingSub.isNotEmpty && !subOptions.contains(existingSub)) {
      subOptions.insert(0, existingSub);
    }

    String selectedSubject = existingSub ?? subOptions.first;
    final topicCtrl = TextEditingController(text: existing?['title'] as String? ?? '');
    final durationCtrl = TextEditingController(text: '${existing?['duration'] ?? 25}');
    String selectedType = existing?['type'] as String? ?? 'quiz';
    String selectedPriority = existing?['priority'] as String? ?? 'Normal';
    int dayOffset = isEdit
        ? _weekKeys.indexOf(editDateKey).clamp(0, 6)
        : _selectedDayOffset;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEdit ? 'Edit task' : 'Add task', style: AppTypography.sectionHeading),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(7, (idx) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppChip(
                            label: _dayTabLabel(idx),
                            isSelected: dayOffset == idx,
                            onTap: () => setSheetState(() => dayOffset = idx),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppInput(
                    label: 'Topic',
                    hintText: 'e.g. Chapter 2 Practice',
                    controller: topicCtrl,
                  ),
                  const SizedBox(height: 14),
                  const Text('Subject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: sheetCtx.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sheetCtx.borderColor, width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSubject,
                        isExpanded: true,
                        dropdownColor: sheetCtx.surfaceColor,
                        items: subOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) {
                          if (v != null) setSheetState(() => selectedSubject = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
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
                                color: sheetCtx.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: sheetCtx.borderColor, width: 1),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedType,
                                  isExpanded: true,
                                  dropdownColor: sheetCtx.surfaceColor,
                                  items: const [
                                    DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                                    DropdownMenuItem(value: 'flashcard', child: Text('Flashcards')),
                                    DropdownMenuItem(value: 'reading', child: Text('Reading')),
                                    DropdownMenuItem(value: 'practice', child: Text('Practice')),
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
                  const SizedBox(height: 14),
                  const Text('Priority', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: _priorities.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AppChip(
                          label: p,
                          isSelected: selectedPriority == p,
                          onTap: () => setSheetState(() => selectedPriority = p),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  AppPrimaryButton(
                    label: isEdit ? 'Save changes' : 'Add to ${_dayTabLabel(dayOffset)}',
                    onPressed: () async {
                      final topic = topicCtrl.text.trim();
                      final mins = int.tryParse(durationCtrl.text.trim()) ?? 25;
                      if (topic.isEmpty) return;

                      final targetKey = _weekKeys[dayOffset];
                      final task = {
                        'id': existing?['id'] ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
                        'title': topic,
                        'subject': selectedSubject,
                        'duration': mins,
                        'type': selectedType,
                        'priority': selectedPriority,
                        'completed': existing?['completed'] == true,
                      };

                      setState(() {
                        if (isEdit) {
                          _tasksByDate[editDateKey]!.removeAt(editIndex);
                        }
                        _tasksByDate[targetKey] ??= [];
                        _tasksByDate[targetKey]!.add(task);
                        _selectedDayOffset = dayOffset;
                      });

                      if (isEdit && editDateKey != targetKey) {
                        await _saveDatePlan(editDateKey);
                      }
                      await _saveDatePlan(targetKey);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _launchTask(Map<String, dynamic> task) {
    final type = (task['type'] as String? ?? 'reading').toLowerCase();
    final subject = Uri.encodeComponent(task['subject'] as String? ?? '');
    final topic = Uri.encodeComponent(task['title'] as String? ?? '');

    if (type == 'quiz') {
      context.push('/quiz?subject=$subject&topic=$topic');
    } else if (type == 'flashcard') {
      context.push('/flashcards?subject=$subject');
    } else {
      context.push(
        '/chat?scope=$subject&prompt=${Uri.encodeComponent('Help me study: ${task['title']} (${task['subject'] ?? ''})')}',
      );
    }
  }

  Future<void> _toggleTask(String key, int index) async {
    final tasks = _tasksByDate[key]!;
    final wasDone = tasks[index]['completed'] == true;
    final alreadyLogged = tasks[index]['loggedOnce'] == true;
    setState(() {
      tasks[index]['completed'] = !wasDone;
      if (!wasDone) {
        tasks[index]['loggedOnce'] = true;
      }
    });
    await _saveDatePlan(key);

    if (!wasDone && !alreadyLogged) {
      await OfflineCacheService.logStudySession(
        activity: 'task',
        subject: tasks[index]['subject'] as String? ?? 'Study',
        title: tasks[index]['title'] as String? ?? 'Task',
        minutes: (tasks[index]['duration'] as num? ?? 20).toInt(),
      );
    }
  }

  Future<void> _deleteTask(String key, int index) async {
    setState(() => _tasksByDate[key]!.removeAt(index));
    await _saveDatePlan(key);
  }

  Future<void> _moveTaskToDay(String fromKey, int index, int toOffset) async {
    final toKey = _weekKeys[toOffset];
    if (fromKey == toKey) return;
    final task = Map<String, dynamic>.from(_tasksByDate[fromKey]!.removeAt(index));
    _tasksByDate[toKey] ??= [];
    _tasksByDate[toKey]!.add(task);
    setState(() {});
    await _saveDatePlan(fromKey);
    await _saveDatePlan(toKey);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved to ${_dayTabLabel(toOffset)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = _weekKeys[_selectedDayOffset];
    final dayTasks = _tasksByDate[currentKey] ?? [];

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Schedule', style: AppTypography.screenTitle),
        actions: [
          IconButton(
            icon: _isGenerating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.accentColor),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 22),
            tooltip: 'Auto-plan with Sage',
            onPressed: _isGenerating ? null : _generateWithSage,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // View mode segmented switch (By Day | By Subject)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  children: [
                    _buildSegmentTab('By day', !_groupBySubject, () => setState(() => _groupBySubject = false)),
                    _buildSegmentTab('By subject', _groupBySubject, () => setState(() => _groupBySubject = true)),
                  ],
                ),
              ),
            ),

            // 7-day strip when in By Day mode
            if (!_groupBySubject)
              SizedBox(
                height: 62,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: 7,
                  itemBuilder: (_, idx) {
                    final selected = _selectedDayOffset == idx;
                    final count = (_tasksByDate[_weekKeys[idx]] ?? []).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedDayOffset = idx),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? context.accentColor : context.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? context.accentColor : context.borderColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dayTabLabel(idx),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : context.textPrimary,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.white.withOpacity(0.22)
                                        : context.accentTint,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: selected ? Colors.white : context.accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                children: [
                  if (!_groupBySubject) ...[
                    Text(_dayFullLabel(_selectedDayOffset), style: AppTypography.sectionHeading),
                    const SizedBox(height: 10),
                    _buildTaskGroupCard(
                      emptyMessage: 'No tasks scheduled for ${_dayTabLabel(_selectedDayOffset).toLowerCase()}.',
                      entries: List.generate(
                        dayTasks.length,
                        (i) => _TaskEntry(dateKey: currentKey, index: i, task: dayTasks[i], showDay: false),
                      ),
                    ),
                  ] else ...[
                    ..._buildSubjectGroupedSections(),
                  ],
                  const SizedBox(height: 20),
                  AppPrimaryButton(
                    label: 'Add task',
                    icon: const Icon(Icons.add, size: 20, color: Colors.white),
                    onPressed: () => _showTaskSheet(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? context.bgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active ? Border.all(color: context.borderColor) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? context.textPrimary : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSubjectGroupedSections() {
    final Map<String, List<_TaskEntry>> bySubject = {};
    for (int d = 0; d < _weekKeys.length; d++) {
      final key = _weekKeys[d];
      final list = _tasksByDate[key] ?? [];
      for (int i = 0; i < list.length; i++) {
        final sub = (list[i]['subject'] as String? ?? 'General').trim();
        bySubject.putIfAbsent(sub, () => []).add(
              _TaskEntry(dateKey: key, index: i, task: list[i], showDay: true, dayLabel: _dayTabLabel(d)),
            );
      }
    }

    if (bySubject.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: const Text('No tasks scheduled this week yet. Tap "Add task" below or Auto-plan with Sage.', style: AppTypography.secondary),
        ),
      ];
    }

    final sortedKeys = bySubject.keys.toList()..sort();
    return sortedKeys.map((subject) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject, style: AppTypography.sectionHeading),
            const SizedBox(height: 8),
            _buildTaskGroupCard(emptyMessage: '', entries: bySubject[subject]!),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildTaskGroupCard({
    required String emptyMessage,
    required List<_TaskEntry> entries,
  }) {
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Text(emptyMessage, style: AppTypography.secondary),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: List.generate(entries.length, (idx) {
          final e = entries[idx];
          final t = e.task;
          final isDone = t['completed'] == true;
          final isHigh = (t['priority'] as String? ?? 'Normal') == 'High';
          final subLabel = [
            if (e.showDay && e.dayLabel != null) e.dayLabel!,
            t['subject'] as String? ?? '',
            '${t['duration'] ?? 20} min',
          ].where((s) => s.isNotEmpty).join(' • ');

          return Column(
            children: [
              InkWell(
                onTap: () => _launchTask(t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isDone,
                        activeColor: context.accentColor,
                        onChanged: (_) => _toggleTask(e.dateKey, e.index),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isHigh && !isDone) ...[
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: const BoxDecoration(
                                      color: AppColors.warning,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    t['title'] as String? ?? 'Task',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isDone ? context.textSecondary : context.textPrimary,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(subLabel, style: AppTypography.smallLabel),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 18, color: context.textSecondary),
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showTaskSheet(editDateKey: e.dateKey, editIndex: e.index);
                          } else if (val == 'delete') {
                            _deleteTask(e.dateKey, e.index);
                          } else if (val == 'tomorrow') {
                            _moveTaskToDay(e.dateKey, e.index, 1);
                          } else if (val == 'today') {
                            _moveTaskToDay(e.dateKey, e.index, 0);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          if (e.dateKey != _weekKeys[0])
                            const PopupMenuItem(value: 'today', child: Text('Move to Today')),
                          if (e.dateKey != _weekKeys[1])
                            const PopupMenuItem(value: 'tomorrow', child: Text('Move to Tomorrow')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (idx < entries.length - 1) Divider(color: context.borderColor, height: 1),
            ],
          );
        }),
      ),
    );
  }
}

class _TaskEntry {
  final String dateKey;
  final int index;
  final Map<String, dynamic> task;
  final bool showDay;
  final String? dayLabel;

  _TaskEntry({
    required this.dateKey,
    required this.index,
    required this.task,
    required this.showDay,
    this.dayLabel,
  });
}
