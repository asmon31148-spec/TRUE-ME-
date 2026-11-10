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
        super(const ChatState());

  Future<void> sendMessage({
    required String question,
    required String userId,
    String? notebookId,
    String? subject,
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
      List<String> retrievedExcerpts = [];
      String? citationSource;

      // 1. Check local uploaded documents & notes for the selected notebook/subject
      String? targetNbId = notebookId;
      if ((targetNbId == null || targetNbId.isEmpty) && subject != null && subject.isNotEmpty) {
        final match = OfflineCacheService.getAllCachedNotebooks().where(
          (n) => (n['title'] as String? ?? '').toLowerCase() == subject.toLowerCase(),
        );
        if (match.isNotEmpty) {
          targetNbId = match.first['id'] as String?;
        }
      }

      if (targetNbId != null && targetNbId.isNotEmpty) {
        final localDocs = OfflineCacheService.getNotebookDocuments(targetNbId);
        if (localDocs.isNotEmpty) {
          for (final doc in localDocs) {
            final content = (doc['content'] as String? ?? '').trim();
            if (content.isNotEmpty) {
              final snippet = content.length > 4000 ? content.substring(0, 4000) : content;
              retrievedExcerpts.add('[Source: ${doc['fileName']} (${doc['section']})]\n$snippet');
              citationSource ??= '${doc['fileName']} (${doc['section']})';
            }
          }
        }

        // Also check pgvector RAG if configured
        if (retrievedExcerpts.isEmpty) {
          try {
            final chunks = await _ragService
                .retrieveContext(
                  query: cleanQuestion,
                  userId: userId,
                  notebookId: targetNbId,
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
          } catch (_) {}
        }
      }

      // 2. Query AI Router (Groq -> OpenRouter -> Gemini fallback)
      String answer;
      try {
        final name = studentName ?? OfflineCacheService.getUserName();
        final subs = OfflineCacheService.getUserSubjects();
        final subContext = subject != null && subject.isNotEmpty
            ? 'Subject focus: $subject.'
            : (subs.isNotEmpty ? 'Student subjects: ${subs.join(', ')}.' : '');

        if (retrievedExcerpts.isEmpty) {
          final systemPrompt = '''
You are Sage, the personal AI study mentor for $name in the True Me app.
$subContext
Provide direct, crystal-clear, concise, and helpful academic explanations.
Format with clear paragraphs and bullet points when useful.
''';
          answer = await _aiRouter.executeRealtimeChat(
            prompt: cleanQuestion,
            systemPrompt: systemPrompt,
          );
        } else {
          answer = await _aiRouter.chatWithNotes(
            question: cleanQuestion,
            retrievedChunks: retrievedExcerpts,
            studentName: name,
          );
        }
      } catch (aiError) {
        answer =
            "I could not reach the AI models right now ($aiError). Please check your internet connection and try again.";
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
