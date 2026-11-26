-- ==============================================================================
-- TRUE ME: Phase 1 Corrective RLS & Function Security Migration (SEC-02)
-- Forward-only migration: drops legacy permissive `allow_app_*` policies that
-- bypassed owner-scoped policies via PostgreSQL OR composition, restricts all
-- tenant policies to `authenticated`, and hardens `match_document_chunks`.
-- ==============================================================================

-- 1. Drop legacy permissive policies from 001_trueme_schema.sql and 20261107_init_trueme.sql
DROP POLICY IF EXISTS "allow_app_user_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "allow_app_notebooks" ON public.notebooks;
DROP POLICY IF EXISTS "allow_app_study_tasks" ON public.study_tasks;
DROP POLICY IF EXISTS "allow_app_quiz_attempts" ON public.quiz_attempts;
DROP POLICY IF EXISTS "allow_app_flashcard_decks" ON public.flashcard_decks;
DROP POLICY IF EXISTS "allow_app_study_sessions" ON public.study_sessions;
DROP POLICY IF EXISTS "allow_app_user_files" ON public.user_files;
DROP POLICY IF EXISTS "allow_app_document_chunks" ON public.document_chunks;

DROP POLICY IF EXISTS "Allow app access to document_chunks" ON public.document_chunks;
DROP POLICY IF EXISTS "Allow app access to user_files" ON public.user_files;
DROP POLICY IF EXISTS "Allow app access to study_sessions" ON public.study_sessions;

-- 2. Ensure RLS is enabled on all 8 tenant tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notebooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcard_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_chunks ENABLE ROW LEVEL SECURITY;

-- 3. Recreate strict owner-scoped policies restricted to `authenticated` role
DROP POLICY IF EXISTS "Users manage own profile" ON public.user_profiles;
CREATE POLICY "Users manage own profile"
ON public.user_profiles FOR ALL
TO authenticated
USING ((auth.uid())::text = id)
WITH CHECK ((auth.uid())::text = id);

DROP POLICY IF EXISTS "Users manage own notebooks" ON public.notebooks;
CREATE POLICY "Users manage own notebooks"
ON public.notebooks FOR ALL
TO authenticated
USING ((auth.uid())::text = user_id)
WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own study_tasks" ON public.study_tasks;
CREATE POLICY "Users manage own study_tasks"
ON public.study_tasks FOR ALL
TO authenticated
USING ((auth.uid())::text = user_id)
WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own quiz_attempts" ON public.quiz_attempts;
CREATE POLICY "Users manage own quiz_attempts"
ON public.quiz_attempts FOR ALL
TO authenticated
USING ((auth.uid())::text = user_id)
WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own flashcard_decks" ON public.flashcard_decks;
CREATE POLICY "Users manage own flashcard_decks"
ON public.flashcard_decks FOR ALL
TO authenticated
USING ((auth.uid())::text = user_id)
WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own study_sessions" ON public.study_sessions;
CREATE POLICY "Users manage own study_sessions"
ON public.study_sessions FOR ALL
TO authenticated
USING ((auth.uid())::text = user_id)
WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own user_files" ON public.user_files;
CREATE POLICY "Users manage own user_files"
ON public.user_files FOR ALL
TO authenticated
USING ((auth.uid())::text = user_id)
WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS "Users manage own document_chunks" ON public.document_chunks;
CREATE POLICY "Users manage own document_chunks"
ON public.document_chunks FOR ALL
TO authenticated
USING ((auth.uid())::text = user_id)
WITH CHECK ((auth.uid())::text = user_id);

-- 4. Harden `match_document_chunks`: SECURITY INVOKER, fixed search_path,
--    strict auth.uid() enforcement (ignoring spoofed filter_user_id), anon revoked.
CREATE OR REPLACE FUNCTION public.match_document_chunks (
  query_embedding VECTOR(768),
  match_count INT DEFAULT 4,
  filter_user_id TEXT DEFAULT NULL,
  filter_notebook_id TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  notebook_id TEXT,
  file_name TEXT,
  chunk_index INT,
  content TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  effective_user_id TEXT;
BEGIN
  effective_user_id := auth.uid()::text;

  IF effective_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Authenticated session required for vector search';
  END IF;

  RETURN QUERY
  SELECT
    dc.id,
    dc.notebook_id,
    dc.file_name,
    dc.chunk_index,
    dc.content,
    (1 - (dc.embedding <=> query_embedding))::FLOAT AS similarity
  FROM public.document_chunks dc
  WHERE
    dc.user_id = effective_user_id
    AND (filter_notebook_id IS NULL OR dc.notebook_id = filter_notebook_id)
  ORDER BY dc.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

REVOKE ALL ON FUNCTION public.match_document_chunks(VECTOR(768), INT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.match_document_chunks(VECTOR(768), INT, TEXT, TEXT) TO authenticated;
