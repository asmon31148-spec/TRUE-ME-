import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../providers/voice_tutor_provider.dart';

class VoiceSessionScreen extends ConsumerStatefulWidget {
  const VoiceSessionScreen({super.key});

  @override
  ConsumerState<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends ConsumerState<VoiceSessionScreen> {
  bool _isMuted = false;
  late String _selectedSubject;
  final DateTime _sessionStart = DateTime.now();
  int _turnsCount = 0;

  @override
  void initState() {
    super.initState();
    final subs = OfflineCacheService.getUserSubjects();
    _selectedSubject = subs.isNotEmpty ? subs.first : 'General Study';
  }

  @override
  void dispose() {
    ref.read(voiceTutorProvider.notifier).stopSession();
    super.dispose();
  }

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
              autofocus: true,
              hintText: 'Ask Sage tutor about $_selectedSubject...',
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Send',
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(ctx);
                if (text.isNotEmpty) {
                  _turnsCount++;
                  ref.read(voiceTutorProvider.notifier).sendTextQuestion(
                        text,
                        subject: _selectedSubject,
                        isMuted: _isMuted,
                      );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endSession() async {
    await ref.read(voiceTutorProvider.notifier).stopSession();
    if (_turnsCount > 0) {
      final mins = DateTime.now().difference(_sessionStart).inMinutes.clamp(1, 120);
      await OfflineCacheService.logStudySession(
        activity: 'voice',
        subject: _selectedSubject,
        title: '$_selectedSubject voice tutor',
        subtitle: '$_turnsCount questions • $mins min',
        minutes: mins,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final vtState = ref.watch(voiceTutorProvider);
    final subjects = OfflineCacheService.getUserSubjects();
    final isListening = vtState.status == VoiceTutorStatus.listening;
    final isProcessing = vtState.status == VoiceTutorStatus.processing;
    final isSpeaking = vtState.status == VoiceTutorStatus.speaking;

    String statusLabel = 'Tap circle to speak';
    if (isListening) statusLabel = 'Listening... tap circle when done';
    if (isProcessing) statusLabel = 'Sage is thinking...';
    if (isSpeaking) statusLabel = 'Sage is speaking (tap to interrupt)';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Voice tutor', style: AppTypography.screenTitle),
        actions: [
          if (subjects.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu_book_outlined, size: 22),
              tooltip: 'Switch subject',
              onSelected: (val) => setState(() => _selectedSubject = val),
              itemBuilder: (_) => subjects
                  .map((s) => PopupMenuItem(value: s, child: Text(s)))
                  .toList(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Tap circle to start/stop listening or interrupt speaking
            GestureDetector(
              onTap: () {
                final notifier = ref.read(voiceTutorProvider.notifier);
                if (isListening) {
                  _turnsCount++;
                  notifier.stopAndProcessInput(subject: _selectedSubject, isMuted: _isMuted);
                } else if (isSpeaking) {
                  notifier.stopSpeaking();
                } else if (!isProcessing) {
                  notifier.startListening();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isListening || isSpeaking ? 136 : 112,
                height: isListening || isSpeaking ? 136 : 112,
                decoration: BoxDecoration(
                  color: isListening ? AppColors.error : AppColors.accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Icon(
                        isListening ? Icons.stop : (isSpeaking ? Icons.volume_up : Icons.mic),
                        color: Colors.white,
                        size: 40,
                      ),
              ),
            ),
            const SizedBox(height: 24),

            Text(statusLabel, style: AppTypography.sectionHeading, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('$_selectedSubject session', style: AppTypography.secondary),

            if (vtState.liveTranscript.isNotEmpty || vtState.lastAiResponse.isNotEmpty || vtState.error != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (vtState.error != null)
                          Text(vtState.error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                        if (vtState.liveTranscript.isNotEmpty) ...[
                          Text('You: ${vtState.liveTranscript}', style: AppTypography.secondary),
                          if (vtState.lastAiResponse.isNotEmpty) const SizedBox(height: 8),
                        ],
                        if (vtState.lastAiResponse.isNotEmpty)
                          Text('Sage: ${vtState.lastAiResponse}', style: AppTypography.body),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppSecondaryButton(
                          label: _isMuted ? 'Audio off' : 'Audio on',
                          icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, size: 20),
                          onPressed: () {
                            setState(() => _isMuted = !_isMuted);
                            if (_isMuted) {
                              ref.read(voiceTutorProvider.notifier).stopSpeaking();
                            }
                          },
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
                    onPressed: _endSession,
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
