import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/setup_profile_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/explainer/screens/explainer_player_screen.dart';
import '../../features/flashcards/screens/deck_list_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/library/screens/notebook_detail_screen.dart';
import '../../features/planner/screens/planner_screen.dart';
import '../../features/quiz/screens/quiz_setup_screen.dart';
import '../../features/voice_tutor/screens/voice_session_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/setup-profile',
      builder: (context, state) => const SetupProfileScreen(),
    ),
    GoRoute(
      path: '/library',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/notebook/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '1';
        return NotebookDetailScreen(notebookId: id);
      },
    ),
    GoRoute(
      path: '/planner',
      builder: (context, state) => const PlannerScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: '/flashcards',
      builder: (context, state) => const DeckListScreen(),
    ),
    GoRoute(
      path: '/quiz',
      builder: (context, state) => const QuizSetupScreen(),
    ),
    GoRoute(
      path: '/voice-tutor',
      builder: (context, state) => const VoiceSessionScreen(),
    ),
    GoRoute(
      path: '/explainer',
      builder: (context, state) => const ExplainerPlayerScreen(),
    ),
  ],
);
