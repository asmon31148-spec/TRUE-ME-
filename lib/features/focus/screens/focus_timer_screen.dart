import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';

enum FocusModePreset {
  pomodoro(25, 5, 'Classic Pomodoro', '25m Focus · 5m Rest'),
  deepWork(50, 10, 'Deep Work', '50m Deep Flow · 10m Rest'),
  sprint(15, 3, 'Quick Sprint', '15m High Intensity'),
  custom(30, 5, 'Custom Timer', 'Personalized duration');

  final int workMinutes;
  final int breakMinutes;
  final String title;
  final String subtitle;
  const FocusModePreset(this.workMinutes, this.breakMinutes, this.title, this.subtitle);
}

enum FocusPhase { work, breakTime }

class FocusTimerScreen extends StatefulWidget {
  final String? subject;
  final String? topic;
  final int? initialMinutes;

  const FocusTimerScreen({
    super.key,
    this.subject,
    this.topic,
    this.initialMinutes,
  });

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with SingleTickerProviderStateMixin {
  late String _selectedSubject;
  late String _selectedTopic;
  List<String> _subjects = [];

  FocusModePreset _preset = FocusModePreset.pomodoro;
  FocusPhase _phase = FocusPhase.work;

  int _totalSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  int _elapsedWorkSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();

    // 1. Load real subjects from user profile and notebooks
    final userSubs = OfflineCacheService.getUserSubjects();
    final nbSubs = OfflineCacheService.getAllCachedNotebooks()
        .map((n) => (n['title'] as String? ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final allSubs = {...userSubs, ...nbSubs}.toList();
    _subjects = allSubs.isNotEmpty ? allSubs : ['General Study'];

    _selectedSubject = (widget.subject != null && widget.subject!.trim().isNotEmpty)
        ? widget.subject!.trim()
        : _subjects.first;

    _selectedTopic = (widget.topic != null && widget.topic!.trim().isNotEmpty)
        ? widget.topic!.trim()
        : 'Deep Concept Review';

    if (widget.initialMinutes != null && widget.initialMinutes! > 0) {
      _preset = FocusModePreset.custom;
      _totalSeconds = widget.initialMinutes! * 60;
      _remainingSeconds = _totalSeconds;
    } else {
      _totalSeconds = _preset.workMinutes * 60;
      _remainingSeconds = _totalSeconds;
    }

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _switchPreset(FocusModePreset preset) {
    if (_isRunning) return;
    HapticFeedback.selectionClick();
    setState(() {
      _preset = preset;
      _phase = FocusPhase.work;
      _totalSeconds = preset.workMinutes * 60;
      _remainingSeconds = _totalSeconds;
    });
  }

  void _showCustomDurationDialog() {
    if (_isRunning) return;
    int picked = (_totalSeconds / 60).round().clamp(5, 120);

    showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Set Focus Duration', style: AppTypography.sectionHeading),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$picked minutes',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: context.accentColor,
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: picked.toDouble(),
                min: 5,
                max: 120,
                divisions: 23, // 5m steps
                activeColor: context.accentColor,
                onChanged: (val) {
                  setDialogState(() => picked = val.round());
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Short bursts (25m) or deep immersion (50m) are ideal for retention.',
                style: AppTypography.secondary,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, picked),
              child: const Text('Set Duration'),
            ),
          ],
        ),
      ),
    ).then((val) {
      if (val != null && mounted) {
        setState(() {
          _preset = FocusModePreset.custom;
          _phase = FocusPhase.work;
          _totalSeconds = val * 60;
          _remainingSeconds = _totalSeconds;
        });
      }
    });
  }

  void _toggleTimer() {
    HapticFeedback.mediumImpact();
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
          if (_phase == FocusPhase.work) {
            _elapsedWorkSeconds++;
          }
        });
      } else {
        timer.cancel();
        _onPhaseCompleted();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    HapticFeedback.lightImpact();
    _pauseTimer();
    setState(() {
      _remainingSeconds = _totalSeconds;
    });
  }

  Future<void> _onPhaseCompleted() async {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);

    if (_phase == FocusPhase.work) {
      final completedMinutes = (_totalSeconds / 60).round();
      await _logCompletedSession(completedMinutes);

      if (mounted) {
        final takeBreak = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Focus Session Complete! 🏆'),
            content: Text(
              'You successfully completed $completedMinutes minutes of deep focus on "$_selectedTopic" ($_selectedSubject).\n\nReady for a ${_preset.breakMinutes}-minute rest to consolidate memory?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Finish Now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.success),
                child: Text('Start ${_preset.breakMinutes}m Break'),
              ),
            ],
          ),
        );

        if (takeBreak == true && mounted) {
          setState(() {
            _phase = FocusPhase.breakTime;
            _totalSeconds = _preset.breakMinutes * 60;
            _remainingSeconds = _totalSeconds;
          });
          _startTimer();
        } else if (mounted) {
          context.pop();
        }
      }
    } else {
      // Break completed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Break finished! Ready for your next focus session.')),
        );
        setState(() {
          _phase = FocusPhase.work;
          _totalSeconds = _preset.workMinutes * 60;
          _remainingSeconds = _totalSeconds;
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _logCompletedSession(int minutes) async {
    if (minutes <= 0) return;

    await OfflineCacheService.logStudySession(
      activity: 'focus',
      subject: _selectedSubject,
      title: '$_selectedSubject Focus: $_selectedTopic',
      subtitle: '$minutes min Pomodoro sprint',
      minutes: minutes,
    );

    // Also mark corresponding task complete in today's study plan if matching topic
    try {
      final todayKey = OfflineCacheService.dateKey(DateTime.now());
      final plan = OfflineCacheService.getCachedStudyPlan(todayKey);
      if (plan != null && plan['sessions'] is List) {
        final sessions = (plan['sessions'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        bool updated = false;
        for (final s in sessions) {
          final tTitle = (s['title'] as String? ?? '').toLowerCase();
          final tSub = (s['subject'] as String? ?? '').toLowerCase();
          if (tTitle.contains(_selectedTopic.toLowerCase()) ||
              _selectedTopic.toLowerCase().contains(tTitle) ||
              tSub == _selectedSubject.toLowerCase()) {
            if (s['completed'] != true) {
              s['completed'] = true;
              s['loggedOnce'] = true;
              updated = true;
              break;
            }
          }
        }
        if (updated) {
          await OfflineCacheService.cacheStudyPlan(todayKey, {
            'sessions': sessions,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (_) {}
  }

  Future<bool> _handlePopRequest() async {
    if (!_isRunning && _elapsedWorkSeconds < 60) {
      return true;
    }

    final elapsedMins = (_elapsedWorkSeconds / 60).round();
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Focus Session?'),
        content: Text(
          elapsedMins >= 1
              ? 'You have focused for $elapsedMins ${elapsedMins == 1 ? 'minute' : 'minutes'}. Would you like to save this progress before leaving?'
              : 'Your active session is running. Are you sure you want to quit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          if (elapsedMins >= 1)
            TextButton(
              onPressed: () async {
                await _logCompletedSession(elapsedMins);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Save & Exit'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard & Exit'),
          ),
        ],
      ),
    );

    return shouldExit == true;
  }

  String _formatTime(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds > 0
        ? (1.0 - (_remainingSeconds / _totalSeconds)).clamp(0.0, 1.0)
        : 0.0;

    final isBreak = _phase == FocusPhase.breakTime;
    final accentThemeColor = isBreak ? AppColors.success : context.accentColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _handlePopRequest();
        if (ok && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await _handlePopRequest();
              if (ok && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            isBreak ? 'Rest Interval 🌿' : 'Focus Flow ✦',
            style: AppTypography.screenTitle,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Custom Duration',
              onPressed: _showCustomDurationDialog,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Preset Switcher Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: FocusModePreset.values.map((p) {
                      final isSelected = _preset == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(p.workMinutes == 0 ? p.title : '${p.workMinutes}m · ${p.title}'),
                          selected: isSelected,
                          selectedColor: accentThemeColor.withOpacity(0.18),
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? accentThemeColor : context.textSecondary,
                          ),
                          side: BorderSide(
                            color: isSelected ? accentThemeColor : context.borderColor,
                            width: 1,
                          ),
                          onSelected: _isRunning ? null : (_) => _switchPreset(p),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // 2. Center Breathing Circular Timer Ring
              Center(
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, _) {
                    final breathScale = _isRunning ? 1.0 + (_pulseCtrl.value * 0.035) : 1.0;
                    return Transform.scale(
                      scale: breathScale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ambient glow ring
                          Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRunning
                                  ? accentThemeColor.withOpacity(0.04 + (_pulseCtrl.value * 0.05))
                                  : Colors.transparent,
                            ),
                          ),

                          // Background Track Circle
                          SizedBox(
                            width: 230,
                            height: 230,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              backgroundColor: context.borderColor.withOpacity(0.5),
                              valueColor: AlwaysStoppedAnimation<Color>(accentThemeColor),
                              strokeCap: StrokeCap.round,
                            ),
                          ),

                          // Center Time & Subject Display
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(_remainingSeconds),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.0,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accentThemeColor.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isBreak ? 'BRAIN RESTORATION' : _selectedSubject.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color: accentThemeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // 3. Subject & Topic Selector Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subject & Focus Target', style: AppTypography.smallLabel),
                          if (!_isRunning && _subjects.length > 1)
                            PopupMenuButton<String>(
                              icon: Icon(Icons.arrow_drop_down_circle_outlined, size: 18, color: context.accentColor),
                              tooltip: 'Switch subject',
                              onSelected: (val) {
                                setState(() => _selectedSubject = val);
                              },
                              itemBuilder: (_) => _subjects
                                  .map((s) => PopupMenuItem(value: s, child: Text(s)))
                                  .toList(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedTopic,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_selectedSubject • ${isBreak ? 'Consolidating synaptic pathways' : 'Deep cognitive session'}',
                        style: AppTypography.secondary,
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // 4. Ergonomic Controls Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    // Reset Button
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 22),
                        tooltip: 'Reset',
                        onPressed: _resetTimer,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Primary Play / Pause Button
                    Expanded(
                      child: AppPrimaryButton(
                        label: _isRunning ? 'Pause Flow' : (_remainingSeconds == _totalSeconds ? 'Enter Flow' : 'Resume Flow'),
                        backgroundColor: accentThemeColor,
                        icon: Icon(
                          _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 24,
                        ),
                        onPressed: _toggleTimer,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Log / Complete Early Button
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                        tooltip: 'Complete & Log',
                        onPressed: () async {
                          final elapsedMins = (_elapsedWorkSeconds / 60).round();
                          if (elapsedMins < 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Study for at least 1 minute before logging.')),
                            );
                            return;
                          }
                          await _logCompletedSession(elapsedMins);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Logged $elapsedMins minutes of deep study! 🎓')),
                            );
                            context.pop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
