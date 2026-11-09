import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/app_components.dart';

class VoiceSessionScreen extends StatefulWidget {
  const VoiceSessionScreen({super.key});

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends State<VoiceSessionScreen> {
  bool _isSpeaking = false;
  bool _isMuted = false;

  void _showTypeSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type question', style: AppTypography.sectionHeading),
            const SizedBox(height: 12),
            AppInput(
              controller: controller,
              hintText: 'Ask Sage tutor...',
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Send',
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _isSpeaking = true);
                Future.delayed(const Duration(seconds: 4), () {
                  if (mounted) setState(() => _isSpeaking = false);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Voice tutor', style: AppTypography.screenTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Centered simple circle that changes size slightly with audio level (flat accent color, no glow, no gradient)
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isSpeaking ? 140 : 110,
                height: _isSpeaking ? 140 : 110,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status text below
            Text(
              _isSpeaking ? 'Sage is speaking' : (_isMuted ? 'Muted' : 'Listening'),
              style: AppTypography.sectionHeading,
            ),
            const SizedBox(height: 6),
            const Text(
              'Microbiology tutor session',
              style: AppTypography.secondary,
            ),

            const Spacer(),

            // Three controls at the bottom: Mute, Type instead, End session
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppSecondaryButton(
                          label: _isMuted ? 'Unmute' : 'Mute',
                          icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, size: 20),
                          onPressed: () => setState(() => _isMuted = !_isMuted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppSecondaryButton(
                          label: 'Type instead',
                          icon: const Icon(Icons.keyboard_outlined, size: 20),
                          onPressed: _showTypeSheet,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppPrimaryButton(
                    label: 'End session',
                    onPressed: () => context.pop(),
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
