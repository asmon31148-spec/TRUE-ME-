import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/voice_tutor_provider.dart';

class VoiceSessionScreen extends ConsumerStatefulWidget {
  const VoiceSessionScreen({super.key});

  @override
  ConsumerState<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends ConsumerState<VoiceSessionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final TextEditingController _textFallbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textFallbackController.dispose();
    super.dispose();
  }

  void _showTextInputDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ask Sage Voice Tutor', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _textFallbackController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Type your study question...',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final text = _textFallbackController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                _textFallbackController.clear();
                // Inject transcript and process
                ref.read(voiceTutorProvider.notifier).startListening();
                // Send directly to Sage
                final prompt = '''
Student question to Voice Tutor:
"$text"

Respond conversationally as Sage, the AI study coach. Keep your response spoken and direct (2-3 concise sentences).
''';
                ref.read(voiceTutorProvider.notifier).stopAndProcessInput();
              }
            },
            child: const Text('Ask', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tutorState = ref.watch(voiceTutorProvider);
    final status = tutorState.status;
    final isListening = status == VoiceTutorStatus.listening;
    final isProcessing = status == VoiceTutorStatus.processing;
    final isSpeaking = status == VoiceTutorStatus.speaking;

    String statusText = 'READY TO TALK';
    Color statusColor = AppColors.accentCyan;

    if (isListening) {
      statusText = 'LISTENING TO YOU...';
      statusColor = AppColors.warning;
    } else if (isProcessing) {
      statusText = 'SAGE IS THINKING...';
      statusColor = AppColors.primaryLight;
    } else if (isSpeaking) {
      statusText = 'SAGE IS SPEAKING';
      statusColor = AppColors.success;
    }

    final displayText = tutorState.liveTranscript.isNotEmpty
        ? tutorState.liveTranscript
        : tutorState.lastAiResponse.isNotEmpty
            ? tutorState.lastAiResponse
            : 'Tap the microphone below and ask Sage about your study topics or exam concepts.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlassAppBar(
        title: 'Sage Voice Tutor',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () async {
            await ref.read(voiceTutorProvider.notifier).stopSession();
            if (mounted) context.go('/library');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_outlined, color: AppColors.accentCyan),
            tooltip: 'Type Question Fallback',
            onPressed: _showTextInputDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Glowing Animated Voice Orb
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = isSpeaking || isListening
                      ? 1.0 + (_pulseController.value * 0.16)
                      : 1.0 + (_pulseController.value * 0.05);

                  final glowRadius = isSpeaking
                      ? 35.0 + (_pulseController.value * 35.0)
                      : isListening
                          ? 25.0 + (_pulseController.value * 25.0)
                          : 20.0;

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSpeaking
                            ? AppColors.primaryGradient
                            : isListening
                                ? const LinearGradient(
                                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                                  )
                                : AppColors.sageGlowGradient,
                        boxShadow: [
                          BoxShadow(
                            color: (isListening ? AppColors.warning : AppColors.primary)
                                .withOpacity(0.5),
                            blurRadius: glowRadius,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isProcessing
                              ? Icons.hourglass_top
                              : isListening
                                  ? Icons.hearing
                                  : Icons.graphic_eq,
                          size: 68,
                          color: Colors.white,
                        ),
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
                        Icon(
                          isListening ? Icons.mic : Icons.subtitles_outlined,
                          size: 16,
                          color: AppColors.accentCyan,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isListening ? 'YOUR LIVE SPEECH' : 'SAGE RESPONSE',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      '"$displayText"',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: Colors.white,
                      ),
                    ),
                    if (tutorState.error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Note: ${tutorState.error}',
                        style: const TextStyle(fontSize: 12, color: AppColors.warning),
                      ),
                    ],
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
                    tooltip: 'Type question',
                    child: const Icon(Icons.edit_note, color: Colors.white),
                    onPressed: _showTextInputDialog,
                  ),
                  const SizedBox(width: 20),
                  GlassButton(
                    isPrimary: true,
                    borderRadius: 999,
                    height: 68,
                    width: 68,
                    padding: EdgeInsets.zero,
                    surfaceColor: isListening ? AppColors.warning : AppColors.primary,
                    child: Icon(
                      isListening ? Icons.stop : Icons.mic,
                      size: 32,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      if (isListening) {
                        await ref.read(voiceTutorProvider.notifier).stopAndProcessInput();
                      } else {
                        await ref.read(voiceTutorProvider.notifier).startListening();
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  GlassButton(
                    borderRadius: 999,
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.call_end, color: AppColors.error),
                    onPressed: () async {
                      await ref.read(voiceTutorProvider.notifier).stopSession();
                      if (mounted) context.go('/library');
                    },
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
