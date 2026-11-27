import 'dart:convert';
import 'dart:io';
import '../utils/rate_limiter.dart';
import 'cloudflare_service.dart';
import 'cognitive/app_capabilities_manifest.dart';
import 'cognitive/student_cognitive_profile.dart';
import 'cohere_service.dart';
import 'gemini_service.dart';
import 'groq_service.dart';
import 'openrouter_service.dart';
import 'pollinations_service.dart';

/// Intelligent Multi-Tier AI Router with dynamic circuit breaking,
/// task-specialized model allocation, and zero-cost fallback chains.
class AiRouter {
  final GeminiService _gemini;
  final GroqService _groq;
  final CohereService _cohere;
  final CloudflareService _cloudflare;
  final OpenRouterService _openRouter;

  AiRouter({
    GeminiService? gemini,
    GroqService? groq,
    CohereService? cohere,
    CloudflareService? cloudflare,
    OpenRouterService? openRouter,
  })  : _gemini = gemini ?? GeminiService(),
        _groq = groq ?? GroqService(),
        _cohere = cohere ?? CohereService(),
        _cloudflare = cloudflare ?? CloudflareService(),
        _openRouter = openRouter ?? OpenRouterService();

  /// Strips markdown code fences, prose, and trailing syntax from LLM output
  /// to extract a clean JSON object or array string.
  static String extractJsonString(String raw) {
    var text = raw.trim();
    // 1. Extract content within markdown code fences
    final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false).firstMatch(text);
    if (fenceMatch != null) {
      text = (fenceMatch.group(1) ?? '').trim();
    }

    // 2. Locate outermost JSON root ({...} or [...])
    final firstBrace = text.indexOf('{');
    final firstBracket = text.indexOf('[');

    int startIndex = -1;
    int endIndex = -1;

    if (firstBrace >= 0 && (firstBracket < 0 || firstBrace < firstBracket)) {
      startIndex = firstBrace;
      endIndex = text.lastIndexOf('}');
    } else if (firstBracket >= 0) {
      startIndex = firstBracket;
      endIndex = text.lastIndexOf(']');
    }

    if (startIndex >= 0 && endIndex > startIndex) {
      text = text.substring(startIndex, endIndex + 1);
    }

    // 3. Remove invalid trailing commas before closing braces/brackets
    text = text.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m.group(1)!);
    return text;
  }

  /// Safely decodes an LLM response into a JSON object map.
  /// Gracefully normalizes raw JSON arrays into standardized object wrappers
  /// so flashcards, quizzes, mindmaps, and explainers never crash on schema variations.
  static Map<String, dynamic> parseJsonObject(String raw) {
    final cleaned = extractJsonString(raw);
    dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      // Secondary fallback: sanitize unescaped line breaks within string literals
      final sanitized = cleaned.replaceAll(RegExp(r'(?<!\\)\n'), ' ');
      decoded = jsonDecode(sanitized);
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    if (decoded is List) {
      // If the LLM returned a direct list of items, wrap into standard collection keys
      return {
        'cards': decoded,
        'questions': decoded,
        'scenes': decoded,
        'items': decoded,
        'nodes': decoded,
      };
    }
    throw const FormatException('Expected a JSON object or array from AI response.');
  }

  // ---------------------------------------------------------------------------
  // TIER 1: ULTRA-HEAVY / COMPLEX REASONING (Deep Synthesis & Big Context)
  // ---------------------------------------------------------------------------
  /// Handles heavy university lectures, full chapters, deep reasoning,
  /// and multi-scene explainer scripts — capped strictly under 50s.
  /// Priority: Groq OSS 120B (2-5s LPU) -> Gemini Flash -> OpenRouter Lightning -> Cohere
  Future<String> executeHeavyReasoning({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
  }) async {
    return _runHeavyReasoning(
      prompt: prompt,
      systemPrompt: systemPrompt,
      jsonMode: jsonMode,
    ).timeout(
      const Duration(seconds: 50),
      onTimeout: () => throw StateError('Generation timed out (50s limit). Please try again.'),
    );
  }

  Future<String> _runHeavyReasoning({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
  }) async {
    final requestId = RateLimitGuardian.newRequestId('heavy');

    // 1. Groq OSS 120B (Ultra-fast LPU inference: typically 1.5 - 4s)
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_heavy')) {
      try {
        final out = await _groq
            .complete70B(
              prompt: prompt,
              systemPrompt: systemPrompt,
              jsonMode: jsonMode,
            )
            .timeout(const Duration(seconds: 20));
        await RateLimitGuardian.recordRequestOnce(
          requestId: requestId,
          providerKey: 'groq_heavy',
          taskType: 'heavy_reasoning',
        );
        return out;
      } catch (e) {
        RateLimitGuardian.trip('groq_heavy');
      }
    }

    // 2. Gemini Flash (Large context fallback)
    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        final out = await _gemini
            .generateContent(
              prompt,
              systemInstruction: systemPrompt,
              jsonMode: jsonMode,
            )
            .timeout(const Duration(seconds: 22));
        await RateLimitGuardian.recordRequestOnce(
          requestId: requestId,
          providerKey: 'gemini_flash',
          taskType: 'heavy_reasoning',
        );
        return out;
      } catch (e) {
        RateLimitGuardian.trip('gemini_flash');
      }
    }

    // 3. OpenRouter Nemotron 3.5 Lightning:free (Fast fallback)
    if (_openRouter.isConfigured && await RateLimitGuardian.isAvailable('openrouter')) {
      try {
        final out = await _openRouter
            .completeFallback(
              prompt: prompt,
              systemPrompt: systemPrompt,
              model: OpenRouterService.modelNemotronLightning,
              jsonMode: jsonMode,
            )
            .timeout(const Duration(seconds: 15));
        await RateLimitGuardian.recordRequestOnce(
          requestId: requestId,
          providerKey: 'openrouter',
          taskType: 'heavy_reasoning',
        );
        return out;
      } catch (e) {
        RateLimitGuardian.trip('openrouter');
      }
    }

    // 4. Cohere Command R+
    if (_cohere.isConfigured && !jsonMode && await RateLimitGuardian.isAvailable('cohere')) {
      try {
        final out = await _cohere
            .chat(
              prompt: prompt,
              systemPrompt: systemPrompt,
            )
            .timeout(const Duration(seconds: 15));
        await RateLimitGuardian.recordRequestOnce(
          requestId: requestId,
          providerKey: 'cohere',
          taskType: 'heavy_reasoning',
        );
        return out;
      } catch (e) {
        RateLimitGuardian.trip('cohere');
      }
    }

    throw StateError('All AI models are currently busy or unreachable.');
  }

  // ---------------------------------------------------------------------------
  // TIER 2: REAL-TIME CONVERSATION & MOTHER AI SAGE (Sub-Second Latency)
  // ---------------------------------------------------------------------------
  /// Low-latency (<400ms time-to-first-token) interactive voice tutor & chat.
  /// Priority: Groq OSS 20B/120B (800 tok/s) -> OpenRouter Nemotron Lightning -> Gemini Flash -> OpenRouter Liquid LFM
  Future<String> executeRealtimeChat({
    required String prompt,
    String? systemPrompt,
  }) async {
    final requestId = RateLimitGuardian.newRequestId('chat');

    // 1. Groq OSS 20B (Extreme speed 500-800 tokens/sec on LPUs)
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_speed')) {
      try {
        final out = await _groq
            .complete8B(
              prompt: prompt,
              systemPrompt: systemPrompt,
              maxTokens: 1400,
              temperature: 0.4,
            )
            .timeout(const Duration(seconds: 12));
        await RateLimitGuardian.recordRequestOnce(
          requestId: requestId,
          providerKey: 'groq_speed',
          taskType: 'realtime_chat',
        );
        return out;
      } catch (e) {
        RateLimitGuardian.trip('groq_speed');
      }
    }

    // 2. OpenRouter Nemotron 3.5 Lightning:free (Fast conversational inference)
    if (_openRouter.isConfigured && await RateLimitGuardian.isAvailable('openrouter')) {
      try {
        final out = await _openRouter
            .completeFallback(
              prompt: prompt,
              systemPrompt: systemPrompt,
              model: OpenRouterService.modelNemotronLightning,
            )
            .timeout(const Duration(seconds: 12));
        await RateLimitGuardian.recordRequestOnce(
          requestId: requestId,
          providerKey: 'openrouter',
          taskType: 'realtime_chat',
        );
        return out;
      } catch (e) {
        RateLimitGuardian.trip('openrouter');
      }
    }

    // 3. Gemini 2.5 Flash
    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        final out = await _gemini.generateContent(
          prompt,
          systemInstruction: systemPrompt,
          maxOutputTokens: 1400,
          temperature: 0.4,
        );
        await RateLimitGuardian.recordRequestOnce(
          requestId: requestId,
          providerKey: 'gemini_flash',
          taskType: 'realtime_chat',
        );
        return out;
      } catch (e) {
        RateLimitGuardian.trip('gemini_flash');
      }
    }

    // 4. OpenRouter Liquid LFM (Ultra-compact neural network)
    if (_openRouter.isConfigured) {
      return await _openRouter.completeFallback(
        prompt: prompt,
        systemPrompt: systemPrompt,
        model: OpenRouterService.modelLiquidSmall,
      );
    }

    throw StateError('All Real-time Chat providers failed.');
  }

  // ---------------------------------------------------------------------------
  // TIER 3: HIGH-VOLUME STUDY TOOLS (Flashcards & Quizzes with JSON Mode)
  // ---------------------------------------------------------------------------
  /// High-volume flashcard generation (Delegates to Groq 14,400 calls/day to protect Gemini quota)
  Future<String> generateFlashcards({
    required String content,
    int count = 10,
  }) async {
    final systemPrompt = '''
You are an expert cognitive study companion. Generate exactly $count high-yield active recall flashcards from the provided content.
CRITICAL PEDAGOGY:
- Do NOT generate passive definitions or robotic copy-paste text.
- Formulate the front as an active recall question, scenario challenge, or "Why/How does X happen?".
- On the back, provide:
  • Clear, high-yield answer (concise)
  • 💡 Mnemonic / Mental Anchor (to lock it in memory)
  • ⚠️ Common Exam Trap (what students usually get wrong on this)

Return ONLY valid JSON matching this schema:
{
  "cards": [
    {
      "front": "Active recall question or diagnostic prompt",
      "back": "High-yield answer\\n\\n💡 Anchor: [Mnemonic/Memory hook]\\n⚠️ Trap: [Common mistake]",
      "topic": "Specific subtopic"
    }
  ]
}
''';

    final prompt = 'Content to process:\n$content';

    // 1. Groq (High daily quota: 14,400 requests/day)
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_speed')) {
      try {
        await RateLimitGuardian.recordRequest('groq_speed');
        return await _groq.complete8B(
          prompt: prompt,
          systemPrompt: systemPrompt,
          jsonMode: true,
          maxTokens: 1000,
          temperature: 0.3,
        );
      } catch (e) {
        RateLimitGuardian.trip('groq_speed');
      }
    }

    // 2. Gemini 2.5 Flash
    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        await RateLimitGuardian.recordRequest('gemini_flash');
        return await _gemini.generateContent(
          prompt,
          systemInstruction: systemPrompt,
          jsonMode: true,
          maxOutputTokens: 1000,
          temperature: 0.3,
        );
      } catch (e) {
        RateLimitGuardian.trip('gemini_flash');
      }
    }

    // 3. OpenRouter Cohere North Mini Code:free (Tuned for code/JSON schemas)
    if (_openRouter.isConfigured) {
      try {
        return await _openRouter.completeFallback(
          prompt: prompt,
          systemPrompt: systemPrompt,
          model: OpenRouterService.modelCohereCode,
          jsonMode: true,
        );
      } catch (_) {
        // Final fallback
      }
    }

    return executeWithFallback(
      prompt: prompt,
      systemPrompt: systemPrompt,
      jsonMode: true,
    ).timeout(const Duration(seconds: 50));
  }

  /// High-volume adaptive quiz generation
  Future<String> generateQuiz({
    required String content,
    int count = 5,
    String difficulty = 'medium',
  }) async {
    final diffLower = difficulty.toLowerCase().trim();
    final isHard = diffLower == 'hard' || diffLower == 'mastery';
    final isEasy = diffLower == 'easy' || diffLower == 'foundational';

    final levelDirective = isHard
        ? '''
COGNITIVE LEVEL: HIGH-YIELD MASTERY / BOARD EXAM LEVEL
- Format questions as case scenarios, clinical vignettes, or multi-step problem solving.
- Distractors MUST be plausible high-probability exam traps.
- Explanation MUST explain: (1) Correct principle, (2) Why distractors fail, (3) High-yield trap to avoid.'''
        : (isEasy
            ? '''
COGNITIVE LEVEL: FOUNDATIONAL SCAFFOLDING
- Focus on first-principles comprehension, definitions, and core intuition.
- Distractors should test fundamental distinctions without obscure tricks.
- Explanation MUST include a clear, memorable real-world analogy.'''
            : '''
COGNITIVE LEVEL: INTERMEDIATE REINFORCING
- Test active recall, process mechanisms, and comparative distinctions (X vs Y).
- Explanation must clearly contrast the correct mechanism against close alternatives.''');

    final systemPrompt = '''
You are an expert cognitive exam designer. Generate exactly $count multiple choice questions tailored to the student's mastery level from the study material.

$levelDirective

Return ONLY valid JSON matching this schema:
{
  "questions": [
    {
      "question": "Clear problem statement or scenario",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctOptionIndex": 0,
      "explanation": "Detailed pedagogical breakdown"
    }
  ]
}
''';

    final prompt = 'Study material:\n$content';

    // 1. Groq
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_speed')) {
      try {
        await RateLimitGuardian.recordRequest('groq_speed');
        return await _groq.complete8B(
          prompt: prompt,
          systemPrompt: systemPrompt,
          jsonMode: true,
          maxTokens: 1100,
          temperature: 0.2,
        );
      } catch (e) {
        RateLimitGuardian.trip('groq_speed');
      }
    }

    // 2. Gemini 2.5 Flash
    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        await RateLimitGuardian.recordRequest('gemini_flash');
        return await _gemini.generateContent(
          prompt,
          systemInstruction: systemPrompt,
          jsonMode: true,
          maxOutputTokens: 1100,
          temperature: 0.2,
        );
      } catch (e) {
        RateLimitGuardian.trip('gemini_flash');
      }
    }

    // 3. OpenRouter Code Specialist
    if (_openRouter.isConfigured) {
      try {
        return await _openRouter.completeFallback(
          prompt: prompt,
          systemPrompt: systemPrompt,
          model: OpenRouterService.modelCohereCode,
          jsonMode: true,
        );
      } catch (_) {
        // Fallback
      }
    }

    return executeWithFallback(
      prompt: prompt,
      systemPrompt: systemPrompt,
      jsonMode: true,
    ).timeout(const Duration(seconds: 50));
  }

  // ---------------------------------------------------------------------------
  // TIER 4: MICRO-TASKS (Titling, Tagging, Intent Classification)
  // ---------------------------------------------------------------------------
  /// Uses ultra-fast Liquid neural networks or small models with zero quota impact.
  Future<String> executeMicroTask({
    required String prompt,
    String? systemPrompt,
  }) async {
    // 1. OpenRouter Liquid LFM 1.7B:free
    if (_openRouter.isConfigured && await RateLimitGuardian.isAvailable('openrouter')) {
      try {
        await RateLimitGuardian.recordRequest('openrouter');
        return await _openRouter.completeFallback(
          prompt: prompt,
          systemPrompt: systemPrompt,
          model: OpenRouterService.modelLiquidSmall,
        );
      } catch (_) {
        // Fallback
      }
    }

    // 2. Groq OSS 20B
    if (_groq.isConfigured) {
      try {
        return await _groq.complete8B(
          prompt: prompt,
          systemPrompt: systemPrompt,
        );
      } catch (_) {
        // Fallback
      }
    }

    return executeWithFallback(prompt: prompt, systemPrompt: systemPrompt);
  }

  // ---------------------------------------------------------------------------
  // RAG KNOWLEDGE BASE CHAT (Cohere Rerank v3.5 Precision + Fast Synthesis)
  // ---------------------------------------------------------------------------
  /// Grounded RAG Chat with precision reranking & sub-second inference
  Future<String> chatWithNotes({
    required String question,
    required List<String> retrievedChunks,
    String studentName = 'Student',
    String? subjectScope,
    String? subjectProgressSummary,
    String? mentorMemory,
    List<String> recentTurns = const [],
    String? systemPromptOverride,
  }) async {
    if (retrievedChunks.isEmpty) {
      return executeRealtimeChat(
        prompt: question,
        systemPrompt: 'You are Sage, the personal AI mentor for $studentName in the True Me app.',
      );
    }

    // Apply Cohere Rerank v3.5 if multiple chunks exist with short timeout
    List<String> optimalChunks = retrievedChunks;
    if (_cohere.isConfigured && retrievedChunks.length > 2 && await RateLimitGuardian.isAvailable('cohere')) {
      try {
        await RateLimitGuardian.recordRequest('cohere');
        optimalChunks = await _cohere
            .rerankDocuments(
              query: question,
              documents: retrievedChunks,
              topN: 3,
            )
            .timeout(
              const Duration(milliseconds: 1000),
              onTimeout: () => retrievedChunks,
            );
      } catch (e) {
        RateLimitGuardian.trip('cohere');
      }
    }

    final contextText = optimalChunks.join('\n---\n');
    final cognitive = StudentCognitiveProfile.buildLive(subjectScope: subjectScope);
    final scopeLine = (subjectScope != null && subjectScope.isNotEmpty)
        ? 'You are scoped to the subject "$subjectScope". Prioritize topics, weaknesses, and progress in "$subjectScope".'
        : '';
    final progressLine = (subjectProgressSummary != null && subjectProgressSummary.isNotEmpty)
        ? '\nDetailed Progress in $subjectScope:\n$subjectProgressSummary'
        : '';
    final memoryLine = (mentorMemory != null && mentorMemory.trim().isNotEmpty)
        ? '\n\nLONG-TERM SUBJECT MENTOR MEMORY (Across All Sessions):\n${mentorMemory.trim()}\nUse this memory seamlessly like a dedicated mentor who remembers the student\'s prior questions, weak spots, and goals in this subject.'
        : '';
    final historyLine = recentTurns.isNotEmpty
        ? '\n\nCURRENT CONVERSATION TURNS:\n${recentTurns.join('\n')}'
        : '';
    final systemPrompt = systemPromptOverride ?? '''
You are Sage, the omniscient cognitive study companion and mentor for $studentName in the True Me app.
$scopeLine$progressLine$memoryLine$historyLine

${cognitive.toSageContextString()}

${AppCapabilitiesManifest.manifestPrompt}

Answer the student's question grounded firmly on the provided lecture notes and document excerpts.
Always cite the source or document when referencing specific concepts.
Formatting rules for mobile readability:
- Use clean ## section headings and high-yield bullet points (- ).
- CRITICAL: NEVER output markdown pipe tables (| col |). Mobile screens are narrow; tables look crowded and broken.
- When summarizing multiple topics or concepts, format each concept clearly:
  ### [Concept or Topic Title]
  - **Core Idea**: [Clear explanation adapted to student's cognitive tier]
  - **Source**: [Source file or lecture]
If the notes do not contain the answer, state so honestly, then provide the general academic explanation.
Whenever it benefits the student, proactively recommend an interactive next action and append the tag on the last line:
[ACTION: export_pdf|export_docx|export_pptx|quiz|flashcards|mindmap|explainer|voice_tutor|schedule | <short topic>]
''';

    final userPrompt = '''
Retrieved Note Excerpts:
$contextText

Student Question:
$question
''';

    // RAG synthesis priority: Groq 8B (blazing fast sub-second) -> Groq 70B -> Gemini Flash -> OpenRouter Lightning
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_speed')) {
      try {
        await RateLimitGuardian.recordRequest('groq_speed');
        return await _groq.complete8B(
          prompt: userPrompt,
          systemPrompt: systemPrompt,
          maxTokens: 1500,
        );
      } catch (e) {
        RateLimitGuardian.trip('groq_speed');
      }
    }

    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_heavy')) {
      try {
        await RateLimitGuardian.recordRequest('groq_heavy');
        return await _groq.complete70B(
          prompt: userPrompt,
          systemPrompt: systemPrompt,
          maxTokens: 1500,
        );
      } catch (e) {
        RateLimitGuardian.trip('groq_heavy');
      }
    }

    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        await RateLimitGuardian.recordRequest('gemini_flash');
        return await _gemini.generateContent(
          userPrompt,
          systemInstruction: systemPrompt,
          maxOutputTokens: 1500,
        );
      } catch (e) {
        RateLimitGuardian.trip('gemini_flash');
      }
    }

    return executeWithFallback(
      prompt: userPrompt,
      systemPrompt: systemPrompt,
    );
  }

  // ---------------------------------------------------------------------------
  // GENERAL FALLBACK CHAIN
  // ---------------------------------------------------------------------------
  Future<String> executeWithFallback({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
  }) async {
    return _runFallbackChain(
      prompt: prompt,
      systemPrompt: systemPrompt,
      jsonMode: jsonMode,
    ).timeout(
      const Duration(seconds: 50),
      onTimeout: () => throw StateError('Generation timed out (50s limit). Please try again.'),
    );
  }

  Future<String> _runFallbackChain({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
  }) async {
    // 1. Groq (Fastest: 1-3s LPU inference)
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_speed')) {
      try {
        await RateLimitGuardian.recordRequest('groq_speed');
        return await _groq
            .complete8B(
              prompt: prompt,
              systemPrompt: systemPrompt,
              jsonMode: jsonMode,
            )
            .timeout(const Duration(seconds: 18));
      } catch (e) {
        RateLimitGuardian.trip('groq_speed');
      }
    }

    // 2. Gemini Flash
    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        await RateLimitGuardian.recordRequest('gemini_flash');
        return await _gemini
            .generateContent(
              prompt,
              systemInstruction: systemPrompt,
              jsonMode: jsonMode,
            )
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        RateLimitGuardian.trip('gemini_flash');
      }
    }

    // 3. OpenRouter Nemotron 3.5 Lightning:free
    if (_openRouter.isConfigured && await RateLimitGuardian.isAvailable('openrouter')) {
      try {
        await RateLimitGuardian.recordRequest('openrouter');
        return await _openRouter.completeFallback(
          prompt: prompt,
          systemPrompt: systemPrompt,
          model: OpenRouterService.modelNemotronLightning,
          jsonMode: jsonMode,
        );
      } catch (e) {
        RateLimitGuardian.trip('openrouter');
      }
    }

    // 4. Cohere Command R+
    if (_cohere.isConfigured && !jsonMode && await RateLimitGuardian.isAvailable('cohere')) {
      try {
        await RateLimitGuardian.recordRequest('cohere');
        return await _cohere.chat(
          prompt: prompt,
          systemPrompt: systemPrompt,
        );
      } catch (e) {
        RateLimitGuardian.trip('cohere');
      }
    }

    // 5. Cloudflare Workers AI
    if (_cloudflare.isConfigured && !jsonMode) {
      try {
        return await _cloudflare.summarizeText(prompt);
      } catch (_) {}
    }

    // 6. Absolute final fallback to OpenRouter Liquid LFM
    if (_openRouter.isConfigured) {
      return await _openRouter.completeFallback(
        prompt: prompt,
        systemPrompt: systemPrompt,
        model: OpenRouterService.modelLiquidSmall,
        jsonMode: jsonMode,
      );
    }

    throw StateError('All AI providers in fallback chain failed or lack keys');
  }

  // ---------------------------------------------------------------------------
  // MULTIMODAL & UTILITIES
  // ---------------------------------------------------------------------------
  /// Embeddings for Vector Search (Delegates to Gemini Embedding 2)
  Future<List<double>> embedText(String text) {
    return _gemini.generateEmbedding(text);
  }

  /// Audio Transcription (Delegates to Groq Whisper Large v3)
  Future<String> transcribeAudio(File file) {
    return _groq.transcribeAudio(file);
  }

  /// Image Generation (Pollinations.ai FLUX — Free & Unlimited)
  String generateImageUrl(String prompt) {
    return PollinationsService.getImageUrl(prompt: prompt);
  }

  /// Generates a structured concept hierarchy for Mind Map visualization.
  Future<String> generateMindmap({
    required String topic,
    String? content,
  }) async {
    final systemPrompt = '''
You are an expert cognitive mind-map architect.
Generate a structured, hierarchical concept map for the given topic and study material.
Organize the branches across 4 distinct cognitive dimensions:
1. Core Foundations & First Principles
2. Key Mechanisms & Processes
3. High-Yield Exam / Practical Applications
4. Common Traps, Edge Cases & Danger Zones

Return ONLY valid JSON matching this schema:
{
  "root": "$topic",
  "branches": [
    {
      "title": "Branch Title",
      "summary": "Clear 1-2 sentence core concept explanation.",
      "children": [
        {
          "title": "Sub-concept",
          "summary": "High-yield detail, formula or critical distinction."
        }
      ]
    }
  ]
}
Provide exactly 4 main branches, each with 2 to 3 concise children.
''';
    final prompt = (content != null && content.trim().isNotEmpty)
        ? 'Topic: $topic\n\nStudy Material:\n$content'
        : 'Topic: $topic';

    return executeWithFallback(
      prompt: prompt,
      systemPrompt: systemPrompt,
      jsonMode: true,
    ).timeout(const Duration(seconds: 50));
  }

  /// Generates a realistic daily study plan from the student's actual subjects & syllabus context.
  Future<String> generateStudyPlan({
    required List<String> subjects,
    required int daysLeft,
    String? syllabusContext,
  }) async {
    final subList = subjects.isNotEmpty ? subjects.join(', ') : 'General Study';
    final systemPrompt = '''
You are Sage, an academic study planner.
Create a realistic, actionable study plan for Today (3-4 focused tasks) and Tomorrow (3 focused tasks) for a student preparing for exams in $daysLeft days.
Student's subjects: $subList.
Return ONLY valid JSON matching this schema:
{
  "today": [
    {
      "title": "Specific topic or skill to study",
      "subject": "One of the student's subjects",
      "duration": 25,
      "type": "reading"
    }
  ],
  "tomorrow": [
    {
      "title": "Specific topic or skill to study",
      "subject": "One of the student's subjects",
      "duration": 25,
      "type": "quiz"
    }
  ]
}
Allowed types: "reading", "flashcard", "quiz".
''';
    final prompt = (syllabusContext != null && syllabusContext.trim().isNotEmpty)
        ? 'Student Syllabus & Notes:\n$syllabusContext'
        : 'Subjects: $subList. Days until exam: $daysLeft.';

    return executeWithFallback(
      prompt: prompt,
      systemPrompt: systemPrompt,
      jsonMode: true,
    ).timeout(const Duration(seconds: 50));
  }
}
