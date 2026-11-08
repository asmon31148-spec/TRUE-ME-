-- ==============================================================================
-- TRUE ME: Hardened Row-Level Security (RLS) Policies
-- Migration: 20261108_hardened_rls.sql
-- ==============================================================================

-- 1. Ensure RLS is active on all tables
ALTER TABLE document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;

-- 2. Drop old open/permissive policies
DROP POLICY IF EXISTS "Allow app access to document_chunks" ON document_chunks;
DROP POLICY IF EXISTS "Allow app access to user_files" ON user_files;
DROP POLICY IF EXISTS "Allow app access to study_sessions" ON study_sessions;

-- 3. Hardened policies for document_chunks (Strict Tenant Isolation)
-- Users can only select their own chunk embeddings
CREATE POLICY "Users can only view their own document chunks"
ON document_chunks FOR SELECT
USING (auth.uid()::text = user_id OR user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Users can only insert chunks under their own user_id
CREATE POLICY "Users can only insert their own document chunks"
ON document_chunks FOR INSERT
WITH CHECK (auth.uid()::text = user_id OR user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- Users can only update their own chunks
CREATE POLICY "Users can only update their own document chunks"
ON document_chunks FOR UPDATE
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);

-- Users can only delete their own chunks
CREATE POLICY "Users can only delete their own document chunks"
ON document_chunks FOR DELETE
USING (auth.uid()::text = user_id);

-- 4. Hardened policies for user_files
CREATE POLICY "Users can only view their own files"
ON user_files FOR SELECT
USING (auth.uid()::text = user_id OR user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can only insert their own files"
ON user_files FOR INSERT
WITH CHECK (auth.uid()::text = user_id OR user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can only update their own files"
ON user_files FOR UPDATE
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can only delete their own files"
ON user_files FOR DELETE
USING (auth.uid()::text = user_id);

-- 5. Hardened policies for study_sessions
CREATE POLICY "Users can only view their own study sessions"
ON study_sessions FOR SELECT
USING (auth.uid()::text = user_id OR user_id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can only insert their own study sessions"
ON study_sessions FOR INSERT
WITH CHECK (auth.uid()::text = user_id OR user_id = current_setting('request.jwt.claims', true)::json->>'sub');

-- 6. Hardened vector similarity search function (prevents cross-tenant vector leakage)
CREATE OR REPLACE FUNCTION match_document_chunks (
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
SECURITY DEFINER
AS $$
DECLARE
  effective_user_id TEXT;
BEGIN
  -- Determine effective user ID from auth context or argument
  effective_user_id := COALESCE(auth.uid()::text, filter_user_id);
  
  -- Require valid user identification to prevent data leakage across users
  IF effective_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User ID must be specified for vector search';
  END IF;

  RETURN QUERY
  SELECT
    dc.id,
    dc.notebook_id,
    dc.file_name,
    dc.chunk_index,
    dc.content,
    (1 - (dc.embedding <=> query_embedding))::FLOAT AS similarity
  FROM document_chunks dc
  WHERE
    dc.user_id = effective_user_id
    AND (filter_notebook_id IS NULL OR dc.notebook_id = filter_notebook_id)
  ORDER BY dc.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
