import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';
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
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type Question', style: AppTypography.sectionHeading),
            const SizedBox(height: 12),
            AppInput(
              controller: controller,
              autofocus: true,
              hintText: 'Ask Sage tutor about $_selectedSubject...',
            ),
            const SizedBox(height: 16),
            TrueMePrimaryButton(
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
        title: '$_selectedSubject Voice Tutor',
        subtitle: '$_turnsCount questions · $mins min',
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

    String statusLabel = 'Tap orb to speak';
    if (isListening) statusLabel = 'Listening... tap when finished';
    if (isProcessing) statusLabel = 'Sage is thinking...';
    if (isSpeaking) statusLabel = 'Sage is speaking (tap to pause)';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _endSession();
        }
      },
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: TrueMeAmbientBackground(
          intenseLavender: true,
          child: SafeArea(
            child: Column(
              children: [
                TrueMeTopBar(
                  title: 'Voice Tutor',
                  onBack: _endSession,
                  trailing: subjects.isNotEmpty
                      ? PopupMenuButton<String>(
                          icon: Icon(Icons.menu_book_rounded, size: 22, color: context.textPrimary),
                          tooltip: 'Switch subject',
                          onSelected: (val) => setState(() => _selectedSubject = val),
                          itemBuilder: (_) => subjects
                              .map((s) => PopupMenuItem(value: s, child: Text(s)))
                              .toList(),
                        )
                      : null,
                ),
                TrueMeTonalPill(
                  label: _selectedSubject,
                  icon: Icons.school_outlined,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),

                const Spacer(),

                GestureDetector(
                  onTap: () {
                    final notifier = ref.read(voiceTutorProvider.notifier);
                    if (isListening) {
                      if (vtState.liveTranscript.trim().isNotEmpty) {
                        _turnsCount++;
                      }
                      notifier.stopAndProcessInput(subject: _selectedSubject, isMuted: _isMuted);
                    } else if (isSpeaking) {
                      notifier.stopSpeaking();
                    } else if (!isProcessing) {
                      notifier.startListening();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: isListening || isSpeaking ? 156 : 132,
                    height: isListening || isSpeaking ? 156 : 132,
                    decoration: BoxDecoration(
                      gradient: isListening ? null : AppColors.sageOrbGradient,
                      color: isListening ? AppColors.error : null,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isListening ? AppColors.error : context.accentColor).withValues(alpha: 0.30),
                          blurRadius: isListening || isSpeaking ? 30 : 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Icon(
                            isListening ? Icons.stop_rounded : (isSpeaking ? Icons.graphic_eq_rounded : Icons.mic_rounded),
                            color: Colors.white,
                            size: 46,
                          ),
                  ),
                ),
                const SizedBox(height: 26),

                Text(
                  statusLabel,
                  style: AppTypography.sectionHeading.copyWith(color: context.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Socratic oral review session',
                  style: AppTypography.secondary.copyWith(color: context.textSecondary),
                ),

                if (vtState.liveTranscript.isNotEmpty || vtState.lastAiResponse.isNotEmpty || vtState.error != null) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TrueMeCard(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 165),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (vtState.error != null)
                                Text(vtState.error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                              if (vtState.liveTranscript.isNotEmpty) ...[
                                Text(
                                  'You: ${vtState.liveTranscript}',
                                  style: AppTypography.secondary.copyWith(color: context.textSecondary),
                                ),
                                if (vtState.lastAiResponse.isNotEmpty) const SizedBox(height: 8),
                              ],
                              if (vtState.lastAiResponse.isNotEmpty)
                                Text('Sage: ${vtState.lastAiResponse}', style: AppTypography.body),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppSecondaryButton(
                              label: _isMuted ? 'Audio Off' : 'Audio On',
                              icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 19),
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
                              label: 'Type Instead',
                              icon: const Icon(Icons.keyboard_outlined, size: 19),
                              onPressed: _showTypeSheet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TrueMePrimaryButton(
                        label: 'End Session',
                        onPressed: _endSession,
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
