import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/study_plan_model.dart';
import '../models/user_model.dart';
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

/// Mock or live daily study plan state
final dailyStudyPlanProvider =
    FutureProvider.family<DailyStudyPlanModel, UserModel>((ref, user) async {
  final sage = ref.watch(sageAgentProvider);
  return sage.generateDailyStudyPlan(
    user: user,
    weakTopics: ['Calculus Eigenvalues', 'OS Process Synchronization'],
  );
});
