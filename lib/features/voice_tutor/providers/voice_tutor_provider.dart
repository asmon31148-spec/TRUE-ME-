import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/services/stt_service.dart';
import '../../../core/services/tts_service.dart';

enum VoiceTutorStatus { idle, listening, processing, speaking }

class VoiceTutorState {
  final VoiceTutorStatus status;
  final String liveTranscript;
  final String lastAiResponse;
  final int remainingSeconds;
  final String? error;

  const VoiceTutorState({
    this.status = VoiceTutorStatus.idle,
    this.liveTranscript = '',
    this.lastAiResponse = '',
    this.remainingSeconds = 1800, // 30 minutes
    this.error,
  });

  VoiceTutorState copyWith({
    VoiceTutorStatus? status,
    String? liveTranscript,
    String? lastAiResponse,
    int? remainingSeconds,
    String? error,
  }) {
    return VoiceTutorState(
      status: status ?? this.status,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      lastAiResponse: lastAiResponse ?? this.lastAiResponse,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      error: error,
    );
  }
}

class VoiceTutorNotifier extends StateNotifier<VoiceTutorState> {
  final AiRouter _aiRouter;
  final TtsService _ttsService;
  final SttService _sttService;

  VoiceTutorNotifier({
    required AiRouter aiRouter,
    required TtsService ttsService,
    required SttService sttService,
  })  : _aiRouter = aiRouter,
        _ttsService = ttsService,
        _sttService = sttService,
        super(const VoiceTutorState());

  /// Starts listening to the student.
  Future<void> startListening() async {
    // If Sage is currently speaking, stop speech immediately (interruption support)
    await _ttsService.stop();

    state = state.copyWith(
      status: VoiceTutorStatus.listening,
      liveTranscript: '',
      error: null,
    );

    try {
      await _sttService.startListening(
        onResult: (text) {
          state = state.copyWith(liveTranscript: text);
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: VoiceTutorStatus.idle,
        error: e.toString(),
      );
    }
  }

  /// Stops listening and sends student's voice input to Sage.
  Future<void> stopAndProcessInput() async {
    await _sttService.stopListening();
    final question = state.liveTranscript.trim();

    if (question.isEmpty) {
      state = state.copyWith(status: VoiceTutorStatus.idle);
      return;
    }

    state = state.copyWith(status: VoiceTutorStatus.processing);

    try {
      final prompt = '''
Student spoken question during voice tutor session:
"$question"

Respond as Sage. Keep your spoken response concise, conversational, and direct (2-3 sentences max). 
Focus on guiding the student conceptually without walls of text.
''';

      final responseText = await _aiRouter.executeWithFallback(prompt: prompt);

      state = state.copyWith(
        status: VoiceTutorStatus.speaking,
        lastAiResponse: responseText,
      );

      // Speak response aloud via device TTS
      await _ttsService.speak(responseText);

      state = state.copyWith(status: VoiceTutorStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: VoiceTutorStatus.idle,
        error: e.toString(),
      );
    }
  }

  /// Stops speaking or listening immediately.
  Future<void> stopSession() async {
    await _ttsService.stop();
    await _sttService.stopListening();
    state = state.copyWith(status: VoiceTutorStatus.idle);
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
final sttServiceProvider = Provider<SttService>((ref) => SttService());

final voiceTutorProvider =
    StateNotifierProvider<VoiceTutorNotifier, VoiceTutorState>((ref) {
  return VoiceTutorNotifier(
    aiRouter: ref.watch(aiRouterProvider),
    ttsService: ref.watch(ttsServiceProvider),
    sttService: ref.watch(sttServiceProvider),
  );
});
