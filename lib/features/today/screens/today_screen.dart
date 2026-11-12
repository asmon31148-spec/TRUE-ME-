import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
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
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  int _daysLeft = 30;
  int _totalExamSpanDays = 30;
  int _streak = 0;
  String _userName = 'Student';
  bool _isGeneratingPlan = false;
  String _subjectFilter = 'All';

  // Dynamic real insight state (never hardcoded)
  String _insightText = '';
  String _insightRoute = '/chat';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayKey = OfflineCacheService.dateKey(now);
    _tomorrowKey = OfflineCacheService.dateKey(now.add(const Duration(days: 1)));
    _loadData();
    _syncCloudInBackground();
  }

  Future<void> _syncCloudInBackground() async {
    await OfflineCacheService.syncFromCloud();
    if (mounted) _loadData();
  }

  void _loadData() {
    _userName = OfflineCacheService.getUserName();
    _deadline = OfflineCacheService.getTargetExamDate();
    final setupDate = OfflineCacheService.getExamSetupDate();

    _daysLeft = OfflineCacheService.daysUntil(_deadline);
    _totalExamSpanDays = _deadline.difference(setupDate).inDays.clamp(1, 999);
    _streak = OfflineCacheService.getCurrentStreak();

    final cached = OfflineCacheService.getCachedStudyPlan(_todayKey);
    if (cached != null && cached['sessions'] is List) {
      _tasks = (cached['sessions'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } else {
      _tasks = [];
    }

    _computeRealInsight();
    setState(() {});
  }

  void _computeRealInsight() {
    final weakTopics = OfflineCacheService.getWeakTopics();
    if (weakTopics.isNotEmpty) {
      final topWeak = weakTopics.first;
      final topic = topWeak['topic'] as String;
      final score = topWeak['score'] as int;
      _insightText =
          'You averaged $score% on "$topic" in your recent quizzes. Worth spending extra time on it today.';
      _insightRoute = '/chat?prompt=${Uri.encodeComponent('Help me strengthen my understanding of $topic')}';
      return;
    }

    final decks = OfflineCacheService.getAllCachedDecks();
    final nowPlus = DateTime.now().add(const Duration(minutes: 5));
    int dueCards = 0;
    String? dueSubject;
    for (final d in decks) {
      final cards = d['cards'] as List? ?? [];
      for (final c in cards) {
        final nextStr = (c as Map)['nextReviewDate'] as String?;
        final nextDt = nextStr != null ? DateTime.tryParse(nextStr) : null;
        if (nextDt == null || nextDt.isBefore(nowPlus)) {
          dueCards++;
          dueSubject ??= d['subject'] as String?;
        }
      }
    }
    if (dueCards > 0) {
      _insightText =
          'You have $dueCards spaced-repetition ${dueCards == 1 ? 'card' : 'cards'} due today${dueSubject != null ? ' in $dueSubject' : ''}. Reviewing them now prevents memory decay.';
      _insightRoute = '/flashcards';
      return;
    }

    final notebooks = OfflineCacheService.getAllCachedNotebooks();
    if (notebooks.isNotEmpty) {
      int totalFiles = 0;
      for (final nb in notebooks) {
        totalFiles += (nb['documents'] as List? ?? []).length;
      }
      if (totalFiles > 0) {
        _insightText =
            'You have $totalFiles uploaded ${totalFiles == 1 ? 'source' : 'sources'} across ${notebooks.length} ${notebooks.length == 1 ? 'subject' : 'subjects'}. Ask Sage to summarize or quiz you directly from them.';
        _insightRoute = '/chat';
      } else {
        final firstSub = notebooks.first['title'] ?? 'your subjects';
        _insightText =
            'Upload syllabus or lecture notes into $firstSub in Library so Sage can personalize your daily sessions.';
        _insightRoute = '/library';
      }
      return;
    }

    _insightText =
        'Add your subjects in Library and upload study materials to get personalized guidance from Sage.';
    _insightRoute = '/library';
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

      final data = AiRouter.parseJsonObject(jsonStr);
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
      if (mounted) _loadData();
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
    HapticFeedback.lightImpact();
    final wasCompleted = _tasks[index]['completed'] == true;
    final alreadyLogged = _tasks[index]['loggedOnce'] == true;
    setState(() {
      _tasks[index]['completed'] = !wasCompleted;
      if (!wasCompleted) {
        _tasks[index]['loggedOnce'] = true;
      }
    });
    await _savePlan();

    if (!wasCompleted && !alreadyLogged) {
      final mins = (_tasks[index]['duration'] as num? ?? 20).toInt();
      final sub = _tasks[index]['subject'] as String? ?? 'Study';
      final title = _tasks[index]['title'] as String? ?? 'Task';
      await OfflineCacheService.logStudySession(
        activity: 'task',
        subject: sub,
        title: title,
        minutes: mins,
      );
      if (mounted) {
        setState(() => _streak = OfflineCacheService.getCurrentStreak());
      }
    }
  }

  Future<void> _moveTaskToTomorrow(int index) async {
    final task = Map<String, dynamic>.from(_tasks[index]);
    task['completed'] = false;
    setState(() {
      _tasks.removeAt(index);
    });
    await _savePlan();

    final tmCached = OfflineCacheService.getCachedStudyPlan(_tomorrowKey);
    final tmTasks = (tmCached?['sessions'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    tmTasks.add(task);
    await OfflineCacheService.cacheStudyPlan(_tomorrowKey, {
      'sessions': tmTasks,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved "${task['title'] ?? 'Task'}" to tomorrow')),
      );
    }
  }

  Future<void> _removeTask(int index) async {
    setState(() {
      _tasks.removeAt(index);
    });
    await _savePlan();
  }

  void _launchTask(Map<String, dynamic> task) {
    final type = (task['type'] as String? ?? 'reading').toLowerCase();
    final rawSubject = task['subject'] as String? ?? '';
    final rawTitle = task['title'] as String? ?? '';
    final subject = Uri.encodeComponent(rawSubject);
    final topic = Uri.encodeComponent(rawTitle);

    if (type == 'quiz') {
      context.push('/quiz?subject=$subject&topic=$topic');
    } else if (type == 'flashcard') {
      context.push('/flashcards?subject=$subject');
    } else {
      context.push(
        '/chat?scope=$subject&prompt=${Uri.encodeComponent('Help me study: $rawTitle ($rawSubject)')}',
      );
    }
  }

  Future<void> _pickExamDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline.isAfter(DateTime.now()) ? _deadline : DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      await OfflineCacheService.saveTargetExamDate(picked);
      if (mounted) _loadData();
    }
  }

  String _formattedDate() {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  IconData _taskIcon(String type) {
    switch (type.toLowerCase()) {
      case 'flashcard':
        return Icons.style_outlined;
      case 'quiz':
        return Icons.checklist_outlined;
      case 'practice':
        return Icons.description_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _tasks.fold<int>(0, (sum, t) => sum + ((t['duration'] as num? ?? 20).toInt()));
    final completedCount = _tasks.where((t) => t['completed'] == true).length;
    final double planProgress = _tasks.isNotEmpty ? completedCount / _tasks.length : 0.0;

    final int upNextIdx = _tasks.indexWhere((t) => t['completed'] != true);
    final Map<String, dynamic>? upNextTask = upNextIdx >= 0 ? _tasks[upNextIdx] : null;

    final double examElapsedRatio = _totalExamSpanDays > 0
        ? ((_totalExamSpanDays - _daysLeft) / _totalExamSpanDays).clamp(0.08, 1.0)
        : 0.1;
    final int filledSegments = (examElapsedRatio * 10).round().clamp(1, 10);

    final taskSubjects = _tasks
        .map((t) => (t['subject'] as String? ?? 'Study').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (_subjectFilter != 'All' && !taskSubjects.contains(_subjectFilter)) {
      _subjectFilter = 'All';
    }

    final List<int> visibleIndices = [];
    for (int i = 0; i < _tasks.length; i++) {
      final sub = (_tasks[i]['subject'] as String? ?? 'Study').trim();
      if (_subjectFilter == 'All' || sub == _subjectFilter) {
        visibleIndices.add(i);
      }
    }

    final initialLetter = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: context.accentColor,
          onRefresh: () async {
            await OfflineCacheService.syncFromCloud();
            if (mounted) _loadData();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // 1. Custom Clean Greeting Header + Streak Pill + Avatar
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $_userName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formattedDate(),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Streak Pill
                  InkWell(
                    onTap: () => context.go('/progress'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.borderColor, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 16,
                            color: Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_streak',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // User Avatar -> Account
                  InkWell(
                    onTap: () async {
                      await context.push('/account');
                      if (mounted) _loadData();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.accentTint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initialLetter,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. Royal Blue Hero Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Circular Progress Indicator Ring
                        SizedBox(
                          width: 62,
                          height: 62,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: _tasks.isEmpty ? 0.0 : planProgress,
                                strokeWidth: 5.5,
                                backgroundColor: Colors.white.withOpacity(0.22),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              Center(
                                child: Text(
                                  '$completedCount/${_tasks.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Today's plan",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _tasks.isNotEmpty
                                    ? '$totalMinutes min, ${_tasks.length} ${_tasks.length == 1 ? 'task' : 'tasks'}'
                                    : 'No tasks scheduled',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _tasks.isEmpty
                                    ? 'Let Sage build your study plan'
                                    : (upNextTask != null
                                        ? 'Up next: ${upNextTask['title']}'
                                        : 'All tasks complete today!'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Inner Full-Width White CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.accent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isGeneratingPlan
                            ? null
                            : () {
                                if (upNextTask != null) {
                                  _launchTask(upNextTask);
                                } else if (_tasks.isNotEmpty) {
                                  context.go('/practice');
                                } else {
                                  _generateAiPlan();
                                }
                              },
                        child: _isGeneratingPlan
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              )
                            : Text(
                                upNextTask != null
                                    ? 'Start ${upNextTask['duration'] ?? 20} min session'
                                    : (_tasks.isNotEmpty ? 'Explore more practice' : 'Generate plan with Sage'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Exam Countdown Segmented Card (tappable to change date)
              InkWell(
                onTap: _pickExamDeadline,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.borderColor, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Exam countdown',
                            style: TextStyle(fontSize: 14, color: context.textSecondary),
                          ),
                          Text(
                            _daysLeft == 0 ? 'Today!' : '$_daysLeft ${_daysLeft == 1 ? 'day' : 'days'} left',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(10, (i) {
                          final isFilled = i < filledSegments;
                          return Expanded(
                            child: Container(
                              height: 6,
                              margin: EdgeInsets.only(right: i < 9 ? 4 : 0),
                              decoration: BoxDecoration(
                                color: isFilled
                                    ? context.accentColor
                                    : (context.isDarkMode ? const Color(0xFF262B33) : const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Today's Tasks Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's tasks",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      if (_tasks.isNotEmpty)
                        TextButton(
                          onPressed: _isGeneratingPlan ? null : _generateAiPlan,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Refresh AI',
                            style: TextStyle(fontSize: 13, color: context.textSecondary),
                          ),
                        ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () async {
                          await context.push('/schedule');
                          if (mounted) _loadData();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'See schedule',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Task Cards List or Clean Empty Card
              if (_tasks.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.borderColor, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No tasks added for today yet.',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Generate plan with Sage" above or add custom tasks in your schedule.',
                        style: TextStyle(fontSize: 13, color: context.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      AppSecondaryButton(
                        label: 'Add task manually',
                        height: 44,
                        onPressed: () async {
                          await context.push('/schedule');
                          if (mounted) _loadData();
                        },
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (taskSubjects.length >= 2) ...[
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All', ...taskSubjects].map((sub) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppChip(
                            label: sub,
                            isSelected: _subjectFilter == sub,
                            onTap: () => setState(() => _subjectFilter = sub),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ...visibleIndices.map((i) {
                  final t = _tasks[i];
                  final isDone = t['completed'] == true;
                  final isUpNext = i == upNextIdx;
                  final isHighPriority = (t['priority'] as String? ?? 'Normal') == 'High';
                  final type = t['type'] as String? ?? 'reading';
                  final subject = t['subject'] as String? ?? 'Study';
                  final mins = (t['duration'] as num? ?? 20).toInt();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _launchTask(t),
                      onLongPress: () => _moveTaskToTomorrow(i),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isUpNext ? context.accentColor : context.borderColor,
                            width: isUpNext ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Left Icon Container
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDone ? context.surfaceColor : context.accentTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _taskIcon(type),
                                size: 20,
                                color: isDone ? context.textSecondary : context.accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Title + Metadata
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isHighPriority && !isDone) ...[
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
                                            fontWeight: FontWeight.w600,
                                            color: isDone ? context.textSecondary : context.textPrimary,
                                            decoration: isDone ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$subject · $mins min',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),

                            if (isUpNext) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: context.accentTint,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Up next',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],

                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, size: 18, color: context.textSecondary),
                              padding: EdgeInsets.zero,
                              onSelected: (val) {
                                if (val == 'start') {
                                  _launchTask(t);
                                } else if (val == 'tomorrow') {
                                  _moveTaskToTomorrow(i);
                                } else if (val == 'delete') {
                                  _removeTask(i);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'start', child: Text('Start session')),
                                PopupMenuItem(value: 'tomorrow', child: Text('Move to tomorrow')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Remove', style: TextStyle(color: AppColors.error)),
                                ),
                              ],
                            ),

                            // Circular Check Button
                            InkWell(
                              onTap: () => _toggleTask(i),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: isDone
                                    ? Icon(
                                        Icons.check_circle,
                                        size: 24,
                                        color: context.accentColor,
                                      )
                                    : Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: context.isDarkMode ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                                            width: 1.8,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 10),

              // 5. Sage Dynamic Insight Card (Real backend state — ZERO fake text)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: context.accentColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'S',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _insightText,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              if (_insightRoute == '/library') {
                                context.go('/library');
                              } else {
                                context.push(_insightRoute);
                              }
                            },
                            child: Text(
                              _insightRoute == '/library'
                                  ? 'Go to Library'
                                  : (_insightRoute == '/flashcards' ? 'Review flashcards' : 'Ask Sage'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
