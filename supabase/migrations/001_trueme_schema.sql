-- True Me Backend Database Schema (Supabase PostgreSQL + pgvector)
-- Run in Supabase SQL Editor if deploying/updating tables cleanly.

-- 1. User Profiles table
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id text PRIMARY KEY,
  name text NOT NULL DEFAULT 'Student',
  email text,
  subjects text[] NOT NULL DEFAULT '{}',
  learning_style text DEFAULT 'Visual & Practice',
  target_exam_date timestamptz,
  setup_started_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 2. Notebooks / Subjects table
CREATE TABLE IF NOT EXISTS public.notebooks (
  id text PRIMARY KEY,
  user_id text NOT NULL,
  title text NOT NULL,
  subject text NOT NULL,
  documents jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notebooks_user_id ON public.notebooks(user_id);

-- 3. Daily Study Tasks table
CREATE TABLE IF NOT EXISTS public.study_tasks (
  id text PRIMARY KEY,
  user_id text NOT NULL,
  plan_date text NOT NULL,
  title text NOT NULL,
  subject text NOT NULL DEFAULT 'General',
  task_type text NOT NULL DEFAULT 'reading',
  duration_min integer NOT NULL DEFAULT 20,
  completed boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_study_tasks_user_date ON public.study_tasks(user_id, plan_date);

-- 4. Quiz Attempts table
CREATE TABLE IF NOT EXISTS public.quiz_attempts (
  id text PRIMARY KEY,
  user_id text NOT NULL,
  subject text NOT NULL,
  topic text NOT NULL,
  score integer NOT NULL,
  total integer NOT NULL,
  percentage integer NOT NULL,
  missed_topics text[] NOT NULL DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_id ON public.quiz_attempts(user_id);

-- 5. Flashcard Decks table
CREATE TABLE IF NOT EXISTS public.flashcard_decks (
  id text PRIMARY KEY,
  user_id text NOT NULL,
  notebook_id text,
  subject text NOT NULL,
  topic text NOT NULL,
  cards jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_flashcard_decks_user_id ON public.flashcard_decks(user_id);

-- 6. Enable RLS & define policies
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notebooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcard_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_chunks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_app_user_profiles" ON public.user_profiles;
CREATE POLICY "allow_app_user_profiles" ON public.user_profiles FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "allow_app_notebooks" ON public.notebooks;
CREATE POLICY "allow_app_notebooks" ON public.notebooks FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "allow_app_study_tasks" ON public.study_tasks;
CREATE POLICY "allow_app_study_tasks" ON public.study_tasks FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "allow_app_quiz_attempts" ON public.quiz_attempts;
CREATE POLICY "allow_app_quiz_attempts" ON public.quiz_attempts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "allow_app_flashcard_decks" ON public.flashcard_decks;
CREATE POLICY "allow_app_flashcard_decks" ON public.flashcard_decks FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "allow_app_study_sessions" ON public.study_sessions;
CREATE POLICY "allow_app_study_sessions" ON public.study_sessions FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "allow_app_user_files" ON public.user_files;
CREATE POLICY "allow_app_user_files" ON public.user_files FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "allow_app_document_chunks" ON public.document_chunks;
CREATE POLICY "allow_app_document_chunks" ON public.document_chunks FOR ALL USING (true) WITH CHECK (true);
