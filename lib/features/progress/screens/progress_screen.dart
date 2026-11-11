import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _daysLeft = 30;
  double _planProgress = 0.0;
  int _streak = 0;
  int _totalWeeklyMinutes = 0;
  List<int> _weeklyBars = [0, 0, 0, 0, 0, 0, 0];
  List<Map<String, dynamic>> _weakTopics = [];
  int _quizzesTaken = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final now = DateTime.now();
    final deadline = OfflineCacheService.getTargetExamDate();
    final daysLeft = OfflineCacheService.daysUntil(deadline);

    final todayPlan = OfflineCacheService.getCachedStudyPlan(OfflineCacheService.dateKey(now));
    final tasks = (todayPlan?['sessions'] as List? ?? []);
    final completed = tasks.where((t) => (t as Map)['completed'] == true).length;
    final planProgress = tasks.isNotEmpty ? completed / tasks.length : 0.0;

    setState(() {
      _daysLeft = daysLeft;
      _planProgress = planProgress;
      _streak = OfflineCacheService.getCurrentStreak();
      _weeklyBars = OfflineCacheService.getWeeklyStudyMinutes();
      _totalWeeklyMinutes = _weeklyBars.fold(0, (s, m) => s + m);
      _weakTopics = OfflineCacheService.getWeakTopics();
      _quizzesTaken = OfflineCacheService.getQuizAttempts().length;
    });
  }

  String _formatDuration(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final maxBarVal = _weeklyBars.fold<int>(30, (maxVal, v) => v > maxVal ? v : maxVal);
    final days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayWeekday = DateTime.now().weekday; // 1=Mon .. 7=Sun

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Progress', style: AppTypography.screenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            tooltip: 'Refresh stats',
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 22),
            tooltip: 'Ask Sage',
            onPressed: () => context.push('/chat'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Pace Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _planProgress >= 1.0
                            ? "Today's plan complete"
                            : (_totalWeeklyMinutes > 0 ? 'Active study' : 'Ready to start'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        '${(_planProgress * 100).toInt()}%',
                        style: AppTypography.smallLabel.copyWith(
                          color: context.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Exam deadline: $_daysLeft ${_daysLeft == 1 ? 'day' : 'days'} left • $_quizzesTaken ${_quizzesTaken == 1 ? 'quiz' : 'quizzes'} completed',
                    style: AppTypography.secondary,
                  ),
                  const SizedBox(height: 12),
                  AppProgressBar(value: _planProgress),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Weak Topics Card (REAL from Quiz attempts)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Topics to improve', style: AppTypography.sectionHeading),
                  const SizedBox(height: 10),
                  if (_weakTopics.isEmpty)
                    Text(
                      _quizzesTaken == 0
                          ? 'Complete a quiz in Practice to detect topics that need review.'
                          : 'No weak topics detected — you scored 80%+ on all quizzes!',
                      style: AppTypography.secondary,
                    )
                  else
                    ...List.generate(_weakTopics.length, (i) {
                      final w = _weakTopics[i];
                      final topic = w['topic'] as String;
                      final score = '${w['score']}%';
                      return Column(
                        children: [
                          _buildWeakTopicRow(context, topic, score),
                          if (i < _weakTopics.length - 1)
                            Divider(color: context.borderColor, height: 16),
                        ],
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Streak and Study Time
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_streak ${_streak == 1 ? 'day' : 'days'}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        const Text('Streak', style: AppTypography.secondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDuration(_totalWeeklyMinutes),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        const Text('This week', style: AppTypography.secondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Study Time Weekly Bar Chart (REAL)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Study time (this week)', style: AppTypography.sectionHeading),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 130,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (i) {
                        return _buildBar(
                          context,
                          days[i],
                          _weeklyBars[i],
                          maxBarVal,
                          isToday: (i + 1) == todayWeekday,
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeakTopicRow(BuildContext context, String topic, String score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              topic,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textPrimary),
            ),
          ),
          Text(
            score,
            style: TextStyle(fontSize: 14, color: context.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () async {
              await context.push('/quiz?topic=${Uri.encodeComponent(topic)}');
              if (mounted) _loadStats();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Practice', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, String day, int minutes, int maxVal, {bool isToday = false}) {
    final ratio = maxVal > 0 ? (minutes / maxVal).clamp(0.0, 1.0) : 0.0;
    final barHeight = minutes > 0 ? (ratio * 84).clamp(6.0, 84.0) : 4.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (minutes > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${minutes}m', style: TextStyle(fontSize: 10, color: context.textSecondary)),
          ),
        Container(
          width: 24,
          height: barHeight,
          decoration: BoxDecoration(
            color: minutes > 0 ? context.accentColor : context.borderColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: AppTypography.smallLabel.copyWith(
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            color: isToday ? context.accentColor : context.textSecondary,
          ),
        ),
      ],
    );
  }
}
