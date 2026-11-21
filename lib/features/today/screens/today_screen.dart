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
import '../../../shared/widgets/generation_progress_view.dart';

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

  String _greetingText() {
    final hour = DateTime.now().hour;
    final prefix = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final name = _userName.trim().isNotEmpty ? _userName.trim() : 'Student';
    return '$prefix, $name';
  }

  String _shortFormattedDate() {
    final now = DateTime.now();
    const weekdays = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    // weekday 1 is Monday in DateTime
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  _SubjectChipStyle _getSubjectChipStyle(String subject, bool isDark) {
    final s = subject.toLowerCase();
    if (s.contains('micro') || s.contains('bio') || s.contains('med') || s.contains('chem') || s.contains('life')) {
      // Soft Emerald
      return _SubjectChipStyle(
        background: isDark ? const Color(0xFF064E3B).withOpacity(0.5) : const Color(0xFFDCFCE7),
        text: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
      );
    } else if (s.contains('cs') || s.contains('comp') || s.contains('data') || s.contains('code') || s.contains('algo') || s.contains('soft')) {
      // Soft Violet
      return _SubjectChipStyle(
        background: isDark ? const Color(0xFF4C1D95).withOpacity(0.5) : const Color(0xFFEDE9FE),
        text: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
      );
    } else if (s.contains('math') || s.contains('calc') || s.contains('stat') || s.contains('phys') || s.contains('geom')) {
      // Soft Amber
      return _SubjectChipStyle(
        background: isDark ? const Color(0xFF78350F).withOpacity(0.5) : const Color(0xFFFEF3C7),
        text: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
      );
    } else if (s.contains('hist') || s.contains('lit') || s.contains('eng') || s.contains('art') || s.contains('phil')) {
      // Soft Rose
      return _SubjectChipStyle(
        background: isDark ? const Color(0xFF881337).withOpacity(0.5) : const Color(0xFFFFE4E6),
        text: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C),
      );
    } else {
      // Soft Slate Blue
      return _SubjectChipStyle(
        background: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0F2FE),
        text: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
      );
    }
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
    final remainingMinutes = _tasks
        .where((t) => t['completed'] != true)
        .fold<int>(0, (sum, t) => sum + ((t['duration'] as num? ?? 20).toInt()));
    final double planProgress = _tasks.isNotEmpty ? completedCount / _tasks.length : 0.0;

    final int upNextIdx = _tasks.indexWhere((t) => t['completed'] != true);
    final Map<String, dynamic>? upNextTask = upNextIdx >= 0 ? _tasks[upNextIdx] : null;

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, kBottomNavigationBarHeight + 28),
            children: [
              // 1. Editorial Header + Subtitle (with inline Exam Countdown) + Streak Capsule + Avatar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greetingText(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: _pickExamDeadline,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _shortFormattedDate(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: context.textSecondary,
                                  ),
                                ),
                                Text(
                                  '  ·  ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.textSecondary.withOpacity(0.4),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.isDarkMode
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: context.borderColor,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🎓', style: TextStyle(fontSize: 11)),
                                      const SizedBox(width: 4),
                                      Text(
                                        _daysLeft == 0
                                            ? 'Exam today!'
                                            : 'Final Exams in ${_daysLeft}d',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: context.accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Streak Capsule
                  InkWell(
                    onTap: () => context.go('/progress'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF97316).withOpacity(0.18),
                            const Color(0xFFEA580C).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF97316).withOpacity(0.35),
                          width: 1,
                        ),
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
                            '$_streak ${_streak == 1 ? 'Day' : 'Days'} Streak',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.isDarkMode
                                  ? const Color(0xFFFDBA74)
                                  : const Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // User Avatar -> Account
                  InkWell(
                    onTap: () async {
                      await context.push('/account');
                      if (mounted) _loadData();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.accentTint,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.borderColor, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initialLetter,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. 'Today's Plan' Hero Card (The Focus Engine — Asymmetric 2-Column + Pill CTA)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.24),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Thick accent progress ring with rounded endpoints
                        SizedBox(
                          width: 68,
                          height: 68,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: _tasks.isEmpty ? 0.0 : planProgress,
                                strokeWidth: 6.5,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white.withOpacity(0.22),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _tasks.isEmpty ? '0%' : '${(planProgress * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                    ),
                                    Text(
                                      '$completedCount/${_tasks.length}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.82),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Right: Active Task Metadata
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (upNextTask != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'UP NEXT · ${upNextTask['duration'] ?? 20} MIN',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  upNextTask['title'] as String? ?? 'Next Topic',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$remainingMinutes mins remaining today',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ] else if (_tasks.isNotEmpty) ...[
                                const Text(
                                  '🎉 All Done For Today!',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'You crushed all $completedCount tasks on your schedule.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ] else ...[
                                const Text(
                                  "Today's Study Cockpit",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Let Sage build a high-momentum plan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Ergonomic Pill Action Trigger
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: _isGeneratingPlan
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
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: _isGeneratingPlan
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        upNextTask != null
                                            ? Icons.play_arrow_rounded
                                            : (_tasks.isNotEmpty ? Icons.explore_rounded : Icons.auto_awesome),
                                        size: 18,
                                        color: AppColors.accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        upNextTask != null
                                            ? 'Start Focus'
                                            : (_tasks.isNotEmpty ? 'Explore Practice' : 'Generate Plan'),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accent,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_isGeneratingPlan) ...[
                const GenerationProgressView(
                  compact: true,
                  title: 'Building your study plan with Sage',
                  stages: [
                    'Checking exam countdown & subjects...',
                    'Prioritizing weak topics...',
                    'Balancing Today & Tomorrow...',
                    'Saving plan...',
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // 3. Today's Tasks Header & Actions (Sparkle + Calendar)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        "Today's tasks",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (_tasks.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.borderColor, width: 0.8),
                          ),
                          child: Text(
                            '$completedCount/${_tasks.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: completedCount == _tasks.length
                                  ? const Color(0xFF16A34A)
                                  : context.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      if (_tasks.isNotEmpty)
                        Tooltip(
                          message: 'Regenerate study plan with Sage',
                          child: InkWell(
                            onTap: _isGeneratingPlan ? null : _generateAiPlan,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.borderColor, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 14, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'AI Plan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'See schedule',
                        child: InkWell(
                          onTap: () async {
                            await context.push('/schedule');
                            if (mounted) _loadData();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: context.accentTint,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.accentColor.withOpacity(0.3), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 14, color: context.accentColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Schedule',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 4. Task Cards List (3 Explicit States + Color-Coded Subject Chips)
              if (_tasks.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderColor, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No tasks scheduled for today yet.',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Generate Plan" above or add custom tasks to your schedule.',
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
                            label: _toTitleCase(sub),
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
                  final isUpNext = (i == upNextIdx) && !isDone;
                  final isHighPriority = (t['priority'] as String? ?? 'Normal') == 'High';
                  final type = t['type'] as String? ?? 'reading';
                  final rawSubject = (t['subject'] as String? ?? 'Study').trim();
                  final subjectTitle = _toTitleCase(rawSubject);
                  final chipStyle = _getSubjectChipStyle(rawSubject, context.isDarkMode);
                  final mins = (t['duration'] as num? ?? 20).toInt();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _launchTask(t),
                      onLongPress: () => _moveTaskToTomorrow(i),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDone
                              ? (context.isDarkMode ? const Color(0xFF14171D) : const Color(0xFFF9FAFB))
                              : (isUpNext
                                  ? (context.isDarkMode ? const Color(0xFF131E33) : const Color(0xFFF0F6FF))
                                  : context.bgColor),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUpNext
                                ? AppColors.accent
                                : (isDone
                                    ? context.borderColor.withOpacity(0.5)
                                    : context.borderColor),
                            width: isUpNext ? 1.6 : 1.0,
                          ),
                          boxShadow: isUpNext
                              ? [
                                  BoxShadow(
                                    color: AppColors.accent.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Left Icon Container
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? context.surfaceColor
                                    : (isUpNext ? AppColors.accent.withOpacity(0.12) : context.accentTint),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _taskIcon(type),
                                size: 20,
                                color: isDone
                                    ? context.textSecondary.withOpacity(0.4)
                                    : (isUpNext ? AppColors.accent : context.accentColor),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Title + Color-Coded Subject Chip + Duration
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
                                            color: isDone
                                                ? context.textSecondary.withOpacity(0.6)
                                                : context.textPrimary,
                                            decoration: isDone ? TextDecoration.lineThrough : null,
                                            decorationColor: context.textSecondary.withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      // Color-Coded Subject Chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: chipStyle.background,
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          subjectTitle,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: chipStyle.text,
                                            letterSpacing: -0.1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '·  $mins min',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: context.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Up Next Pill
                            if (isUpNext) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
                                    SizedBox(width: 2),
                                    Text(
                                      'Up next',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],

                            // More Vert Options Menu
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

                            // Checkbox with visual dopamine reward (Soft Emerald Green check on Done)
                            InkWell(
                              onTap: () => _toggleTask(i),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: isDone
                                    ? Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF16A34A),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isUpNext
                                                ? AppColors.accent
                                                : (context.isDarkMode
                                                    ? const Color(0xFF4B5563)
                                                    : const Color(0xFFD1D5DB)),
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
              const SizedBox(height: 14),

              // 5. Sage Dynamic Insight Card (Real backend state — ZERO fake text)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
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

class _SubjectChipStyle {
  final Color background;
  final Color text;
  const _SubjectChipStyle({required this.background, required this.text});
}
