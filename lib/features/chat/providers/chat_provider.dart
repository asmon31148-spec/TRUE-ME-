import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/ai/rag_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/utils/text_chunker.dart';

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
        // 1a. Try Supabase pgvector semantic search first
        try {
          final chunks = await _ragService
              .retrieveContext(
                query: cleanQuestion,
                userId: userId,
                notebookId: targetNbId,
                topK: 4,
              )
              .timeout(
                const Duration(milliseconds: 2500),
                onTimeout: () => [],
              );

          if (chunks.isNotEmpty) {
            retrievedExcerpts = chunks.map((c) => c.content).toList();
            final top = chunks.first;
            citationSource = '${top.fileName ?? 'Notebook'} (Chunk #${top.chunkIndex + 1})';
          }
        } catch (_) {}

        // 1b. Keyword-ranked local chunk retrieval across entire documents (no 4000-char blind truncation)
        if (retrievedExcerpts.isEmpty) {
          final localDocs = OfflineCacheService.getNotebookDocuments(targetNbId);
          if (localDocs.isNotEmpty) {
            final queryTerms = cleanQuestion
                .toLowerCase()
                .split(RegExp(r'[^a-z0-9]+'))
                .where((w) => w.length >= 3)
                .toSet();

            final List<Map<String, dynamic>> scoredChunks = [];
            for (final doc in localDocs) {
              final content = (doc['content'] as String? ?? '').trim();
              if (content.isEmpty) continue;
              final fName = doc['fileName'] as String? ?? 'Document';
              final section = doc['section'] as String? ?? 'Notes';

              final chunks = TextChunker.splitIntoChunks(
                content,
                targetChunkChars: 2500,
                overlapChars: 250,
              );
              for (final ch in chunks) {
                final lower = ch.content.toLowerCase();
                int score = 0;
                for (final term in queryTerms) {
                  if (lower.contains(term)) score++;
                }
                scoredChunks.add({
                  'score': score,
                  'text': '[Source: $fName ($section)]\n${ch.content}',
                  'citation': '$fName ($section)',
                });
              }
            }

            scoredChunks.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
            final topChunks = scoredChunks.take(4).toList();
            if (topChunks.isNotEmpty) {
              retrievedExcerpts = topChunks.map((e) => e['text'] as String).toList();
              citationSource = topChunks.first['citation'] as String;
            }
          }
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
