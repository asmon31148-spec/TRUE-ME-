import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/theme_provider.dart';
import '../../app/theme/typography.dart';
import 'app_components.dart';

/// Displays an animated real-time percentage progress indicator (0% -> 96%),
/// stage label, and elapsed timer capped under 1 minute for AI generation tasks.
class GenerationProgressView extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> stages;
  final bool compact;

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
    // Smooth asymptotic curve reaching ~95% by 25-50s, never exceeding 96% until complete
    final secs = _elapsedMs / 1000.0;
    if (secs < 1.5) return 0.12 + (secs / 1.5) * 0.22; // 12% -> 34%
    if (secs < 5.0) return 0.34 + ((secs - 1.5) / 3.5) * 0.38; // 34% -> 72%
    if (secs < 15.0) return 0.72 + ((secs - 5.0) / 10.0) * 0.18; // 72% -> 90%
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
    final value = _progress;
    final pct = (value * 100).round();
    final elapsedSec = (_elapsedMs / 1000).floor();
    final stage = _currentStage(pct);

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.accentColor.withOpacity(0.5)),
        ),
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                  ),
                ),
                Text(
                  '$pct%',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.accentColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppProgressBar(value: value),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(stage, style: AppTypography.smallLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text('${elapsedSec}s / 50s max', style: AppTypography.smallLabel),
              ],
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 6,
                    backgroundColor: context.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(context.accentColor),
                  ),
                  Center(
                    child: Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: AppTypography.sectionHeading,
            ),
            const SizedBox(height: 6),
            Text(
              stage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: context.accentColor, fontWeight: FontWeight.w500),
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, textAlign: TextAlign.center, style: AppTypography.secondary),
            ],
            const SizedBox(height: 12),
            Text(
              'Elapsed: ${elapsedSec}s (max 50s)',
              style: AppTypography.smallLabel,
            ),
          ],
        ),
      ),
    );
  }
}
