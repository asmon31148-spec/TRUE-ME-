import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme_provider.dart';
import '../../app/theme/typography.dart';
import 'app_components.dart';
import 'true_me_ui.dart';

/// Displays an animated real-time percentage progress indicator (0% -> 96%),
/// stage label, and elapsed timer capped under 1 minute for AI generation tasks.
class GenerationProgressView extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> stages;
  final bool compact;
  final int? realStageIndex;
  final int? realTotalStages;
  final String? realStageLabel;

  const GenerationProgressView({
    super.key,
    required this.title,
    this.subtitle,
    this.stages = const [
      'Reading your study material...',
      'Synthesizing key concepts with Sage...',
      'Structuring output...',
      'Finalizing...',
    ],
    this.compact = false,
    this.realStageIndex,
    this.realTotalStages,
    this.realStageLabel,
  });

  @override
  State<GenerationProgressView> createState() => _GenerationProgressViewState();
}

class _GenerationProgressViewState extends State<GenerationProgressView> {
  Timer? _timer;
  int _elapsedMs = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) {
        setState(() => _elapsedMs += 250);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double get _progress {
    final secs = _elapsedMs / 1000.0;
    if (secs < 1.5) return 0.12 + (secs / 1.5) * 0.22;
    if (secs < 5.0) return 0.34 + ((secs - 1.5) / 3.5) * 0.38;
    if (secs < 15.0) return 0.72 + ((secs - 5.0) / 10.0) * 0.18;
    return (0.90 + ((secs - 15.0) / 35.0) * 0.06).clamp(0.90, 0.96);
  }

  String _currentStage(int pct) {
    if (widget.stages.isEmpty) return 'Generating...';
    if (pct < 28) return widget.stages[0];
    if (pct < 65 && widget.stages.length > 1) return widget.stages[1];
    if (pct < 88 && widget.stages.length > 2) return widget.stages[2];
    return widget.stages.last;
  }

  @override
  Widget build(BuildContext context) {
    final hasRealStage = widget.realStageLabel != null && widget.realStageIndex != null;
    final total = widget.realTotalStages ?? 7;
    final value = hasRealStage
        ? ((widget.realStageIndex! + 1) / total).clamp(0.08, 1.0)
        : _progress;
    final pct = (value * 100).round();
    final elapsedSec = (_elapsedMs / 1000).floor();
    final stage = hasRealStage
        ? 'Stage ${widget.realStageIndex! + 1}/$total · ${widget.realStageLabel!}'
        : _currentStage(pct);

    if (widget.compact) {
      return TrueMeCard(
        borderRadius: 18,
        padding: const EdgeInsets.all(16),
        borderColor: context.accentColor.withValues(alpha: 0.35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: context.textPrimary),
                  ),
                ),
                TrueMeTonalPill(
                  label: '$pct%',
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppProgressBar(value: value),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(stage, style: AppTypography.smallLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text('${elapsedSec}s', style: AppTypography.smallLabel),
              ],
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: TrueMeCard(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrueMeCircularRing(
                progress: value,
                size: 92,
                strokeWidth: 8,
                gradientColors: const [
                  AppColors.accent,
                  AppColors.secondary,
                  AppColors.accentCyan,
                  AppColors.accent,
                ],
                center: Text(
                  '$pct%',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontFamilyFallback: AppTypography.serifFallbacks,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTypography.sectionHeading.copyWith(color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                stage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.accentColor, fontWeight: FontWeight.w600),
              ),
              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(widget.subtitle!, textAlign: TextAlign.center, style: AppTypography.secondary),
              ],
              const SizedBox(height: 12),
              Text(
                'Elapsed: ${elapsedSec}s',
                style: AppTypography.smallLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
