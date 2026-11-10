# True Me — Architecture & Organization Guide

## 1. Directory Structure

```text
lib/
├── app/
│   ├── app.dart                 # Root ConsumerWidget wired to ThemeModeNotifier
│   ├── router/app_router.dart   # GoRouter routes + 4-tab AppScaffoldShell
│   └── theme/
│       ├── app_theme.dart       # Light & Dark ThemeData definitions
│       ├── colors.dart          # Static color tokens
│       ├── theme_provider.dart  # Persistent System/Light/Dark ThemeMode & BuildContext helpers
│       └── typography.dart      # Shared text styles inheriting Theme colors
├── core/
│   ├── ai/                      # Multi-provider AI Router (Gemini -> Groq -> OpenRouter -> Cohere), RAG, Sage agent
│   ├── algorithms/              # SM-2 spaced repetition algorithm
│   ├── models/                  # Data models (User, Notebook, Quiz, Flashcard, StudyPlan, StudySession, Chunk)
│   ├── services/
│   │   ├── drive_service.dart         # Google Drive OAuth & `True Me / [Subject] / [Section]` sync
│   │   ├── offline_cache_service.dart # Hive offline-first cache + background Supabase sync
│   │   ├── supabase_service.dart      # Cloud database & auth persistence
│   │   ├── update_service.dart        # GitHub Releases OTA updater
│   │   └── ...                        # OCR, STT, TTS, notifications, achievements
│   └── utils/                   # Text chunker, formatters, rate limiter
├── features/
│   ├── auth/                    # Splash, Onboarding, Login, Profile Setup
│   ├── today/                   # Daily Hero Plan, Exam Countdown, Subject-Filtered Tasks, Dynamic Sage Insight
│   ├── library/                 # Subject Library (search/sort) & Notebook Detail (Sources, Chat, Study)
│   ├── planner/                 # 7-Day Week & Subject-Grouped Study Schedule + Priority & AI Auto-Plan
│   ├── practice/                # Quiz, Flashcards (SM-2), Voice Tutor, Mind Map
│   ├── chat/                    # Sage RAG Chat grounded in uploaded subject sources
│   ├── notes/                   # Markdown Note Editor synced to Notes section
│   ├── upload/                  # AddFilesSheet (PDF, Camera/Gallery OCR, URL/YouTube, Text, Audio, Drive Import)
│   ├── explainer/               # AI Narrated Audio Walkthrough Player
│   ├── export/                  # PDF / DOCX / PPTX study guide exporters
│   └── profile/                 # Account Center (Theme switcher, Drive vault status, Update check, Reset)
└── shared/widgets/              # Reusable themed UI components & stationary 4-tab bottom bar
```

---

## 2. Navigation & App Flow

- **4 Root Tabs (`AppScaffoldShell`):**
  - **Today (`/today`):** Daily plan progress ring, exam countdown, subject-filterable task list, quick task menu (`Start`, `Move to tomorrow`, `Remove`), and real-time Sage insight.
  - **Library (`/library`):** Search & sort subjects, connect Google Drive, jump into any subject (`NotebookDetailScreen`).
  - **Practice (`/practice`):** Launch AI Quizzes, SM-2 Flashcards, Voice Tutor, or Mind Maps, plus recent practice history.
  - **Progress (`/progress`):** Plan progress, quiz-detected weak topics, streak, and weekly study time bar chart.
- **Full-Screen Flows:** `/schedule` (7-day week & subject planner), `/notebook/:id`, `/chat`, `/quiz`, `/flashcards`, `/voice-tutor`, `/mindmap`, `/explainer`, `/note-editor`, `/account`.

---

## 3. Data & Storage Model

- **Offline-First Cache (`Hive` via `OfflineCacheService`):** Immediate read/write on device so the app works offline with zero fake/hardcoded data.
- **Cloud Database (`Supabase` via `SupabaseService`):** Syncs profiles, notebooks, upcoming 7-day study tasks, quiz attempts, study sessions, and RAG `document_chunks`.
- **Google Drive Vault (`DriveService`):**
  - Organizes uploaded study files automatically inside:
    `True Me / [Subject] / [Section]` (where `Section` is `Syllabus`, `Notes`, `Books`, or `Previous papers`).
  - Supports importing files either from the `True Me` vault or across recent Drive files.

---

## 4. Build & Release Workflow

- Pushing to `main` triggers [`.github/workflows/build_apk.yml`](.github/workflows/build_apk.yml).
- Signs release APKs using `trueme-release.jks` (`applicationId = com.trueme.study.trueme`) and publishes `TrueMe-release.apk` to GitHub Releases.
- `UpdateService` checks GitHub Releases on launch and in Account Center for seamless in-app APK updates.
