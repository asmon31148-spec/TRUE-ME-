import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class ExplainerPlayerScreen extends StatefulWidget {
  const ExplainerPlayerScreen({super.key});

  @override
  State<ExplainerPlayerScreen> createState() => _ExplainerPlayerScreenState();
}

class _ExplainerPlayerScreenState extends State<ExplainerPlayerScreen> {
  bool _isPlaying = true;
  double _currentProgress = 0.35; // 35% through the 10-minute video
  double _playbackSpeed = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Explainer Video',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white70),
            tooltip: 'Export Explainer',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Explainer video script saved to study notes.'),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated Video Stage (Pure Flutter Timeline)
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 28,
                  surfaceGradient: const LinearGradient(
                    colors: [Color(0x331E1B4B), Color(0x1A0F172A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Diagram Node Simulation
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.accentCyan, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentCyan.withOpacity(0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.hub_outlined,
                              size: 54,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Scene 2: The Bankers Safety Algorithm',
                          style: AppTypography.headlineMedium,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            '"Let Work = Available and Finish[i] = false for all processes. Find an index i such that Finish[i] == false and Need_i <= Work..."',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Progress Scrubber & Timing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('03:30', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const Text('10:00', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbColor: AppColors.accentCyan,
                  activeTrackColor: AppColors.accentCyan,
                  inactiveTrackColor: Colors.white.withOpacity(0.12),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: _currentProgress,
                  onChanged: (val) => setState(() => _currentProgress = val),
                ),
              ),

              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_playbackSpeed == 1.0) {
                          _playbackSpeed = 1.25;
                        } else if (_playbackSpeed == 1.25) {
                          _playbackSpeed = 1.5;
                        } else {
                          _playbackSpeed = 1.0;
                        }
                      });
                    },
                    child: Text(
                      '${_playbackSpeed}x',
                      style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GlassButton(
                    borderRadius: 999,
                    height: 54,
                    width: 54,
                    padding: EdgeInsets.zero,
                    isPrimary: true,
                    child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 28),
                    onPressed: () => setState(() => _isPlaying = !_isPlaying),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: Colors.white70),
                    onPressed: () {
                      setState(() {
                        _currentProgress = (_currentProgress - 0.05).clamp(0.0, 1.0);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
