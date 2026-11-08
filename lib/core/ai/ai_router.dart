import 'dart:io';
import '../utils/rate_limiter.dart';
import 'cloudflare_service.dart';
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

  // ---------------------------------------------------------------------------
  // TIER 1: ULTRA-HEAVY / COMPLEX REASONING (Deep Synthesis & Big Context)
  // ---------------------------------------------------------------------------
  /// Handles heavy university lectures, full chapters, deep reasoning,
  /// and multi-scene explainer scripts.
  /// Priority: Gemini 2.5 Flash (1M ctx) -> OpenRouter Nemotron 550B -> Cohere Command R+ -> Groq OSS 120B
  Future<String> executeHeavyReasoning({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
  }) async {
    // 1. Gemini 2.5 Flash (1 Million token window, 1,500 RPD)
    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        final res = await _gemini.generateContent(
          prompt,
          systemInstruction: systemPrompt,
          jsonMode: jsonMode,
        );
        return res;
      } catch (e) {
        RateLimitGuardian.trip('gemini_flash');
      }
    }

    // 2. OpenRouter Nemotron 3 Ultra 550B:free (Monster parameter capacity for complex math & logic)
    if (_openRouter.isConfigured && await RateLimitGuardian.isAvailable('openrouter')) {
      try {
        await RateLimitGuardian.recordRequest('openrouter');
        return await _openRouter.completeFallback(
          prompt: prompt,
          systemPrompt: systemPrompt,
          model: OpenRouterService.modelNemotronUltra,
          jsonMode: jsonMode,
        );
      } catch (e) {
        RateLimitGuardian.trip('openrouter');
      }
    }

    // 3. Cohere Command R+ (128k context, rigorous academic citations)
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

    // 4. Groq OSS 120B (Large reasoning model, ultra-fast)
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_heavy')) {
      try {
        return await _groq.complete70B(
          prompt: prompt,
          systemPrompt: systemPrompt,
          jsonMode: jsonMode,
        );
      } catch (e) {
        RateLimitGuardian.trip('groq_heavy');
      }
    }

    // 5. OpenRouter Nemotron 3.5 Lightning:free (Reliable fallback)
    if (_openRouter.isConfigured) {
      return await _openRouter.completeFallback(
        prompt: prompt,
        systemPrompt: systemPrompt,
        model: OpenRouterService.modelNemotronLightning,
        jsonMode: jsonMode,
      );
    }

    throw StateError('All Heavy Reasoning models failed or lack configuration.');
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
    // 1. Groq OSS 20B (Extreme speed 500-800 tokens/sec on LPUs)
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_speed')) {
      try {
        return await _groq.complete8B(
          prompt: prompt,
          systemPrompt: systemPrompt,
        );
      } catch (e) {
        RateLimitGuardian.trip('groq_speed');
      }
    }

    // 2. OpenRouter Nemotron 3.5 Lightning:free (Fast conversational inference)
    if (_openRouter.isConfigured && await RateLimitGuardian.isAvailable('openrouter')) {
      try {
        await RateLimitGuardian.recordRequest('openrouter');
        return await _openRouter.completeFallback(
          prompt: prompt,
          systemPrompt: systemPrompt,
          model: OpenRouterService.modelNemotronLightning,
        );
      } catch (e) {
        RateLimitGuardian.trip('openrouter');
      }
    }

    // 3. Gemini 2.5 Flash
    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        return await _gemini.generateContent(
          prompt,
          systemInstruction: systemPrompt,
        );
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
You are an expert study assistant. Generate exactly $count high-yield flashcards from the provided content.
Return ONLY valid JSON matching this schema:
{
  "cards": [
    {
      "front": "Question or prompt",
      "back": "Concise, complete answer",
      "topic": "Specific subtopic"
    }
  ]
}
''';

    final prompt = 'Content to process:\n$content';

    // 1. Groq (High daily quota: 14,400 requests/day)
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_speed')) {
      try {
        return await _groq.complete8B(
          prompt: prompt,
          systemPrompt: systemPrompt,
          jsonMode: true,
        );
      } catch (e) {
        RateLimitGuardian.trip('groq_speed');
      }
    }

    // 2. Gemini 2.5 Flash
    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        return await _gemini.generateContent(
          prompt,
          systemInstruction: systemPrompt,
          jsonMode: true,
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
    );
  }

  /// High-volume quiz generation
  Future<String> generateQuiz({
    required String content,
    int count = 5,
    String difficulty = 'medium',
  }) async {
    final systemPrompt = '''
You are an adaptive test designer. Generate $count $difficulty level multiple choice questions from the content.
Return ONLY valid JSON matching this schema:
{
  "questions": [
    {
      "question": "Clear problem statement",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctOptionIndex": 0,
      "explanation": "Why this option is correct and others are wrong"
    }
  ]
}
''';

    final prompt = 'Study material:\n$content';

    // 1. Groq
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_speed')) {
      try {
        return await _groq.complete8B(
          prompt: prompt,
          systemPrompt: systemPrompt,
          jsonMode: true,
        );
      } catch (e) {
        RateLimitGuardian.trip('groq_speed');
      }
    }

    // 2. Gemini 2.5 Flash
    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        return await _gemini.generateContent(
          prompt,
          systemInstruction: systemPrompt,
          jsonMode: true,
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
    );
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
  /// Grounded RAG Chat with precision reranking
  Future<String> chatWithNotes({
    required String question,
    required List<String> retrievedChunks,
    String studentName = 'Alex',
  }) async {
    // Apply Cohere Rerank v3.5 if available (elevates recall by 25-30%)
    List<String> optimalChunks = retrievedChunks;
    if (_cohere.isConfigured && retrievedChunks.length > 1 && await RateLimitGuardian.isAvailable('cohere')) {
      try {
        await RateLimitGuardian.recordRequest('cohere');
        optimalChunks = await _cohere.rerankDocuments(
          query: question,
          documents: retrievedChunks,
          topN: 4,
        );
      } catch (e) {
        RateLimitGuardian.trip('cohere');
      }
    }

    final contextText = optimalChunks.join('\n---\n');
    final systemPrompt = '''
You are Sage, the personal AI study mentor for $studentName in the True Me app.
Answer the student's question grounded firmly on the provided lecture notes and document excerpts.
Always cite the source or document when referencing specific concepts or equations.
If the notes do not contain the answer, state so honestly, then provide the general academic explanation.
''';

    final userPrompt = '''
Retrieved Note Excerpts:
$contextText

Student Question:
$question
''';

    // RAG synthesis priority: Groq OSS 120B (fastest readable answer) -> Gemini Flash -> OpenRouter Lightning
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_heavy')) {
      try {
        return await _groq.complete70B(
          prompt: userPrompt,
          systemPrompt: systemPrompt,
        );
      } catch (e) {
        RateLimitGuardian.trip('groq_heavy');
      }
    }

    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        return await _gemini.generateContent(
          userPrompt,
          systemInstruction: systemPrompt,
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
    // 1. Gemini Flash
    if (_gemini.isConfigured && await RateLimitGuardian.isAvailable('gemini_flash')) {
      try {
        return await _gemini.generateContent(
          prompt,
          systemInstruction: systemPrompt,
          jsonMode: jsonMode,
        );
      } catch (e) {
        RateLimitGuardian.trip('gemini_flash');
      }
    }

    // 2. Groq (OSS 120B or 20B)
    if (_groq.isConfigured && await RateLimitGuardian.isAvailable('groq_speed')) {
      try {
        return await _groq.complete8B(
          prompt: prompt,
          systemPrompt: systemPrompt,
          jsonMode: jsonMode,
        );
      } catch (e) {
        RateLimitGuardian.trip('groq_speed');
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
}
