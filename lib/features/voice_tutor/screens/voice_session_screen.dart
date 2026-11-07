import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class VoiceSessionScreen extends StatefulWidget {
  const VoiceSessionScreen({super.key});

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends State<VoiceSessionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isListening = false;
  bool _isSageSpeaking = true;
  int _sessionMinutes = 24;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Sage Voice Tutor',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => context.go('/library'),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_sessionMinutes}m left',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentCyan),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSageSpeaking ? AppColors.accentCyan : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSageSpeaking ? 'SAGE IS SPEAKING' : 'LISTENING TO YOU',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Glowing Animated Voice Orb (Liquid Glass Core)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.12);
                  final glowRadius = 30.0 + (_pulseController.value * 35.0);

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.sageGlowGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: glowRadius,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.4),
                            blurRadius: glowRadius * 0.8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.graphic_eq, size: 68, color: Colors.white),
                      ),
                    ),
                  );
                },
              ),

              const Spacer(),

              // Live Transcript Card
              GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.subtitles_outlined, size: 16, color: AppColors.accentCyan),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE TRANSCRIPT (ON-DEVICE STT/TTS)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '"Let\'s review Mutexes vs Semaphores. Can you explain why a binary semaphore is fundamentally different from a mutex with ownership?"',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassButton(
                    borderRadius: 999,
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.volume_up, color: Colors.white),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 20),
                  GlassButton(
                    isPrimary: true,
                    borderRadius: 999,
                    height: 64,
                    width: 64,
                    padding: EdgeInsets.zero,
                    child: Icon(
                      _isListening ? Icons.pause : Icons.mic,
                      size: 28,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _isListening = !_isListening;
                        _isSageSpeaking = !_isListening;
                      });
                    },
                  ),
                  const SizedBox(width: 20),
                  GlassButton(
                    borderRadius: 999,
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.call_end, color: AppColors.error),
                    onPressed: () => context.go('/library'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
