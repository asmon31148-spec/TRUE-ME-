import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/ai/answer_verifier.dart';
import '../../../core/ai/rag_service.dart';
import '../../../core/ai/retrieval_engine.dart';
import '../../../core/ai/sage_context_builder.dart';
import '../../../core/ai/sage_orchestrator.dart';
import '../../../core/ai/smai/memory_event_service.dart';
import '../../../core/ai/smai/memory_retrieval_service.dart';
import '../../../core/ai/smai/smai_models.dart';
import '../../../core/services/offline_cache_service.dart';
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
  final AnswerVerificationReport? verification;
  final List<String> quickReplies;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.citation,
    this.action,
    this.verification,
    this.quickReplies = const [],
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'isUser': isUser,
        'text': text,
        'citation': citation,
        'action': action?.toMap(),
        if (verification != null) 'verification': verification!.toMap(),
        if (quickReplies.isNotEmpty) 'quickReplies': quickReplies,
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
      verification: map['verification'] is Map
          ? AnswerVerificationReport.fromMap(
              Map<String, dynamic>.from(map['verification'] as Map),
            )
          : null,
      quickReplies: (map['quickReplies'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ChatSessionMeta {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  const ChatSessionMeta({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
  });

  factory ChatSessionMeta.fromMap(Map<String, dynamic> map) {
    return ChatSessionMeta(
      id: map['id'] as String? ?? 'default',
      title: map['title'] as String? ?? 'New Chat',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      messageCount: (map['messageCount'] as num? ?? 0).toInt(),
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isThinking;
  final String? thinkingStatus;
  final String? activeCitation;
  final String? error;
  final String activeSessionId;
  final List<ChatSessionMeta> sessions;

  const ChatState({
    this.messages = const [],
    this.isThinking = false,
    this.thinkingStatus,
    this.activeCitation,
    this.error,
    this.activeSessionId = 'default',
    this.sessions = const [],
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isThinking,
    String? thinkingStatus,
    String? activeCitation,
    String? error,
    String? activeSessionId,
    List<ChatSessionMeta>? sessions,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      thinkingStatus: thinkingStatus ?? this.thinkingStatus,
      activeCitation: activeCitation ?? this.activeCitation,
      error: error,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      sessions: sessions ?? this.sessions,
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
        super(_loadInitial(scopeKey));

  static ChatState _loadInitial(String scopeKey) {
    final activeId = OfflineCacheService.getActiveChatSessionId(scopeKey);
    final saved = OfflineCacheService.getChatHistory(scopeKey, sessionId: activeId);
    final sessions = OfflineCacheService.getChatSessions(scopeKey)
        .map(ChatSessionMeta.fromMap)
        .toList();
    return ChatState(
      messages: saved.map(ChatMessage.fromMap).toList(),
      activeSessionId: activeId,
      sessions: sessions,
    );
  }

  Future<void> _persist() async {
    await OfflineCacheService.saveChatHistory(
      scopeKey,
      state.messages.map((m) => m.toMap()).toList(),
      sessionId: state.activeSessionId,
    );
    final refreshed = OfflineCacheService.getChatSessions(scopeKey)
        .map(ChatSessionMeta.fromMap)
        .toList();
    if (mounted) {
      state = state.copyWith(sessions: refreshed);
    }
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
      thinkingStatus: 'Understanding intent & subject scope...',
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

      // 1b. SAGE-004 Intent & Scope Orchestration (also resolves subject mentioned in Main Sage)
      final intentPlan = SageOrchestrator.classify(
        query: cleanQuestion,
        notebookId: targetNbId,
        subject: effectiveSubject,
      );
      if ((targetNbId == null || targetNbId.isEmpty) &&
          intentPlan.resolvedNotebookId != null) {
        targetNbId = intentPlan.resolvedNotebookId;
        effectiveSubject = intentPlan.resolvedSubject ?? effectiveSubject;
      }

      if (intentPlan.needsClarification && intentPlan.clarificationQuestion != null) {
        final clarifyMsg = ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch + 1}',
          isUser: false,
          text: intentPlan.clarificationQuestion!,
          quickReplies: intentPlan.clarificationOptions,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(
          messages: [...state.messages, clarifyMsg],
          isThinking: false,
        );
        await _persist();
        return clarifyMsg;
      }

      // 1b-compound. Execute multi-feature compound workflows directly (e.g. Mind Map -> PDF)
      if (intentPlan.isCompound &&
          (intentPlan.intent == SageIntentType.mindmap ||
              intentPlan.intent == SageIntentType.quiz) &&
          intentPlan.secondaryOutputIntent != null) {
        final sec = intentPlan.secondaryOutputIntent!;
        final outFmt = sec == SageIntentType.exportPdf
            ? 'pdf'
            : (sec == SageIntentType.exportDocx ? 'docx' : 'pptx');
        final primaryTool =
            intentPlan.intent == SageIntentType.mindmap ? 'mindmap' : 'quiz';
        final subLabel = effectiveSubject.isNotEmpty ? effectiveSubject : 'Study';
        final styleId = intentPlan.explicitStyleId ??
            (outFmt == 'pdf'
                ? OfflineCacheService.getPreferredPdfStyle()
                : (outFmt == 'pptx'
                    ? OfflineCacheService.getPreferredPptxStyle()
                    : 'elegant_academic_notes'));

        state = state.copyWith(
          thinkingStatus:
              'Building ${primaryTool == 'mindmap' ? 'Mind Map' : 'Quiz'} from $subLabel notes & rendering ${outFmt.toUpperCase()}...',
        );
        final res = await DocumentGenerationService.generateCompoundArtifact(
          aiRouter: _aiRouter,
          primaryTool: primaryTool,
          outputFormat: outFmt,
          styleId: styleId,
          subject: subLabel,
          topic: intentPlan.topic,
          notebookId: targetNbId,
          sourceChatId: scopeKey,
        );
        final actionType = outFmt == 'pdf'
            ? SageActionType.exportPdf
            : (outFmt == 'docx'
                ? SageActionType.exportDocx
                : SageActionType.exportPptx);
        final compoundMsg = ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch + 1}',
          isUser: false,
          text:
              'Done! I built the **${primaryTool == 'mindmap' ? 'Visual Mind Map' : 'Practice Quiz'}** for **$subLabel — ${intentPlan.topic}** and exported it as a **${outFmt.toUpperCase()}** in your Study Library.',
          action: SageAction(
            type: actionType,
            label: 'Open ${primaryTool == 'mindmap' ? 'Mind Map' : 'Quiz'} ${outFmt.toUpperCase()}',
            topic: res.title,
            filePath: res.filePath,
          ),
          timestamp: DateTime.now(),
        );
        state = state.copyWith(
          messages: [...state.messages, compoundMsg],
          isThinking: false,
        );
        await _persist();
        return compoundMsg;
      }

      // 1c. SAGE-002 Hybrid Retrieval & Evidence Engine (strictly scoped to targetNbId)
      if (targetNbId != null && targetNbId.isNotEmpty) {
        state = state.copyWith(
          thinkingStatus:
              'Searching ${effectiveSubject.isNotEmpty ? effectiveSubject : 'subject'} notes & syllabus...',
        );
      }
      final retrievalEngine = RetrievalEngine(ragService: _ragService);
      EvidenceBundle evidenceBundle = await retrievalEngine.retrieveEvidence(
        query: cleanQuestion,
        userId: userId,
        notebookId: targetNbId,
        sectionFilter: intentPlan.sourcePriority == SourcePriority.syllabusFirst
            ? 'Syllabus'
            : (intentPlan.sourcePriority == SourcePriority.pyqFirst
                ? 'Previous papers'
                : null),
        topK: 5,
      );
      if (!evidenceBundle.hasSufficientEvidence &&
          intentPlan.sourcePriority != SourcePriority.balanced &&
          targetNbId != null &&
          targetNbId.isNotEmpty) {
        evidenceBundle = await retrievalEngine.retrieveEvidence(
          query: cleanQuestion,
          userId: userId,
          notebookId: targetNbId,
          topK: 5,
        );
      }

      if (evidenceBundle.hasSufficientEvidence) {
        retrievedExcerpts = evidenceBundle.formattedExcerpts;
        citationSource = evidenceBundle.primaryCitation;
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
          final mentorMemory = OfflineCacheService.buildSubjectMentorMemoryBlock(
            scopeKey,
            excludeSessionId: state.activeSessionId,
          );
          final priorMsgs = state.messages.length > 1
              ? state.messages.sublist(0, state.messages.length - 1)
              : <ChatMessage>[];
          final recentTurns = priorMsgs.reversed
              .take(6)
              .toList()
              .reversed
              .map((m) {
                final role = m.isUser ? 'Student' : 'Sage';
                final txt = m.text.trim().replaceAll(RegExp(r'\s+'), ' ');
                final clipped = txt.length > 260 ? '${txt.substring(0, 257)}...' : txt;
                return '$role: $clipped';
              })
              .toList();

          final smaiPkg = await MemoryRetrievalService.assembleContext(
            query: cleanQuestion,
            aiMode: (targetNbId != null && targetNbId.isNotEmpty)
                ? SmaiAiMode.subject
                : SmaiAiMode.main,
            subjectId: targetNbId,
            requestIntent: intentPlan.intent.name,
            overrideUserId: userId,
          );

          final builtCtx = SageContextBuilder.build(
            studentName: name,
            subject: effectiveSubject.isNotEmpty ? effectiveSubject : null,
            notebookId: targetNbId,
            retrievedExcerpts: retrievedExcerpts,
            citationSource: citationSource,
            mentorMemory: mentorMemory,
            recentTurns: recentTurns,
            smaiContext: smaiPkg,
          );
          final isDeepResearch = intentPlan.intent == SageIntentType.explain ||
              intentPlan.intent == SageIntentType.compare ||
              intentPlan.intent == SageIntentType.summarize ||
              intentPlan.intent == SageIntentType.extract ||
              cleanQuestion.length > 90;

          if (retrievedExcerpts.isEmpty) {
            state = state.copyWith(
              thinkingStatus: isDeepResearch
                  ? 'Researching deep explanation with Sage...'
                  : 'Thinking with Sage...',
            );
            rawAnswer = isDeepResearch
                ? await _aiRouter.executeHeavyReasoning(
                    prompt: cleanQuestion,
                    systemPrompt: builtCtx.systemPrompt,
                  )
                : await _aiRouter.executeRealtimeChat(
                    prompt: cleanQuestion,
                    systemPrompt: builtCtx.systemPrompt,
                  );
          } else {
            state = state.copyWith(
              thinkingStatus:
                  'Found ${evidenceBundle.passages.length} source passage(s) · Synthesizing grounded answer...',
            );
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
              mentorMemory: mentorMemory,
              recentTurns: recentTurns,
              systemPromptOverride: builtCtx.systemPrompt,
            );
          }
        } catch (aiError) {
          rawAnswer =
              "I could not reach the AI models right now ($aiError). Please check your internet connection and try again.";
        }

        state = state.copyWith(
          thinkingStatus: 'Verifying claims & citations against sources...',
        );
        final (cleanAnswer, tagType, tagTopic) = _extractActionTag(rawAnswer, subjectLabel);
        rawAnswer = cleanAnswer;
        final resolvedActionType = directIntent ?? tagType;

        if (resolvedActionType != null) {
          state = state.copyWith(
            thinkingStatus: 'Preparing ${resolvedActionType.name}...',
          );
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

      // SAGE-005 Answer Verification & Uncertainty Disclosure
      final verification = isExportOfPrevious
          ? null
          : AnswerVerifier.verify(
              query: cleanQuestion,
              answer: rawAnswer,
              evidence: evidenceBundle,
              notebookId: targetNbId,
            );

      final aiMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch + 1}',
        isUser: false,
        text: rawAnswer,
        citation: citationSource,
        action: finalAction,
        verification: verification,
        timestamp: DateTime.now(),
      );

      final updatedMsgs = [...state.messages, aiMsg];
      state = state.copyWith(
        messages: updatedMsgs,
        isThinking: false,
      );
      await _persist();

      // Emit SMAI immutable conversation events (user + Sage)
      unawaited(
        MemoryEventService.capture(
          eventType: SmaiEventType.conversationMessageCreated,
          idempotencyKey: 'msg_${userMsg.id}',
          subjectId: targetNbId,
          overrideUserId: userId,
          payload: {'role': 'student', 'sessionId': state.activeSessionId, 'text': cleanQuestion},
          searchText: cleanQuestion,
        ).catchError((_) => LearningEvent(
              id: '',
              userId: userId,
              eventType: SmaiEventType.conversationMessageCreated,
              idempotencyKey: 'err',
              occurredAt: DateTime.now(),
            )),
      );
      unawaited(
        MemoryEventService.capture(
          eventType: SmaiEventType.conversationMessageCreated,
          idempotencyKey: 'msg_${aiMsg.id}',
          subjectId: targetNbId,
          overrideUserId: userId,
          provenanceRefs: citationSource != null ? [citationSource] : const [],
          payload: {'role': 'sage', 'sessionId': state.activeSessionId, 'text': rawAnswer},
          searchText: rawAnswer,
        ).catchError((_) => LearningEvent(
              id: '',
              userId: userId,
              eventType: SmaiEventType.conversationMessageCreated,
              idempotencyKey: 'err',
              occurredAt: DateTime.now(),
            )),
      );

      // Update long-term subject mentor memory in the background every 2 exchanges
      if (updatedMsgs.length >= 2 && updatedMsgs.length % 4 == 0) {
        unawaited(_distillMentorMemory(updatedMsgs, subjectLabel: subjectLabel));
      }
      return aiMsg;
    } catch (e) {
      state = state.copyWith(
        isThinking: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<void> _distillMentorMemory(
    List<ChatMessage> msgs, {
    String subjectLabel = 'this subject',
  }) async {
    if (msgs.isEmpty) return;
    try {
      final existing = OfflineCacheService.getMentorMemory(scopeKey);
      final prevSummary = (existing['summary'] as String? ?? '').trim();
      final recentSnippet = msgs.reversed
          .take(6)
          .toList()
          .reversed
          .map((m) {
            final who = m.isUser ? 'Student' : 'Sage';
            final t = m.text.trim().replaceAll(RegExp(r'\s+'), ' ');
            return '$who: ${t.length > 260 ? '${t.substring(0, 257)}...' : t}';
          })
          .join('\n');

      final prompt = '''
Update the concise personal mentor memory for this student studying $subjectLabel.
Keep it under 180 words as 5-7 short bullet points covering:
- Topics covered so far
- Concepts the student mastered vs struggled with
- Student's goals, exam focus, or preferred explanation style
- Recommended next mentor step

Previous Mentor Memory:
${prevSummary.isNotEmpty ? prevSummary : 'None yet.'}

Latest Conversation:
$recentSnippet

Return ONLY the updated bullet-point mentor memory.
''';

      final distilled = await _aiRouter.executeMicroTask(
        prompt: prompt,
        systemPrompt:
            'You maintain accurate, concise long-term academic mentor memory.',
      );
      final clean = distilled.trim();
      if (clean.isNotEmpty) {
        await OfflineCacheService.saveMentorMemory(scopeKey, {
          'summary': clean,
          'lastUpdated': DateTime.now().toIso8601String(),
          'interactionsCount':
              ((existing['interactionsCount'] as num?)?.toInt() ?? 0) + 1,
        });
      }
    } catch (_) {
      // Non-fatal: deterministic cross-session digest still provides memory
    }
  }

  /// Starts a fresh chat thread under the same subject while preserving
  /// previous threads and distilling them into Subject Mentor Memory.
  Future<void> startNewChat({String subjectLabel = 'this subject'}) async {
    if (state.isThinking) return;
    if (state.messages.isEmpty) return;

    final prevMessages = List<ChatMessage>.from(state.messages);
    unawaited(_distillMentorMemory(prevMessages, subjectLabel: subjectLabel));

    final newId = await OfflineCacheService.createChatSession(scopeKey);
    final sessions = OfflineCacheService.getChatSessions(scopeKey)
        .map(ChatSessionMeta.fromMap)
        .toList();
    state = state.copyWith(
      messages: const [],
      activeSessionId: newId,
      sessions: sessions,
      error: null,
    );
  }

  Future<void> switchSession(String sessionId) async {
    if (state.isThinking || sessionId == state.activeSessionId) return;
    await OfflineCacheService.setActiveChatSessionId(scopeKey, sessionId);
    final msgs = OfflineCacheService.getChatHistory(scopeKey, sessionId: sessionId)
        .map(ChatMessage.fromMap)
        .toList();
    final sessions = OfflineCacheService.getChatSessions(scopeKey)
        .map(ChatSessionMeta.fromMap)
        .toList();
    state = state.copyWith(
      messages: msgs,
      activeSessionId: sessionId,
      sessions: sessions,
      error: null,
    );
  }

  Future<void> deleteSession(String sessionId) async {
    if (state.isThinking) return;
    final nextId = await OfflineCacheService.deleteChatSession(scopeKey, sessionId);
    final msgs = OfflineCacheService.getChatHistory(scopeKey, sessionId: nextId)
        .map(ChatMessage.fromMap)
        .toList();
    final sessions = OfflineCacheService.getChatSessions(scopeKey)
        .map(ChatSessionMeta.fromMap)
        .toList();
    state = state.copyWith(
      messages: msgs,
      activeSessionId: nextId,
      sessions: sessions,
      error: null,
    );
  }

  void clearHistory() {
    state = state.copyWith(messages: const [], error: null);
    OfflineCacheService.clearChatHistory(scopeKey, sessionId: state.activeSessionId);
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
