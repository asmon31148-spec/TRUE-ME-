import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';

enum FocusModePreset {
  pomodoro(25, 5, 'Pomodoro', '25m Focus · 5m Rest'),
  deepWork(50, 10, 'Deep Work', '50m Deep Flow · 10m Rest'),
  sprint(15, 3, 'Sprint', '15m High Intensity'),
  custom(30, 5, 'Custom', 'Personalized duration');

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
                style: AppTypography.editorialHero.copyWith(fontSize: 32, color: context.accentColor),
              ),
              const SizedBox(height: 16),
              Slider(
                value: picked.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                activeColor: context.accentColor,
                onChanged: (val) => setDialogState(() => picked = val.round()),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(110, 42)),
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
    setState(() => _remainingSeconds = _totalSeconds);
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
            title: const Text('Focus Session Complete!'),
            content: Text(
              'You completed $completedMinutes minutes of deep focus on "$_selectedTopic" ($_selectedSubject).\n\nReady for a ${_preset.breakMinutes}-minute rest?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Finish Now')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(120, 42),
                ),
                onPressed: () => Navigator.pop(ctx, true),
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
    if (!_isRunning && _elapsedWorkSeconds < 60) return true;

    final elapsedMins = (_elapsedWorkSeconds / 60).round();
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Focus Session?'),
        content: Text(
          elapsedMins >= 1
              ? 'You have focused for $elapsedMins ${elapsedMins == 1 ? 'minute' : 'minutes'}. Save this progress before leaving?'
              : 'Your active session is running. Are you sure you want to quit?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
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
        body: TrueMeAmbientBackground(
          child: SafeArea(
            child: Column(
              children: [
                TrueMeTopBar(
                  title: isBreak ? 'Rest Interval' : 'Focus Flow',
                  onBack: () async {
                    final ok = await _handlePopRequest();
                    if (ok && mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  trailing: TrueMeCircleIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Custom Duration',
                    size: 40,
                    onPressed: _showCustomDurationDialog,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: FocusModePreset.values.map((p) {
                        final isSelected = _preset == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppChip(
                            label: '${p.workMinutes}m · ${p.title}',
                            isSelected: isSelected,
                            onTap: _isRunning ? () {} : () => _switchPreset(p),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                Center(
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, _) {
                      final breathScale = _isRunning ? 1.0 + (_pulseCtrl.value * 0.025) : 1.0;
                      return Transform.scale(
                        scale: breathScale,
                        child: TrueMeCircularRing(
                          progress: progress,
                          size: 236,
                          strokeWidth: 12,
                          gradientColors: isBreak
                              ? const [AppColors.success, Color(0xFF34D399), AppColors.success]
                              : const [AppColors.accent, AppColors.secondary, AppColors.accentCyan, AppColors.accent],
                          center: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(_remainingSeconds),
                                style: AppTypography.editorialHero.copyWith(
                                  fontSize: 48,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TrueMeTonalPill(
                                label: isBreak ? 'REST BREAK' : _selectedSubject.toUpperCase(),
                                backgroundColor: accentThemeColor.withValues(alpha: 0.12),
                                foregroundColor: accentThemeColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TrueMeCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        AppIconBadge(icon: Icons.track_changes_rounded, color: accentThemeColor),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedTopic,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$_selectedSubject · ${isBreak ? 'Consolidating memory' : 'Deep cognitive focus'}',
                                style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (!_isRunning && _subjects.length > 1)
                          PopupMenuButton<String>(
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.textSecondary),
                            tooltip: 'Switch subject',
                            onSelected: (val) => setState(() => _selectedSubject = val),
                            itemBuilder: (_) => _subjects
                                .map((s) => PopupMenuItem(value: s, child: Text(s)))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Row(
                    children: [
                      TrueMeCircleIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Reset',
                        size: 52,
                        onPressed: _resetTimer,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TrueMePrimaryButton(
                          label: _isRunning
                              ? 'Pause Flow'
                              : (_remainingSeconds == _totalSeconds ? 'Enter Flow' : 'Resume Flow'),
                          leadingIcon: Icon(
                            _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                          onPressed: _toggleTimer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      TrueMeCircleIconButton(
                        icon: Icons.check_circle_outline_rounded,
                        tooltip: 'Complete & Log',
                        iconColor: AppColors.success,
                        size: 52,
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
                              SnackBar(content: Text('Logged $elapsedMins minutes of deep study!')),
                            );
                            context.pop();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
