import 'dart:io';
import 'cloudflare_service.dart';
import 'gemini_service.dart';
import 'groq_service.dart';
import 'openrouter_service.dart';
import 'pollinations_service.dart';

class AiRouter {
  final GeminiService _gemini;
  final GroqService _groq;
  final CloudflareService _cloudflare;
  final OpenRouterService _openRouter;

  AiRouter({
    GeminiService? gemini,
    GroqService? groq,
    CloudflareService? cloudflare,
    OpenRouterService? openRouter,
  })  : _gemini = gemini ?? GeminiService(),
        _groq = groq ?? GroqService(),
        _cloudflare = cloudflare ?? CloudflareService(),
        _openRouter = openRouter ?? OpenRouterService();

  /// General reasoning with automatic fallback chain:
  /// Gemini 1.5 Flash -> Groq 70B -> Groq 8B -> Cloudflare -> OpenRouter Free
  Future<String> executeWithFallback({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
  }) async {
    // 1. Try Gemini 1.5 Flash
    if (_gemini.isConfigured) {
      try {
        return await _gemini.generateContent(
          prompt,
          systemInstruction: systemPrompt,
          jsonMode: jsonMode,
        );
      } catch (_) {
        // Fallback to Groq 70B
      }
    }

    // 2. Try Groq LLaMA 70B
    if (_groq.isConfigured) {
      try {
        return await _groq.complete70B(
          prompt: prompt,
          systemPrompt: systemPrompt,
          jsonMode: jsonMode,
        );
      } catch (_) {
        // Fallback to Groq 8B
      }
    }

    // 3. Try Groq LLaMA 8B
    if (_groq.isConfigured) {
      try {
        return await _groq.complete8B(
          prompt: prompt,
          systemPrompt: systemPrompt,
          jsonMode: jsonMode,
        );
      } catch (_) {
        // Fallback to Cloudflare
      }
    }

    // 4. Try Cloudflare Workers AI
    if (_cloudflare.isConfigured && !jsonMode) {
      try {
        return await _cloudflare.summarizeText(prompt);
      } catch (_) {
        // Fallback to OpenRouter Free
      }
    }

    // 5. Final fallback to OpenRouter Free
    if (_openRouter.isConfigured) {
      return await _openRouter.completeFallback(
        prompt: prompt,
        systemPrompt: systemPrompt,
      );
    }

    throw StateError('All AI providers in fallback chain failed or lack keys');
  }

  /// High-volume flashcard generation (Delegates to Groq 8B, 14,400 calls/day)
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

    if (_groq.isConfigured) {
      try {
        return await _groq.complete8B(
          prompt: 'Content to process:\n$content',
          systemPrompt: systemPrompt,
          jsonMode: true,
        );
      } catch (_) {
        // Fallback to Gemini
      }
    }

    return executeWithFallback(
      prompt: 'Content to process:\n$content',
      systemPrompt: systemPrompt,
      jsonMode: true,
    );
  }

  /// High-volume quiz generation (Delegates to Groq 8B)
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

    if (_groq.isConfigured) {
      try {
        return await _groq.complete8B(
          prompt: 'Study material:\n$content',
          systemPrompt: systemPrompt,
          jsonMode: true,
        );
      } catch (_) {
        // Fallback
      }
    }

    return executeWithFallback(
      prompt: 'Study material:\n$content',
      systemPrompt: systemPrompt,
      jsonMode: true,
    );
  }

  /// Grounded RAG Chat (Delegates to Groq 70B)
  Future<String> chatWithNotes({
    required String question,
    required List<String> retrievedChunks,
    String studentName = 'Alex',
  }) async {
    final contextText = retrievedChunks.join('\n---\n');
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

    if (_groq.isConfigured) {
      try {
        return await _groq.complete70B(
          prompt: userPrompt,
          systemPrompt: systemPrompt,
        );
      } catch (_) {
        // Fallback to Gemini
      }
    }

    return executeWithFallback(
      prompt: userPrompt,
      systemPrompt: systemPrompt,
    );
  }

  /// Embeddings for Vector Search (Delegates to Gemini text-embedding-004)
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
