import '../openrouter_service.dart';
import 'ai_monitor_models.dart';

/// Automatically discovers all configured AI providers, models, pricing,
/// assigned features, and callback routes from TRUE ME's active architecture,
/// and dynamically merges any new models discovered from live provider APIs.
class AiModelRegistry {
  AiModelRegistry._();

  static const List<String> knownProviders = [
    'gemini',
    'groq',
    'openrouter',
    'cohere',
    'cloudflare',
  ];

  static String providerDisplayName(String provider) {
    switch (provider.toLowerCase()) {
      case 'gemini':
        return 'Google Gemini';
      case 'groq':
        return 'Groq LPU';
      case 'openrouter':
        return 'OpenRouter';
      case 'cohere':
        return 'Cohere';
      case 'cloudflare':
        return 'Cloudflare Workers AI';
      default:
        return provider;
    }
  }

  /// Discovers all configured models + merges any newly discovered models
  /// from [snapshots] so new models appear automatically without manual edits.
  static List<ModelRegistryEntry> discoverModels({
    Map<String, ProviderSnapshot> snapshots = const {},
  }) {
    final byKey = <String, ModelRegistryEntry>{};

    void register(ModelRegistryEntry entry) {
      byKey['${entry.provider}::${entry.modelId}'] = entry;
    }

    // 1. Groq configured models (from ai-gateway & GroqService)
    register(const ModelRegistryEntry(
      provider: 'groq',
      modelId: 'openai/gpt-oss-120b',
      displayName: 'GPT-OSS 120B (Groq Heavy)',
      isDefault: true,
      isPrimary: true,
      contextWindow: 131072,
      inputPricePer1M: 0.15,
      outputPricePer1M: 0.75,
      assignedFeatures: [
        'Study Assistant (Sage)',
        'Chat with Notes',
        'Quiz Generator',
        'Flashcards',
        'Mindmap',
        'Explainer Script',
        'Document Generation',
        'Study Planner',
        'Syllabus Extractor',
      ],
      callbackRoutes: [
        'AiRouter.executeHeavyReasoning',
        'AiRouter.chatWithNotes',
        'AiRouter.generateQuiz',
        'AiRouter.generateFlashcards',
        'AiRouter.generateMindmap',
        'AiRouter.generateStudyPlan',
      ],
    ));

    register(const ModelRegistryEntry(
      provider: 'groq',
      modelId: 'llama-3.3-70b-versatile',
      displayName: 'Llama 3.3 70B Versatile',
      isFallback: true,
      contextWindow: 131072,
      inputPricePer1M: 0.59,
      outputPricePer1M: 0.79,
      assignedFeatures: ['Heavy Reasoning Fallback', 'Quiz & Flashcard Fallback'],
      callbackRoutes: ['AiRouter.executeHeavyReasoning', 'AiRouter.chatWithNotes'],
    ));

    register(const ModelRegistryEntry(
      provider: 'groq',
      modelId: 'openai/gpt-oss-20b',
      displayName: 'GPT-OSS 20B (Groq Speed)',
      isPrimary: true,
      contextWindow: 131072,
      inputPricePer1M: 0.075,
      outputPricePer1M: 0.30,
      assignedFeatures: ['Realtime Voice & Chat', 'Micro Tasks', 'YouTube/URL Notes'],
      callbackRoutes: ['AiRouter.executeRealtimeChat', 'AiRouter.executeMicroTask'],
    ));

    register(const ModelRegistryEntry(
      provider: 'groq',
      modelId: 'llama-3.1-8b-instant',
      displayName: 'Llama 3.1 8B Instant',
      isFallback: true,
      contextWindow: 131072,
      inputPricePer1M: 0.05,
      outputPricePer1M: 0.08,
      assignedFeatures: ['Realtime Chat Fallback'],
      callbackRoutes: ['AiRouter.executeRealtimeChat'],
    ));

    register(const ModelRegistryEntry(
      provider: 'groq',
      modelId: 'whisper-large-v3',
      displayName: 'Whisper Large v3 (Audio)',
      isPrimary: true,
      isFreeTier: true,
      assignedFeatures: ['Audio & Lecture Transcription'],
      callbackRoutes: ['AiRouter.transcribeAudio', 'GroqService.transcribeAudio'],
    ));

    // 2. Google Gemini configured models (from ai-gateway & GeminiService)
    for (final g in [
      ('gemini-3.5-flash', 'Gemini 3.5 Flash', true),
      ('gemini-3.8-flash', 'Gemini 3.8 Flash', false),
      ('gemini-flash-latest', 'Gemini Flash Latest', false),
      ('gemini-2.5-flash', 'Gemini 2.5 Flash', false),
      ('gemini-2.0-flash', 'Gemini 2.0 Flash', false),
    ]) {
      register(ModelRegistryEntry(
        provider: 'gemini',
        modelId: g.$1,
        displayName: g.$2,
        isPrimary: g.$3,
        isFallback: !g.$3,
        contextWindow: 1048576,
        inputPricePer1M: 0.10,
        outputPricePer1M: 0.40,
        cachedInputPricePer1M: 0.025,
        assignedFeatures: const [
          'Study Assistant (Sage)',
          'Chat with Notes Fallback',
          'Document Generation Fallback',
        ],
        callbackRoutes: const [
          'GeminiService.generateContent',
          'AiRouter.executeHeavyReasoning',
          'AiRouter.chatWithNotes',
        ],
      ));
    }

    register(const ModelRegistryEntry(
      provider: 'gemini',
      modelId: 'gemini-embedding-001',
      displayName: 'Gemini Embedding 001 (768-dim)',
      isPrimary: true,
      contextWindow: 2048,
      inputPricePer1M: 0.0,
      outputPricePer1M: 0.0,
      assignedFeatures: ['RAG Document Ingestion', 'Semantic Search'],
      callbackRoutes: ['AiRouter.embedText', 'GeminiService.generateEmbedding'],
    ));

    // 3. OpenRouter configured models (dynamically read from OpenRouterService.freeModels)
    for (final orId in OpenRouterService.freeModels) {
      final isDefault = orId == OpenRouterService.modelNemotronLightning;
      register(ModelRegistryEntry(
        provider: 'openrouter',
        modelId: orId,
        displayName: _humanizeModelId(orId),
        isDefault: isDefault,
        isFallback: true,
        isFreeTier: orId.endsWith(':free'),
        contextWindow: 131072,
        inputPricePer1M: 0.0,
        outputPricePer1M: 0.0,
        assignedFeatures: isDefault
            ? const ['Document Generation Fallback', 'Quiz & Chat Fallback']
            : const ['OpenRouter Standby Pool'],
        callbackRoutes: const ['OpenRouterService.completeFallback', 'AiRouter.executeWithFallback'],
      ));
    }

    // 4. Cohere configured models (from CohereService & ai-gateway)
    register(const ModelRegistryEntry(
      provider: 'cohere',
      modelId: 'command-r-plus-08-2024',
      displayName: 'Cohere Command R+ (08-2024)',
      isFallback: true,
      isFreeTier: true,
      contextWindow: 128000,
      inputPricePer1M: 2.50,
      outputPricePer1M: 10.00,
      assignedFeatures: ['Writing & Reasoning Fallback'],
      callbackRoutes: ['CohereService.chat', 'AiRouter.executeHeavyReasoning'],
    ));

    register(const ModelRegistryEntry(
      provider: 'cohere',
      modelId: 'rerank-v3.5',
      displayName: 'Cohere Rerank v3.5',
      isPrimary: true,
      isFreeTier: true,
      contextWindow: 4096,
      assignedFeatures: ['RAG Chunk Reranking'],
      callbackRoutes: ['CohereService.rerankDocuments', 'RagService.queryContext'],
    ));

    // 5. Cloudflare Workers AI
    register(const ModelRegistryEntry(
      provider: 'cloudflare',
      modelId: '@cf/meta/llama-3-8b-instruct',
      displayName: 'Llama 3 8B Instruct (Cloudflare)',
      isPrimary: true,
      isFreeTier: true,
      contextWindow: 8192,
      assignedFeatures: ['Web Article & URL Summarizer'],
      callbackRoutes: ['CloudflareService.summarizeText', 'UrlProcessor.fetchAndSummarize'],
    ));

    // 6. Merge any newly discovered active models from live official provider snapshots
    for (final entry in snapshots.entries) {
      final provider = entry.key;
      final snap = entry.value;
      for (final modelId in snap.discoveredModelIds) {
        final key = '$provider::$modelId';
        final existing = byKey[key];
        final ctx = snap.modelContextLimits[modelId];
        if (existing != null) {
          byKey[key] = existing.copyWith(
            isActive: true,
            contextWindow: ctx ?? existing.contextWindow,
          );
        } else {
          // Only auto-append newly discovered models if they are relevant text/chat models
          // (avoids flooding with 50+ legacy deprecated Gemini/Groq sub-variants unless used)
          if (_isRelevantDiscoveredModel(provider, modelId)) {
            byKey[key] = ModelRegistryEntry(
              provider: provider,
              modelId: modelId,
              displayName: _humanizeModelId(modelId),
              isActive: true,
              isFallback: true,
              isFreeTier: modelId.endsWith(':free') || provider == 'groq' || provider == 'gemini',
              contextWindow: ctx,
              assignedFeatures: const ['Discovered via Provider API'],
              callbackRoutes: const ['Dynamic Discovery'],
            );
          }
        }
      }
    }

    return byKey.values.toList();
  }

  static bool _isRelevantDiscoveredModel(String provider, String modelId) {
    final lower = modelId.toLowerCase();
    if (provider == 'gemini') {
      return lower.contains('flash') || lower.contains('pro') || lower.contains('embedding');
    }
    if (provider == 'groq') {
      return lower.contains('llama') || lower.contains('gpt-oss') || lower.contains('whisper');
    }
    return true;
  }

  static String _humanizeModelId(String id) {
    final clean = id.split('/').last.replaceAll(':free', '').replaceAll('-', ' ');
    return clean
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
