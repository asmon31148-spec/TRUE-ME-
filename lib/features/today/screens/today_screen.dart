import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/utils/study_analytics.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/generation_progress_view.dart';
import '../../../shared/widgets/true_me_ui.dart';

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
  String _userName = 'Student';
  bool _isGeneratingPlan = false;
  String _subjectFilter = 'All';
  late StudyAnalyticsSnapshot _analytics;

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

    final cached = OfflineCacheService.getCachedStudyPlan(_todayKey);
    if (cached != null && cached['sessions'] is List) {
      _tasks = (cached['sessions'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } else {
      _tasks = [];
    }

    _analytics = StudyAnalyticsSnapshot.computeLive();
    if (mounted) setState(() {});
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
        daysLeft: _analytics.daysLeft,
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
        setState(() => _analytics = StudyAnalyticsSnapshot.computeLive());
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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline.isAfter(now) ? _deadline : now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      await OfflineCacheService.saveTargetExamDate(picked);
      if (mounted) _loadData();
    }
  }

  String _greetingPrefix() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String _shortFormattedDate() {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
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
    final isDark = context.isDarkMode;
    final completedCount = _tasks.where((t) => t['completed'] == true).length;
    final double planProgress = _tasks.isNotEmpty ? completedCount / _tasks.length : 0.0;
    final int upNextIdx = _tasks.indexWhere((t) => t['completed'] != true);
    final Map<String, dynamic>? upNextTask = upNextIdx >= 0 ? _tasks[upNextIdx] : null;
    final firstName = _userName.trim().split(RegExp(r'\s+')).first;

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

    final hasAnalyticsProgress = _analytics.readinessScore > 0;
    final kpiProgressPct = hasAnalyticsProgress ? _analytics.readinessScore : (planProgress * 100).round();
    final kpiProgressValue = hasAnalyticsProgress ? _analytics.readinessScore / 100.0 : planProgress;
    final kpiProgressLabel = hasAnalyticsProgress ? 'Exam Readiness' : 'Daily Progress';

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.accentColor,
            onRefresh: () async {
              await OfflineCacheService.syncFromCloud();
              if (mounted) _loadData();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
              children: [
                // 1. Editorial Header Row (Greeting + Calendar/Exam + Avatar)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greetingPrefix(),
                            style: AppTypography.sectionHeading.copyWith(
                              fontSize: 21,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            '${firstName.isNotEmpty ? firstName : 'Scholar'}!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.editorialHero.copyWith(
                              fontSize: 29,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _pickExamDeadline,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_outlined, size: 13.5, color: context.textSecondary),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '${_shortFormattedDate()} · ${_analytics.daysLeft == 0 ? 'Exam Today' : '${_analytics.daysLeft}d to exam'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.secondary.copyWith(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          TrueMeCircleIconButton(
                            icon: Icons.calendar_month_outlined,
                            tooltip: 'Study Planner',
                            onPressed: () async {
                              await context.push('/schedule');
                              if (mounted) _loadData();
                            },
                          ),
                          const SizedBox(width: 10),
                          TrueMeAvatar(
                            name: _userName,
                            size: 44,
                            onTap: () async {
                              await context.push('/account');
                              if (mounted) _loadData();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. Hero "Today's Focus" Card
                _buildHeroFocusCard(context, isDark, upNextTask, completedCount),
                const SizedBox(height: 12),

                // 3. Split 2-Column KPI Cards (Study Streak + Overall/Daily Progress)
                Row(
                  children: [
                    Expanded(
                      child: TrueMeCard(
                        borderRadius: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        onTap: () => context.go('/progress'),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2B2110)
                                    : AppColors.pastelAmber,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.local_fire_department_rounded,
                                size: 22,
                                color: isDark ? AppColors.darkWarning : const Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Study Streak',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.smallLabel.copyWith(
                                      color: context.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_analytics.streak} ${_analytics.streak == 1 ? 'day' : 'days'}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, size: 15, color: context.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TrueMeCard(
                        borderRadius: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        onTap: () => context.go('/progress'),
                        child: Row(
                          children: [
                            TrueMeCircularRing(
                              progress: kpiProgressValue.clamp(0.0, 1.0),
                              size: 40,
                              strokeWidth: 4.5,
                              gradientColors: const [
                                AppColors.success,
                                AppColors.accent,
                                AppColors.success,
                              ],
                              center: Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    kpiProgressLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.smallLabel.copyWith(
                                      color: context.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$kpiProgressPct%',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, size: 15, color: context.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // 4. Quick Access Strip (Sage, Library, Planner, Quiz)
                TrueMeSectionHeader(
                  title: 'Quick Access',
                  actionLabel: 'See all',
                  onActionTap: () => context.go('/practice'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _QuickAccessItem(
                      label: 'Sage',
                      icon: Icons.auto_awesome_rounded,
                      bgColor: isDark ? AppColors.darkAccentWash : const Color(0xFFEDE9FE),
                      iconColor: context.accentColor,
                      onTap: () => context.push('/chat'),
                    ),
                    const SizedBox(width: 10),
                    _QuickAccessItem(
                      label: 'Library',
                      icon: Icons.menu_book_rounded,
                      bgColor: isDark ? const Color(0xFF11233D) : const Color(0xFFE0F2FE),
                      iconColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0284C7),
                      onTap: () => context.go('/library'),
                    ),
                    const SizedBox(width: 10),
                    _QuickAccessItem(
                      label: 'Planner',
                      icon: Icons.event_note_rounded,
                      bgColor: isDark ? const Color(0xFF2B2110) : const Color(0xFFFEF3C7),
                      iconColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                      onTap: () async {
                        await context.push('/schedule');
                        if (mounted) _loadData();
                      },
                    ),
                    const SizedBox(width: 10),
                    _QuickAccessItem(
                      label: 'Quiz',
                      icon: Icons.quiz_rounded,
                      bgColor: isDark ? const Color(0xFF1D1B3B) : const Color(0xFFE0E7FF),
                      iconColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                      onTap: () async {
                        await context.push('/quiz');
                        if (mounted) _loadData();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (_isGeneratingPlan) ...[
                  const GenerationProgressView(
                    compact: true,
                    title: 'Crafting your study plan with Sage',
                    stages: [
                      'Checking your exam deadline...',
                      'Balancing weak topics & decks...',
                      'Organizing Today & Tomorrow...',
                      'Saving study sessions...',
                    ],
                  ),
                  const SizedBox(height: 18),
                ],

                // 5. Today's Study Plan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            "Today's Plan",
                            style: AppTypography.sectionHeading.copyWith(color: context.textPrimary),
                          ),
                          if (_tasks.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            TrueMeTonalPill(
                              label: '$completedCount/${_tasks.length}',
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_tasks.isNotEmpty)
                          TrueMeTonalPill(
                            label: 'Re-align',
                            icon: Icons.auto_awesome_rounded,
                            onTap: _isGeneratingPlan ? null : _generateAiPlan,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        const SizedBox(width: 6),
                        TrueMeTonalPill(
                          label: 'Schedule',
                          icon: Icons.calendar_today_outlined,
                          backgroundColor: context.surfaceColor,
                          foregroundColor: context.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          onTap: () async {
                            await context.push('/schedule');
                            if (mounted) _loadData();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_tasks.isEmpty)
                  TrueMeCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No study sessions scheduled for today.',
                          style: AppTypography.cardTitle.copyWith(color: context.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Let Sage generate a balanced plan from your subjects, or add a task manually.',
                          style: AppTypography.secondary.copyWith(color: context.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TrueMePrimaryButton(
                                label: 'Plan with Sage',
                                height: 46,
                                leadingIcon: const Icon(Icons.auto_awesome_rounded, size: 17, color: Colors.white),
                                isLoading: _isGeneratingPlan,
                                onPressed: _generateAiPlan,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppSecondaryButton(
                                label: 'Add Manually',
                                height: 46,
                                onPressed: () async {
                                  await context.push('/schedule');
                                  if (mounted) _loadData();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (taskSubjects.length >= 2) ...[
                    SizedBox(
                      height: 38,
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

                  TrueMeCard(
                    borderRadius: 20,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: List.generate(visibleIndices.length, (entryIdx) {
                        final i = visibleIndices[entryIdx];
                        final t = _tasks[i];
                        final isDone = t['completed'] == true;
                        final isUpNext = (i == upNextIdx) && !isDone;
                        final type = t['type'] as String? ?? 'reading';
                        final rawSubject = (t['subject'] as String? ?? 'Study').trim();
                        final subjectTitle = _toTitleCase(rawSubject);
                        final pastel = SubjectPastelStyle.forSubject(rawSubject, isDark: isDark);
                        final mins = (t['duration'] as num? ?? 20).toInt();
                        final isLast = entryIdx == visibleIndices.length - 1;

                        return Container(
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : Border(bottom: BorderSide(color: context.borderColor, width: 0.8)),
                          ),
                          child: InkWell(
                            onTap: () => _launchTask(t),
                            onLongPress: () => _moveTaskToTomorrow(i),
                            borderRadius: BorderRadius.vertical(
                              top: entryIdx == 0 ? const Radius.circular(20) : Radius.zero,
                              bottom: isLast ? const Radius.circular(20) : Radius.zero,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleTask(i),
                                    behavior: HitTestBehavior.opaque,
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 160),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDone ? context.accentColor : Colors.transparent,
                                          border: Border.all(
                                            color: isDone
                                                ? context.accentColor
                                                : (isUpNext ? context.accentColor : context.borderColor),
                                            width: 1.8,
                                          ),
                                        ),
                                        child: isDone
                                            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: pastel.bgStart,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: pastel.border, width: 0.8),
                                    ),
                                    child: Icon(_taskIcon(type), size: 18, color: pastel.accent),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t['title'] as String? ?? 'Task',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: isUpNext ? FontWeight.w700 : FontWeight.w600,
                                            color: isDone ? context.textSecondary : context.textPrimary,
                                            decoration: isDone ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: pastel.bgEnd,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                subjectTitle,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: pastel.accent,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '· ${mins}m',
                                              style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert_rounded, size: 19, color: context.textSecondary),
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
                                        context.push(
                                          '/chat?scope=$sub&prompt=${Uri.encodeComponent('Help me study: ${t['title']} (${t['subject']})')}',
                                        );
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
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // 6. Calm Sage Insight Banner (Real Insight Data, Pastoral Backdrop)
                TrueMeCard(
                  borderRadius: 20,
                  padding: EdgeInsets.zero,
                  gradient: isDark ? AppColors.heroFocusDarkGradient : AppColors.heroFocusLightGradient,
                  onTap: () {
                    if (_analytics.prescriptionRoute == '/library') {
                      context.go('/library');
                    } else {
                      context.push(_analytics.prescriptionRoute);
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -12,
                          bottom: -14,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: const Size(150, 96),
                              painter: _SoftHorizonPainter(isDark: isDark),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 16, color: context.accentColor),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Sage Prescription',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: context.accentColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(right: 48),
                                child: Text(
                                  _analytics.sagePrescription,
                                  style: AppTypography.body.copyWith(
                                    fontSize: 14,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TrueMeTonalPill(
                                label: _analytics.dueCards > 0
                                    ? 'Review ${_analytics.dueCards} Due Cards'
                                    : (_analytics.weakTopics.isNotEmpty ? 'Practice Weak Topic' : 'Ask Sage'),
                                icon: Icons.arrow_forward_rounded,
                                backgroundColor: context.surfaceColor,
                                foregroundColor: context.accentColor,
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
        ),
      ),
    );
  }

  Widget _buildHeroFocusCard(
    BuildContext context,
    bool isDark,
    Map<String, dynamic>? upNextTask,
    int completedCount,
  ) {
    final hasTask = upNextTask != null;
    final allDone = !hasTask && _tasks.isNotEmpty;

    final String heroTitle = hasTask
        ? (upNextTask['title'] as String? ?? 'Next Session')
        : (allDone ? 'All Goals Completed!' : 'Today\'s Study Focus');

    final String heroSubtitle = hasTask
        ? '${_toTitleCase(upNextTask['subject'] as String? ?? 'Study')} · ${upNextTask['duration'] ?? 25} min session'
        : (allDone
            ? 'You completed all $completedCount study sessions today.'
            : 'Draft your daily study roadmap with Sage.');

    final String ctaLabel = hasTask
        ? 'Continue'
        : (allDone ? 'View Progress' : 'Plan Day with Sage');

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.heroFocusDarkGradient : AppColors.heroFocusLightGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE0DCF5),
          width: 1,
        ),
        boxShadow: context.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Soft calm architectural arch illustration on right side
            Positioned(
              right: 0,
              bottom: 0,
              top: 0,
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size(165, 190),
                  painter: _HeroArchPainter(isDark: isDark),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: context.surfaceColor.withValues(alpha: 0.78),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.track_changes_rounded,
                          size: 14,
                          color: context.accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Today's Focus",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 68),
                    child: Text(
                      heroTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sectionHeading.copyWith(
                        fontSize: 21,
                        color: context.textPrimary,
                        height: 1.22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 68),
                    child: Text(
                      heroSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.secondary.copyWith(
                        fontSize: 13.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (hasTask) {
                            _launchTask(upNextTask);
                          } else if (allDone) {
                            context.go('/progress');
                          } else {
                            _generateAiPlan();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.accent : AppColors.textPrimary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.textPrimary.withValues(alpha: 0.16),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isGeneratingPlan) ...[
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                ctaLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TrueMeCard(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight custom painter creating the calm pastel arch & hill motif on Hero Focus Card.
class _HeroArchPainter extends CustomPainter {
  final bool isDark;

  const _HeroArchPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final hill1 = Paint()
      ..color = (isDark ? const Color(0xFF2D2C54) : const Color(0xFFC5C0F0)).withValues(alpha: 0.45);
    final hill2 = Paint()
      ..color = (isDark ? const Color(0xFF3A376B) : const Color(0xFFAFA7EC)).withValues(alpha: 0.50);

    final p1 = Path()
      ..moveTo(size.width * 0.15, size.height)
      ..quadraticBezierTo(size.width * 0.50, size.height * 0.42, size.width, size.height * 0.62)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p1, hill1);

    final p2 = Path()
      ..moveTo(size.width * 0.35, size.height)
      ..quadraticBezierTo(size.width * 0.72, size.height * 0.58, size.width, size.height * 0.75)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p2, hill2);

    // Serene gateway portal arch
    final archOuter = Paint()
      ..color = (isDark ? const Color(0xFF818CF8) : const Color(0xFF6B6CE6)).withValues(alpha: 0.35);
    final archInner = Paint()
      ..color = (isDark ? const Color(0xFF1F2238) : const Color(0xFFF3F1FC)).withValues(alpha: 0.85);

    final archRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(size.width * 0.54, size.height * 0.32, 36, 52),
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
    );
    canvas.drawRRect(archOuterRect(archRect), archOuter);
    canvas.drawRRect(archRect.deflate(4), archInner);
  }

  RRect archOuterRect(RRect inner) => inner;

  @override
  bool shouldRepaint(covariant _HeroArchPainter oldDelegate) => oldDelegate.isDark != isDark;
}

class _SoftHorizonPainter extends CustomPainter {
  final bool isDark;

  const _SoftHorizonPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.18, size.width, size.height * 0.50)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      p1,
      Paint()..color = (isDark ? const Color(0xFF33306B) : const Color(0xFFCCC6F6)).withValues(alpha: 0.55),
    );

    final sun = Paint()
      ..color = (isDark ? const Color(0xFF818CF8) : const Color(0xFF9E98F2)).withValues(alpha: 0.35);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 0.70, size.height * 0.45), radius: math.min(size.width, size.height) * 0.24),
      0,
      math.pi * 2,
      true,
      sun,
    );
  }

  @override
  bool shouldRepaint(covariant _SoftHorizonPainter oldDelegate) => oldDelegate.isDark != isDark;
}
