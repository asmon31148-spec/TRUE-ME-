import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/setup_profile_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/explainer/screens/explainer_player_screen.dart';
import '../../features/flashcards/screens/deck_list_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/library/screens/notebook_detail_screen.dart';
import '../../features/mindmap/screens/mindmap_screen.dart';
import '../../features/notes/screens/note_editor_screen.dart';
import '../../features/planner/screens/planner_screen.dart';
import '../../features/profile/screens/account_center_screen.dart';
import '../../features/quiz/screens/quiz_setup_screen.dart';
import '../../features/upload/screens/upload_screen.dart';
import '../../features/voice_tutor/screens/voice_session_screen.dart';
import '../../shared/widgets/app_scaffold_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/splash',
    ),
    // Standalone Fullscreen Flow
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
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
      path: '/account-center',
      builder: (context, state) => const AccountCenterScreen(),
    ),
    GoRoute(
      path: '/note-editor',
      builder: (context, state) => const NoteEditorScreen(),
    ),
    GoRoute(
      path: '/voice-tutor',
      builder: (context, state) => const VoiceSessionScreen(),
    ),
    GoRoute(
      path: '/explainer',
      builder: (context, state) => const ExplainerPlayerScreen(),
    ),

    // Main App Navigation Shell (Persistent Floating Liquid Glass Bar)
    ShellRoute(
      builder: (context, state, child) => AppScaffoldShell(child: child),
      routes: [
        GoRoute(
          path: '/library',
          builder: (context, state) => const LibraryScreen(),
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
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/planner',
          builder: (context, state) => const PlannerScreen(),
        ),
        GoRoute(
          path: '/quiz',
          builder: (context, state) => const QuizSetupScreen(),
        ),
        GoRoute(
          path: '/upload',
          builder: (context, state) => const UploadScreen(),
        ),
        GoRoute(
          path: '/mindmap',
          builder: (context, state) => const MindmapScreen(),
        ),
        GoRoute(
          path: '/notebook/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '1';
            return NotebookDetailScreen(notebookId: id);
          },
        ),
      ],
    ),
  ],
);
