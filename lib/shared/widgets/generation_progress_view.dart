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

  @override
  Widget build(BuildContext context) {
    final hasRealStage = widget.realStageLabel != null && widget.realStageIndex != null;
    final total = widget.realTotalStages ?? 7;
    final double? value = hasRealStage
        ? ((widget.realStageIndex! + 1) / total).clamp(0.08, 1.0)
        : null; // Honest indeterminate when real stage counts are absent
    final elapsedSec = (_elapsedMs / 1000).floor();
    final stage = hasRealStage
        ? 'Stage ${widget.realStageIndex! + 1}/$total · ${widget.realStageLabel!}'
        : (widget.stages.isNotEmpty ? widget.stages.first : 'Working...');

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
                  label: hasRealStage
                      ? 'Step ${widget.realStageIndex! + 1}/$total'
                      : 'In Progress',
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ],
            ),
            const SizedBox(height: 10),
            value != null
                ? AppProgressBar(value: value)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(minHeight: 6),
                  ),
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
              value != null
                  ? TrueMeCircularRing(
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
                        '${widget.realStageIndex! + 1}/$total',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontFamilyFallback: AppTypography.serifFallbacks,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    )
                  : const SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(strokeWidth: 5),
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
