import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/ai/rag_service.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/utils/text_chunker.dart';
import '../../export/docx_exporter.dart';
import '../../export/pdf_exporter.dart';
import '../../export/pptx_exporter.dart';

enum SageActionType {
  exportPdf,
  exportDocx,
  exportPptx,
  quiz,
  flashcards,
  mindmap,
  explainer,
  schedule,
}

class SageAction {
  final SageActionType type;
  final String label;
  final String topic;
  final String? filePath;

  const SageAction({
    required this.type,
    required this.label,
    required this.topic,
    this.filePath,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'label': label,
        'topic': topic,
        'filePath': filePath,
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
    }
    return (clean, type, topic.isNotEmpty ? topic : defaultTopic);
  }

  Future<SageAction> _executeAction({
    required SageActionType type,
    required String topic,
    required String subject,
    required String? notebookId,
    required String contentForExport,
  }) async {
    final safeBase = subject.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final dir = await getApplicationDocumentsDirectory();

    switch (type) {
      case SageActionType.exportPdf:
        final bytes = await PdfExporter.generateStudyGuidePdf(
          title: '$subject — $topic',
          subject: subject,
          content: contentForExport,
        );
        final fileName = '${safeBase}_Sage_Guide.pdf';
        final outFile = File('${dir.path}/$fileName');
        await outFile.writeAsBytes(bytes, flush: true);
        if (DriveService.instance.isSignedIn) {
          try {
            await DriveService.instance.uploadFile(
              outFile,
              customName: fileName,
              subject: subject,
              section: 'Notes',
            );
          } catch (_) {}
        }
        return SageAction(
          type: SageActionType.exportPdf,
          label: 'Open / Share PDF ($fileName)',
          topic: topic,
          filePath: outFile.path,
        );

      case SageActionType.exportDocx:
        final bytes = DocxExporter.createDocument(
          title: '$subject — $topic',
          subject: subject,
          content: contentForExport,
        );
        final fileName = '${safeBase}_Sage_Notes.docx';
        final outFile = File('${dir.path}/$fileName');
        await outFile.writeAsBytes(bytes, flush: true);
        if (DriveService.instance.isSignedIn) {
          try {
            await DriveService.instance.uploadFile(
              outFile,
              customName: fileName,
              subject: subject,
              section: 'Notes',
            );
          } catch (_) {}
        }
        return SageAction(
          type: SageActionType.exportDocx,
          label: 'Open Word Document (.docx)',
          topic: topic,
          filePath: outFile.path,
        );

      case SageActionType.exportPptx:
        final slidesRaw = await _aiRouter.executeHeavyReasoning(
          prompt:
              'Convert this study material for "$subject" into 6 concise PowerPoint slides. Return ONLY a JSON array [{"title": "...", "bullets": ["...", "..."]}].\n\nMaterial:\n$contentForExport',
        );
        final slides = _parseSlides(slidesRaw, subject);
        final bytes = PptxExporter.createPresentation(
          presentationTitle: '$subject Slides',
          slides: slides,
        );
        final fileName = '${safeBase}_Sage_Slides.pptx';
        final outFile = File('${dir.path}/$fileName');
        await outFile.writeAsBytes(bytes, flush: true);
        if (DriveService.instance.isSignedIn) {
          try {
            await DriveService.instance.uploadFile(
              outFile,
              customName: fileName,
              subject: subject,
              section: 'Notes',
            );
          } catch (_) {}
        }
        return SageAction(
          type: SageActionType.exportPptx,
          label: 'Open PowerPoint (.pptx)',
          topic: topic,
          filePath: outFile.path,
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
    }
  }

  List<PptxSlideData> _parseSlides(String raw, String fallbackTitle) {
    try {
      String cleaned = raw.trim();
      final start = cleaned.indexOf('[');
      final end = cleaned.lastIndexOf(']');
      if (start >= 0 && end > start) cleaned = cleaned.substring(start, end + 1);
      final list = jsonDecode(cleaned) as List<dynamic>;
      final slides = <PptxSlideData>[];
      for (final item in list) {
        if (item is Map) {
          final t = (item['title'] as String? ?? 'Key Concept').trim();
          final bList = (item['bullets'] as List? ?? []).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          if (bList.isNotEmpty) slides.add(PptxSlideData(title: t, bulletPoints: bList));
        }
      }
      if (slides.isNotEmpty) return slides;
    } catch (_) {}
    final lines = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).take(6).toList();
    return [
      PptxSlideData(
        title: fallbackTitle,
        bulletPoints: lines.isNotEmpty ? lines : ['Summary of $fallbackTitle'],
      ),
    ];
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
        );
        rawAnswer = 'Done! I generated your ${directIntent.name.replaceFirst('export', '').toUpperCase()} file for **$subjectLabel**. Tap the button below to open or share it.';
      } else {
        try {
          if (retrievedExcerpts.isEmpty) {
            final scopeInstruction = effectiveSubject.isNotEmpty
                ? 'You are scoped STRICTLY to the subject "$effectiveSubject". Only track and answer for "$effectiveSubject".\nStudent Progress in $effectiveSubject:\n$progressSummary'
                : 'General study mode.';
            final systemPrompt = '''
You are Sage, the personal AI study mentor for $name in the True Me app.
$scopeInstruction
Format with clean ## headings and concise bullet points (- ). Avoid markdown pipe tables (| col |) so it reads cleanly on mobile.
If the student asks to export a PDF/Word/PPTX, or open Quiz/Flashcards/Mind Map/Audio Explainer/Schedule, confirm briefly and append on the last line:
[ACTION: export_pdf|export_docx|export_pptx|quiz|flashcards|mindmap|explainer|schedule | <short topic>]
''';
            rawAnswer = await _aiRouter.executeRealtimeChat(
              prompt: cleanQuestion,
              systemPrompt: systemPrompt,
            );
          } else {
            rawAnswer = await _aiRouter.chatWithNotes(
              question: cleanQuestion,
              retrievedChunks: retrievedExcerpts,
              studentName: name,
              subjectScope: effectiveSubject.isNotEmpty ? effectiveSubject : null,
              subjectProgressSummary: progressSummary,
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
          String exportSource = rawAnswer;
          if ((resolvedActionType == SageActionType.exportPdf ||
                  resolvedActionType == SageActionType.exportDocx ||
                  resolvedActionType == SageActionType.exportPptx) &&
              targetNbId != null &&
              exportSource.length < 300) {
            final nbText = OfflineCacheService.getNotebookCombinedText(targetNbId, maxChars: 12000);
            if (nbText.trim().isNotEmpty) {
              exportSource = await _aiRouter.executeHeavyReasoning(
                prompt:
                    'Create a clean, well-structured study guide for "$subjectLabel" ($tagTopic) from these notes using ## headings and - bullet points.\n\n$nbText',
              );
            }
          }

          finalAction = await _executeAction(
            type: resolvedActionType,
            topic: tagTopic,
            subject: subjectLabel,
            notebookId: targetNbId,
            contentForExport: exportSource,
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
