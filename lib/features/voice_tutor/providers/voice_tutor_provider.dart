import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/services/offline_cache_service.dart';
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
    this.remainingSeconds = 1800,
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

  Future<void> startListening() async {
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

  Future<void> stopAndProcessInput({String? subject, bool isMuted = false}) async {
    await _sttService.stopListening();
    final question = state.liveTranscript.trim();
    if (question.isEmpty) {
      state = state.copyWith(status: VoiceTutorStatus.idle);
      return;
    }
    await sendTextQuestion(question, subject: subject, isMuted: isMuted);
  }

  Future<void> sendTextQuestion(String question, {String? subject, bool isMuted = false}) async {
    final clean = question.trim();
    if (clean.isEmpty) return;

    state = state.copyWith(
      status: VoiceTutorStatus.processing,
      liveTranscript: clean,
      error: null,
    );

    try {
      String contextSnippet = '';
      if (subject != null && subject.isNotEmpty) {
        final match = OfflineCacheService.getAllCachedNotebooks().where(
          (n) => (n['title'] as String? ?? '').toLowerCase() == subject.toLowerCase(),
        );
        if (match.isNotEmpty) {
          contextSnippet = OfflineCacheService.getNotebookCombinedText(match.first['id'] as String, maxChars: 6000);
        }
      }

      final prompt = '''
Student spoken question during voice tutor session (${subject ?? 'General Study'}):
"$clean"
${contextSnippet.isNotEmpty ? '\nRelevant student notes:\n$contextSnippet\n' : ''}
Respond as Sage. Keep your spoken response concise, conversational, and direct (2-4 clear sentences max).
''';

      final responseText = await _aiRouter.executeRealtimeChat(prompt: prompt);

      state = state.copyWith(
        status: isMuted ? VoiceTutorStatus.idle : VoiceTutorStatus.speaking,
        lastAiResponse: responseText,
      );

      if (!isMuted) {
        await _ttsService.speak(responseText);
      }

      state = state.copyWith(status: VoiceTutorStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: VoiceTutorStatus.idle,
        error: e.toString(),
      );
    }
  }

  Future<void> stopSpeaking() async {
    await _ttsService.stop();
    if (state.status == VoiceTutorStatus.speaking) {
      state = state.copyWith(status: VoiceTutorStatus.idle);
    }
  }

  Future<void> stopSession() async {
    await _ttsService.stop();
    await _sttService.stopListening();
    state = const VoiceTutorState();
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
