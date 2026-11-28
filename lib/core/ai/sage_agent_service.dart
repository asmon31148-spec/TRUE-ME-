import 'dart:convert';
import '../services/offline_cache_service.dart';
import 'ai_gateway_client.dart';
import 'rag_service.dart';
import 'retrieval_engine.dart';
import 'syllabus_service.dart';

class SageAgentResult {
  final String text;
  final List<EvidencePassage> passages;
  final List<String> toolsUsed;

  const SageAgentResult({
    required this.text,
    required this.passages,
    required this.toolsUsed,
  });
}

/// Real tool-calling mentor agent: Sage decides on its own when to reply
/// naturally, when to inspect the syllabus/PYQs, and when to search or read notes.
class SageAgentService {
  final RagService _ragService;

  SageAgentService({RagService? ragService})
      : _ragService = ragService ?? RagService();

  static const List<Map<String, dynamic>> _toolDefinitions = [
    {
      'type': 'function',
      'function': {
        'name': 'list_sources',
        'description':
            'List all uploaded study files in this subject (Syllabus, Books, Notes, Previous papers) with their index status and size.',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'read_syllabus',
        'description':
            'Read the structured syllabus units, topics, and subtopics (or raw syllabus text) for this subject.',
        'parameters': {
          'type': 'object',
          'properties': {
            'unitFilter': {
              'type': 'string',
              'description': 'Optional unit title or number to focus on.',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'search_notes',
        'description':
            'Search across the student\'s Books, Notes, Syllabus, or Previous papers using hybrid semantic + keyword search.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Focused academic search query.',
            },
            'section': {
              'type': 'string',
              'description': 'Optional section filter: Syllabus, Notes, Books, or Previous papers.',
            },
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'read_document_excerpt',
        'description':
            'Read continuous text directly from a specific uploaded file (useful for reading a full PYQ paper, syllabus, or textbook section).',
        'parameters': {
          'type': 'object',
          'properties': {
            'fileName': {
              'type': 'string',
              'description': 'Exact or partial file name from list_sources.',
            },
            'offsetChars': {
              'type': 'integer',
              'description': 'Starting character offset (default 0).',
            },
          },
          'required': ['fileName'],
        },
      },
    },
  ];

  Future<SageAgentResult?> runTurn({
    required String question,
    required String userId,
    required String studentName,
    String? notebookId,
    String? subject,
    List<Map<String, String>> recentTurns = const [],
    String? mentorMemory,
    void Function(String status)? onStatus,
  }) async {
    if (!AiGatewayClient.instance.isConfigured) return null;

    final hasSubject = notebookId != null && notebookId.isNotEmpty;
    final docs = hasSubject
        ? OfflineCacheService.getNotebookDocuments(notebookId)
        : <Map<String, dynamic>>[];
    final sourceSummary = docs.isEmpty
        ? 'No uploaded files yet.'
        : docs
            .map((d) => '${d['fileName']} (${d['section']}, ${d['ingestionStatus'] ?? 'saved'})')
            .take(12)
            .join('; ');

    final memoryBlock = (mentorMemory != null && mentorMemory.trim().isNotEmpty)
        ? '\nLong-term mentor memory for this subject:\n${mentorMemory.trim()}\n'
        : '';

    final systemPrompt = '''
You are Sage, $studentName's personal AI study mentor${subject != null && subject.isNotEmpty ? ' for $subject' : ''}.
Available files in this subject: $sourceSummary$memoryBlock

How to behave:
1. Have a real brain — match the student's intent naturally:
   - If they say "hi", "thanks", or chat casually, reply warmly in 1-2 short sentences with NO tool calls and NO headings/bullet walls.
   - If they ask about their syllabus, exam pattern, PYQs, or textbook concepts, call ONLY the tools you need (e.g. read_syllabus, search_notes, read_document_excerpt) BEFORE answering.
   - If a request is huge or ambiguous (e.g. "give me whole semester notes"), inspect the syllabus first and ask which unit/depth they want or propose a clear unit-by-unit plan instead of dumping a shallow summary.
2. Adapt your formatting to the question. Never force rigid templates or markdown pipe tables (| col |) on narrow mobile screens.
3. Cite the actual file names/pages you read when answering from sources. If a topic is missing from their uploaded files, say so honestly.
4. Only when it genuinely helps the student take action right now, append one tag on the last line:
   [ACTION: export_pdf|export_docx|export_pptx|quiz|flashcards|mindmap|explainer|voice_tutor|schedule | <short topic>]
''';

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      for (final t in recentTurns)
        {'role': t['role'] ?? 'user', 'content': t['content'] ?? ''},
      {'role': 'user', 'content': question},
    ];

    final collectedPassages = <EvidencePassage>[];
    final toolsUsed = <String>[];
    final retrievalEngine = RetrievalEngine(ragService: _ragService);

    for (int step = 0; step < 4; step++) {
      final resp = await AiGatewayClient.instance.agentStep(
        messages: messages,
        tools: hasSubject ? _toolDefinitions : const [],
        temperature: 0.35,
        maxTokens: 2800,
      );

      final type = resp['type']?.toString() ?? 'final';
      if (type == 'final') {
        final text = resp['text']?.toString().trim() ?? '';
        return SageAgentResult(
          text: text,
          passages: collectedPassages,
          toolsUsed: toolsUsed,
        );
      }

      final callsRaw = resp['calls'] as List? ?? [];
      if (callsRaw.isEmpty) break;

      final assistantToolCalls = <Map<String, dynamic>>[];
      final toolResultMessages = <Map<String, dynamic>>[];

      for (final rawCall in callsRaw) {
        final call = Map<String, dynamic>.from(rawCall as Map);
        final callId = call['id']?.toString() ?? 'call_${DateTime.now().millisecondsSinceEpoch}';
        final name = call['name']?.toString() ?? '';
        final args = call['arguments'] is Map
            ? Map<String, dynamic>.from(call['arguments'] as Map)
            : <String, dynamic>{};

        toolsUsed.add(name);
        assistantToolCalls.add({
          'id': callId,
          'type': 'function',
          'function': {
            'name': name,
            'arguments': jsonEncode(args),
          },
        });

        final toolOutput = await _executeTool(
          name: name,
          args: args,
          userId: userId,
          notebookId: notebookId ?? '',
          docs: docs,
          retrievalEngine: retrievalEngine,
          collectedPassages: collectedPassages,
          onStatus: onStatus,
        );

        toolResultMessages.add({
          'role': 'tool',
          'tool_call_id': callId,
          'name': name,
          'content': toolOutput,
        });
      }

      messages.add({
        'role': 'assistant',
        'content': null,
        'tool_calls': assistantToolCalls,
      });
      messages.addAll(toolResultMessages);
    }

    return null;
  }

  Future<String> _executeTool({
    required String name,
    required Map<String, dynamic> args,
    required String userId,
    required String notebookId,
    required List<Map<String, dynamic>> docs,
    required RetrievalEngine retrievalEngine,
    required List<EvidencePassage> collectedPassages,
    void Function(String status)? onStatus,
  }) async {
    switch (name) {
      case 'list_sources':
        onStatus?.call('Checking uploaded sources...');
        if (docs.isEmpty) return 'No files uploaded in this subject yet.';
        return docs
            .map((d) =>
                '- ${d['fileName']} | Section: ${d['section']} | Status: ${d['ingestionStatus'] ?? 'saved'} | Chars: ${(d['content']?.toString().length ?? 0)}')
            .join('\n');

      case 'read_syllabus':
        onStatus?.call('Reading syllabus...');
        final unitFilter = args['unitFilter']?.toString().toLowerCase().trim() ?? '';
        final nodes = SyllabusService.getSyllabusNodes(notebookId);
        if (nodes.isNotEmpty) {
          final filtered = unitFilter.isEmpty
              ? nodes
              : nodes.where((n) => n['title'].toString().toLowerCase().contains(unitFilter)).toList();
          final toShow = filtered.isNotEmpty ? filtered : nodes;
          return toShow
              .take(60)
              .map((n) => '[${n['nodeType']}] ${n['title']}')
              .join('\n');
        }
        final sylDoc = docs
            .where((d) => (d['section']?.toString().toLowerCase() ?? '') == 'syllabus')
            .firstOrNull;
        if (sylDoc == null) return 'No syllabus uploaded yet.';
        final content = sylDoc['content']?.toString() ?? '';
        return content.length > 6000 ? content.substring(0, 6000) : content;

      case 'search_notes':
        final query = args['query']?.toString().trim() ?? '';
        final section = args['section']?.toString().trim();
        onStatus?.call('Searching ${section ?? 'subject'} notes for "$query"...');
        final bundle = await retrievalEngine.retrieveEvidence(
          query: query,
          userId: userId,
          notebookId: notebookId,
          sectionFilter: (section != null && section.isNotEmpty) ? section : null,
          topK: 5,
        );
        if (!bundle.hasSufficientEvidence) {
          return 'No matching passages found for "$query".';
        }
        collectedPassages.addAll(bundle.passages);
        return bundle.formattedExcerpts.join('\n\n---\n\n');

      case 'read_document_excerpt':
        final target = args['fileName']?.toString().toLowerCase().trim() ?? '';
        final offset = (args['offsetChars'] as num?)?.toInt() ?? 0;
        final doc = docs
            .where((d) => (d['fileName']?.toString().toLowerCase() ?? '').contains(target))
            .firstOrNull;
        if (doc == null) return 'File "$target" not found in this subject.';
        final fileName = doc['fileName']?.toString() ?? 'Document';
        onStatus?.call('Reading $fileName...');
        final text = doc['content']?.toString() ?? '';
        if (text.isEmpty) return '$fileName has no extracted text (may need OCR).';
        final safeStart = offset.clamp(0, text.length);
        final safeEnd = (safeStart + 5000).clamp(0, text.length);
        return '[$fileName | chars $safeStart..$safeEnd of ${text.length}]\n${text.substring(safeStart, safeEnd)}';

      default:
        return 'Unknown tool: $name';
    }
  }
}
