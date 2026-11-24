import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/liquid_glass_theme.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/generation_progress_view.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

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
  int _dueCardsCount = 0;
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
    // Calculate live due cards count for Spaced Repetition Bento Card
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
    _dueCardsCount = dueCards;

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
    final duration = (task['duration'] as num? ?? 25).toInt();
    final subject = Uri.encodeComponent(rawSubject);
    final topic = Uri.encodeComponent(rawTitle);

    if (type == 'quiz') {
      context.push('/quiz?subject=$subject&topic=$topic');
    } else if (type == 'flashcard') {
      context.push('/flashcards?subject=$subject');
    } else {
      context.push('/focus?subject=$subject&topic=$topic&minutes=$duration');
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
    final words = s.split(RegExp(r'[^a-z0-9]+')).toSet();
    final isCs = words.contains('cs') ||
        s.startsWith('cs ') ||
        s.contains('comp') ||
        s.contains('data') ||
        s.contains('code') ||
        s.contains('algo') ||
        s.contains('soft') ||
        s.contains('program');

    if (s.contains('micro') || s.contains('bio') || s.contains('med') || s.contains('chem') || s.contains('life') || s.contains('gene')) {
      // Forest Ink
      return _SubjectChipStyle(
        background: isDark ? const Color(0xFF064E3B).withOpacity(0.4) : ZenColors.microbioWash,
        text: isDark ? const Color(0xFF86EFAC) : ZenColors.microbioInk,
      );
    } else if (s.contains('math') || s.contains('calc') || s.contains('stat') || s.contains('phys') || s.contains('geom') || s.contains('econ') || s.contains('mech')) {
      // Amber Ink
      return _SubjectChipStyle(
        background: isDark ? const Color(0xFF78350F).withOpacity(0.4) : ZenColors.calculusWash,
        text: isDark ? const Color(0xFFFDE68A) : ZenColors.calculusInk,
      );
    } else if (isCs) {
      // Violet Ink
      return _SubjectChipStyle(
        background: isDark ? const Color(0xFF4C1D95).withOpacity(0.4) : ZenColors.csWash,
        text: isDark ? const Color(0xFFC4B5FD) : ZenColors.csInk,
      );
    } else if (s.contains('hist') || s.contains('lit') || s.contains('eng') || s.contains('art') || s.contains('phil') || s.contains('law')) {
      // Vermilion Cinnabar Ink
      return _SubjectChipStyle(
        background: isDark ? const Color(0xFF881337).withOpacity(0.4) : ZenColors.vermilionSoft,
        text: isDark ? const Color(0xFFFDA4AF) : ZenColors.vermilionSeal,
      );
    } else {
      // Stone Mist Wash
      return _SubjectChipStyle(
        background: isDark ? const Color(0xFF292524) : const Color(0xFFE7E3D9),
        text: isDark ? ZenColors.darkMist : ZenColors.stoneMist,
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

    final isDark = context.isDarkMode;
    final canvasBg = isDark ? ZenColors.darkCanvas : ZenColors.washiCanvas;
    final surfaceBg = isDark ? ZenColors.darkSurface : ZenColors.washiSurface;
    final hairlineBorder = isDark ? ZenColors.darkBorder : ZenColors.washiBorder;
    final primaryInk = isDark ? ZenColors.darkInk : ZenColors.sumiInk;
    final secondaryMist = isDark ? ZenColors.darkMist : ZenColors.stoneMist;
    final redSeal = isDark ? ZenColors.darkVermilion : ZenColors.vermilionSeal;
    final redWash = isDark ? ZenColors.darkVermilion.withOpacity(0.16) : ZenColors.vermilionSoft;

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
      backgroundColor: context.liquidCanvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: LiquidGlassTheme.electricIndigo,
          onRefresh: () async {
            await OfflineCacheService.syncFromCloud();
            if (mounted) _loadData();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
            children: [
              // 1. Top Utility Row: Exam Countdown Pill (Left), Streak + Scholar Avatar (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _pickExamDeadline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1711) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: LiquidGlassTheme.amberStreak.withOpacity(isDark ? 0.45 : 0.6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              value: (1.0 - (_daysLeft / _totalExamSpanDays)).clamp(0.08, 1.0),
                              strokeWidth: 2,
                              backgroundColor: LiquidGlassTheme.amberStreak.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(LiquidGlassTheme.amberStreak),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _daysLeft == 0 ? 'Exam is Today!' : '$_daysLeft days until exam',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // Streak Badge: [ 🔥 1 Day ]
                      GestureDetector(
                        onTap: () => context.go('/progress'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF231C13) : const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: LiquidGlassTheme.amberStreak.withOpacity(isDark ? 0.4 : 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 5),
                              Text(
                                '$_streak ${_streak == 1 ? 'Day' : 'Days'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Scholar Avatar
                      GestureDetector(
                        onTap: () async {
                          await context.push('/account');
                          if (mounted) _loadData();
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: context.liquidGlassFill,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initialLetter,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.liquidTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Editorial Greeting & Subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greetingText(),
                    style: TextStyle(
                      color: context.liquidTextPrimary,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_shortFormattedDate()} · The Mindful Study Flow',
                    style: TextStyle(
                      color: context.liquidTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ===============================================================
              // SAGE BENTO GRID: Hero Focus + Flashcards + Voice + Prescription
              // ===============================================================
              // 1. Hero Bento Card: Today's Primary Focus & Daily Mastery
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                glowColor: LiquidGlassTheme.electricIndigo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DAILY MASTERY',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: context.liquidTextSecondary,
                          ),
                        ),
                        Text(
                          _tasks.isEmpty
                              ? '0 of 0 finished'
                              : '$completedCount of ${_tasks.length} finished  (${(planProgress * 100).toInt()}%)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: context.liquidTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _tasks.isEmpty ? 0.0 : planProgress.clamp(0.04, 1.0),
                        minHeight: 5,
                        backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(LiquidGlassTheme.electricIndigo),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (upNextTask != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: LiquidGlassTheme.electricIndigo.withOpacity(isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: LiquidGlassTheme.electricIndigo.withOpacity(0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'UP NEXT · ${upNextTask['duration'] ?? 25} MIN FOCUS',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: LiquidGlassTheme.electricIndigo,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$remainingMinutes mins remaining',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.liquidTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        upNextTask['title'] as String? ?? 'Next Topic',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: context.liquidTextPrimary,
                          letterSpacing: -0.3,
                          height: 1.25,
                        ),
                      ),
                    ] else if (_tasks.isNotEmpty) ...[
                      Text(
                        '🎉 All Goals Completed!',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: context.liquidTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You completed all $completedCount study sessions today.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.liquidTextSecondary,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Today\'s Study Focus',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: context.liquidTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Consult Sage to draft your personalized daily plan.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.liquidTextSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Action row with Subject Tag and Primary Begin Session Button
                    Row(
                      children: [
                        if (upNextTask != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: _getSubjectChipStyle(upNextTask['subject'] as String? ?? 'Study', isDark).background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _toTitleCase(upNextTask['subject'] as String? ?? 'Study'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _getSubjectChipStyle(upNextTask['subject'] as String? ?? 'Study', isDark).text,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        SizedBox(
                          width: 180,
                          child: GlassButton(
                            isPrimary: true,
                            height: 44,
                            borderRadius: 22,
                            isLoading: _isGeneratingPlan,
                            icon: Icon(
                              upNextTask != null
                                  ? Icons.play_arrow_rounded
                                  : (_tasks.isNotEmpty ? Icons.check_circle_outline_rounded : Icons.auto_awesome_rounded),
                              size: 18,
                              color: Colors.white,
                            ),
                            text: upNextTask != null
                                ? 'Begin Session • ${upNextTask['duration'] ?? 25}m'
                                : (_tasks.isNotEmpty ? 'All Done Today' : 'Plan Day with Sage'),
                            onPressed: () {
                              if (upNextTask != null) {
                                _launchTask(upNextTask);
                              } else if (_tasks.isNotEmpty) {
                                context.go('/progress');
                              } else {
                                _generateAiPlan();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Bento Split Row: Spaced Repetition Due Cards (Left) + 1-Click Voice Tutor (Right)
              Row(
                children: [
                  // Bento Left: Spaced Repetition Cards Due
                  Expanded(
                    child: GlassCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(16),
                      onTap: () => context.push('/flashcards'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: LiquidGlassTheme.amberStreak.withOpacity(isDark ? 0.18 : 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.style_rounded,
                                  size: 19,
                                  color: LiquidGlassTheme.amberStreak,
                                ),
                              ),
                              if (_dueCardsCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: LiquidGlassTheme.amberStreak.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Due Today',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: LiquidGlassTheme.amberStreak,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _dueCardsCount > 0 ? '$_dueCardsCount Cards' : 'All Clear',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: context.liquidTextPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Spaced Repetition',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.liquidTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Text(
                                'Review cards',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: LiquidGlassTheme.amberStreak,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 13, color: LiquidGlassTheme.amberStreak),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Bento Right: 1-Click Voice Tutor
                  Expanded(
                    child: GlassCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(16),
                      onTap: () => context.push('/voice-tutor'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: LiquidGlassTheme.emeraldFocus.withOpacity(isDark ? 0.18 : 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 19,
                                  color: LiquidGlassTheme.emeraldFocus,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: LiquidGlassTheme.emeraldFocus.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '15 min',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: LiquidGlassTheme.emeraldFocus,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Voice Tutor',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: context.liquidTextPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Socratic Recall',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.liquidTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Text(
                                'Start voice',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: LiquidGlassTheme.emeraldFocus,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 13, color: LiquidGlassTheme.emeraldFocus),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Bento Card: Mother AI Sage Diagnostic Prescription
              GlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.all(18),
                borderGradient: LiquidGlassTheme.indigoSpecularBorder,
                glowColor: LiquidGlassTheme.electricIndigo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: LiquidGlassTheme.electricIndigo.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: LiquidGlassTheme.electricIndigo,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Sage Diagnostic Prescription',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: LiquidGlassTheme.electricIndigo,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _insightText,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: context.liquidTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () {
                          if (_insightRoute == '/library') {
                            context.go('/library');
                          } else {
                            context.push(_insightRoute);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _insightRoute == '/library'
                                    ? 'Consult Sage in Library'
                                    : (_insightRoute == '/flashcards' ? 'Review Due Cards' : 'Ask Sage'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: LiquidGlassTheme.electricIndigo,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: LiquidGlassTheme.electricIndigo),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_isGeneratingPlan) ...[
                const GenerationProgressView(
                  compact: true,
                  title: 'Aligning your study path with Sage',
                  stages: [
                    'Reviewing your exam trial date...',
                    'Prioritizing weak topics with clarity...',
                    'Balancing Today & Tomorrow...',
                    'Inscribing study plan...',
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 3. Today's Study Plan Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            "Today's Plan",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ZenTypography.editorialHeadline.copyWith(
                              fontSize: 18,
                              color: primaryInk,
                            ),
                          ),
                        ),
                        if (_tasks.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '·  $completedCount/${_tasks.length}',
                            style: TextStyle(
                              fontFamilyFallback: ZenTypography.sansFallbacks,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: secondaryMist,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_tasks.isNotEmpty)
                        InkWell(
                          onTap: _isGeneratingPlan ? null : _generateAiPlan,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: surfaceBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: hairlineBorder, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('✦', style: TextStyle(fontSize: 11, color: redSeal)),
                                const SizedBox(width: 3),
                                Text(
                                  'Re-align',
                                  style: TextStyle(
                                    fontFamilyFallback: ZenTypography.sansFallbacks,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: primaryInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          await context.push('/schedule');
                          if (mounted) _loadData();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: surfaceBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: hairlineBorder, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month_outlined, size: 12, color: primaryInk),
                              const SizedBox(width: 3),
                              Text(
                                'Schedule',
                                style: TextStyle(
                                  fontFamilyFallback: ZenTypography.sansFallbacks,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: primaryInk,
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
              const SizedBox(height: 12),

              // 4. The Daily Scroll (Zero Box Enclosures — Delicate Hairline Dividers & Spacious Layout)
              if (_tasks.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: hairlineBorder, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No study sessions scheduled for today.',
                        style: ZenTypography.editorialHeadline.copyWith(
                          fontSize: 16,
                          color: primaryInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Draft Plan with Sage" above or add study items in your schedule.',
                        style: TextStyle(
                          fontFamilyFallback: ZenTypography.sansFallbacks,
                          fontSize: 13,
                          color: secondaryMist,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppSecondaryButton(
                        label: 'Add study task manually',
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

                // The Scroll Canvas: Delicate Hairline Dividers & Multi-tier Unclipped Rows
                Container(
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: hairlineBorder, width: 0.8),
                  ),
                  child: Column(
                    children: List.generate(visibleIndices.length, (entryIdx) {
                      final i = visibleIndices[entryIdx];
                      final t = _tasks[i];
                      final isDone = t['completed'] == true;
                      final isUpNext = (i == upNextIdx) && !isDone;
                      final isHighPriority = (t['priority'] as String? ?? 'Normal') == 'High';
                      final type = t['type'] as String? ?? 'reading';
                      final rawSubject = (t['subject'] as String? ?? 'Study').trim();
                      final subjectTitle = _toTitleCase(rawSubject);
                      final chipStyle = _getSubjectChipStyle(rawSubject, isDark);
                      final mins = (t['duration'] as num? ?? 20).toInt();
                      final isLast = entryIdx == visibleIndices.length - 1;

                      return Container(
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : Border(
                                  bottom: BorderSide(color: hairlineBorder, width: 0.6),
                                ),
                        ),
                        child: InkWell(
                          onTap: () => _launchTask(t),
                          onLongPress: () => _moveTaskToTomorrow(i),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (isUpNext) ...[
                                      Container(
                                        width: 3.5,
                                        height: 24,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: redSeal,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? canvasBg
                                            : (isUpNext ? redWash : canvasBg),
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(color: hairlineBorder, width: 0.6),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        _taskIcon(type),
                                        size: 15,
                                        color: isDone
                                            ? secondaryMist.withOpacity(0.4)
                                            : (isUpNext ? redSeal : primaryInk),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Full Unclipped Task Title
                                    Expanded(
                                      child: Row(
                                        children: [
                                          if (isHighPriority && !isDone) ...[
                                            Container(
                                              width: 6,
                                              height: 6,
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(
                                                color: redSeal,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                          Expanded(
                                            child: Text(
                                              t['title'] as String? ?? 'Task',
                                              maxLines: 2,
                                              style: TextStyle(
                                                fontFamilyFallback: ZenTypography.sansFallbacks,
                                                fontSize: 15,
                                                fontWeight: isUpNext ? FontWeight.w700 : FontWeight.w600,
                                                color: isDone
                                                    ? secondaryMist.withOpacity(0.55)
                                                    : primaryInk,
                                                decoration: isDone ? TextDecoration.lineThrough : null,
                                                decorationColor: secondaryMist.withOpacity(0.55),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Options Menu
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert, size: 17, color: secondaryMist),
                                      padding: EdgeInsets.zero,
                                      onSelected: (val) {
                                        if (val == 'start') {
                                          _launchTask(t);
                                        } else if (val == 'focus') {
                                          final sub = Uri.encodeComponent(t['subject'] as String? ?? '');
                                          final top = Uri.encodeComponent(t['title'] as String? ?? '');
                                          final dur = (t['duration'] as num? ?? 25).toInt();
                                          context.push('/focus?subject=$sub&topic=$top&minutes=$dur');
                                        } else if (val == 'chat') {
                                          final sub = Uri.encodeComponent(t['subject'] as String? ?? '');
                                          final top = Uri.encodeComponent(t['title'] as String? ?? '');
                                          context.push('/chat?scope=$sub&prompt=${Uri.encodeComponent('Help me study: ${t['title']} (${t['subject']})')}');
                                        } else if (val == 'tomorrow') {
                                          _moveTaskToTomorrow(i);
                                        } else if (val == 'delete') {
                                          _removeTask(i);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'start', child: Text('Begin session')),
                                        PopupMenuItem(value: 'focus', child: Text('Focus timer')),
                                        PopupMenuItem(value: 'chat', child: Text('Ask Sage about this')),
                                        PopupMenuItem(value: 'tomorrow', child: Text('Move to tomorrow')),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Remove task', style: TextStyle(color: AppColors.error)),
                                        ),
                                      ],
                                    ),

                                    // Checkbox Toggle
                                    InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        _toggleTask(i);
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: isDone
                                            ? Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: redSeal,
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.check_rounded,
                                                  size: 15,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isUpNext
                                                        ? redSeal
                                                        : (isDark ? const Color(0xFF44403C) : const Color(0xFFD6D3D1)),
                                                    width: 1.6,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Bottom Metadata Line: Subject Tag + Duration + Mastered Stamp on Right
                                Padding(
                                  padding: const EdgeInsets.only(left: 40),
                                  child: Row(
                                    children: [
                                      // Subject Wash Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: chipStyle.background,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          subjectTitle,
                                          style: TextStyle(
                                            fontFamilyFallback: ZenTypography.sansFallbacks,
                                            fontSize: 10,
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
                                          fontFamilyFallback: ZenTypography.sansFallbacks,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: secondaryMist,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isDone) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF059669).withOpacity(0.5) : const Color(0xFF16A34A).withOpacity(0.4),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            '✓ Completed',
                                            style: TextStyle(
                                              fontFamilyFallback: ZenTypography.sansFallbacks,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D),
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ),
                                      ] else if (isUpNext) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? ZenColors.darkVermilion : ZenColors.sumiInk,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
                                              SizedBox(width: 2),
                                              Text(
                                                'Focus',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Quick Study Tools
              Text(
                "Quick Study",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.liquidTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _QuickStudyChip(
                      icon: Icons.quiz_outlined,
                      label: 'Rapid Quiz',
                      onTap: () => context.push('/quiz'),
                    ),
                    const SizedBox(width: 8),
                    _QuickStudyChip(
                      icon: Icons.style_outlined,
                      label: 'Flashcards',
                      onTap: () => context.push('/flashcards'),
                    ),
                    const SizedBox(width: 8),
                    _QuickStudyChip(
                      icon: Icons.timer_outlined,
                      label: 'Focus Timer',
                      onTap: () => context.push('/focus'),
                    ),
                    const SizedBox(width: 8),
                    _QuickStudyChip(
                      icon: Icons.mic_none_rounded,
                      label: 'Voice Tutor',
                      onTap: () => context.push('/voice-tutor'),
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

class _QuickStudyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickStudyChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.liquidGlassFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: isDark ? LiquidGlassTheme.darkGlassShadow() : LiquidGlassTheme.lightGlassShadow(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: LiquidGlassTheme.electricIndigo),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.liquidTextPrimary,
              ),
            ),
          ],
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
