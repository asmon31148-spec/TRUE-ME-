import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/setup_profile_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/explainer/screens/explainer_player_screen.dart';
import '../../features/flashcards/screens/deck_list_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/library/screens/notebook_detail_screen.dart';
import '../../features/mindmap/screens/mindmap_screen.dart';
import '../../features/notes/screens/note_editor_screen.dart';
import '../../features/planner/screens/schedule_screen.dart';
import '../../features/practice/screens/practice_screen.dart';
import '../../features/profile/screens/account_center_screen.dart';
import '../../features/progress/screens/progress_screen.dart';
import '../../features/quiz/screens/quiz_setup_screen.dart';
import '../../features/today/screens/today_screen.dart';
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
    // Fullscreen Flows
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
      path: '/account',
      builder: (context, state) => const AccountCenterScreen(),
    ),
    GoRoute(
      path: '/account-center',
      builder: (context, state) => const AccountCenterScreen(),
    ),
    GoRoute(
      path: '/schedule',
      builder: (context, state) => const ScheduleScreen(),
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
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final scope = state.uri.queryParameters['scope'];
        return ChatScreen(subject: scope);
      },
    ),
    GoRoute(
      path: '/quiz',
      builder: (context, state) => const QuizSetupScreen(),
    ),
    GoRoute(
      path: '/flashcards',
      builder: (context, state) => const DeckListScreen(),
    ),
    GoRoute(
      path: '/mindmap',
      builder: (context, state) => const MindmapScreen(),
    ),
    GoRoute(
      path: '/upload',
      builder: (context, state) => const UploadScreen(),
    ),

    // Main App Navigation Shell (Stationary 4-Tab Bottom Bar)
    ShellRoute(
      builder: (context, state, child) => AppScaffoldShell(child: child),
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const TodayScreen(),
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: '/practice',
          builder: (context, state) => const PracticeScreen(),
        ),
        GoRoute(
          path: '/progress',
          builder: (context, state) => const ProgressScreen(),
        ),
        GoRoute(
          path: '/notebook/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '1';
            return NotebookDetailScreen(notebookId: id);
          },
        ),
        // Backward-compat aliases
        GoRoute(
          path: '/dashboard',
          redirect: (context, state) => '/today',
        ),
        GoRoute(
          path: '/planner',
          redirect: (context, state) => '/schedule',
        ),
      ],
    ),
  ],
);
