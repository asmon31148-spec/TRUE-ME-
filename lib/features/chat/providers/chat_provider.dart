import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/ai/rag_service.dart';
import '../../../core/services/offline_cache_service.dart';

class ChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final String? citation;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.citation,
    required this.timestamp,
  });
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isThinking;
  final String? activeCitation;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isThinking = false,
    this.activeCitation,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isThinking,
    String? activeCitation,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      activeCitation: activeCitation ?? this.activeCitation,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final AiRouter _aiRouter;
  final RagService _ragService;

  ChatNotifier({required AiRouter aiRouter, required RagService ragService})
      : _aiRouter = aiRouter,
        _ragService = ragService,
        super(
          ChatState(
            messages: [
              ChatMessage(
                id: 'welcome_1',
                isUser: false,
                text:
                    "Hello ${OfflineCacheService.getUserName()}! I am Sage, your AI study coach. Ask me anything about your lecture notes, equations, or exam topics!",
                timestamp: DateTime.now(),
              ),
            ],
          ),
        );

  Future<void> sendMessage({
    required String question,
    required String userId,
    String? notebookId,
    String? studentName,
  }) async {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) return;

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      isUser: true,
      text: cleanQuestion,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
      error: null,
    );

    try {
      // 1. Retrieve relevant grounded chunks from pgvector ONLY if studying a notebook
      List<String> retrievedExcerpts = [];
      String? citationSource;

      if (notebookId != null && notebookId.isNotEmpty) {
        try {
          final chunks = await _ragService
              .retrieveContext(
                query: cleanQuestion,
                userId: userId,
                notebookId: notebookId,
                topK: 4,
              )
              .timeout(
                const Duration(milliseconds: 1200),
                onTimeout: () => [],
              );

          if (chunks.isNotEmpty) {
            retrievedExcerpts = chunks.map((c) => c.content).toList();
            final top = chunks.first;
            citationSource = '${top.fileName ?? 'Notebook'} (Chunk #${top.chunkIndex + 1})';
          }
        } catch (ragError) {
          // Log gracefully; answer directly without grounded chunks
          retrievedExcerpts = [];
          citationSource = null;
        }
      }

      // 2. Query AI Router (Groq 8B instant LPU -> fast fallback)
      String answer;
      try {
        final name = studentName ?? OfflineCacheService.getUserName();
        if (retrievedExcerpts.isEmpty) {
          // ULTRA FAST PATH: Real-time conversation (<500ms latency)
          final systemPrompt = '''
You are Sage, the personal AI mentor for $name in the True Me app.
Provide direct, crystal-clear, concise, and helpful explanations.
Format with concise paragraphs, bullet points, or bold highlights when useful.
''';
          answer = await _aiRouter.executeRealtimeChat(
            prompt: cleanQuestion,
            systemPrompt: systemPrompt,
          );
        } else {
          // Grounded Notebook Chat
          answer = await _aiRouter.chatWithNotes(
            question: cleanQuestion,
            retrievedChunks: retrievedExcerpts,
            studentName: name,
          );
        }
      } catch (aiError) {
        answer =
            "I could not reach the AI models at this moment ($aiError). Please verify that your API keys are active or try again shortly.";
      }

      final aiMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch + 1}',
        isUser: false,
        text: answer,
        citation: citationSource,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isThinking: false,
      );
    } catch (e) {
      state = state.copyWith(
        isThinking: false,
        error: e.toString(),
      );
    }
  }

  void clearHistory() {
    state = const ChatState(messages: []);
  }
}

final ragServiceProvider = Provider<RagService>((ref) {
  return RagService(geminiService: ref.watch(geminiServiceProvider));
});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    aiRouter: ref.watch(aiRouterProvider),
    ragService: ref.watch(ragServiceProvider),
  );
});
