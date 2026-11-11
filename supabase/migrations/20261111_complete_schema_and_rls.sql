-- ==============================================================================
-- TRUE ME: Complete Cloud Schema & Hardened RLS Policies
-- Migration: 20261111_complete_schema_and_rls.sql
--
-- Note: Apply this in Supabase SQL Editor. Once applied, authenticated users
-- (auth.uid()) can read/write only their own rows; unauthenticated/guest users
-- stay local-only in Hive.
-- ==============================================================================

-- 1. User Profiles
CREATE TABLE IF NOT EXISTS user_profiles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT 'Student',
  email TEXT NOT NULL,
  subjects TEXT[] DEFAULT '{}',
  learning_style TEXT DEFAULT 'Visual & Practice',
  target_exam_date TIMESTAMPTZ,
  setup_started_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Notebooks & Embedded Documents
CREATE TABLE IF NOT EXISTS notebooks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  documents JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notebooks_user ON notebooks(user_id);

-- 3. Daily Study Tasks (Today & 7-Day Schedule)
CREATE TABLE IF NOT EXISTS study_tasks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plan_date TEXT NOT NULL,
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  task_type TEXT NOT NULL DEFAULT 'reading',
  duration_min INT NOT NULL DEFAULT 20,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_study_tasks_user_date ON study_tasks(user_id, plan_date);

-- 4. Flashcard Decks (SM-2)
CREATE TABLE IF NOT EXISTS flashcard_decks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  notebook_id TEXT,
  subject TEXT NOT NULL,
  topic TEXT NOT NULL,
  cards JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_flashcard_decks_user ON flashcard_decks(user_id);

-- 5. Quiz Attempts
CREATE TABLE IF NOT EXISTS quiz_attempts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  subject TEXT NOT NULL,
  topic TEXT NOT NULL,
  score INT NOT NULL,
  total INT NOT NULL,
  percentage INT NOT NULL,
  missed_topics TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user ON quiz_attempts(user_id, created_at DESC);

-- ==============================================================================
-- 6. Strict Tenant-Isolated RLS Across All Tables
-- ==============================================================================
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE notebooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE flashcard_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;

-- user_profiles (owner key is id)
DROP POLICY IF EXISTS "Users manage own profile" ON user_profiles;
CREATE POLICY "Users manage own profile"
ON user_profiles FOR ALL
USING (auth.uid()::text = id)
WITH CHECK (auth.uid()::text = id);

-- notebooks
DROP POLICY IF EXISTS "Users manage own notebooks" ON notebooks;
CREATE POLICY "Users manage own notebooks"
ON notebooks FOR ALL
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);

-- study_tasks
DROP POLICY IF EXISTS "Users manage own study_tasks" ON study_tasks;
CREATE POLICY "Users manage own study_tasks"
ON study_tasks FOR ALL
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);

-- flashcard_decks
DROP POLICY IF EXISTS "Users manage own flashcard_decks" ON flashcard_decks;
CREATE POLICY "Users manage own flashcard_decks"
ON flashcard_decks FOR ALL
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);

-- quiz_attempts
DROP POLICY IF EXISTS "Users manage own quiz_attempts" ON quiz_attempts;
CREATE POLICY "Users manage own quiz_attempts"
ON quiz_attempts FOR ALL
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);
