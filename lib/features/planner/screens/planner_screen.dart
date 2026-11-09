import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late String _todayKey;
  List<Map<String, dynamic>> _planSessions = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _loadCachedPlan();
  }

  void _loadCachedPlan() {
    final cached = OfflineCacheService.getCachedStudyPlan(_todayKey);
    if (cached != null && cached['sessions'] is List && (cached['sessions'] as List).isNotEmpty) {
      final list = cached['sessions'] as List;
      _planSessions = list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } else {
      // Generate initial dynamic schedule based on enrolled subjects
      final subjects = OfflineCacheService.getUserSubjects();
      _planSessions = [];

      for (int i = 0; i < subjects.length; i++) {
        final sub = subjects[i];
        final type = i % 3 == 0 ? 'flashcard' : (i % 3 == 1 ? 'quiz' : 'reading');
        _planSessions.add({
          'subject': sub,
          'topic': '$sub Key Concept Mastery',
          'type': type,
          'duration': 20 + (i * 5),
          'completed': false,
          'priority': i == 0 ? 'High Priority' : 'Scheduled',
        });
      }
      _persistStudyPlan();
    }
    setState(() {});
  }

  void _persistStudyPlan() {
    OfflineCacheService.cacheStudyPlan(_todayKey, {
      'sessions': _planSessions,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  void _showAddSessionDialog() {
    final userSubjects = OfflineCacheService.getUserSubjects();
    String selectedSub = userSubjects.isNotEmpty ? userSubjects.first : 'General';
    final topicCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '25');
    String selectedType = 'quiz';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text('Add Study Task', style: TextStyle(color: Colors.white, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Subject', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSub,
                        dropdownColor: AppColors.surface,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        items: userSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedSub = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Task / Topic Name', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: topicCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Chapter 4 Practice Problems...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Duration (mins)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: durationCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedType,
                                  dropdownColor: AppColors.surface,
                                  isExpanded: true,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  items: const [
                                    DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                                    DropdownMenuItem(value: 'flashcard', child: Text('Flashcard')),
                                    DropdownMenuItem(value: 'reading', child: Text('Reading')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setDialogState(() => selectedType = v);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  final topic = topicCtrl.text.trim();
                  if (topic.isEmpty) return;

                  final duration = int.tryParse(durationCtrl.text.trim()) ?? 25;
                  setState(() {
                    _planSessions.add({
                      'subject': selectedSub,
                      'topic': topic,
                      'type': selectedType,
                      'duration': duration,
                      'completed': false,
                      'priority': 'Custom Task',
                    });
                    _persistStudyPlan();
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Add Task', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteSession(int index) {
    setState(() {
      _planSessions.removeAt(index);
      _persistStudyPlan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _planSessions.where((s) => s['completed'] == true).length;
    final totalMinutes = _planSessions.fold<int>(0, (sum, s) => sum + (s['duration'] as int));
    final progress = _planSessions.isNotEmpty ? completedCount / _planSessions.length : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Daily Study Planner',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task, color: AppColors.accentCyan),
            tooltip: 'Add Task',
            onPressed: _showAddSessionDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Today's Progress Card
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(20),
            surfaceGradient: const LinearGradient(
              colors: [Color(0x336366F1), Color(0x1A0F172A)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Today’s Target', style: AppTypography.headlineMedium),
                    Text(
                      '$completedCount of ${_planSessions.length} done',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${totalMinutes}m planned study time across your active subjects.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation(AppColors.accentCyan),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Scheduled Tasks', style: AppTypography.headlineMedium),
              TextButton.icon(
                onPressed: _showAddSessionDialog,
                icon: const Icon(Icons.add, size: 16, color: AppColors.accentCyan),
                label: const Text('Add Task', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_planSessions.isEmpty)
            GlassCard(
              padding: const EdgeInsets.all(32),
              borderRadius: 20,
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.checklist_rtl, size: 48, color: Colors.white38),
                    const SizedBox(height: 12),
                    const Text('All caught up for today!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Tap "+ Add Task" to plan new sessions.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Task Cards
          ..._planSessions.asMap().entries.map((entry) {
            final idx = entry.key;
            final session = entry.value;
            final isCompleted = session['completed'] == true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isCompleted ? AppColors.success : Colors.white38,
                        size: 26,
                      ),
                      onPressed: () {
                        setState(() {
                          session['completed'] = !isCompleted;
                          _persistStudyPlan();
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
                                session['subject'].toString().toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${session['duration']}m',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session['topic'],
                            style: AppTypography.titleLarge.copyWith(
                              fontSize: 14,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              color: isCompleted ? Colors.white54 : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white38),
                      tooltip: 'Remove',
                      onPressed: () => _deleteSession(idx),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
