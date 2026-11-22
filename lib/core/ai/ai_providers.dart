import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/study_plan_model.dart';
import '../models/user_model.dart';
import '../services/offline_cache_service.dart';
import 'ai_router.dart';
import 'cohere_service.dart';
import 'gemini_service.dart';
import 'groq_service.dart';
import 'sage_agent.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

final groqServiceProvider = Provider<GroqService>((ref) {
  return GroqService();
});

final cohereServiceProvider = Provider<CohereService>((ref) {
  return CohereService();
});

final aiRouterProvider = Provider<AiRouter>((ref) {
  return AiRouter(
    gemini: ref.watch(geminiServiceProvider),
    groq: ref.watch(groqServiceProvider),
    cohere: ref.watch(cohereServiceProvider),
  );
});

final sageAgentProvider = Provider<SageAgent>((ref) {
  return SageAgent(aiRouter: ref.watch(aiRouterProvider));
});

/// Live daily study plan state powered by real student analytics
final dailyStudyPlanProvider =
    FutureProvider.family<DailyStudyPlanModel, UserModel>((ref, user) async {
  final sage = ref.watch(sageAgentProvider);
  final realWeak = OfflineCacheService.getWeakTopics()
      .map((e) => (e['topic'] as String?)?.trim())
      .whereType<String>()
      .where((t) => t.isNotEmpty)
      .toList();
  final weakTopics = realWeak.isNotEmpty
      ? realWeak
      : (user.subjects.isNotEmpty
          ? user.subjects
          : ['Core Concepts & High-Yield Review']);
  return sage.generateDailyStudyPlan(
    user: user,
    weakTopics: weakTopics,
  );
});
