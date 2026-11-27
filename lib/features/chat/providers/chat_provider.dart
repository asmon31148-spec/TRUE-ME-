import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/ai/rag_service.dart';
import '../../../core/ai/sage_context_builder.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/utils/text_chunker.dart';
import '../../export/services/document_generation_service.dart';
import '../../export/services/generation_job_service.dart';

enum SageActionType {
  exportPdf,
  exportDocx,
  exportPptx,
  quiz,
  flashcards,
  mindmap,
  explainer,
  schedule,
  voiceTutor,
}

class SageAction {
  final SageActionType type;
  final String label;
  final String topic;
  final String? filePath;
  final bool needsStylePicker;
  final String? pendingSubject;
  final String? pendingNotebookId;
  final String? pendingSourceContext;

  const SageAction({
    required this.type,
    required this.label,
    required this.topic,
    this.filePath,
    this.needsStylePicker = false,
    this.pendingSubject,
    this.pendingNotebookId,
    this.pendingSourceContext,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'label': label,
        'topic': topic,
        'filePath': filePath,
        if (needsStylePicker) 'needsStylePicker': needsStylePicker,
        if (pendingSubject != null) 'pendingSubject': pendingSubject,
        if (pendingNotebookId != null) 'pendingNotebookId': pendingNotebookId,
      };

  factory SageAction.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? 'quiz';
    final parsedType = SageActionType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => SageActionType.quiz,
    );
    return SageAction(
      type: parsedType,
      label: map['label'] as String? ?? 'Open tool',
      topic: map['topic'] as String? ?? '',
      filePath: map['filePath'] as String?,
      needsStylePicker: map['needsStylePicker'] == true,
      pendingSubject: map['pendingSubject'] as String?,
      pendingNotebookId: map['pendingNotebookId'] as String?,
    );
  }
}

class ChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final String? citation;
  final SageAction? action;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.citation,
    this.action,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'isUser': isUser,
        'text': text,
        'citation': citation,
        'action': action?.toMap(),
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String? ?? 'msg',
      isUser: map['isUser'] == true,
      text: map['text'] as String? ?? '',
      citation: map['citation'] as String?,
      action: map['action'] is Map
          ? SageAction.fromMap(Map<String, dynamic>.from(map['action'] as Map))
          : null,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
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
  final String scopeKey;

  ChatNotifier({
    required AiRouter aiRouter,
    required RagService ragService,
    required this.scopeKey,
  })  : _aiRouter = aiRouter,
        _ragService = ragService,
        super(ChatState(messages: _loadInitial(scopeKey)));

  static List<ChatMessage> _loadInitial(String scopeKey) {
    final saved = OfflineCacheService.getChatHistory(scopeKey);
    return saved.map(ChatMessage.fromMap).toList();
  }

  void _persist() {
    OfflineCacheService.saveChatHistory(
      scopeKey,
      state.messages.map((m) => m.toMap()).toList(),
    );
  }

  SageActionType? _detectDirectIntent(String text) {
    final q = text.toLowerCase();
    if (RegExp(r'\b(pdf|study sheet)\b').hasMatch(q) &&
        RegExp(r'\b(make|create|export|give|provide|convert|generate|save|download|as a|into)\b').hasMatch(q)) {
      return SageActionType.exportPdf;
    }
    if (RegExp(r'\b(docx|word doc|word file|word document)\b').hasMatch(q)) {
      return SageActionType.exportDocx;
    }
    if (RegExp(r'\b(pptx|powerpoint|ppt|slides|presentation)\b').hasMatch(q) &&
        RegExp(r'\b(make|create|export|give|provide|convert|generate|build)\b').hasMatch(q)) {
      return SageActionType.exportPptx;
    }
    if (RegExp(r'\b(mind ?map|concept map)\b').hasMatch(q)) {
      return SageActionType.mindmap;
    }
    if (RegExp(r'\b(flashcard|flash card|cards)\b').hasMatch(q) &&
        RegExp(r'\b(make|create|generate|build|give|open|practice|review)\b').hasMatch(q)) {
      return SageActionType.flashcards;
    }
    if (RegExp(r'\b(quiz|test me|mcq|practice questions)\b').hasMatch(q)) {
      return SageActionType.quiz;
    }
    if (RegExp(r'\b(audio explainer|narrated|podcast|listen)\b').hasMatch(q)) {
      return SageActionType.explainer;
    }
    if (RegExp(r'\b(schedule|today.?s plan|add task|study plan)\b').hasMatch(q) &&
        RegExp(r'\b(add|schedule|put|plan)\b').hasMatch(q)) {
      return SageActionType.schedule;
    }
    if (RegExp(r'\b(voice tutor|live tutor|oral exam|talk with sage|speak with sage|voice mode)\b').hasMatch(q) ||
        (RegExp(r'\b(talk|speak|voice)\b').hasMatch(q) && RegExp(r'\b(sage|tutor|me|practice)\b').hasMatch(q))) {
      return SageActionType.voiceTutor;
    }
    return null;
  }

  (String cleanText, SageActionType? parsedType, String parsedTopic) _extractActionTag(
    String raw,
    String defaultTopic,
  ) {
    final match = RegExp(r'\[ACTION:\s*([a-z_]+)(?:\s*\|\s*([^\]]+))?\]', caseSensitive: false)
        .firstMatch(raw);
    if (match == null) return (raw.trim(), null, defaultTopic);

    final actionStr = (match.group(1) ?? '').trim().toLowerCase();
    final topic = (match.group(2) ?? defaultTopic).trim();
    final clean = raw.replaceAll(match.group(0)!, '').trim();

    SageActionType? type;
    switch (actionStr) {
      case 'export_pdf':
        type = SageActionType.exportPdf;
        break;
      case 'export_docx':
        type = SageActionType.exportDocx;
        break;
      case 'export_pptx':
        type = SageActionType.exportPptx;
        break;
      case 'quiz':
        type = SageActionType.quiz;
        break;
      case 'flashcards':
        type = SageActionType.flashcards;
        break;
      case 'mindmap':
        type = SageActionType.mindmap;
        break;
      case 'explainer':
        type = SageActionType.explainer;
        break;
      case 'schedule':
        type = SageActionType.schedule;
        break;
      case 'voice_tutor':
      case 'voicetutor':
      case 'voice':
        type = SageActionType.voiceTutor;
        break;
    }
    return (clean, type, topic.isNotEmpty ? topic : defaultTopic);
  }

  Future<GeneratedDocumentResult?> generateDocumentWithStyle({
    required String format,
    required String styleId,
    required String topic,
    required String subject,
    String scopeLabel = 'Chat Context',
    String? notebookId,
    String? sourceContext,
  }) async {
    state = state.copyWith(isThinking: true, error: null);
    try {
      final res = await GenerationJobService.runDurableJob(
        aiRouter: _aiRouter,
        format: format,
        styleId: styleId,
        subject: subject,
        topic: topic,
        scopeLabel: scopeLabel,
        notebookId: notebookId,
        sourceContext: sourceContext,
        sourceChatId: scopeKey,
      );
      if (res == null) {
        state = state.copyWith(isThinking: false);
        return null;
      }

      final doneMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        isUser: false,
        text: 'Generated your **${format.toUpperCase()}** ($styleId) for **$subject — $topic** and saved it to your Study Library.',
        action: SageAction(
          type: format == 'pdf'
              ? SageActionType.exportPdf
              : (format == 'docx' ? SageActionType.exportDocx : SageActionType.exportPptx),
          label: 'Open ${format.toUpperCase()}',
          topic: res.title,
          filePath: res.filePath,
        ),
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, doneMsg],
        isThinking: false,
      );
      _persist();
      return res;
    } catch (e) {
      state = state.copyWith(isThinking: false, error: e.toString());
      return null;
    }
  }

  Future<SageAction> _executeAction({
    required SageActionType type,
    required String topic,
    required String subject,
    required String? notebookId,
    required String contentForExport,
    String userQuestion = '',
  }) async {
    switch (type) {
      case SageActionType.exportPdf:
      case SageActionType.exportDocx:
      case SageActionType.exportPptx:
        final format = type == SageActionType.exportPdf
            ? 'pdf'
            : (type == SageActionType.exportDocx ? 'docx' : 'pptx');
        final explicitStyle = DocumentGenerationService.detectExplicitStyleId(userQuestion, format);
        if (explicitStyle == null) {
          return SageAction(
            type: type,
            label: 'Choose Style & Generate ${format.toUpperCase()}',
            topic: topic,
            needsStylePicker: true,
            pendingSubject: subject,
            pendingNotebookId: notebookId,
            pendingSourceContext: contentForExport,
          );
        }
        final res = await GenerationJobService.runDurableJob(
          aiRouter: _aiRouter,
          format: format,
          styleId: explicitStyle,
          subject: subject,
          topic: topic,
          scopeLabel: 'Explicit Chat Request',
          notebookId: notebookId,
          sourceContext: contentForExport,
          sourceChatId: scopeKey,
        );
        if (res == null) {
          throw StateError('Document generation did not produce a file.');
        }
        return SageAction(
          type: type,
          label: 'Open ${format.toUpperCase()} (${res.title})',
          topic: res.title,
          filePath: res.filePath,
        );

      case SageActionType.schedule:
        final todayKey = OfflineCacheService.dateKey(DateTime.now());
        final cached = OfflineCacheService.getCachedStudyPlan(todayKey);
        final tasks = (cached?['sessions'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        tasks.add({
          'id': 'task_${DateTime.now().millisecondsSinceEpoch}',
          'title': topic,
          'subject': subject,
          'duration': 25,
          'type': 'reading',
          'priority': 'High',
          'completed': false,
        });
        await OfflineCacheService.cacheStudyPlan(todayKey, {
          'sessions': tasks,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        return SageAction(
          type: SageActionType.schedule,
          label: 'Added to Today — View Schedule',
          topic: topic,
        );

      case SageActionType.quiz:
        return SageAction(
          type: SageActionType.quiz,
          label: 'Start $subject Quiz',
          topic: topic,
        );

      case SageActionType.flashcards:
        return SageAction(
          type: SageActionType.flashcards,
          label: 'Open $subject Flashcards',
          topic: topic,
        );

      case SageActionType.mindmap:
        return SageAction(
          type: SageActionType.mindmap,
          label: 'Open Mind Map: $topic',
          topic: topic,
        );

      case SageActionType.explainer:
        return SageAction(
          type: SageActionType.explainer,
          label: 'Play Audio Explainer',
          topic: topic,
        );

      case SageActionType.voiceTutor:
        return SageAction(
          type: SageActionType.voiceTutor,
          label: 'Start Live Voice Session: $topic',
          topic: topic,
        );
    }
  }

  Future<ChatMessage?> sendMessage({
    required String question,
    required String userId,
    String? notebookId,
    String? subject,
    String? studentName,
  }) async {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) return null;

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
    _persist();

    try {
      List<String> retrievedExcerpts = [];
      String? citationSource;

      // 1. Resolve target subject/notebook strictly
      String? targetNbId = notebookId;
      String effectiveSubject = subject?.trim() ?? '';
      if ((targetNbId == null || targetNbId.isEmpty) && effectiveSubject.isNotEmpty) {
        final match = OfflineCacheService.getAllCachedNotebooks().where(
          (n) => (n['title'] as String? ?? '').toLowerCase() == effectiveSubject.toLowerCase(),
        );
        if (match.isNotEmpty) {
          targetNbId = match.first['id'] as String?;
        }
      } else if (targetNbId != null && targetNbId.isNotEmpty && effectiveSubject.isEmpty) {
        final nb = OfflineCacheService.getCachedNotebook(targetNbId);
        effectiveSubject = (nb?['title'] as String? ?? '').trim();
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

        // 1b. Keyword-ranked local chunk retrieval across entire subject documents
        if (retrievedExcerpts.isEmpty) {
          final localDocs = OfflineCacheService.getNotebookDocuments(targetNbId);
          if (localDocs.isNotEmpty) {
            final queryTerms = cleanQuestion
                .toLowerCase()
                .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
                .where((w) => w.length >= 2)
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
                if (score > 0) {
                  scoredChunks.add({
                    'score': score,
                    'text': '[Source: $fName ($section)]\n${ch.content}',
                    'citation': '$fName ($section)',
                  });
                }
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

      // 2. Check if user directly asked for an export/study action
      final directIntent = _detectDirectIntent(cleanQuestion);
      final name = studentName ?? OfflineCacheService.getUserName();
      final subjectLabel = effectiveSubject.isNotEmpty ? effectiveSubject : 'Study';
      final progressSummary = effectiveSubject.isNotEmpty
          ? OfflineCacheService.getSubjectProgressSummary(effectiveSubject, notebookId: targetNbId)
          : null;

      // For "provide me this as a pdf" when previous Sage message already exists
      final prevAiMsgs = state.messages.where((m) => !m.isUser && m.text.trim().isNotEmpty).toList();
      final lastAiAnswer = prevAiMsgs.isNotEmpty ? prevAiMsgs.last.text : '';
      final isExportOfPrevious = (directIntent == SageActionType.exportPdf ||
              directIntent == SageActionType.exportDocx ||
              directIntent == SageActionType.exportPptx) &&
          lastAiAnswer.length > 80 &&
          RegExp(r'\b(this|above|previous|that|summary|notes)\b', caseSensitive: false)
              .hasMatch(cleanQuestion);

      String rawAnswer;
      SageAction? finalAction;

      if (isExportOfPrevious && directIntent != null) {
        finalAction = await _executeAction(
          type: directIntent,
          topic: subjectLabel,
          subject: subjectLabel,
          notebookId: targetNbId,
          contentForExport: lastAiAnswer,
          userQuestion: cleanQuestion,
        );
        rawAnswer = finalAction.needsStylePicker
            ? 'Choose a visual style for your **${directIntent.name.replaceFirst('export', '').toUpperCase()}** of **$subjectLabel**.'
            : 'Done! I generated your ${directIntent.name.replaceFirst('export', '').toUpperCase()} file for **$subjectLabel**. Tap the button below to open it.';
      } else {
        try {
          final builtCtx = SageContextBuilder.build(
            studentName: name,
            subject: effectiveSubject.isNotEmpty ? effectiveSubject : null,
            notebookId: targetNbId,
            retrievedExcerpts: retrievedExcerpts,
            citationSource: citationSource,
          );
          if (retrievedExcerpts.isEmpty) {
            rawAnswer = await _aiRouter.executeRealtimeChat(
              prompt: cleanQuestion,
              systemPrompt: builtCtx.systemPrompt,
            );
          } else {
            final enrichedSummary = [
              if (progressSummary != null && progressSummary.isNotEmpty) progressSummary,
              if (builtCtx.syllabusSummary != null && builtCtx.syllabusSummary!.isNotEmpty)
                builtCtx.syllabusSummary!,
            ].join('\n');
            rawAnswer = await _aiRouter.chatWithNotes(
              question: cleanQuestion,
              retrievedChunks: retrievedExcerpts,
              studentName: name,
              subjectScope: effectiveSubject.isNotEmpty ? effectiveSubject : null,
              subjectProgressSummary: enrichedSummary.isNotEmpty ? enrichedSummary : null,
            );
          }
        } catch (aiError) {
          rawAnswer =
              "I could not reach the AI models right now ($aiError). Please check your internet connection and try again.";
        }

        final (cleanAnswer, tagType, tagTopic) = _extractActionTag(rawAnswer, subjectLabel);
        rawAnswer = cleanAnswer;
        final resolvedActionType = directIntent ?? tagType;

        if (resolvedActionType != null) {
          // If the chat response is brief, pass empty context so DocumentGenerationService
          // loads the full subject sources through DocumentPipelineService map-reduce.
          final exportSource = rawAnswer.length >= 300 ? rawAnswer : '';

          finalAction = await _executeAction(
            type: resolvedActionType,
            topic: tagTopic,
            subject: subjectLabel,
            notebookId: targetNbId,
            contentForExport: exportSource,
            userQuestion: cleanQuestion,
          );
        }
      }

      final aiMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch + 1}',
        isUser: false,
        text: rawAnswer,
        citation: citationSource,
        action: finalAction,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isThinking: false,
      );
      _persist();
      return aiMsg;
    } catch (e) {
      state = state.copyWith(
        isThinking: false,
        error: e.toString(),
      );
      return null;
    }
  }

  void clearHistory() {
    state = const ChatState(messages: []);
    OfflineCacheService.clearChatHistory(scopeKey);
  }
}

final ragServiceProvider = Provider<RagService>((ref) {
  return RagService(geminiService: ref.watch(geminiServiceProvider));
});

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, scopeKey) {
  return ChatNotifier(
    aiRouter: ref.watch(aiRouterProvider),
    ragService: ref.watch(ragServiceProvider),
    scopeKey: scopeKey,
  );
});
